const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const socketService = require('../services/socketService');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { sendPushToUser } = require('../services/firebaseService');

exports.logWarning = async (req, res) => {
  try {
    // Read deviceCode from header (primary) or body (fallback) — matches all other child endpoints
    const deviceCode = req.headers['x-device-code'] || req.body.deviceCode;
    if (!deviceCode) {
      return sendError(res, 'Device code required', 400);
    }

    const { type, warningType, message } = req.body;
    let actualType = type || warningType || 'UNKNOWN';

    // Map Flutter types to backend types if necessary
    if (actualType === 'TIME_30_MIN') actualType = 'SOFT_30';
    else if (actualType === 'TIME_15_MIN') actualType = 'SOFT_15';
    else if (actualType === 'TIME_5_MIN') actualType = 'SOFT_5';


    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const warning = await prisma.warning.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,                               // BUG 1 FIX: persist deviceId
        warningType: actualType,                           // matches DB schema
        message: message || `Cảnh báo ${actualType} cho ${device.profile.profileName}`,
      },
    });

    // Notify Parent qua Socket.IO
    socketService.notifyFamily(device.userId, 'softWarning', {
      profileId: device.profile.id,
      profileName: device.profile.profileName,
      type: actualType,
      message: warning.message,
      createdAt: warning.warnedAt, // Using warnedAt to match DB schema
    });

    // Push notification cho Parent (FCM)
    const warningLabels = {
      SOFT_30: '30 phút',
      SOFT_15: '15 phút',
      SOFT_5: '5 phút',
      TIME_UP: 'Hết giờ',
    };

    await sendPushToUser(device.userId, {
      title: `⏰ ${device.profile.profileName}`,
      body: `Còn ${warningLabels[actualType] || actualType} sử dụng thiết bị`,
      data: { type: 'soft_warning', profileId: String(device.profile.id), warningType: actualType },
    });

    return sendSuccess(res, { warningId: warning.id }, 201);
  } catch (err) {
    console.error('Warning Controller Error:', err);
    return sendError(res, err.message, 500);
  }
};

exports.getWarnings = async (req, res) => {
  try {
    const warnings = await prisma.warning.findMany({
      where: { profileId: parseInt(req.params.id) },
      orderBy: { warnedAt: 'desc' }, // Used warnedAt to match Schema
      take: 50,
    });

    return sendSuccess(res, { warnings });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
