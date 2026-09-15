const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { getCached, setCache, clearCache } = require('../services/cacheService');
const { vnDayRange } = require('../utils/vnTime');

// Helper: calculate remaining minutes for a profile today, including bonus
// Results are cached for 30s to reduce DB load from frequent heartbeat calls
const calcRemaining = async (profileId, deviceId) => {
  const cacheKey = `remaining_${profileId}_${deviceId}`;
  const cached = getCached(cacheKey);
  if (cached) return cached;
  const { startOfDay, endOfDay, dayOfWeek } = vnDayRange();

  const timeLimit = await prisma.timeLimit.findUnique({
    where: {
      profileId_dayOfWeek: { profileId, dayOfWeek }
    }
  });

  const dailyLimitMinutes = timeLimit?.dailyLimitMinutes || 120;

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

  const now = new Date();
  // BUG FIX: open logs (endTime=null, durationSeconds=null) were counted as 0.
  // Calculate elapsed seconds for open logs so the countdown is accurate on restart.
  const totalSeconds = usageLogs.reduce((sum, log) => {
    if (log.durationSeconds !== null) return sum + log.durationSeconds;
    // Open log — count elapsed time since startTime, capped at end-of-day
    const effectiveEnd = now < endOfDay ? now : endOfDay;
    return sum + Math.max(0, Math.floor((effectiveEnd - new Date(log.startTime)) / 1000));
  }, 0);
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

  // Lọc theo lúc DUYỆT, không phải lúc tạo: trẻ xin lúc 23:55 mà phụ huynh duyệt
  // lúc 00:05 hôm sau thì giờ được cộng phải tính cho ngày mới — ngày cũ đã hết,
  // usage cũng đã reset, tính cho ngày cũ là mất trắng. Bản ghi cũ có thể chưa
  // có respondedAt nên vẫn fallback về createdAt.
  const extensions = await prisma.timeExtensionRequest.findMany({
    where: {
      profileId,
      status: 'APPROVED',
      OR: [
        { respondedAt: { gte: startOfDay, lte: endOfDay } },
        { AND: [{ respondedAt: null }, { createdAt: { gte: startOfDay, lte: endOfDay } }] }
      ]
    }
  });
  const extensionBonus = extensions.reduce((sum, req) => sum + (req.responseMinutes || 0), 0);

  const bonusMinutes = sessionBonus + extensionBonus;

  const limitSeconds = (dailyLimitMinutes + bonusMinutes) * 60;
  const remainingSeconds = Math.max(0, limitSeconds - totalSeconds);
  const remainingMinutes = Math.round(remainingSeconds / 60);

  const result = { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, remainingSeconds, timeLimit, activeSession };
  setCache(cacheKey, result, 30 * 1000); // Cache 30s — invalidate khi Parent thay đổi time limit
  return result;
};

// GET /api/child/status
/**
 * POST /api/child/ping — "tôi còn sống".
 *
 * Câu trả lời của app trẻ khi server dò `pingRequestedAt` trước lúc xoá thiết
 * bị (xem deviceController.probeDeviceAlive). CỐ TÌNH tối giản: đúng một UPDATE
 * theo primary key, không đụng calcRemaining hay bất cứ thứ gì khác.
 *
 * Lý do phải tách riêng thay vì tái dùng /api/child/status: endpoint đó kéo
 * theo cả calcRemaining và mất 13-14 giây khi đo thật, tức câu trả lời về tới
 * nơi thì cửa sổ dò đã đóng từ lâu và máy trẻ đang online bị báo mất kết nối.
 */
