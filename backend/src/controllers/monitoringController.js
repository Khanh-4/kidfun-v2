const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/monitoring/usage/:profileId
const getUsageStats = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);
    const { startDate, endDate } = req.query;

    const usageLogs = await prisma.usageLog.findMany({
      where: {
        profileId,
        startTime: {
          gte: startDate ? new Date(startDate) : new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
          lte: endDate ? new Date(endDate) : new Date()
        }
      },
      orderBy: { startTime: 'desc' }
    });

    // Tính tổng thời gian sử dụng
    const totalSeconds = usageLogs.reduce((sum, log) => sum + (log.durationSeconds || 0), 0);

    sendSuccess(res, {
      usageLogs,
      summary: {
        totalMinutes: Math.round(totalSeconds / 60),
        totalHours: Math.round(totalSeconds / 3600 * 10) / 10,
        logCount: usageLogs.length
      }
    });
  } catch (error) {
    console.error('Get usage stats error:', error);
    sendError(res, 'Failed to get usage stats', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/monitoring/usage
const logUsage = async (req, res) => {
  try {
    const { profileId, deviceId, appName, websiteUrl, startTime, endTime, activityType } = req.body;

    const durationSeconds = endTime && startTime
      ? Math.round((new Date(endTime) - new Date(startTime)) / 1000)
      : null;

    const usageLog = await prisma.usageLog.create({
      data: {
        profileId,
        deviceId,
        appName,
        websiteUrl,
        startTime: new Date(startTime),
        endTime: endTime ? new Date(endTime) : null,
        durationSeconds,
        activityType
      }
    });

    sendSuccess(res, usageLog, 201);
  } catch (error) {
    console.error('Log usage error:', error);
    sendError(res, 'Failed to log usage', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/monitoring/warnings/:profileId
const getWarnings = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);

    const warnings = await prisma.warning.findMany({
      where: { profileId },
      orderBy: { warnedAt: 'desc' },
      take: 50
    });

    sendSuccess(res, warnings);
  } catch (error) {
    console.error('Get warnings error:', error);
    sendError(res, 'Failed to get warnings', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/monitoring/warnings
const createWarning = async (req, res) => {
  try {
    const { profileId, deviceId, warningType, message } = req.body;

    const warning = await prisma.warning.create({
      data: {
        profileId,
        deviceId,
        warningType,
        message
      }
    });

    sendSuccess(res, warning, 201);
  } catch (error) {
    console.error('Create warning error:', error);
    sendError(res, 'Failed to create warning', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/monitoring/reports/:profileId
const getReports = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);
    const { period = '7days' } = req.query;

    // Verify profile belongs to current user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId },
      include: { timeLimits: true }
    });
    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    // Determine date range from period
    const periodDays = period === '90days' ? 90 : period === '30days' ? 30 : 7;
    const startDate = new Date();
    startDate.setHours(0, 0, 0, 0);
    startDate.setDate(startDate.getDate() - periodDays + 1);

    // Fetch sessions in the period
    const sessions = await prisma.session.findMany({
      where: {
        profileId,
        startTime: { gte: startDate }
      },
      select: { startTime: true, totalMinutes: true, bonusMinutes: true }
    });

    // Build a map of timeLimits by dayOfWeek (0=Sunday..6=Saturday)
    const timeLimitMap = {};
    for (const tl of profile.timeLimits) {
      timeLimitMap[tl.dayOfWeek] = tl.dailyLimitMinutes;
    }

    // Group sessions by date
    const dayMap = {};
    for (const s of sessions) {
      const dateKey = s.startTime.toISOString().split('T')[0];
      dayMap[dateKey] = (dayMap[dateKey] || 0) + (s.totalMinutes || 0);
    }

    // Build dailyUsage array for every day in the period
    const dailyUsage = [];
    const now = new Date();
    now.setHours(23, 59, 59, 999);
    for (let d = new Date(startDate); d <= now; d.setDate(d.getDate() + 1)) {
      const dateKey = d.toISOString().split('T')[0];
      dailyUsage.push({ date: dateKey, minutes: dayMap[dateKey] || 0 });
    }

    // Compute stats
    const totalMinutes = dailyUsage.reduce((sum, d) => sum + d.minutes, 0);
    const avgMinutesPerDay = dailyUsage.length > 0 ? Math.round(totalMinutes / dailyUsage.length) : 0;

    // Peak day
    let peakDay = { date: null, minutes: 0 };
    for (const d of dailyUsage) {
      if (d.minutes > peakDay.minutes) {
        peakDay = { date: d.date, minutes: d.minutes };
      }
    }

    // Compliance rate: % of days where usage <= daily limit
    let compliantDays = 0;
    let daysWithLimit = 0;
    for (const d of dailyUsage) {
      const dateObj = new Date(d.date + 'T00:00:00');
      const dow = dateObj.getDay(); // 0=Sun..6=Sat
      const limit = timeLimitMap[dow];
      if (limit !== undefined) {
        daysWithLimit++;
        if (d.minutes <= limit) {
          compliantDays++;
        }
      }
    }
    const complianceRate = daysWithLimit > 0 ? Math.round((compliantDays / daysWithLimit) * 100) : 100;

    // Weekday vs weekend averages
    let weekdayTotal = 0, weekdayCount = 0, weekendTotal = 0, weekendCount = 0;
    for (const d of dailyUsage) {
      const dateObj = new Date(d.date + 'T00:00:00');
      const dow = dateObj.getDay();
      if (dow >= 1 && dow <= 5) {
        weekdayTotal += d.minutes;
        weekdayCount++;
      } else {
        weekendTotal += d.minutes;
        weekendCount++;
      }
    }
    const weekdayAvg = weekdayCount > 0 ? Math.round(weekdayTotal / weekdayCount) : 0;
    const weekendAvg = weekendCount > 0 ? Math.round(weekendTotal / weekendCount) : 0;

    sendSuccess(res, {
      dailyUsage,
      totalMinutes,
      avgMinutesPerDay,
      peakDay,
      complianceRate,
      weekdayAvg,
      weekendAvg
    });
  } catch (error) {
    console.error('Get reports error:', error);
    sendError(res, 'Failed to get reports', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/monitoring/activity-history/:profileId
const getActivityHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);
    const { startDate, endDate, page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const skip = (pageNum - 1) * limitNum;

    // Verify profile belongs to current user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId }
    });
    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    // Build date filter
    const dateFilter = {};
    if (startDate) dateFilter.gte = new Date(startDate);
    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      dateFilter.lte = end;
    }

    const where = {
      profileId,
      ...(Object.keys(dateFilter).length > 0 && { startTime: dateFilter })
    };

    // Fetch paginated sessions + total count
    const [sessions, totalCount] = await Promise.all([
      prisma.session.findMany({
        where,
        include: { device: true },
        orderBy: { startTime: 'desc' },
        skip,
        take: limitNum
      }),
      prisma.session.count({ where })
    ]);

    // Compute summary from ALL sessions in date range (not just current page)
    const allSessions = await prisma.session.findMany({
      where,
      select: { startTime: true, totalMinutes: true }
    });

    const totalMinutes = allSessions.reduce((sum, s) => sum + (s.totalMinutes || 0), 0);

    // Group by date to find peak day and count distinct days
    const dayMap = {};
    for (const s of allSessions) {
      const dateKey = s.startTime.toISOString().split('T')[0];
      dayMap[dateKey] = (dayMap[dateKey] || 0) + (s.totalMinutes || 0);
    }

    const distinctDays = Object.keys(dayMap).length;
    const avgPerDay = distinctDays > 0 ? Math.round(totalMinutes / distinctDays) : 0;

    let peakDay = null;
    if (distinctDays > 0) {
      const peak = Object.entries(dayMap).sort((a, b) => b[1] - a[1])[0];
      peakDay = { date: peak[0], minutes: peak[1] };
    }

    sendSuccess(res, {
      sessions,
      totalCount,
      summary: { totalMinutes, avgPerDay, peakDay }
    });
  } catch (error) {
    console.error('Get activity history error:', error);
    sendError(res, 'Failed to get activity history', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getUsageStats,
  logUsage,
  getWarnings,
  createWarning,
  getReports,
  getActivityHistory
};
