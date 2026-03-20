const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// POST /api/fcm-tokens/register
const registerToken = async (req, res) => {
  try {
    const { token, deviceId, platform, deviceType } = req.body;
    const userId = req.user.userId;

    // Only strictly require token
    if (!token) {
      return sendError(res, 'token is required', 400, 'INVALID_INPUT');
    }

    // Gracefully resolve platform and safe fallback
    const resolvedPlatform = platform || deviceType || 'ANDROID';
    let platformUpper = String(resolvedPlatform).toUpperCase();
    if (!['ANDROID', 'IOS'].includes(platformUpper)) {
      platformUpper = 'ANDROID';
    }

    // Safely parse deviceId
    let parsedDeviceId = null;
    if (deviceId) {
      const parsed = parseInt(deviceId);
      if (!isNaN(parsed)) parsedDeviceId = parsed;
    }

    // Upsert: nếu token đã tồn tại → update userId/deviceId
    await prisma.fCMToken.upsert({
      where: { token },
      update: {
        userId,
        deviceId: parsedDeviceId,
        platform: platformUpper
      },
      create: {
        userId,
        deviceId: parsedDeviceId,
        token,
        platform: platformUpper
      }
    });

    sendSuccess(res, { message: 'Token registered' });
  } catch (error) {
    console.error('Register FCM token error:', error);
    sendError(res, 'Failed to register token', 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/fcm-tokens/unregister
const unregisterToken = async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return sendError(res, 'token is required', 400, 'INVALID_INPUT');
    }

    const existing = await prisma.fCMToken.findUnique({ where: { token } });

    if (!existing) {
      return sendError(res, 'Token not found', 404, 'NOT_FOUND');
    }

    await prisma.fCMToken.delete({ where: { token } });

    sendSuccess(res, { message: 'Token removed' });
  } catch (error) {
    console.error('Unregister FCM token error:', error);
    sendError(res, 'Failed to unregister token', 500, 'INTERNAL_ERROR');
  }
};

module.exports = { registerToken, unregisterToken };
