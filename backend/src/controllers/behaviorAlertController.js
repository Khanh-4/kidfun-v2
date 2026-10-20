const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { sendBehaviorAlertPush } = require('../services/fcmService');
const { parseBehaviorAlerts, buildMessage, FEEDBACK } = require('../utils/behaviorAlert');

// Đồ án chuyên ngành (M2): cảnh báo hành vi + phản hồi phụ huynh + mức thường ngày cho luật tầng 1.

const MAX_BASELINES = 50;
const MAX_BASELINE_BYTES = 64 * 1024;
const DEFAULT_LIST = 50;
const MAX_LIST = 200;

const findLinkedDevice = (deviceCode) =>
  prisma.device.findFirst({
    where: { deviceCode },
    select: { id: true, profileId: true, profile: { select: { id: true, userId: true, profileName: true } } },
  });

// GET /api/child/behavior-baseline?deviceCode=XXX — máy trẻ tải mức thường ngày (null nếu server chưa tính)
const getBaseline = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    if (!deviceCode) return sendError(res, 'deviceCode is required', 400, 'MISSING_FIELDS');

    const device = await findLinkedDevice(deviceCode);
    if (!device || !device.profileId) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    const row = await prisma.behaviorBaseline.findUnique({ where: { profileId: device.profileId } });
    return sendSuccess(res, { baseline: row ? row.payload : null, validUntil: row ? row.validUntil : null });
  } catch (err) {
    console.error('getBaseline error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/behavior-alerts — tầng 1 phát hiện trên máy trẻ, gửi ngay; mỗi cảnh báo MỚI -> FCM cho phụ huynh
const createAlerts = async (req, res) => {
  try {
    const { deviceCode, alerts } = req.body;
    if (!deviceCode) return sendError(res, 'deviceCode is required', 400, 'MISSING_FIELDS');

    const { valid, rejected, error } = parseBehaviorAlerts(alerts);
    if (error) return sendError(res, error, 400, 'INVALID_ALERTS');

    const device = await findLinkedDevice(deviceCode);
    if (!device || !device.profileId) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }
    if (valid.length === 0) return sendError(res, 'No valid alerts', 400, 'INVALID_ALERTS');

    const created = [];
    let duplicates = 0;
    for (const alert of valid) {
      try {
        created.push(
          await prisma.behaviorAlert.create({
            data: {
              profileId: device.profileId,
              deviceId: device.id,
              source: 'TIER1',
              ...alert,
              message: buildMessage(alert),
            },
          })
        );
      } catch (err) {
        if (err.code !== 'P2002') throw err;
        duplicates += 1; // máy trẻ gửi lại cảnh báo đã có (vd mất mạng giữa chừng) -> bỏ qua, không báo lại
      }
    }

    for (const alert of created) {
      await sendBehaviorAlertPush(device.profile, alert);
    }
    if (created.length > 0) {
      await prisma.behaviorAlert.updateMany({
        where: { id: { in: created.map((a) => a.id) } },
        data: { notifiedAt: new Date() },
      });
    }

    return sendSuccess(res, { created: created.length, duplicates, rejected });
  } catch (err) {
    console.error('createAlerts error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/profiles/:id/behavior-alerts?limit=50 — phụ huynh xem cảnh báo của con mình
const listAlerts = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id, 10);
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || DEFAULT_LIST, 1), MAX_LIST);

    const profile = await prisma.profile.findFirst({ where: { id: profileId, userId: req.user.userId } });
    if (!profile) return sendError(res, 'Profile not found', 404, 'NOT_FOUND');

    const alerts = await prisma.behaviorAlert.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return sendSuccess(res, { alerts });
  } catch (err) {
    console.error('listAlerts error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/behavior-alerts/:id/feedback { feedback } — "Đúng là bất thường" / "Được phép (lý do)"
const setFeedback = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { feedback } = req.body;
    if (!FEEDBACK.includes(feedback)) {
      return sendError(res, `feedback must be one of ${FEEDBACK.join(', ')}`, 400, 'INVALID_FEEDBACK');
    }

    const alert = await prisma.behaviorAlert.findFirst({
      where: { id, profile: { userId: req.user.userId } },
      select: { id: true },
    });
    if (!alert) return sendError(res, 'Alert not found', 404, 'NOT_FOUND');

    const updated = await prisma.behaviorAlert.update({
      where: { id },
      data: { feedback, feedbackAt: new Date() },
    });
    return sendSuccess(res, { alert: updated });
  } catch (err) {
    console.error('setFeedback error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

const isValidBaseline = (b) => {
  const validUntil = new Date(b?.validUntil);
  return (
    Number.isInteger(b?.profileId) &&
    b.payload !== null &&
    typeof b.payload === 'object' &&
    !Array.isArray(b.payload) &&
    JSON.stringify(b.payload).length <= MAX_BASELINE_BYTES &&
    !Number.isNaN(validUntil.getTime())
  );
};

// PUT /api/cron/behavior-baselines { baselines: [{ profileId, payload, validUntil }] } — tác vụ ML ban đêm ghi lên
const upsertBaselines = async (req, res) => {
  try {
    const { baselines } = req.body;
    if (!Array.isArray(baselines) || baselines.length === 0 || baselines.length > MAX_BASELINES) {
      return sendError(res, `baselines must be an array of 1..${MAX_BASELINES}`, 400, 'INVALID_BASELINES');
    }
    if (!baselines.every(isValidBaseline)) {
      return sendError(res, 'invalid baseline entry', 400, 'INVALID_BASELINES');
    }
    const rows = baselines.map((b) => ({ profileId: b.profileId, payload: b.payload, validUntil: new Date(b.validUntil) }));

    const existing = await prisma.profile.findMany({
      where: { id: { in: rows.map((r) => r.profileId) } },
      select: { id: true },
    });
    const known = new Set(existing.map((p) => p.id));
    const toWrite = rows.filter((r) => known.has(r.profileId));

    await prisma.$transaction(
      toWrite.map((r) =>
        prisma.behaviorBaseline.upsert({
          where: { profileId: r.profileId },
          update: { payload: r.payload, validUntil: r.validUntil },
          create: r,
        })
      )
    );
    return sendSuccess(res, { saved: toWrite.length, unknownProfiles: rows.length - toWrite.length });
  } catch (err) {
    console.error('upsertBaselines error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getBaseline, createAlerts, listAlerts, setFeedback, upsertBaselines };
