/**
 * Kiểm tra và chuẩn hoá dữ liệu thời gian dùng app theo giờ do máy trẻ gửi lên
 * (POST /api/child/app-usage/hourly — đồ án chuyên ngành).
 *
 * Máy trẻ tính lại TOÀN BỘ các giờ từ 00:00 hôm qua đến hiện tại rồi gửi giá trị
 * tuyệt đối của từng ô (giờ, app); server ghi đè. Vì vậy một ô hỏng không được
 * làm hỏng cả lô: ô sai bị loại và đếm vào `rejected`, các ô còn lại vẫn được lưu.
 * Nếu không thì một ô lỗi (vd đồng hồ máy trẻ sai) sẽ chặn dữ liệu mãi mãi vì
 * lần sau máy trẻ lại gửi đúng ô đó.
 */

const HOUR_MS = 60 * 60 * 1000;
const MAX_BUCKETS = 500;
const MAX_AGE_MS = 7 * 24 * HOUR_MS;
// Đồng hồ máy trẻ có thể nhanh hơn server vài phút → đã sang giờ mới.
const CLOCK_SKEW_MS = 10 * 60 * 1000;
const MAX_PACKAGE_LENGTH = 255;
const MAX_LAUNCH_COUNT = 1000;

const isNonNegativeInt = (value, max) =>
  Number.isInteger(value) && value >= 0 && value <= max;

const parseBucket = (raw, nowMs) => {
  if (!raw || typeof raw !== 'object') return null;

  const { packageName, appName, hourStart, usageSeconds, launchCount = 0 } = raw;

  if (typeof packageName !== 'string' || packageName.length === 0) return null;
  if (packageName.length > MAX_PACKAGE_LENGTH) return null;
  if (!isNonNegativeInt(usageSeconds, 3600)) return null;
  if (!isNonNegativeInt(launchCount, MAX_LAUNCH_COUNT)) return null;

  const hourMs = typeof hourStart === 'string' ? Date.parse(hourStart) : NaN;
  if (Number.isNaN(hourMs) || hourMs % HOUR_MS !== 0) return null;
  if (hourMs > nowMs + CLOCK_SKEW_MS) return null;
  if (hourMs < nowMs - MAX_AGE_MS) return null;

  return {
    packageName,
    appName: typeof appName === 'string' && appName.length > 0 ? appName.slice(0, 255) : null,
    hourStart: new Date(hourMs),
    usageSeconds,
    launchCount,
  };
};

/**
 * @param {unknown} buckets  mảng ô thô từ request body
 * @param {Date} now
 * @returns {{ valid: Array<{packageName: string, appName: string|null, hourStart: Date,
 *   usageSeconds: number, launchCount: number}>, rejected: number, error?: string }}
 */
const parseHourlyBuckets = (buckets, now = new Date()) => {
  if (!Array.isArray(buckets) || buckets.length === 0) {
    return { valid: [], rejected: 0, error: 'buckets[] is required' };
  }
  if (buckets.length > MAX_BUCKETS) {
    return { valid: [], rejected: 0, error: `buckets[] must have at most ${MAX_BUCKETS} items` };
  }

  const nowMs = now.getTime();
  const byKey = new Map();
  let rejected = 0;

  for (const raw of buckets) {
    const parsed = parseBucket(raw, nowMs);
    if (!parsed) {
      rejected += 1;
      continue;
    }
    // Ô trùng khoá upsert trong cùng một transaction → giữ ô sau cùng
    byKey.set(`${parsed.packageName}|${parsed.hourStart.getTime()}`, parsed);
  }

  return { valid: [...byKey.values()], rejected };
};

module.exports = { parseHourlyBuckets, MAX_BUCKETS };
