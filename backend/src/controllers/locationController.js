const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { checkGeofenceEvents } = require('../services/geofenceService');
const socketService = require('../services/socketService');
const { sendDataMessage } = require('../services/firebaseService');

// POST /api/profiles/:id/location/request — Parent yêu cầu máy trẻ gửi vị trí
// ngay. Thay cho event Socket.IO 'requestLocation' (chết từ khi lên Vercel):
// gửi lệnh FCM data-only 'location_request', máy trẻ lấy GPS rồi gọi
// POST /api/child/location như bình thường → phụ huynh nhận qua Realtime.
exports.requestLocation = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const devices = await prisma.device.findMany({
      where: { profileId },
      select: { id: true },
    });
    if (devices.length === 0) {
      return sendError(res, 'Chưa có thiết bị nào liên kết với hồ sơ này', 404, 'NO_DEVICE');
    }

    const tokens = await prisma.fCMToken.findMany({
      where: { deviceId: { in: devices.map(d => d.id) } },
      select: { token: true },
    });
    if (tokens.length === 0) {
      return sendError(res, 'Máy của bé chưa đăng ký nhận lệnh, hãy mở app KidFun trên máy bé', 409, 'NO_FCM_TOKEN');
    }

    const results = await Promise.allSettled(
      tokens.map(t => sendDataMessage(t.token, { type: 'location_request', profileId: String(profileId) })),
    );
    const invalidTokens = results
      .filter(r => r.status === 'fulfilled' && r.value?.error === 'INVALID_TOKEN')
      .map(r => r.value.token);
    const sent = results.filter(r => r.status === 'fulfilled' && r.value && !r.value.error).length;

    if (invalidTokens.length > 0) {
      await prisma.fCMToken.deleteMany({ where: { token: { in: invalidTokens } } });
    }
    console.log(`📍 [LOCATION] Requested location for profile ${profileId}: sent ${sent}/${tokens.length}`);

    if (sent === 0) {
      return sendError(res, 'Không gửi được yêu cầu tới máy của bé', 502, 'FCM_FAILED');
    }
    return sendSuccess(res, { sent });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// POST /api/child/location — Child gửi GPS (no auth, dùng deviceCode)
exports.postLocation = async (req, res) => {
  try {
    const { deviceCode, latitude, longitude, accuracy, source } = req.body;

    if (!deviceCode || typeof latitude !== 'number' || typeof longitude !== 'number') {
      return sendError(res, 'Invalid location data', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const log = await prisma.locationLog.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        latitude,
        longitude,
        accuracy: accuracy ?? null,
        source: source || 'GPS',
      },
    });

    // Notify Parent qua Socket.IO
    const io = socketService.io;
    if (io) {
      io.to(`family_${device.profile.userId}`).emit('locationUpdated', {
        profileId: device.profile.id,
        latitude,
        longitude,
        accuracy: accuracy ?? null,
        timestamp: log.createdAt,
      });
    }

    // Kiểm tra geofence events (Task 4)
    await checkGeofenceEvents(device.profile.id, latitude, longitude, io);

    return sendSuccess(res, { id: log.id }, 201);
  } catch (err) {
    console.error('❌ [postLocation] Error:', err.message);
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/location/current — Parent lấy vị trí mới nhất
exports.getCurrentLocation = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const latest = await prisma.locationLog.findFirst({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
    });

    if (!latest) {
      return sendError(res, 'No location data yet', 404);
    }

    return sendSuccess(res, { location: latest });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/location/history?date=YYYY-MM-DD — Lịch sử theo ngày
exports.getLocationHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);

    // Dùng múi giờ Việt Nam (UTC+7) để tính đầu/cuối ngày
    const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
    const todayVN = new Date(Date.now() + VN_OFFSET_MS).toISOString().split('T')[0];
    const dateStr = req.query.date || todayVN;

    const [year, month, day] = dateStr.split('-').map(Number);
    const startOfDay = new Date(Date.UTC(year, month - 1, day, 0, 0, 0) - VN_OFFSET_MS);
    const endOfDay   = new Date(Date.UTC(year, month - 1, day + 1, 0, 0, 0) - VN_OFFSET_MS);

    const history = await prisma.locationLog.findMany({
      where: {
        profileId,
        createdAt: { gte: startOfDay, lt: endOfDay },
      },
      orderBy: { createdAt: 'asc' },
    });

    return sendSuccess(res, { date: dateStr, count: history.length, history });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
