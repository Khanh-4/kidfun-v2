const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// Helper: calculate remaining minutes for a profile today, including bonus
const calcRemaining = async (profileId, deviceId) => {
  const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
  const dayOfWeek = vnNow.getDay();

  const timeLimit = await prisma.timeLimit.findUnique({
    where: {
      profileId_dayOfWeek: { profileId, dayOfWeek }
    }
  });

  const dailyLimitMinutes = timeLimit?.dailyLimitMinutes || 120;

  const startOfDay = new Date(vnNow);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(vnNow);
  endOfDay.setHours(23, 59, 59, 999);

  // Auto-close stale ACTIVE sessions from previous days
  const staleSessions = await prisma.session.findMany({
    where: {
      deviceId,
      status: 'ACTIVE',
      startTime: { lt: startOfDay }
    }
  });

  if (staleSessions.length > 0) {
    const now = new Date();
    for (const session of staleSessions) {
      const durationMinutes = Math.floor((now - new Date(session.startTime)) / 60000);
      await prisma.session.update({
        where: { id: session.id },
        data: {
          status: 'COMPLETED',
          endTime: now,
          totalMinutes: durationMinutes
        }
      });
    }
  }

  const usageLogs = await prisma.usageLog.findMany({
    where: {
      profileId,
      startTime: { gte: startOfDay, lte: endOfDay }
    }
  });

  const totalSeconds = usageLogs.reduce((sum, log) => sum + (log.durationSeconds || 0), 0);
  const usedMinutes = Math.round(totalSeconds / 60);

  // Get bonus from active session started TODAY only
  const activeSession = await prisma.session.findFirst({
    where: {
      deviceId,
      status: 'ACTIVE',
      startTime: { gte: startOfDay }
    },
    orderBy: { startTime: 'desc' }
  });
  const sessionBonus = activeSession?.bonusMinutes || 0;

  const extensions = await prisma.timeExtensionRequest.findMany({
    where: {
      profileId,
      status: 'APPROVED',
      createdAt: { gte: startOfDay, lte: endOfDay }
    }
  });
  const extensionBonus = extensions.reduce((sum, req) => sum + (req.responseMinutes || 0), 0);

  const bonusMinutes = sessionBonus + extensionBonus;

  const limitSeconds = (dailyLimitMinutes + bonusMinutes) * 60;
  const remainingSeconds = Math.max(0, limitSeconds - totalSeconds);
  const remainingMinutes = Math.round(remainingSeconds / 60);

  return { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, remainingSeconds, timeLimit, activeSession };
};

