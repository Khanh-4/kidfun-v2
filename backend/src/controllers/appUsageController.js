const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// POST /api/child/app-usage
// Child gửi batch usage data lên server định kỳ
const syncAppUsage = async (req, res) => {
  try {
    const { deviceCode, usageData } = req.body;

    if (!deviceCode || !Array.isArray(usageData) || usageData.length === 0) {
      return sendError(res, 'deviceCode and usageData[] are required', 400, 'MISSING_FIELDS');
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    // Dùng ngày VN (UTC+7) để group by date
    const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const today = new Date(vnNow);
    today.setHours(0, 0, 0, 0);

    const results = await Promise.all(
      usageData.map((usage) => {
        if (!usage.packageName || typeof usage.usageSeconds !== 'number') return null;

        return prisma.appUsageLog.upsert({
          where: {
            profileId_deviceId_packageName_date: {
              profileId: device.profile.id,
              deviceId: device.id,
              packageName: usage.packageName,
              date: today,
            },
          },
          update: {
            usageSeconds: { increment: usage.usageSeconds },
            ...(usage.appName ? { appName: usage.appName } : {}),
          },
          create: {
            profileId: device.profile.id,
            deviceId: device.id,
            packageName: usage.packageName,
            appName: usage.appName || null,
            usageSeconds: usage.usageSeconds,
            date: today,
          },
        });
      })
    );

    const synced = results.filter(Boolean).length;
    return sendSuccess(res, { synced }, 201);
  } catch (err) {
    console.error('syncAppUsage error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/profiles/:id/app-usage?date=YYYY-MM-DD
const getDailyUsage = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const date = new Date(dateStr);
    date.setHours(0, 0, 0, 0);

    const usage = await prisma.appUsageLog.findMany({
      where: { profileId, date },
      orderBy: { usageSeconds: 'desc' },
    });

    const totalSeconds = usage.reduce((sum, u) => sum + u.usageSeconds, 0);

    return sendSuccess(res, {
      date: dateStr,
      totalMinutes: Math.round(totalSeconds / 60),
      totalSeconds,
      apps: usage.map((u) => ({
        packageName: u.packageName,
        appName: u.appName,
        usageMinutes: Math.round(u.usageSeconds / 60),
        usageSeconds: u.usageSeconds,
      })),
    });
  } catch (err) {
    console.error('getDailyUsage error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/profiles/:id/app-usage/weekly
const getWeeklyUsage = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 6);
    startDate.setHours(0, 0, 0, 0);

    const usage = await prisma.appUsageLog.findMany({
      where: {
        profileId,
        date: { gte: startDate, lte: endDate },
      },
      orderBy: { date: 'asc' },
    });

    // Group by date
    const dailyTotals = {};
    usage.forEach((u) => {
      const key = u.date.toISOString().split('T')[0];
      if (!dailyTotals[key]) dailyTotals[key] = 0;
      dailyTotals[key] += u.usageSeconds;
    });

    // Group by app (top 10)
    const appTotals = {};
    usage.forEach((u) => {
      if (!appTotals[u.packageName]) {
        appTotals[u.packageName] = { appName: u.appName, totalSeconds: 0 };
      }
      appTotals[u.packageName].totalSeconds += u.usageSeconds;
    });

    const topApps = Object.entries(appTotals)
      .sort((a, b) => b[1].totalSeconds - a[1].totalSeconds)
      .slice(0, 10)
      .map(([pkg, data]) => ({
        packageName: pkg,
        appName: data.appName,
        totalMinutes: Math.round(data.totalSeconds / 60),
      }));

    return sendSuccess(res, { dailyTotals, topApps });
  } catch (err) {
    console.error('getWeeklyUsage error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { syncAppUsage, getDailyUsage, getWeeklyUsage };
