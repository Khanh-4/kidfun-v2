const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// POST /api/child/fcm-token — máy trẻ (không đăng nhập, định danh bằng
// X-Device-Code) đăng ký FCM token gắn deviceId. Lệnh FCM theo deviceId
// (location_request, blocked_apps_update) chỉ tới được máy trẻ nhờ route này.
// userId = chủ máy (FCMToken.userId bắt buộc); token trùng → gắn lại sang máy trẻ.
const registerChildToken = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { token } = req.body || {};
    if (!deviceCode) {
      return sendError(res, 'Device code required in X-Device-Code header', 400, 'MISSING_DEVICE_CODE');
    }
    if (!token || typeof token !== 'string') {
      return sendError(res, 'token is required', 400, 'INVALID_INPUT');
    }

    const device = await prisma.device.findUnique({ where: { deviceCode }, select: { id: true, userId: true } });
    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    await prisma.fCMToken.upsert({
      where: { token },
      update: { userId: device.userId, deviceId: device.id, platform: 'ANDROID' },
      create: { userId: device.userId, deviceId: device.id, token, platform: 'ANDROID' },
    });
    sendSuccess(res, { message: 'Token registered' });
  } catch (error) {
    console.error('Register child FCM token error:', error);
    sendError(res, 'Failed to register token', 500, 'INTERNAL_ERROR');
  }
};

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
      // Không gửi deviceId thì giữ nguyên deviceId cũ — tránh việc app phụ
      // huynh trên cùng máy xoá liên kết token↔máy trẻ (lệnh FCM sẽ mất người nhận).
      update: {
        userId,
        ...(parsedDeviceId !== null && { deviceId: parsedDeviceId }),
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

module.exports = { registerToken, registerChildToken, unregisterToken };
