const { analyzeVideo, isAIAvailable } = require('../services/aiService');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const BATCH_SIZE = 10;
const ALERT_THRESHOLD = 4;

let isRunning = false;
let io = null;
let emptyRunCount = 0;

exports.setSocketIO = (socketIO) => { io = socketIO; };

exports.runAnalysisBatch = async () => {
  if (isRunning) {
    console.log('⏳ [AI WORKER] Already running, skip');
    return;
  }

  if (!isAIAvailable()) {
    console.log('⏭️ [AI WORKER] No AI provider configured (GROQ_API_KEY or OPENROUTER_API_KEY), skip batch');
    return;
  }

  isRunning = true;
  try {
    const logs = await prisma.youTubeLog.findMany({
      where: { isAnalyzed: false },
      orderBy: { watchedAt: 'asc' },
      take: BATCH_SIZE,
      include: { profile: { include: { user: true } } },
    });

    if (logs.length === 0) {
      emptyRunCount++;
      if (emptyRunCount % 6 === 1) {
        console.log('✅ [AI WORKER] No videos to analyze (checking every 10 min)');
      }
      return;
    }
    emptyRunCount = 0;

    console.log(`🤖 [AI WORKER] Analyzing ${logs.length} videos...`);

    for (const log of logs) {
      try {
        const result = await analyzeVideo({
          title: log.videoTitle,
          channel: log.channelName,
          thumbnailUrl: log.thumbnailUrl,
        });

        await prisma.youTubeLog.update({
          where: { id: log.id },
          data: {
            isAnalyzed: true,
            dangerLevel: result.dangerLevel,
            category: result.category,
            aiSummary: result.summary,
          },
        });

        if (result.dangerLevel >= ALERT_THRESHOLD) {
          await handleDangerousVideo(log, result);
        }

        // Rate limit: 2.5s giữa requests (Groq free tier 30 RPM)
        await sleep(2500);
      } catch (err) {
        const isTransient = err.message && (
          err.message.includes('503') || err.message.includes('Service Unavailable') ||
          err.message.includes('overloaded') || err.message.includes('high demand') ||
          err.message.includes('429') || err.message.includes('Too Many Requests')
        );
        if (isTransient) {
          // Transient error — leave isAnalyzed: false so next batch will retry
          console.warn(`⏳ [AI WORKER] Transient error for log ${log.id}, will retry next batch: ${err.message}`);
        } else {
          console.error(`❌ [AI WORKER] Permanent error for log ${log.id}, marking as analyzed: ${err.message}`);
          await prisma.youTubeLog.update({
            where: { id: log.id },
            data: { isAnalyzed: true, category: 'SAFE', dangerLevel: 1, aiSummary: 'Lỗi phân tích' },
          }).catch(() => {});
        }
      }
    }

    console.log(`✅ [AI WORKER] Batch done`);
  } finally {
    isRunning = false;
  }
};

async function handleDangerousVideo(log, result) {
  // 1. Tạo AIAlert
  const alert = await prisma.aIAlert.create({
    data: {
      profileId: log.profileId,
      youtubeLogId: log.id,
      dangerLevel: result.dangerLevel,
      category: result.category,
      summary: result.summary,
      notifiedAt: new Date(),
    },
  });

  // 2. Block video (findFirst + create để tránh lỗi khi không có unique constraint)
  const existing = await prisma.blockedVideo.findFirst({
    where: { profileId: log.profileId, videoTitle: log.videoTitle },
  });
  if (!existing) {
    await prisma.blockedVideo.create({
      data: {
        profileId: log.profileId,
        videoTitle: log.videoTitle,
        channelName: log.channelName,
        videoId: log.videoId,
        reason: 'AI_DETECTED',
      },
    }).catch(() => {});
  }

  // 3. Mark log as blocked
  await prisma.youTubeLog.update({
    where: { id: log.id },
    data: { isBlocked: true },
  });

  // 4. Emit Socket.IO real-time
  if (io && log.profile?.user) {
    io.to(`family_${log.profile.user.id}`).emit('aiAlert', {
      alertId: alert.id,
      profileId: log.profileId,
      profileName: log.profile.profileName,
      videoTitle: log.videoTitle,
      channelName: log.channelName,
      dangerLevel: result.dangerLevel,
      category: result.category,
      summary: result.summary,
    });

    const devices = await prisma.device.findMany({ where: { profileId: log.profileId } });
    devices.forEach(d => {
      io.to(`device_${d.deviceCode}`).emit('blockedVideosUpdated', { profileId: log.profileId });
    });
  }

  // 5. Push notification via FCM
  if (log.profile?.user) {
    try {
      const { sendAIAlertPush } = require('../services/fcmService');
      await sendAIAlertPush(log.profile.user, log.profile, alert, log);
    } catch (err) {
      console.error('❌ [AI WORKER] FCM push error:', err.message);
    }
  }

  console.log(`⚠️ [AI ALERT] Profile ${log.profileId}: "${log.videoTitle}" (level ${result.dangerLevel})`);
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
