const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { checkGeofenceEvents } = require('../services/geofenceService');
const socketService = require('../services/socketService');

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
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];

    const startOfDay = new Date(dateStr);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

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
