const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

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
  // 1. App usage
  const appLogs = await prisma.appUsageLog.findMany({
    where: { profileId, date: { gte: start, lt: end } },
  });

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
  const youtubeLogs = await prisma.youTubeLog.findMany({
    where: { profileId, watchedAt: { gte: start, lt: end } },
  });
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
  const locationLogs = await prisma.locationLog.findMany({
    where: { profileId, createdAt: { gte: start, lt: end } },
    select: { latitude: true, longitude: true, createdAt: true },
  });
  const geofenceEvents = await prisma.geofenceEvent.findMany({
    where: { profileId, createdAt: { gte: start, lt: end } },
    include: { geofence: { select: { name: true } } },
    orderBy: { createdAt: 'asc' },
  });
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
  const [blockedCategoriesCount, customBlockedDomainsCount, appTimeLimitsCount, schoolSchedule] = await Promise.all([
    prisma.blockedCategory.count({ where: { profileId, isBlocked: true } }),
    prisma.customBlockedDomain.count({ where: { profileId } }),
    prisma.appTimeLimit.count({ where: { profileId, isActive: true } }),
    prisma.schoolSchedule.findUnique({ where: { profileId } }),
  ]);
  const policyStats = {
    activeAppLimits: appTimeLimitsCount,
    blockedWebCategories: blockedCategoriesCount,
    customBlockedDomains: customBlockedDomainsCount,
    schoolModeEnabled: schoolSchedule?.isEnabled || false,
  };

  // 5. SOS alerts
  const sosAlerts = await prisma.sOSAlert.count({
    where: { profileId, createdAt: { gte: start, lt: end } },
  });

  // 6. AI alerts
  const aiAlerts = await prisma.aIAlert.count({
    where: { profileId, createdAt: { gte: start, lt: end } },
  });

  // 7. Time extensions
  const timeExtensions = await prisma.timeExtensionRequest.count({
    where: {
      profileId,
      createdAt: { gte: start, lt: end },
      status: 'APPROVED',
    },
  });

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
