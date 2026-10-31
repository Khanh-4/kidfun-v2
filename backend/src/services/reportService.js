const prisma = require('../utils/prisma');

exports.generateDailyReport = async (profileId, date) => {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  const data = await aggregateData(profileId, start, end);

  const report = await prisma.reportSnapshot.upsert({
    where: {
      profileId_type_periodStart: { profileId, type: 'DAILY', periodStart: start },
    },
    update: { data, generatedAt: new Date() },
    create: {
      profileId,
      type: 'DAILY',
      periodStart: start,
      periodEnd: end,
      data,
      generatedAt: new Date(),
    },
  });

  return report;
};

exports.generateWeeklyReport = async (profileId, mondayDate) => {
  const start = new Date(mondayDate);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 7);

  const data = await aggregateData(profileId, start, end);

  const report = await prisma.reportSnapshot.upsert({
    where: {
      profileId_type_periodStart: { profileId, type: 'WEEKLY', periodStart: start },
    },
    update: { data, generatedAt: new Date() },
    create: {
      profileId,
      type: 'WEEKLY',
      periodStart: start,
      periodEnd: end,
      data,
      generatedAt: new Date(),
    },
  });

  return report;
};

async function aggregateData(profileId, start, end) {
  const inRange = { gte: start, lt: end };

  // Các query độc lập nhau — chạy song song thay vì tuần tự (cron daily-reports
  // từng timeout 60s vì cộng dồn round-trip tới Supabase).
  const [
    appLogs,
    youtubeLogs,
    locationLogs,
    geofenceEvents,
    blockedCategoriesCount,
    customBlockedDomainsCount,
    appTimeLimitsCount,
    schoolSchedule,
    sosAlerts,
    aiAlerts,
    timeExtensions,
  ] = await Promise.all([
    prisma.appUsageLog.findMany({ where: { profileId, date: inRange } }),
    prisma.youTubeLog.findMany({ where: { profileId, watchedAt: inRange } }),
    prisma.locationLog.findMany({
      where: { profileId, createdAt: inRange },
      select: { latitude: true, longitude: true, createdAt: true },
    }),
    prisma.geofenceEvent.findMany({
      where: { profileId, createdAt: inRange },
      include: { geofence: { select: { name: true } } },
      orderBy: { createdAt: 'asc' },
    }),
    prisma.blockedCategory.count({ where: { profileId, isBlocked: true } }),
    prisma.customBlockedDomain.count({ where: { profileId } }),
    prisma.appTimeLimit.count({ where: { profileId, isActive: true } }),
    prisma.schoolSchedule.findUnique({ where: { profileId } }),
    prisma.sOSAlert.count({ where: { profileId, createdAt: inRange } }),
    prisma.aIAlert.count({ where: { profileId, createdAt: inRange } }),
    prisma.timeExtensionRequest.count({
      where: { profileId, createdAt: inRange, status: 'APPROVED' },
    }),
  ]);

  // 1. App usage
  const totalScreenSeconds = appLogs.reduce((sum, l) => sum + l.usageSeconds, 0);

  const appMap = {};
  for (const log of appLogs) {
    const key = log.packageName;
    if (!appMap[key]) appMap[key] = { packageName: key, appName: log.appName, seconds: 0 };
    appMap[key].seconds += log.usageSeconds;
  }
  const topApps = Object.values(appMap)
    .sort((a, b) => b.seconds - a.seconds)
    .slice(0, 10);

  // 2. YouTube stats
  const youtubeStats = {
    totalVideos: youtubeLogs.length,
    totalMinutes: Math.round(youtubeLogs.reduce((s, l) => s + l.durationSeconds, 0) / 60),
    blocked: youtubeLogs.filter(l => l.isBlocked).length,
    dangerLevels: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
  };
  for (const l of youtubeLogs) {
    if (l.dangerLevel) youtubeStats.dangerLevels[l.dangerLevel] = (youtubeStats.dangerLevels[l.dangerLevel] || 0) + 1;
  }

  // 3. Location stats
  const locationStats = {
    totalPoints: locationLogs.length,
    geofenceEvents: geofenceEvents.map(e => ({
      type: e.type,
      geofenceName: e.geofence.name,
      timestamp: e.createdAt,
    })),
    enterCount: geofenceEvents.filter(e => e.type === 'ENTER').length,
    exitCount: geofenceEvents.filter(e => e.type === 'EXIT').length,
  };

  // 4. Policy stats
  const policyStats = {
    activeAppLimits: appTimeLimitsCount,
    blockedWebCategories: blockedCategoriesCount,
    customBlockedDomains: customBlockedDomainsCount,
    schoolModeEnabled: schoolSchedule?.isEnabled || false,
  };

  return {
    totalScreenSeconds,
    totalScreenMinutes: Math.round(totalScreenSeconds / 60),
    topApps,
    youtubeStats,
    locationStats,
    policyStats,
    sosAlertsCount: sosAlerts,
    aiAlertsCount: aiAlerts,
    approvedExtensionsCount: timeExtensions,
  };
}
