const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/profiles/:id/activity-history?date=YYYY-MM-DD
exports.getActivityHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const start = new Date(dateStr);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const activities = [];

    // 1. Usage sessions
    const sessions = await prisma.usageSession.findMany({
      where: { profileId, startTime: { gte: start, lt: end } },
    });
    for (const s of sessions) {
      activities.push({
        type: 'SESSION_START',
        timestamp: s.startTime,
        title: 'Bắt đầu dùng điện thoại',
        description: null,
        icon: 'phone_android',
      });
      if (s.endTime) {
        activities.push({
          type: 'SESSION_END',
          timestamp: s.endTime,
          title: 'Kết thúc phiên dùng',
          description: `${Math.round((new Date(s.endTime) - new Date(s.startTime)) / 1000 / 60)} phút`,
          icon: 'stop',
        });
      }
    }

    // 2. Geofence events
    const geofenceEvents = await prisma.geofenceEvent.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
      include: { geofence: true },
    });
    for (const e of geofenceEvents) {
      activities.push({
        type: e.type === 'ENTER' ? 'GEOFENCE_ENTER' : 'GEOFENCE_EXIT',
        timestamp: e.createdAt,
        title: e.type === 'ENTER' ? `Vào ${e.geofence.name}` : `Rời ${e.geofence.name}`,
        description: null,
        icon: 'place',
      });
    }

    // 3. Time extension requests
    const extensions = await prisma.timeExtensionRequest.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
    });
    for (const ext of extensions) {
      activities.push({
        type: 'TIME_EXTENSION',
        timestamp: ext.createdAt,
        title: `Xin thêm ${ext.requestMinutes} phút`,
        description: `Trạng thái: ${ext.status}`,
        icon: 'access_time',
      });
    }

    // 4. SOS alerts
    const sos = await prisma.sOSAlert.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
    });
    for (const s of sos) {
      activities.push({
        type: 'SOS',
        timestamp: s.createdAt,
        title: '🆘 Gửi SOS khẩn cấp',
        description: s.message || null,
        icon: 'warning',
      });
    }

    // 5. AI alerts
    const aiAlerts = await prisma.aIAlert.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
      include: { youtubeLog: true },
    });
    for (const a of aiAlerts) {
      activities.push({
        type: 'AI_ALERT',
        timestamp: a.createdAt,
        title: `⚠️ Cảnh báo AI: ${a.category}`,
        description: a.summary,
        icon: 'psychology',
      });
    }

    // 6. Soft warnings
    const warnings = await prisma.warning.findMany({
      where: { profileId, warnedAt: { gte: start, lt: end } },
    });
    for (const w of warnings) {
      activities.push({
        type: 'WARNING',
        timestamp: w.warnedAt,
        title: `Cảnh báo: ${w.message}`,
        description: null,
        icon: 'notifications',
      });
    }

    // Sort newest first
    activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    return sendSuccess(res, { date: dateStr, count: activities.length, activities });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
