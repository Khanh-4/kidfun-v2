const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

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

    res.json({
      usageLogs,
      summary: {
        totalMinutes: Math.round(totalSeconds / 60),
        totalHours: Math.round(totalSeconds / 3600 * 10) / 10,
        logCount: usageLogs.length
      }
    });
  } catch (error) {
    console.error('Get usage stats error:', error);
    res.status(500).json({ error: 'Failed to get usage stats' });
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

    res.status(201).json(usageLog);
  } catch (error) {
    console.error('Log usage error:', error);
    res.status(500).json({ error: 'Failed to log usage' });
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

    res.json(warnings);
  } catch (error) {
    console.error('Get warnings error:', error);
    res.status(500).json({ error: 'Failed to get warnings' });
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

    res.status(201).json(warning);
  } catch (error) {
    console.error('Create warning error:', error);
    res.status(500).json({ error: 'Failed to create warning' });
  }
};

// GET /api/monitoring/reports/:profileId
const getReports = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);

    // Lấy dữ liệu 30 ngày gần nhất
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const [usageLogs, warnings, profile] = await Promise.all([
      prisma.usageLog.findMany({
        where: {
          profileId,
          startTime: { gte: thirtyDaysAgo }
        }
      }),
      prisma.warning.findMany({
        where: {
          profileId,
          warnedAt: { gte: thirtyDaysAgo }
        }
      }),
      prisma.profile.findUnique({
        where: { id: profileId },
        include: { timeLimits: true }
      })
    ]);

    // Tính thống kê
    const totalUsageSeconds = usageLogs.reduce((sum, log) => sum + (log.durationSeconds || 0), 0);
    
    // Nhóm theo app
    const appUsage = usageLogs.reduce((acc, log) => {
      acc[log.appName] = (acc[log.appName] || 0) + (log.durationSeconds || 0);
      return acc;
    }, {});

    res.json({
      profile,
      summary: {
        totalHours: Math.round(totalUsageSeconds / 3600 * 10) / 10,
        averageHoursPerDay: Math.round(totalUsageSeconds / 3600 / 30 * 10) / 10,
        totalWarnings: warnings.length,
        warningsByType: warnings.reduce((acc, w) => {
          acc[w.warningType] = (acc[w.warningType] || 0) + 1;
          return acc;
        }, {})
      },
      appUsage: Object.entries(appUsage)
        .map(([name, seconds]) => ({ name, hours: Math.round(seconds / 3600 * 10) / 10 }))
        .sort((a, b) => b.hours - a.hours)
        .slice(0, 10)
    });
  } catch (error) {
    console.error('Get reports error:', error);
    res.status(500).json({ error: 'Failed to get reports' });
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
      return res.status(404).json({ error: 'Profile not found' });
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

    res.json({
      sessions,
      totalCount,
      summary: { totalMinutes, avgPerDay, peakDay }
    });
  } catch (error) {
    console.error('Get activity history error:', error);
    res.status(500).json({ error: 'Failed to get activity history' });
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