const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');

// Helper: notify child devices of profile that app time limits changed
const notifyAppTimeLimitUpdated = async (profileId) => {
  const io = socketService.io;
  if (!io) return;

  const devices = await prisma.device.findMany({ where: { profileId } });
  for (const d of devices) {
    io.to(`device_${d.deviceCode}`).emit('appTimeLimitUpdated', { profileId });
  }
};

// GET /api/profiles/:id/app-time-limits
const getAppTimeLimits = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const limits = await prisma.appTimeLimit.findMany({
      where: { profileId, isActive: true },
      orderBy: { appName: 'asc' },
    });
    return sendSuccess(res, { limits });
  } catch (err) {
    console.error('getAppTimeLimits error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles/:id/app-time-limits — upsert (tạo mới hoặc cập nhật)
const upsertAppTimeLimit = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { packageName, appName, dailyLimitMinutes } = req.body;

    if (!packageName || typeof dailyLimitMinutes !== 'number' || dailyLimitMinutes < 0) {
      return sendError(res, 'packageName and dailyLimitMinutes (number >= 0) are required', 400, 'INVALID_DATA');
    }

    const limit = await prisma.appTimeLimit.upsert({
      where: { profileId_packageName: { profileId, packageName } },
      update: { dailyLimitMinutes, appName: appName || null, isActive: true },
      create: { profileId, packageName, appName: appName || null, dailyLimitMinutes, isActive: true },
    });

    await notifyAppTimeLimitUpdated(profileId);

    return sendSuccess(res, { limit }, 201);
  } catch (err) {
    console.error('upsertAppTimeLimit error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/profiles/:id/app-time-limits/:packageName
const deleteAppTimeLimit = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const packageName = decodeURIComponent(req.params.packageName);

    await prisma.appTimeLimit.deleteMany({ where: { profileId, packageName } });

    await notifyAppTimeLimitUpdated(profileId);

    return sendSuccess(res, { message: 'App time limit deleted' });
  } catch (err) {
    console.error('deleteAppTimeLimit error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/child/app-time-limits?deviceCode=XXX — Child sync
const getChildAppTimeLimits = async (req, res) => {
  try {
    const { deviceCode } = req.query;

    if (!deviceCode) {
      return sendError(res, 'deviceCode query param required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: { appTimeLimits: { where: { isActive: true } } },
        },
      },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    // Lấy usage hôm nay
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayUsage = await prisma.appUsageLog.findMany({
      where: { profileId: device.profile.id, date: today },
    });

    const limits = device.profile.appTimeLimits.map((limit) => {
      const usage = todayUsage.find((u) => u.packageName === limit.packageName);
      const usedSeconds = usage?.usageSeconds || 0;
      const remainingSeconds = Math.max(0, limit.dailyLimitMinutes * 60 - usedSeconds);
      return {
        packageName: limit.packageName,
        appName: limit.appName,
        dailyLimitMinutes: limit.dailyLimitMinutes,
        usedSeconds,
        remainingSeconds,
      };
    });

    return sendSuccess(res, { limits });
  } catch (err) {
    console.error('getChildAppTimeLimits error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getAppTimeLimits, upsertAppTimeLimit, deleteAppTimeLimit, getChildAppTimeLimits };
