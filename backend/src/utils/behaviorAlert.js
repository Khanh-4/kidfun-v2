/**
 * Cảnh báo hành vi tầng 1 do máy trẻ gửi lên (POST /api/child/behavior-alerts — đồ án chuyên ngành).
 *
 * Máy trẻ chỉ gửi SỐ LIỆU (luật, nhóm app, ô giờ, số phút); câu tiếng Việt gửi phụ huynh do server
 * dựng, cùng mẫu câu với ml/models/explain.py, để sửa câu chữ không phải phát hành lại app trẻ.
 * Ô sai bị loại và đếm vào `rejected`, ô còn lại vẫn xử lý (cùng cách với hourlyUsage.js).
 */

const HOUR_MS = 60 * 60 * 1000;
const VN_OFFSET_MS = 7 * HOUR_MS;
const MAX_ALERTS = 20;
const MAX_AGE_MS = 48 * HOUR_MS;
const CLOCK_SKEW_MS = 10 * 60 * 1000;

const RULES = ['night', 'spike'];
const CATEGORIES = ['video', 'game', 'social', 'study', 'other'];
const DAY_TYPES = ['school', 'weekend', 'off'];
const FEEDBACK = ['CONFIRMED', 'ALLOWED_WEEKEND', 'ALLOWED_HOLIDAY', 'ALLOWED_OTHER'];

const ACTIVITY_VI = {
  video: 'xem video',
  game: 'chơi game',
  social: 'dùng mạng xã hội',
  study: 'dùng app học tập',
  other: 'dùng ứng dụng khác',
};

const isMinutes = (value) => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 60;

const parseAlert = (raw, nowMs) => {
  if (!raw || typeof raw !== 'object') return null;
  const { rule, category, dayType, slotStart, minutes, usualMinutes = null } = raw;

  if (!RULES.includes(rule) || !CATEGORIES.includes(category)) return null;
  if (dayType != null && !DAY_TYPES.includes(dayType)) return null;
  if (!isMinutes(minutes)) return null;
  if (usualMinutes !== null && !isMinutes(usualMinutes)) return null;

  const slotMs = typeof slotStart === 'string' ? Date.parse(slotStart) : NaN;
  if (Number.isNaN(slotMs) || slotMs % HOUR_MS !== 0) return null;
  if (slotMs > nowMs + CLOCK_SKEW_MS || slotMs < nowMs - MAX_AGE_MS) return null;

  return { rule, category, dayType: dayType ?? null, slotStart: new Date(slotMs), minutes, usualMinutes };
};

const parseBehaviorAlerts = (alerts, nowMs = Date.now()) => {
  if (!Array.isArray(alerts) || alerts.length === 0) return { error: 'alerts must be a non-empty array' };
  if (alerts.length > MAX_ALERTS) return { error: `at most ${MAX_ALERTS} alerts per request` };
  const valid = [];
  let rejected = 0;
  for (const raw of alerts) {
    const parsed = parseAlert(raw, nowMs);
    if (parsed) valid.push(parsed);
    else rejected += 1;
  }
  return { valid, rejected };
};

/** "45 phút", "1 giờ", "2 giờ 30 phút" */
const formatMinutes = (m) => {
  const total = Math.round(m);
  if (total < 60) return `${total} phút`;
  const h = Math.floor(total / 60);
  const rest = total % 60;
  return rest ? `${h} giờ ${rest} phút` : `${h} giờ`;
};

/** "gấp 3 lần" (>= 2 làm tròn số nguyên), "gấp 1,5 lần" */
const formatTimes = (ratio) =>
  ratio >= 2 ? `gấp ${Math.round(ratio)} lần` : `gấp ${ratio.toFixed(1).replace('.', ',')} lần`;

const vnHour = (date) => new Date(date.getTime() + VN_OFFSET_MS).getUTCHours();

const buildMessage = ({ rule, category, slotStart, minutes, usualMinutes }) => {
  const activity = ACTIVITY_VI[category];
  const hour = vnHour(slotStart);
  if (rule === 'night') {
    return `Bé ${activity} lúc ${hour}h trong ${formatMinutes(minutes)} — giờ này bé thường đã ngủ.`;
  }
  const usual = usualMinutes ?? 0;
  if (usual < 1) {
    return `Bé ${activity} lúc ${hour}h trong ${formatMinutes(minutes)} — giờ này bé thường hầu như không ${activity}.`;
  }
  return (
    `Bé ${activity} lúc ${hour}h ${formatTimes(minutes / usual)} so với bình thường ` +
    `(${formatMinutes(minutes)}, thường khoảng ${formatMinutes(usual)}).`
  );
};

module.exports = { parseBehaviorAlerts, buildMessage, formatMinutes, formatTimes, FEEDBACK, MAX_ALERTS };
