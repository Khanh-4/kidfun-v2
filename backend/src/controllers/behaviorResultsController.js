/**
 * POST /api/cron/behavior-results — tác vụ ML ban đêm (đồ án chuyên ngành, T7.2.3) gửi kết quả lên.
 *
 * Body: { modelVersion, predictions: [{ profileId, date 'YYYY-MM-DD', predictedMinutes, pOverLimit?,
 *         limitMinutes?, message? }], alerts?: [{ profileId, rule, category, dayType?, slotStart, minutes,
 *         usualMinutes? }] }
 *
 * - Mọi dự đoán upsert vào UsagePrediction theo (profileId, date): chạy lại trong ngày thì ghi đè.
 * - pOverLimit ≥ M1_ALERT_THRESHOLD → server tự tạo BehaviorAlert source "M1" (ngưỡng đặt ở MỘT chỗ,
 *   theo docs/thesis/07: ≈ 5% số ngày, đúng ≈ 63%). Cảnh báo tầng 2 gửi kèm trong `alerts` → source "TIER2".
 * - Chống trùng bằng khoá unique của BehaviorAlert; chỉ cảnh báo MỚI mới gửi FCM.
 */

const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { sendBehaviorAlertPush } = require('../services/fcmService');
const { parseBehaviorAlerts, buildMessage, formatMinutes } = require('../utils/behaviorAlert');

const M1_ALERT_THRESHOLD = 0.6;
const MAX_PREDICTIONS = 500;
const MAX_MINUTES = 24 * 60;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const isNum = (v, min, max) => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;
const isOptNum = (v, min, max) => v === undefined || v === null || isNum(v, min, max);

const isValidPrediction = (p) =>
  Number.isInteger(p?.profileId) &&
  typeof p.date === 'string' &&
  DATE_RE.test(p.date) &&
  !Number.isNaN(Date.parse(`${p.date}T00:00:00Z`)) &&
  isNum(p.predictedMinutes, 0, MAX_MINUTES) &&
  isOptNum(p.pOverLimit, 0, 1) &&
  (p.limitMinutes === undefined || p.limitMinutes === null || (Number.isInteger(p.limitMinutes) && p.limitMinutes >= 0)) &&
  (p.message === undefined || p.message === null || typeof p.message === 'string');

/** "06/11" */
const formatDay = (date) => `${date.slice(8, 10)}/${date.slice(5, 7)}`;

const m1Message = (p) => {
  const pct = Math.round(p.pOverLimit * 100);
  const limit = p.limitMinutes != null ? ` ${formatMinutes(p.limitMinutes)}` : '';
  return `Dự đoán ngày ${formatDay(p.date)}: bé dùng khoảng ${formatMinutes(p.predictedMinutes)}, ` +
    `${pct}% khả năng vượt giới hạn${limit}.`;
};

/** Cảnh báo M1 nói về CẢ NGÀY → slotStart = 00:00 giờ VN của ngày được dự đoán. */
const m1Alert = (p) => ({
  profileId: p.profileId,
  source: 'M1',
  rule: 'over_limit',
  category: 'all',
  dayType: null,
  slotStart: new Date(`${p.date}T00:00:00+07:00`),
  minutes: p.predictedMinutes,
  usualMinutes: p.limitMinutes ?? null,
  message: p.message || m1Message(p),
});

const parseTier2 = (alerts) => {
  if (alerts === undefined || (Array.isArray(alerts) && alerts.length === 0)) return { valid: [], rejected: 0 };
  if (!Array.isArray(alerts) || !alerts.every((a) => Number.isInteger(a?.profileId))) {
    return { error: 'alerts must be an array of objects with integer profileId' };
  }
  const { error } = parseBehaviorAlerts(alerts);
  if (error) return { error };
  // parseBehaviorAlerts không giữ profileId → phân tích từng ô để ghép lại đúng trẻ
  const valid = [];
  let rejected = 0;
  for (const raw of alerts) {
    const [parsed] = parseBehaviorAlerts([raw]).valid;
    if (!parsed) rejected += 1;
    else valid.push({ ...parsed, profileId: raw.profileId, source: 'TIER2', message: buildMessage(parsed) });
  }
  return { valid, rejected };
};

