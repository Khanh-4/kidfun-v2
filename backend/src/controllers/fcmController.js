const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// POST /api/fcm-tokens/register
const registerToken = async (req, res) => {
  try {
    const { token, deviceId } = req.body;
    const { platform, deviceType } = req.body;
    const userId = req.user.userId;

    const resolvedPlatform = platform || deviceType;

    if (!token || !resolvedPlatform) {
      return sendError(res, 'token and platform/deviceType are required', 400, 'INVALID_INPUT');
    }

    const platformUpper = resolvedPlatform.toUpperCase();
    if (!['ANDROID', 'IOS'].includes(platformUpper)) {
      return sendError(res, 'platform must be ANDROID or IOS', 400, 'INVALID_INPUT');
    }

    // Upsert: nếu token đã tồn tại → update userId/deviceId
    await prisma.fCMToken.upsert({
      where: { token },
      update: {
        userId,
        deviceId: deviceId ? parseInt(deviceId) : null,
        platform: platformUpper
      },
      create: {
        userId,
        deviceId: deviceId ? parseInt(deviceId) : null,
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
