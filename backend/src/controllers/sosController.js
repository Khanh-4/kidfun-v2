const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');
const { sendSOSPushNotification } = require('../services/fcmService');

// POST /api/child/sos — Child gửi SOS (multipart/form-data, no auth)
exports.createSOS = async (req, res) => {
  try {
    const deviceCode = req.body.deviceCode || req.headers['x-device-code'];
    const { latitude, longitude, message } = req.body;

    if (!deviceCode || !latitude || !longitude) {
      return sendError(res, 'Missing required fields', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: { include: { user: true } } },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const audioUrl = req.file ? `/uploads/sos-audio/${req.file.filename}` : null;

    const sos = await prisma.sOSAlert.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        audioUrl,
        message: message || null,
        status: 'ACTIVE',
      },
    });

    // Emit Socket.IO ngay lập tức
    const io = socketService.io;
    if (io) {
      io.to(`family_${device.profile.userId}`).emit('sosAlert', {
        sosId: sos.id,
        profileId: device.profile.id,
        profileName: device.profile.profileName,
        latitude: sos.latitude,
        longitude: sos.longitude,
        audioUrl: audioUrl ? `${req.protocol}://${req.get('host')}${audioUrl}` : null,
        message: sos.message,
        timestamp: sos.createdAt,
      });
    }

    // Push notification CRITICAL (Task 7 implement đầy đủ)
    await sendSOSPushNotification(device.profile.user, device.profile, sos);

    return sendSuccess(res, { sos }, 201);
  } catch (err) {
    console.error('❌ [SOS] Error:', err.message);
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/sos — Lịch sử SOS của profile
exports.getSOSHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const alerts = await prisma.sOSAlert.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return sendSuccess(res, { alerts });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// PUT /api/sos/:id/acknowledge — Parent xác nhận đã nhận SOS
exports.acknowledgeSOS = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const sos = await prisma.sOSAlert.update({
      where: { id },
      data: { status: 'ACKNOWLEDGED', acknowledgedAt: new Date() },
    });

    // Thông báo lại cho child device biết đã được nhận
    const io = socketService.io;
    if (io) {
      const device = await prisma.device.findUnique({ where: { id: sos.deviceId } });
      if (device) {
        io.to(`device_${device.deviceCode}`).emit('sosAcknowledged', { sosId: id });
      }
    }

    return sendSuccess(res, { sos });
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'SOS alert not found', 404);
    return sendError(res, err.message, 500);
  }
};

// PUT /api/sos/:id/resolve — Parent đánh dấu đã giải quyết
exports.resolveSOS = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const sos = await prisma.sOSAlert.update({
      where: { id },
      data: { status: 'RESOLVED', resolvedAt: new Date() },
    });
    return sendSuccess(res, { sos });
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'SOS alert not found', 404);
    return sendError(res, err.message, 500);
  }
};
