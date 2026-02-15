const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Helper: calculate remaining minutes for a profile today, including bonus
const calcRemaining = async (profileId, deviceId) => {
  const today = new Date();
  const dayOfWeek = today.getDay();

  const timeLimit = await prisma.timeLimit.findUnique({
    where: {
      profileId_dayOfWeek: { profileId, dayOfWeek }
    }
  });

  const dailyLimitMinutes = timeLimit?.dailyLimitMinutes || 120;

  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date();
  endOfDay.setHours(23, 59, 59, 999);

  const usageLogs = await prisma.usageLog.findMany({
    where: {
      profileId,
      startTime: { gte: startOfDay, lte: endOfDay }
    }
  });

  const totalSeconds = usageLogs.reduce((sum, log) => sum + (log.durationSeconds || 0), 0);
  const usedMinutes = Math.round(totalSeconds / 60);

  // Get bonus from active session
  const activeSession = await prisma.session.findFirst({
    where: { deviceId, status: 'ACTIVE' },
    orderBy: { startTime: 'desc' }
  });
  const bonusMinutes = activeSession?.bonusMinutes || 0;

  const remainingMinutes = Math.max(0, dailyLimitMinutes + bonusMinutes - usedMinutes);

  return { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, timeLimit, activeSession };
};

// GET /api/child/status
// Lấy thông tin profile, thời gian, session hiện tại
const getStatus = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required in X-Device-Code header' });
    }

    // Tìm device
    const device = await prisma.device.findUnique({
      where: { deviceCode },
      include: { profile: true }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
    }

    if (!device.profileId) {
      return res.status(400).json({
        error: 'DEVICE_NOT_ASSIGNED',
        message: 'Thiết bị chưa được gán cho hồ sơ nào. Vui lòng yêu cầu bố mẹ gán trong Parent Dashboard.'
      });
    }

    const { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, timeLimit, activeSession } =
      await calcRemaining(device.profileId, device.id);

    const dayOfWeek = new Date().getDay();

    // Response
    res.json({
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
      remainingMinutes
    });
  } catch (error) {
    console.error('Get child status error:', error);
    res.status(500).json({ error: 'Failed to get status' });
  }
};

// POST /api/child/session/start
// Bắt đầu session mới
const startSession = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { appName } = req.body;

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required' });
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
    }

    if (!device.profileId) {
      return res.status(400).json({ error: 'Device not assigned to a profile' });
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

    res.status(201).json({
      message: 'Session started successfully',
      session: {
        id: newSession.id,
        profileId: newSession.profileId,
        deviceId: newSession.deviceId,
        startTime: newSession.startTime,
        status: newSession.status
      }
    });
  } catch (error) {
    console.error('Start session error:', error);
    res.status(500).json({ error: 'Failed to start session' });
  }
};

// POST /api/child/session/heartbeat
// Cập nhật session đang chạy
const heartbeat = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { sessionId, elapsedMinutes } = req.body;

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required' });
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
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
    }

    // Update device lastSeen
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: now }
    });

    // Calculate remaining time (includes bonus)
    const { remainingMinutes } = await calcRemaining(session.profileId, device.id);

    res.json({
      success: true,
      remainingMinutes
    });
  } catch (error) {
    console.error('Heartbeat error:', error);
    res.status(500).json({ error: 'Failed to update heartbeat' });
  }
};

// POST /api/child/session/end
// Kết thúc session
const endSession = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { sessionId, reason } = req.body;

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required' });
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
    }

    const now = new Date();
    const session = await prisma.session.findUnique({
      where: { id: sessionId }
    });

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
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

    res.json({
      success: true,
      totalMinutes: durationMinutes,
      reason
    });
  } catch (error) {
    console.error('End session error:', error);
    res.status(500).json({ error: 'Failed to end session' });
  }
};

// POST /api/child/bonus
// Lưu bonus minutes khi Parent duyệt thêm giờ
const addBonus = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { additionalMinutes } = req.body;

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required' });
    }

    if (!additionalMinutes || additionalMinutes <= 0) {
      return res.status(400).json({ error: 'additionalMinutes must be positive' });
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
    }

    // Find active session
    const activeSession = await prisma.session.findFirst({
      where: { deviceId: device.id, status: 'ACTIVE' },
      orderBy: { startTime: 'desc' }
    });

    if (!activeSession) {
      return res.status(404).json({ error: 'No active session' });
    }

    // Increment bonus
    const updated = await prisma.session.update({
      where: { id: activeSession.id },
      data: { bonusMinutes: activeSession.bonusMinutes + additionalMinutes }
    });

    // Calculate new remaining
    const { remainingMinutes } = await calcRemaining(device.profileId, device.id);

    res.json({
      success: true,
      bonusMinutes: updated.bonusMinutes,
      remainingMinutes
    });
  } catch (error) {
    console.error('Add bonus error:', error);
    res.status(500).json({ error: 'Failed to add bonus' });
  }
};

// POST /api/child/warnings
// Ghi log warning
const createWarning = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { warningType, message, remainingMinutes } = req.body;

    if (!deviceCode) {
      return res.status(400).json({ error: 'Device code required' });
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return res.status(404).json({ error: 'Invalid device code' });
    }

    if (!device.profileId) {
      return res.status(400).json({ error: 'Device not assigned to a profile' });
    }

    const warning = await prisma.warning.create({
      data: {
        profileId: device.profileId,
        deviceId: device.id,
        warningType,
        message: message || `Còn ${remainingMinutes} phút sử dụng`
      }
    });

    res.status(201).json({
      success: true,
      warningId: warning.id
    });
  } catch (error) {
    console.error('Create warning error:', error);
    res.status(500).json({ error: 'Failed to create warning' });
  }
};

module.exports = {
  getStatus,
  startSession,
  heartbeat,
  endSession,
  addBonus,
  createWarning
};
