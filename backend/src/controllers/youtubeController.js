const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// POST /api/child/youtube-logs — Child batch upload
exports.batchUploadLogs = async (req, res) => {
  try {
    const { deviceCode, logs } = req.body;

    if (!deviceCode || !Array.isArray(logs) || logs.length === 0) {
      return sendError(res, 'Invalid data: deviceCode and logs[] required', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404);
    }

    const created = [];
    for (const log of logs) {
      if ((log.durationSeconds || 0) < 10) continue;

      try {
        const yt = await prisma.youTubeLog.create({
          data: {
            profileId: device.profile.id,
            deviceId: device.id,
            videoTitle: log.videoTitle,
            channelName: log.channelName || null,
            videoId: log.videoId || null,
            thumbnailUrl: log.thumbnailUrl || null,
            watchedAt: new Date(log.watchedAt || Date.now()),
            durationSeconds: log.durationSeconds || 0,
          },
        });
        created.push(yt.id);
      } catch (err) {
        // Skip duplicates or invalid records silently
      }
    }

    console.log(`📺 [YOUTUBE] Saved ${created.length}/${logs.length} logs for profile ${device.profile.id}`);
    return sendSuccess(res, { saved: created.length }, 201);
  } catch (err) {
    console.error('❌ [YOUTUBE] batchUploadLogs error:', err.message);
    return sendError(res, err.message, 500);
  }
};

// GET /api/child/blocked-videos?deviceCode=XXX — Child sync blocked videos
exports.getBlockedVideos = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    if (!deviceCode) return sendError(res, 'deviceCode required', 400);

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: { include: { blockedVideos: true } } },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const videos = device.profile.blockedVideos.map(v => ({
      videoTitle: v.videoTitle,
      channelName: v.channelName,
      videoId: v.videoId,
    }));

    return sendSuccess(res, { blockedVideos: videos });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/blocked-videos — Parent sync blocked videos
exports.getParentBlockedVideos = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const blockedVideos = await prisma.blockedVideo.findMany({
      where: { profileId },
      select: {
        id: true,
        videoTitle: true,
        channelName: true,
        videoId: true,
        reason: true,
        createdAt: true,
      }
    });

    return sendSuccess(res, { blockedVideos });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/youtube/dashboard?days=7 — Parent dashboard
exports.getDashboard = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const days = parseInt(req.query.days) || 7;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const allLogs = await prisma.youTubeLog.findMany({
      where: { profileId, watchedAt: { gte: startDate } },
      select: { durationSeconds: true, channelName: true, dangerLevel: true, category: true },
    });

    const totalVideos = allLogs.length;
    const totalWatchSeconds = allLogs.reduce((sum, l) => sum + l.durationSeconds, 0);

    const channelMap = {};
    for (const log of allLogs) {
      const ch = log.channelName || 'Unknown';
      if (!channelMap[ch]) channelMap[ch] = { name: ch, count: 0, watchSeconds: 0 };
      channelMap[ch].count++;
      channelMap[ch].watchSeconds += log.durationSeconds;
    }
    const topChannels = Object.values(channelMap)
      .sort((a, b) => b.watchSeconds - a.watchSeconds)
      .slice(0, 10);

    const dangerCounts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, unanalyzed: 0 };
    const categoryCounts = {};
    for (const log of allLogs) {
      if (log.dangerLevel == null) {
        dangerCounts.unanalyzed++;
      } else {
        dangerCounts[log.dangerLevel] = (dangerCounts[log.dangerLevel] || 0) + 1;
      }
      if (log.category) {
        categoryCounts[log.category] = (categoryCounts[log.category] || 0) + 1;
      }
    }

    const recentAlerts = await prisma.aIAlert.findMany({
      where: { profileId },
      include: { youtubeLog: true },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    const dailyLogs = await prisma.youTubeLog.findMany({
      where: { profileId, watchedAt: { gte: startDate } },
      select: { watchedAt: true },
    });
    const dailyMap = {};
    for (const log of dailyLogs) {
      const day = log.watchedAt.toISOString().slice(0, 10);
      dailyMap[day] = (dailyMap[day] || 0) + 1;
    }

    return sendSuccess(res, {
      totalVideos,
      totalWatchMinutes: Math.round(totalWatchSeconds / 60),
      topChannels,
      dangerSummary: dangerCounts,
      categorySummary: categoryCounts,
      recentAlerts,
      dailyActivity: dailyMap,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/youtube/logs?date=&minDanger=&channel=&page=&limit=
exports.getLogs = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { date, minDanger, channel } = req.query;
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);

    const where = { profileId };
    if (date) {
      const start = new Date(date);
      start.setHours(0, 0, 0, 0);
      const end = new Date(start);
      end.setDate(end.getDate() + 1);
      where.watchedAt = { gte: start, lt: end };
    }
    if (minDanger) where.dangerLevel = { gte: parseInt(minDanger) };
    if (channel) where.channelName = channel;

    const [total, logs, blockedVideos] = await Promise.all([
      prisma.youTubeLog.count({ where }),
      prisma.youTubeLog.findMany({
        where,
        orderBy: { watchedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.blockedVideo.findMany({
        where: { profileId },
        select: { videoTitle: true },
      })
    ]);

    const blockedSet = new Set(blockedVideos.map(b => b.videoTitle.toLowerCase()));
    const enrichedLogs = logs.map(log => ({
      ...log,
      isBlocked: blockedSet.has(log.videoTitle.toLowerCase())
    }));

    return sendSuccess(res, { total, page, limit, logs: enrichedLogs });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// POST /api/profiles/:id/blocked-videos — Parent manual block
exports.blockVideo = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { videoTitle, channelName, videoId } = req.body;

    if (!videoTitle) return sendError(res, 'videoTitle required', 400);

    const blocked = await prisma.blockedVideo.create({
      data: {
        profileId,
        videoTitle,
        channelName: channelName || null,
        videoId: videoId || null,
        reason: 'PARENT_MANUAL',
      },
    });

    const io = req.app.get('io');
    if (io) {
      const devices = await prisma.device.findMany({ where: { profileId } });
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('blockedVideosUpdated', { profileId });
      });
    }

    return sendSuccess(res, { blocked }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// DELETE /api/blocked-videos/:id — Parent unblock
exports.unblockVideo = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const blocked = await prisma.blockedVideo.findUnique({ where: { id } });
    if (!blocked) return sendError(res, 'Not found', 404);

    await prisma.blockedVideo.delete({ where: { id } });

    const io = req.app.get('io');
    if (io) {
      const devices = await prisma.device.findMany({ where: { profileId: blocked.profileId } });
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('blockedVideosUpdated', { profileId: blocked.profileId });
      });
    }

    return sendSuccess(res, { message: 'Unblocked successfully' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
