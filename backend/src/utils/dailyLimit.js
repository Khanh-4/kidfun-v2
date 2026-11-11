// Hạn mức hiệu lực của một ngày — nguồn DUY NHẤT cho mọi endpoint tính thời gian
// còn lại (today-limit, heartbeat, status, pause/resume, duyệt xin thêm giờ).
//
// Lỗi 11/11: calcRemaining dùng `dailyLimitMinutes || 120` còn today-limit dùng
// `dailyLimitMinutes || limitMinutes || 0` và có tính giảm dần. Phụ huynh đặt
// 0 phút → today-limit nói còn 158s, heartbeat nói còn 7298s, app trẻ "sửa drift"
// theo heartbeat nên bộ đếm nhảy ~2 tiếng. Số 0 là hạn mức hợp lệ, phải dùng `??`.

/** Khớp @default(120) của TimeLimit.dailyLimitMinutes trong schema. */
const DEFAULT_DAILY_LIMIT_MINUTES = 120;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * @param {{ dailyLimitMinutes?: number|null, isGradual?: boolean, gradualTarget?: number|null,
 *           gradualWeeks?: number|null, gradualStartDate?: Date|string|null } | null | undefined} timeLimit
 * @param {Date} [now]
 * @returns {number} số phút được dùng trong ngày (chưa gồm phút thưởng/xin thêm)
 */
const effectiveDailyLimit = (timeLimit, now = new Date()) => {
  if (!timeLimit) return DEFAULT_DAILY_LIMIT_MINUTES;

  const base = timeLimit.dailyLimitMinutes ?? DEFAULT_DAILY_LIMIT_MINUTES;

  const { isGradual, gradualTarget, gradualWeeks, gradualStartDate } = timeLimit;
  if (!isGradual || gradualTarget == null || !gradualWeeks || !gradualStartDate) return base;

  // Chênh lệch hai mốc thật — không phụ thuộc timezone.
  const weeksElapsed = Math.floor((now - new Date(gradualStartDate)) / WEEK_MS);
  if (weeksElapsed >= gradualWeeks) return gradualTarget;

  return Math.round(base - (base - gradualTarget) * (weeksElapsed / gradualWeeks));
};

module.exports = { effectiveDailyLimit, DEFAULT_DAILY_LIMIT_MINUTES };