const createAlerts = async (alerts, profiles) => {
  const created = [];
  let duplicates = 0;
  for (const alert of alerts) {
    try {
      created.push(await prisma.behaviorAlert.create({ data: alert }));
    } catch (err) {
      if (err.code !== 'P2002') throw err;
      duplicates += 1; // tác vụ chạy lại → cảnh báo đã có, không báo lại phụ huynh
    }
  }
  for (const alert of created) {
    await sendBehaviorAlertPush(profiles.get(alert.profileId), alert);
  }
  if (created.length > 0) {
    await prisma.behaviorAlert.updateMany({
      where: { id: { in: created.map((a) => a.id) } },
      data: { notifiedAt: new Date() },
    });
  }
  return { created: created.length, duplicates };
};

const upsertPrediction = (p, modelVersion) => {
  const data = {
    predictedMinutes: p.predictedMinutes,
    pOverLimit: p.pOverLimit ?? null,
    limitMinutes: p.limitMinutes ?? null,
    message: p.message ?? null,
    modelVersion,
  };
  const date = new Date(`${p.date}T00:00:00Z`);
  return prisma.usagePrediction.upsert({
    where: { profileId_date: { profileId: p.profileId, date } },
    update: data,
    create: { profileId: p.profileId, date, ...data },
  });
};

const saveResults = async (req, res) => {
  try {
    const { modelVersion, predictions, alerts } = req.body;
    if (typeof modelVersion !== 'string' || !modelVersion) {
      return sendError(res, 'modelVersion is required', 400, 'INVALID_RESULTS');
    }
    if (!Array.isArray(predictions) || predictions.length > MAX_PREDICTIONS || !predictions.every(isValidPrediction)) {
      return sendError(res, `predictions must be an array of 0..${MAX_PREDICTIONS} valid entries`, 400, 'INVALID_RESULTS');
    }
    const tier2 = parseTier2(alerts);
    if (tier2.error) return sendError(res, tier2.error, 400, 'INVALID_RESULTS');

    const ids = [...new Set([...predictions.map((p) => p.profileId), ...tier2.valid.map((a) => a.profileId)])];
    const found = await prisma.profile.findMany({
      where: { id: { in: ids } },
      select: { id: true, userId: true, profileName: true },
    });
    const profiles = new Map(found.map((p) => [p.id, p]));
    const known = predictions.filter((p) => profiles.has(p.profileId));

    await prisma.$transaction(known.map((p) => upsertPrediction(p, modelVersion)));

    const newAlerts = [
      ...known.filter((p) => p.pOverLimit != null && p.pOverLimit >= M1_ALERT_THRESHOLD).map(m1Alert),
      ...tier2.valid.filter((a) => profiles.has(a.profileId)),
    ];
    const { created, duplicates } = await createAlerts(newAlerts, profiles);

    return sendSuccess(res, {
      predictions: known.length,
      unknownProfiles: ids.filter((id) => !profiles.has(id)).length,
      alertsCreated: created,
      alertDuplicates: duplicates,
      alertsRejected: tier2.rejected,
    });
  } catch (err) {
    console.error('saveResults error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

const DEFAULT_DAYS = 14;
const MAX_DAYS = 60;
const DAY_MS = 24 * 60 * 60 * 1000;
const VN_OFFSET_MS = 7 * 60 * 60 * 1000;

// GET /api/profiles/:id/predictions?days=14 (T7.2.4) — thẻ "Ngày mai" trên app phụ huynh.
// Trả dự đoán từ (hôm nay giờ VN − days + 1) trở đi, gồm cả ngày mai; mới nhất trước.
// Hồ sơ không thuộc phụ huynh → 404 như listAlerts (không lộ là hồ sơ có tồn tại).
const listPredictions = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id, 10);
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || DEFAULT_DAYS, 1), MAX_DAYS);

    const profile = await prisma.profile.findFirst({ where: { id: profileId, userId: req.user.userId } });
    if (!profile) return sendError(res, 'Profile not found', 404, 'NOT_FOUND');

    const todayVn = new Date(Date.now() + VN_OFFSET_MS).toISOString().slice(0, 10);
    const from = new Date(Date.parse(`${todayVn}T00:00:00Z`) - (days - 1) * DAY_MS);
    const rows = await prisma.usagePrediction.findMany({
      where: { profileId, date: { gte: from } },
      orderBy: { date: 'desc' },
    });
    const predictions = rows.map((r) => ({
      date: r.date.toISOString().slice(0, 10),
      predictedMinutes: r.predictedMinutes,
      pOverLimit: r.pOverLimit,
      limitMinutes: r.limitMinutes,
      message: r.message,
      modelVersion: r.modelVersion,
    }));
    return sendSuccess(res, { predictions });
  } catch (err) {
    console.error('listPredictions error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { saveResults, listPredictions, M1_ALERT_THRESHOLD };