const ping = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];

    if (!deviceCode) {
      return sendError(res, 'Device code required in X-Device-Code header', 400, 'MISSING_DEVICE_CODE');
    }

    // updateMany thay vì findUnique + update: đúng MỘT vòng tới DB. Mỗi vòng
    // tốn ~0.3-1.5s tuỳ độ trễ tới Supabase, mà server chỉ chờ 5 giây — cắt
    // được một vòng là cắt được một phần đáng kể của ngân sách đó.
    const updated = await prisma.device.updateMany({
      where: { deviceCode },
      data: { lastSeen: new Date(), isOnline: true }
    });

    // Không có dòng nào khớp = thiết bị đã bị phụ huynh xoá. Tín hiệu hữu ích
    // cho app trẻ: tự gỡ liên kết luôn thay vì chờ heartbeat kế tiếp.
    if (updated.count === 0) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    sendSuccess(res, { alive: true });
  } catch (error) {
    console.error('Child ping error:', error);
    sendError(res, 'Failed to ping', 500, 'INTERNAL_ERROR');
  }
};

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

    // Gọi được tới đây nghĩa là máy trẻ đang có mạng — ghi nhận ngay. Đây là
    // cách app trẻ "điểm danh" khi server dò `pingRequestedAt` trước lúc xoá
    // thiết bị (xem deviceController.deleteDevice), và cũng giúp lastSeen bớt
    // thô so với việc chỉ trông vào heartbeat 60s.
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: new Date(), isOnline: true }
    });

    const { dailyLimitMinutes, usedMinutes, bonusMinutes, remainingMinutes, remainingSeconds, timeLimit, activeSession } =
      await calcRemaining(device.profileId, device.id);

    const { dayOfWeek } = vnDayRange();

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

      // BUG FIX: close any open UsageLog entries from this session.
      // Use device.lastSeen as the effective end time — that's the last confirmed
      // active heartbeat, so we don't count idle time between force-close and restart.
      // Falls back to now if lastSeen is unavailable.
      const lastActiveTime = device.lastSeen ? new Date(device.lastSeen) : now;
      const openLogs = await prisma.usageLog.findMany({
        where: {
          deviceId: device.id,
          endTime: null,
          startTime: { gte: session.startTime }
        }
      });
      for (const log of openLogs) {
        const logStart = new Date(log.startTime);
        // Use lastActiveTime only if it's after the log started, otherwise fall back to now
        const effectiveEnd = lastActiveTime > logStart ? lastActiveTime : now;
        const durationSeconds = Math.max(0, Math.floor((effectiveEnd - logStart) / 1000));
        await prisma.usageLog.update({
          where: { id: log.id },
          data: { endTime: effectiveEnd, durationSeconds }
        });
      }
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

    if (!sessionId || !Number.isInteger(Number(sessionId))) {
      return sendError(res, 'sessionId is required and must be an integer', 400, 'INVALID_SESSION_ID');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    // Update session
    const session = await prisma.session.update({
      where: { id: Number(sessionId) },
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

    if (!sessionId || !Number.isInteger(Number(sessionId))) {
      return sendError(res, 'sessionId is required and must be an integer', 400, 'INVALID_SESSION_ID');
    }

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }

    const now = new Date();
    const session = await prisma.session.findUnique({
      where: { id: Number(sessionId) }
    });

    if (!session) {
      return sendError(res, 'Session not found', 404, 'NOT_FOUND');
    }

    const durationMinutes = Math.floor((now - new Date(session.startTime)) / 60000);

    // Update session
    await prisma.session.update({
      where: { id: Number(sessionId) },
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

// POST /api/child/session/pause — Screen turned off, stop counting usage
const pauseSession = async (req, res) => {
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

    const now = new Date();

    // Close open usage logs — this stops accumulating usage time
    const openLogs = await prisma.usageLog.findMany({
      where: {
        deviceId: device.id,
        endTime: null
      }
    });

    for (const log of openLogs) {
      const durationSeconds = Math.max(0, Math.floor((now - new Date(log.startTime)) / 1000));
      await prisma.usageLog.update({
        where: { id: log.id },
        data: { endTime: now, durationSeconds }
      });
    }

    // Update device lastSeen
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: now }
    });

    console.log(`⏸️ Session PAUSED: deviceCode=${deviceCode}, closed ${openLogs.length} open logs`);

    // Calculate remaining for response
    if (device.profileId) {
      const { remainingMinutes, remainingSeconds } = await calcRemaining(device.profileId, device.id);
      return sendSuccess(res, { paused: true, remainingMinutes, remainingSeconds });
    }

    sendSuccess(res, { paused: true });
  } catch (error) {
    console.error('Pause session error:', error);
    sendError(res, 'Failed to pause session', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/child/session/resume — Screen turned on, resume counting usage
const resumeSession = async (req, res) => {
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

    const now = new Date();

    // Ensure active session exists
    const activeSession = await prisma.session.findFirst({
      where: { deviceId: device.id, status: 'ACTIVE' },
      orderBy: { startTime: 'desc' }
    });

    if (!activeSession) {
      return sendError(res, 'No active session to resume', 404, 'NO_ACTIVE_SESSION');
    }

    // Create new usage log entry (startTime only) — this resumes accumulation
    await prisma.usageLog.create({
      data: {
        profileId: device.profileId,
        deviceId: device.id,
        appName: 'KidFun Monitor',
        startTime: now,
        activityType: 'MONITORING'
      }
    });

    // Update device
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: now, isOnline: true }
    });

    console.log(`▶️ Session RESUMED: deviceCode=${deviceCode}`);

    // Calculate remaining for response
    const { remainingMinutes, remainingSeconds } = await calcRemaining(device.profileId, device.id);
    sendSuccess(res, { resumed: true, remainingMinutes, remainingSeconds });
  } catch (error) {
    console.error('Resume session error:', error);
    sendError(res, 'Failed to resume session', 500, 'INTERNAL_ERROR');
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

    // Invalidate cache so next calcRemaining reflects new bonus
    clearCache(`remaining_${device.profileId}_`);

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

    const { dayOfWeek: today } = vnDayRange(); // 0 = Sunday, theo giờ VN
    const todayLimit = device.profile.timeLimits.find(tl => tl.dayOfWeek === today);

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
      // Đo khoảng cách giữa hai mốc thật nên dùng now() thẳng: chênh lệch hai
      // thời điểm không phụ thuộc timezone, cộng thêm +7h vào một vế chỉ gây lệch.
      const weeksElapsed = Math.floor((Date.now() - startDate) / (7 * 24 * 60 * 60 * 1000));
      if (weeksElapsed < todayLimit.gradualWeeks) {
        const reduction =
          (baseLimit - todayLimit.gradualTarget) * (weeksElapsed / todayLimit.gradualWeeks);
        baseLimit = Math.round(baseLimit - reduction);
      } else {
        baseLimit = todayLimit.gradualTarget;
      }
    }

    // BUG FIX: dùng calcRemaining() thay vì usageSession (bảng không được ghi bởi session APIs)
    // calcRemaining đọc từ usageLog (được tạo bởi startSession + heartbeat) → chính xác
    const { usedMinutes, bonusMinutes, remainingMinutes, remainingSeconds } =
      await calcRemaining(device.profile.id, device.id);

    const limitMinutes = baseLimit + bonusMinutes;

    const dbIsActive = todayLimit?.isActive ?? true;
    const isLimitEnabled = dbIsActive;

    console.log(`📊 getTodayLimit: deviceCode=${deviceCode}, profileId=${device.profile.id}, today=${today}, baseLimit=${baseLimit}, bonusMinutes=${bonusMinutes}, limitMinutes=${limitMinutes}, usedMinutes=${usedMinutes}, remainingMinutes=${remainingMinutes}, remainingSeconds=${remainingSeconds}`);

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

// POST /api/child/realtime-token — mint JWT riêng cho Supabase Realtime (child app)
const { mintChildRealtimeToken, REALTIME_TOKEN_TTL_SECONDS } = require('../utils/realtimeAuth');
const getRealtimeToken = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    if (!deviceCode) {
      return sendError(res, 'Device code required in X-Device-Code header', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findUnique({ where: { deviceCode } });
    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'INVALID_DEVICE_CODE');
    }
    if (!device.profileId) {
      return sendError(res, 'Device not assigned to a profile', 400, 'DEVICE_NOT_ASSIGNED');
    }

    const token = mintChildRealtimeToken(device.id, device.profileId);
    sendSuccess(res, { token, expiresIn: REALTIME_TOKEN_TTL_SECONDS });
  } catch (err) {
    console.error('❌ getRealtimeToken (child) ERROR:', err.message);
    sendError(res, 'Failed to mint realtime token', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  ping,
  getStatus,
  startSession,
  heartbeat,
  endSession,
  addBonus,
  createWarning,
  getBlockedSites,
  getTodayLimit,
  pauseSession,
  resumeSession,
  getRealtimeToken
};
