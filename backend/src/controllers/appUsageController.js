const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// Helper: get VN date as 'YYYY-MM-DD' string (avoids UTC/VN day-boundary mismatch on Railway)
const getVnDateStr = (date = new Date()) => {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(date);
};

// Parse a 'YYYY-MM-DD' string into a UTC midnight Date that matches Prisma's stored date field
const parseDateStr = (dateStr) => {
  // Store dates as UTC midnight so they compare correctly with Prisma
  const d = new Date(dateStr + 'T00:00:00.000Z');
  return d;
};

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

    // Dùng ngày VN (UTC+7) để tránh cross-day overlap khi server chạy ở UTC (Railway)
    const todayStr = getVnDateStr();
    const today = parseDateStr(todayStr);

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
            // Android UsageStatsManager trả về totalTimeInForeground tích lũy từ đầu ngày
            // → set trực tiếp thay vì increment để tránh double-counting mỗi sync cycle
            usageSeconds: usage.usageSeconds,
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
    // Chuẩn hóa date theo VN timezone để match với data đã lưu
    const dateStr = req.query.date || getVnDateStr();
    const date = parseDateStr(dateStr);

    const usage = await prisma.appUsageLog.findMany({
      where: { profileId, date },
      orderBy: { usageSeconds: 'desc' },
      include: { device: { select: { id: true, deviceName: true } } },
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
        deviceId: u.deviceId,
        deviceName: u.device?.deviceName ?? null,
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
    // Tính 7 ngày gần nhất theo VN timezone để không bị lệch ngày
    const todayStr = getVnDateStr();
    const endDate = parseDateStr(todayStr);
    const startDate = new Date(endDate);
    startDate.setUTCDate(startDate.getUTCDate() - 6);
    // endDate = today midnight UTC, range = [startDate, endDate+1day)
    const endDateExclusive = new Date(endDate);
    endDateExclusive.setUTCDate(endDateExclusive.getUTCDate() + 1);

    const usage = await prisma.appUsageLog.findMany({
      where: {
        profileId,
        date: { gte: startDate, lt: endDateExclusive },
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
        usageSeconds: data.totalSeconds,
      }));

    return sendSuccess(res, { dailyTotals, topApps });
  } catch (err) {
    console.error('getWeeklyUsage error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/profiles/:id/all-apps
// Trả về tất cả app đã từng được cài trên thiết bị con (distinct packageName, tổng usage)
const getAllApps = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);

    // Group by packageName+appName+deviceId so we can show per-device breakdown
    const rows = await prisma.appUsageLog.groupBy({
      by: ['packageName', 'appName', 'deviceId'],
      where: { profileId },
      _sum: { usageSeconds: true },
      orderBy: { _sum: { usageSeconds: 'desc' } },
    });

    // Fetch device names for all unique deviceIds
    const deviceIds = [...new Set(rows.map((r) => r.deviceId).filter(Boolean))];
    const devices = await prisma.device.findMany({
      where: { id: { in: deviceIds } },
      select: { id: true, deviceName: true },
    });
    const deviceMap = Object.fromEntries(devices.map((d) => [d.id, d.deviceName]));

    return sendSuccess(res, {
      apps: rows.map((r) => ({
        packageName: r.packageName,
        appName: r.appName,
        usageSeconds: r._sum.usageSeconds ?? 0,
        deviceId: r.deviceId,
        deviceName: deviceMap[r.deviceId] ?? null,
      })),
    });
  } catch (err) {
    console.error('getAllApps error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { syncAppUsage, getDailyUsage, getWeeklyUsage, getAllApps };