// GET /api/child/status
const getStatus = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];

    if (!deviceCode) {
      return sendError(res, 'Device code required in X-Device-Code header', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode },
      include: { profile: true }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    if (!device.profileId) {
      return sendError(res, 'Thiết bị chưa được gán cho hồ sơ nào. Vui lòng yêu cầu bố mẹ gán trong Parent Dashboard.', 400, 'DEVICE_NOT_ASSIGNED');
    }

    const { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, remainingSeconds, timeLimit, activeSession } =
      await calcRemaining(device.profileId, device.id);

    const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const dayOfWeek = vnNow.getDay();

    sendSuccess(res, {
      device: {
        id: device.id,
        deviceName: device.deviceName,
        userId: device.userId,
        profileId: device.profileId,
        isOnline: device.isOnline
      },
      profile: device.profile ? {
        id: device.profile.id,
        profileName: device.profile.profileName,
        avatarUrl: device.profile.avatarUrl
      } : null,
      timeLimit: {
        dayOfWeek,
        dailyLimitMinutes,
        bonusMinutes,
        isGradual: timeLimit?.isGradual || false
      },
      usageToday: {
        totalMinutes: usedMinutes
      },
      activeSession: activeSession ? {
        id: activeSession.id,
        startTime: activeSession.startTime,
        totalMinutes: activeSession.totalMinutes || 0,
        bonusMinutes: activeSession.bonusMinutes || 0
      } : null,
      remainingMinutes,
      remainingSeconds
    });
  } catch (error) {
    console.error('Get child status error:', error);
    sendError(res, 'Failed to get status', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/session/start
const startSession = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { appName } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    if (!device.profileId) {
      return sendError(res, 'Device not assigned to a profile', 400, 'DEVICE_NOT_ASSIGNED');
    }

    // End tất cả ACTIVE sessions cũ của device này
    const now = new Date();
    const activeSessions = await prisma.session.findMany({
      where: {
        deviceId: device.id,
        status: 'ACTIVE'
      }
    });

    for (const session of activeSessions) {
      const durationMinutes = Math.floor((now - new Date(session.startTime)) / 60000);
      await prisma.session.update({
        where: { id: session.id },
        data: {
          status: 'COMPLETED',
          endTime: now,
          totalMinutes: durationMinutes
        }
      });
    }

    // Tạo session mới
    const newSession = await prisma.session.create({
      data: {
        profileId: device.profileId,
        deviceId: device.id,
        startTime: now,
        status: 'ACTIVE'
      }
    });

    // Tạo usage log entry (startTime only)
    await prisma.usageLog.create({
      data: {
        profileId: device.profileId,
        deviceId: device.id,
        appName: appName || 'KidFun Monitor',
        startTime: now,
        activityType: 'MONITORING'
      }
    });

    // Update device online status
    await prisma.device.update({
      where: { id: device.id },
      data: { isOnline: true, lastSeen: now }
    });

    sendSuccess(res, {
      session: {
        id: newSession.id,
        profileId: newSession.profileId,
        deviceId: newSession.deviceId,
        startTime: newSession.startTime,
        status: newSession.status
      }
    }, 201);
  } catch (error) {
    console.error('Start session error:', error);
    sendError(res, 'Failed to start session', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/session/heartbeat
const heartbeat = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { sessionId, elapsedMinutes } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    // Update session
    const session = await prisma.session.update({
      where: { id: sessionId },
      data: { totalMinutes: elapsedMinutes }
    });

    // Update latest usage log
    const now = new Date();
    const latestLog = await prisma.usageLog.findFirst({
      where: {
        profileId: session.profileId,
        deviceId: session.deviceId,
        endTime: null
      },
      orderBy: { startTime: 'desc' }
    });

    if (latestLog) {
      const durationSeconds = Math.floor((now - new Date(latestLog.startTime)) / 1000);

      await prisma.usageLog.update({
        where: { id: latestLog.id },
        data: {
          endTime: now,
          durationSeconds
        }
      });

      // Create new usage log for next interval so tracking continues
      await prisma.usageLog.create({
        data: {
          profileId: session.profileId,
          deviceId: session.deviceId,
          appName: 'KidFun Monitor',
          startTime: now,
          activityType: 'MONITORING'
        }
      });
    }

    // Update device lastSeen
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: now }
    });

    // Calculate remaining time (includes bonus)
    const { remainingMinutes, remainingSeconds } = await calcRemaining(session.profileId, device.id);

    sendSuccess(res, { remainingMinutes, remainingSeconds });
  } catch (error) {
    console.error('Heartbeat error:', error);
    sendError(res, 'Failed to update heartbeat', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/session/end
const endSession = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { sessionId, reason } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    const now = new Date();
    const session = await prisma.session.findUnique({
      where: { id: sessionId }
    });

    if (!session) {
      return sendError(res, 'Session not found', 404, 'NOT_FOUND');
    }

    const durationMinutes = Math.floor((now - new Date(session.startTime)) / 60000);

    // Update session
    await prisma.session.update({
      where: { id: sessionId },
      data: {
        status: 'COMPLETED',
        endTime: now,
        totalMinutes: durationMinutes
      }
    });

    // Close all open usage logs
    await prisma.usageLog.updateMany({
      where: {
        profileId: session.profileId,
        deviceId: session.deviceId,
        endTime: null
      },
      data: {
        endTime: now
      }
    });

    // Update durationSeconds cho logs đã close
    const openLogs = await prisma.usageLog.findMany({
      where: {
        profileId: session.profileId,
        deviceId: session.deviceId,
        endTime: now
      }
    });

    for (const log of openLogs) {
      const duration = Math.floor((now - new Date(log.startTime)) / 1000);
      await prisma.usageLog.update({
        where: { id: log.id },
        data: { durationSeconds: duration }
      });
    }

    // Update device
    await prisma.device.update({
      where: { id: device.id },
      data: {
        lastSeen: now,
        isOnline: false
      }
    });

    sendSuccess(res, { totalMinutes: durationMinutes, reason });
  } catch (error) {
    console.error('End session error:', error);
    sendError(res, 'Failed to end session', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/bonus
const addBonus = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { additionalMinutes } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    if (!additionalMinutes || additionalMinutes <= 0) {
      return sendError(res, 'additionalMinutes must be positive', 400, 'INVALID_INPUT');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    // Find active session
    const activeSession = await prisma.session.findFirst({
      where: { deviceId: device.id, status: 'ACTIVE' },
      orderBy: { startTime: 'desc' }
    });

    if (!activeSession) {
      return sendError(res, 'No active session', 404, 'NO_ACTIVE_SESSION');
    }

    // Increment bonus
    const updated = await prisma.session.update({
      where: { id: activeSession.id },
      data: { bonusMinutes: activeSession.bonusMinutes + additionalMinutes }
    });

    // Calculate new remaining
    const { remainingMinutes } = await calcRemaining(device.profileId, device.id);

    sendSuccess(res, {
      bonusMinutes: updated.bonusMinutes,
      remainingMinutes
    });
  } catch (error) {
    console.error('Add bonus error:', error);
    sendError(res, 'Failed to add bonus', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/warnings
const createWarning = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { warningType, message, remainingMinutes } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    if (!device.profileId) {
      return sendError(res, 'Device not assigned to a profile', 400, 'DEVICE_NOT_ASSIGNED');
    }

    const warning = await prisma.warning.create({
      data: {
        profileId: device.profileId,
        deviceId: device.id,
        warningType,
        message: message || `Còn ${remainingMinutes} phút sử dụng`
      }
    });

    sendSuccess(res, { warningId: warning.id }, 201);
  } catch (error) {
    console.error('Create warning error:', error);
    sendError(res, 'Failed to create warning', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/child/blocked-sites
const getBlockedSites = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];

    if (!deviceCode) {
      return sendError(res, 'Device code required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    if (!device.profileId) {
      return sendError(res, 'Device not assigned to a profile', 400, 'DEVICE_NOT_ASSIGNED');
    }

    const blockedSites = await prisma.blockedWebsite.findMany({
      where: { profileId: device.profileId }
    });

    sendSuccess(res, blockedSites);
  } catch (error) {
    console.error('Get blocked sites error:', error);
    sendError(res, 'Failed to get blocked sites', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/child/today-limit
const getTodayLimit = async (req, res) => {
  try {
    const deviceCode = req.query.deviceCode || req.headers['x-device-code'];

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: { timeLimits: true }
        }
      }
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not found or not linked to profile', 404);
    }

    const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const today = vnNow.getDay(); // 0 = Sunday
    const todayLimit = device.profile.timeLimits.find(tl => tl.dayOfWeek === today);

    const startOfDay = new Date(vnNow);
    startOfDay.setHours(0, 0, 0, 0);

    // Tính tổng thời gian được cộng (extensions)
    const extensions = await prisma.timeExtensionRequest.findMany({
      where: {
        profileId: device.profile.id,
        status: 'APPROVED',
        createdAt: { gte: startOfDay }
      }
    });
    const extensionBonus = extensions.reduce((sum, req) => sum + (req.responseMinutes || 0), 0);

    const sessions = await prisma.usageSession.findMany({
      where: {
        profileId: device.profile.id,
        startTime: { gte: startOfDay },
      },
    });

    const usedSeconds = sessions.reduce((total, s) => {
      const end = s.endTime || new Date();
      return total + (end.getTime() - new Date(s.startTime).getTime()) / 1000;
    }, 0);

    // fallback to limitMinutes if dailyLimitMinutes is null
    let baseLimit = todayLimit?.dailyLimitMinutes || todayLimit?.limitMinutes || 0;

    // Gradual reduction: tính limit hiệu lực nếu đang trong tiến trình giảm dần
    if (
      todayLimit?.isGradual &&
      todayLimit.gradualTarget != null &&
      todayLimit.gradualWeeks &&
      todayLimit.gradualStartDate
    ) {
      const startDate = new Date(todayLimit.gradualStartDate);
      const weeksElapsed = Math.floor((vnNow - startDate) / (7 * 24 * 60 * 60 * 1000));
      if (weeksElapsed < todayLimit.gradualWeeks) {
        const reduction =
          (baseLimit - todayLimit.gradualTarget) * (weeksElapsed / todayLimit.gradualWeeks);
        baseLimit = Math.round(baseLimit - reduction);
      } else {
        baseLimit = todayLimit.gradualTarget;
      }
    }

    const limitMinutes = baseLimit + extensionBonus;
    const limitSeconds = limitMinutes * 60;
    const remainingSeconds = Math.max(0, Math.round(limitSeconds - usedSeconds));
    const remainingMinutes = Math.ceil(remainingSeconds / 60);
    const usedMinutes = Math.floor(usedSeconds / 60);

    const dbIsActive = todayLimit?.isActive ?? true;
    const isLimitEnabled = dbIsActive;

    console.log(`📊 getTodayLimit: deviceCode=${deviceCode}, profileId=${device.profile.id}, today=${today}, baseLimit=${baseLimit}, extensionBonus=${extensionBonus}, limitMinutes=${limitMinutes}, usedMinutes=${usedMinutes}, remainingMinutes=${remainingMinutes}, remainingSeconds=${remainingSeconds}`);

    return sendSuccess(res, {
      profileId: device.profile.id,
      profileName: device.profile.profileName,
      dayOfWeek: today,
      limitMinutes,
      usedMinutes,
      remainingMinutes,
      remainingSeconds,
      isActive: dbIsActive,
      isLimitEnabled,
    });
  } catch (err) {
    console.error('❌ getTodayLimit ERROR:', err.message, err.stack);
    return sendError(res, err.message, 500);
  }
};

module.exports = {
  getStatus,
  startSession,
  heartbeat,
  endSession,
  addBonus,
  createWarning,
  getBlockedSites,
  getTodayLimit
};
