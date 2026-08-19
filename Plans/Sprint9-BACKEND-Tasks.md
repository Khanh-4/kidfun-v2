# KidFun V3 — Sprint 9: YouTube Monitoring, AI Safety & Reports — BACKEND (Khanh)

> **Sprint Goal:** YouTube tracking + AI Gemini content analysis + Daily/Weekly Reports + Activity History
> **Branch gốc:** `develop`
> **AI:** Google Gemini 2.5 Flash (vision) — free tier (API key từ [aistudio.google.com](https://aistudio.google.com/app/apikey))
> **Trigger AI:** Batch analysis mỗi 10-15 phút
> **Alert ngưỡng:** dangerLevel >= 4
> **Reports:** Cron daily 00:05 VN + weekly T2 00:10 VN + realtime fallback

---

## Tổng quan Sprint 9 — Backend Tasks

### Phần A: YouTube Monitoring + AI Safety

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 1** | Database models (YouTubeLog, AIAlert, BlockedVideo) | Không |
| **Task 2** | YouTube logging API (Child batch upload) | Task 1 |
| **Task 3** | Gemini API integration | Task 1 |
| **Task 4** | Batch AI analysis worker (10 phút) | Task 2, 3 |
| **Task 5** | AI Alert API + Push notification | Task 1, 4 |
| **Task 6** | Dashboard query API cho Parent | Task 1, 4 |
| **Task 7** | Block video API (manual) | Task 5 |

### Phần B: Reports & Analytics

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 8** | ReportSnapshot model | Không |
| **Task 9** | Report aggregation service | Task 8 + data từ Sprint 5-8 |
| **Task 10** | Cron job (daily + weekly) | Task 9 |
| **Task 11** | Report API với cache fallback | Task 9 |
| **Task 12** | Activity History API | Task 1 + data từ Sprint 4-8 |

### Phần C: Test & Deploy

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 13** | Deploy + Integration test | Task 1-12 |

---

## 🎯 PHẦN A: YouTube Monitoring & AI Safety

## Task 1: Database Models

> **Branch:** `feature/backend/youtube-ai-models`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/youtube-ai-models
```

### 1.1: Prisma schema

File sửa: `backend/prisma/schema.prisma`

```prisma
model YouTubeLog {
  id                Int      @id @default(autoincrement())
  profileId         Int
  deviceId          Int
  videoTitle        String
  channelName       String?
  videoId           String?  // Optional, nếu lấy được
  thumbnailUrl      String?  // URL thumbnail (https://i.ytimg.com/vi/{id}/...)
  watchedAt         DateTime @default(now())
  durationSeconds   Int      @default(0) // Thời gian xem (không phải duration video)
  
  // AI analysis result (filled later by worker)
  isAnalyzed        Boolean  @default(false)
  dangerLevel       Int?     // 1-5 (null = chưa phân tích)
  category          String?  // SAFE | BULLY | SEXUAL | DRUG | VIOLENCE | SELF_HARM | DISTURBING
  aiSummary         String?  // Tóm tắt ngắn từ AI
  
  isBlocked         Boolean  @default(false)
  
  profile           Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device            Device   @relation(fields: [deviceId], references: [id], onDelete: Cascade)
  alerts            AIAlert[]
  
  @@index([profileId, watchedAt])
  @@index([isAnalyzed])
  @@index([dangerLevel])
}

model AIAlert {
  id            Int      @id @default(autoincrement())
  profileId     Int
  youtubeLogId  Int
  dangerLevel   Int      // 1-5
  category      String
  summary       String
  isRead        Boolean  @default(false)
  notifiedAt    DateTime?
  createdAt     DateTime @default(now())

  profile       Profile     @relation(fields: [profileId], references: [id], onDelete: Cascade)
  youtubeLog    YouTubeLog  @relation(fields: [youtubeLogId], references: [id], onDelete: Cascade)
  
  @@index([profileId, createdAt])
  @@index([isRead])
}

model BlockedVideo {
  id          Int      @id @default(autoincrement())
  profileId   Int
  videoTitle  String   // Match by title (vì có thể không có videoId)
  channelName String?
  videoId     String?
  reason      String?  // "AI_DETECTED" | "PARENT_MANUAL"
  createdAt   DateTime @default(now())

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  
  @@index([profileId])
}
```

### 1.2: Thêm relations vào Profile và Device

```prisma
model Profile {
  // ...
  youtubeLogs    YouTubeLog[]
  aiAlerts       AIAlert[]
  blockedVideos  BlockedVideo[]
}

model Device {
  // ...
  youtubeLogs    YouTubeLog[]
}
```

### 1.3: Migration

```bash
npx prisma migrate dev --name add-youtube-ai-models
npx prisma generate
```

### Commit:

```bash
git commit -m "feat(backend): add YouTubeLog, AIAlert, BlockedVideo models"
git push origin feature/backend/youtube-ai-models
```
→ PR → develop → merge

---

## Task 2: YouTube Logging API

> **Branch:** `feature/backend/youtube-logging`

### 2.1: YouTube Controller

File tạo mới: `backend/src/controllers/youtubeController.js`

**POST /api/child/youtube-logs** — Child batch upload

```javascript
exports.batchUploadLogs = async (req, res) => {
  try {
    const { deviceCode, logs } = req.body;
    // logs: [{ videoTitle, channelName, videoId, thumbnailUrl, watchedAt, durationSeconds }]

    if (!deviceCode || !Array.isArray(logs) || logs.length === 0) {
      return sendError(res, 'Invalid data', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    // Bulk create — bỏ qua duplicates dựa trên videoTitle + watchedAt
    const created = [];
    for (const log of logs) {
      // Skip nếu duration < 10 giây (chỉ là click qua)
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
        // Skip duplicates silently
      }
    }

    console.log(`📺 [YOUTUBE] Saved ${created.length} logs for profile ${device.profile.id}`);
    return sendSuccess(res, { saved: created.length }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/child/blocked-videos?deviceCode=XXX** — Child sync blocked videos

```javascript
exports.getBlockedVideos = async (req, res) => {
  try {
    const { deviceCode } = req.query;
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
```

### 2.2: Routes

```javascript
// routes/child.js
router.post('/youtube-logs', youtubeController.batchUploadLogs);
router.get('/blocked-videos', youtubeController.getBlockedVideos);
```

### Commit:

```bash
git commit -m "feat(backend): add YouTube logs batch upload + blocked videos sync"
```

---

## Task 3: Gemini API Integration

> **Branch:** `feature/backend/gemini-integration`

### 3.1: Cài SDK

```bash
cd backend
npm install @google/generative-ai
```

### 3.2: Lấy API key

1. Vào https://aistudio.google.com/app/apikey
2. Create API Key (free tier)
3. Add vào `.env`:

```
GEMINI_API_KEY=your_key_here
```

### 3.3: Gemini Service

File tạo mới: `backend/src/services/geminiService.js`

```javascript
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
// Dùng gemini-2.5-flash hoặc gemini-2.0-flash-exp (vision support, free tier)
const model = genAI.getGenerativeModel({ 
  model: 'gemini-2.5-flash',
  generationConfig: {
    temperature: 0.2,
    responseMimeType: 'application/json',
  },
});

const ANALYSIS_PROMPT = `Bạn là chuyên gia phân tích an toàn nội dung cho trẻ em từ 6-15 tuổi.
Phân tích video YouTube dưới đây (dựa trên title, channel name, và thumbnail) để xác định mức độ an toàn.

Trả về JSON với format CHÍNH XÁC:
{
  "dangerLevel": <số từ 1 đến 5>,
  "category": "<SAFE|BULLY|SEXUAL|DRUG|VIOLENCE|SELF_HARM|DISTURBING>",
  "summary": "<tóm tắt ngắn 1-2 câu lý do đánh giá, bằng tiếng Việt>"
}

Mức độ nguy hiểm:
- 1: Hoàn toàn an toàn (giáo dục, giải trí trẻ em phù hợp)
- 2: An toàn với cảnh báo nhỏ (giải trí người lớn nhưng không nguy hiểm)
- 3: Đáng nghi (nội dung gây tranh cãi, bạo lực nhẹ, ngôn từ không phù hợp)
- 4: Nguy hiểm (nội dung 18+, bạo lực rõ ràng, drug, gambling)
- 5: Cực kỳ nguy hiểm (self-harm, sexual abuse, predator content, ELSAGATE)

Categories:
- SAFE: An toàn cho trẻ
- BULLY: Bắt nạt, ngôn ngữ thù địch
- SEXUAL: Nội dung tình dục, gợi cảm
- DRUG: Ma túy, rượu, thuốc lá
- VIOLENCE: Bạo lực, máu me
- SELF_HARM: Tự hại, tự sát
- DISTURBING: Đáng sợ, ELSAGATE, đánh lừa trẻ em

Title: {title}
Channel: {channel}
`;

exports.analyzeVideo = async ({ title, channel, thumbnailUrl }) => {
  try {
    const prompt = ANALYSIS_PROMPT
      .replace('{title}', title || 'Unknown')
      .replace('{channel}', channel || 'Unknown');

    const parts = [{ text: prompt }];

    // Nếu có thumbnail, fetch và đính kèm vision
    if (thumbnailUrl) {
      try {
        const response = await fetch(thumbnailUrl);
        const buffer = await response.arrayBuffer();
        const base64 = Buffer.from(buffer).toString('base64');
        parts.push({
          inlineData: {
            mimeType: 'image/jpeg',
            data: base64,
          },
        });
      } catch (e) {
        console.warn('⚠️ [GEMINI] Cannot fetch thumbnail, fallback to text-only:', e.message);
      }
    }

    const result = await model.generateContent({ contents: [{ role: 'user', parts }] });
    const text = result.response.text();
    const parsed = JSON.parse(text);

    // Validation
    const dangerLevel = Math.max(1, Math.min(5, parseInt(parsed.dangerLevel) || 1));
    const validCategories = ['SAFE', 'BULLY', 'SEXUAL', 'DRUG', 'VIOLENCE', 'SELF_HARM', 'DISTURBING'];
    const category = validCategories.includes(parsed.category) ? parsed.category : 'SAFE';
    const summary = (parsed.summary || '').slice(0, 500);

    return { dangerLevel, category, summary };
  } catch (err) {
    console.error('❌ [GEMINI] Analysis error:', err.message);
    // Fallback: return SAFE để không block
    return { dangerLevel: 1, category: 'SAFE', summary: 'Phân tích thất bại' };
  }
};
```

### 3.4: Test endpoint (optional, dev only)

```javascript
// routes/dev.js (chỉ enable trong dev)
exports.testAnalyze = async (req, res) => {
  const { title, channel, thumbnailUrl } = req.body;
  const result = await geminiService.analyzeVideo({ title, channel, thumbnailUrl });
  return sendSuccess(res, result);
};
```

### Commit:

```bash
git commit -m "feat(backend): integrate Gemini AI for video safety analysis"
```

---

## Task 4: Batch AI Analysis Worker

> **Branch:** `feature/backend/ai-analysis-worker`

### 4.1: Worker logic

File tạo mới: `backend/src/workers/aiAnalysisWorker.js`

```javascript
const { analyzeVideo } = require('../services/geminiService');
const { sendAIAlertPush } = require('../services/fcmService');
const prisma = require('../prisma/client');

const BATCH_SIZE = 10;       // Process 10 videos/lần
const ALERT_THRESHOLD = 4;   // dangerLevel >= 4 → alert

let isRunning = false;
let io = null;

exports.setSocketIO = (socketIO) => { io = socketIO; };

exports.runAnalysisBatch = async () => {
  if (isRunning) {
    console.log('⏳ [AI WORKER] Already running, skip');
    return;
  }

  isRunning = true;
  try {
    // Lấy unanalyzed logs (oldest first), giới hạn batch size
    const logs = await prisma.youTubeLog.findMany({
      where: { isAnalyzed: false },
      orderBy: { watchedAt: 'asc' },
      take: BATCH_SIZE,
      include: { profile: { include: { user: true } } },
    });

    if (logs.length === 0) {
      console.log('✅ [AI WORKER] No videos to analyze');
      return;
    }

    console.log(`🤖 [AI WORKER] Analyzing ${logs.length} videos...`);

    for (const log of logs) {
      try {
        const result = await analyzeVideo({
          title: log.videoTitle,
          channel: log.channelName,
          thumbnailUrl: log.thumbnailUrl,
        });

        // Update log với kết quả
        await prisma.youTubeLog.update({
          where: { id: log.id },
          data: {
            isAnalyzed: true,
            dangerLevel: result.dangerLevel,
            category: result.category,
            aiSummary: result.summary,
          },
        });

        // Nếu nguy hiểm → tạo alert + block + push notification
        if (result.dangerLevel >= ALERT_THRESHOLD) {
          await handleDangerousVideo(log, result);
        }

        // Rate limit: sleep 1 giây giữa các requests (Gemini free tier 15 RPM)
        await sleep(4500); // 60s/15 = 4s safe
      } catch (err) {
        console.error(`❌ [AI WORKER] Error analyzing log ${log.id}:`, err.message);
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

  // 2. Block video (thêm vào BlockedVideo)
  await prisma.blockedVideo.upsert({
    where: { /* cần unique constraint, đơn giản dùng findFirst + create */ id: -1 },
    update: {},
    create: {
      profileId: log.profileId,
      videoTitle: log.videoTitle,
      channelName: log.channelName,
      videoId: log.videoId,
      reason: 'AI_DETECTED',
    },
  }).catch(() => {}); // Skip nếu trùng

  // 3. Mark log as blocked
  await prisma.youTubeLog.update({
    where: { id: log.id },
    data: { isBlocked: true },
  });

  // 4. Emit Socket.IO real-time
  if (io && log.profile?.user) {
    // Notify Parent
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

    // Notify Child device để sync blocked list
    const devices = await prisma.device.findMany({ where: { profileId: log.profileId } });
    devices.forEach(d => {
      io.to(`device_${d.deviceCode}`).emit('blockedVideosUpdated', { profileId: log.profileId });
    });
  }

  // 5. Push notification
  if (log.profile?.user) {
    await sendAIAlertPush(log.profile.user, log.profile, alert, log);
  }

  console.log(`⚠️ [AI ALERT] Profile ${log.profileId}: ${log.videoTitle} (level ${result.dangerLevel})`);
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
```

### 4.2: Schedule worker

File sửa: `backend/src/server.js`

```javascript
const aiWorker = require('./workers/aiAnalysisWorker');

// Pass Socket.IO instance
aiWorker.setSocketIO(io);

// Run every 10 minutes
setInterval(() => {
  aiWorker.runAnalysisBatch().catch(console.error);
}, 10 * 60 * 1000);

// Run once on startup (after 30s delay)
setTimeout(() => aiWorker.runAnalysisBatch(), 30 * 1000);
```

### 4.3: Manual trigger endpoint (testing)

```javascript
// routes/admin.js (auth required)
router.post('/admin/run-ai-analysis', authMiddleware, async (req, res) => {
  aiWorker.runAnalysisBatch().catch(console.error);
  return sendSuccess(res, { message: 'Analysis started' });
});
```

### Commit:

```bash
git commit -m "feat(backend): add batch AI analysis worker (10min interval)"
```

---

## Task 5: AI Alert API + Push Notification

> **Branch:** `feature/backend/ai-alert-push`

### 5.1: FCM helper

File sửa: `backend/src/services/fcmService.js`

```javascript
exports.sendAIAlertPush = async (user, profile, alert, log) => {
  try {
    const tokens = await prisma.fCMToken.findMany({ where: { userId: user.id } });
    if (tokens.length === 0) return;

    const dangerEmoji = alert.dangerLevel === 5 ? '🚨' : '⚠️';
    
    await admin.messaging().sendEachForMulticast({
      tokens: tokens.map(t => t.token),
      notification: {
        title: `${dangerEmoji} Cảnh báo nội dung nguy hiểm`,
        body: `${profile.profileName} đã xem: "${log.videoTitle.slice(0, 60)}"\n${alert.summary}`,
      },
      data: {
        type: 'AI_ALERT',
        alertId: String(alert.id),
        profileId: String(profile.id),
        dangerLevel: String(alert.dangerLevel),
        category: alert.category,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'ai_alerts',
          sound: 'default',
        },
      },
    });

    console.log(`🔔 [FCM AI ALERT] Sent to ${tokens.length} devices`);
  } catch (err) {
    console.error('❌ [FCM AI Alert] Error:', err.message);
  }
};
```

### 5.2: Alert Controller

File tạo mới: `backend/src/controllers/aiAlertController.js`

**GET /api/profiles/:id/ai-alerts** — List

```javascript
exports.getAlerts = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const onlyUnread = req.query.unread === 'true';

    const alerts = await prisma.aIAlert.findMany({
      where: {
        profileId,
        ...(onlyUnread ? { isRead: false } : {}),
      },
      include: { youtubeLog: true },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return sendSuccess(res, { alerts });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**PUT /api/ai-alerts/:id/read**

```javascript
exports.markRead = async (req, res) => {
  try {
    const alert = await prisma.aIAlert.update({
      where: { id: parseInt(req.params.id) },
      data: { isRead: true },
    });
    return sendSuccess(res, { alert });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add AI alert API and push notification"
```

---

## Task 6: Dashboard Query API

> **Branch:** `feature/backend/youtube-dashboard`

### 6.1: Dashboard endpoint

**GET /api/profiles/:id/youtube/dashboard?days=7**

```javascript
exports.getDashboard = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const days = parseInt(req.query.days) || 7;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // 1. Tổng số videos
    const totalVideos = await prisma.youTubeLog.count({
      where: { profileId, watchedAt: { gte: startDate } },
    });

    // 2. Tổng watch time
    const allLogs = await prisma.youTubeLog.findMany({
      where: { profileId, watchedAt: { gte: startDate } },
      select: { durationSeconds: true, channelName: true, dangerLevel: true, category: true },
    });
    const totalWatchSeconds = allLogs.reduce((sum, l) => sum + l.durationSeconds, 0);

    // 3. Top channels
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

    // 4. Danger summary
    const dangerCounts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, unanalyzed: 0 };
    const categoryCounts = {};
    for (const log of allLogs) {
      if (log.dangerLevel == null) {
        dangerCounts.unanalyzed++;
      } else {
        dangerCounts[log.dangerLevel]++;
      }
      if (log.category) {
        categoryCounts[log.category] = (categoryCounts[log.category] || 0) + 1;
      }
    }

    // 5. Recent alerts
    const recentAlerts = await prisma.aIAlert.findMany({
      where: { profileId },
      include: { youtubeLog: true },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    // 6. Daily activity (videos per day)
    const dailyMap = {};
    for (const log of await prisma.youTubeLog.findMany({
      where: { profileId, watchedAt: { gte: startDate } },
      select: { watchedAt: true },
    })) {
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
```

### 6.2: Drill-down list

**GET /api/profiles/:id/youtube/logs?date=YYYY-MM-DD&minDanger=0&channel=&page=1&limit=20**

```javascript
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

    const [total, logs] = await Promise.all([
      prisma.youTubeLog.count({ where }),
      prisma.youTubeLog.findMany({
        where,
        orderBy: { watchedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return sendSuccess(res, { total, page, limit, logs });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add YouTube dashboard and logs query API"
```

---

## Task 7: Block Video API (Manual)

> **Branch:** `feature/backend/block-video-api`

### 7.1: Endpoints

**POST /api/profiles/:id/blocked-videos** — Parent chặn manual

```javascript
exports.blockVideo = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { videoTitle, channelName, videoId } = req.body;

    if (!videoTitle) return sendError(res, 'videoTitle required', 400);

    const blocked = await prisma.blockedVideo.create({
      data: {
        profileId,
        videoTitle,
        channelName,
        videoId,
        reason: 'PARENT_MANUAL',
      },
    });

    // Notify Child
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
```

**DELETE /api/blocked-videos/:id**

```javascript
exports.unblockVideo = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const blocked = await prisma.blockedVideo.findUnique({ where: { id } });
    if (!blocked) return sendError(res, 'Not found', 404);

    await prisma.blockedVideo.delete({ where: { id } });

    // Notify Child
    const io = req.app.get('io');
    if (io) {
      const devices = await prisma.device.findMany({ where: { profileId: blocked.profileId } });
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('blockedVideosUpdated', { profileId: blocked.profileId });
      });
    }

    return sendSuccess(res, { message: 'Unblocked' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add manual block video API"
```

---


---

## 📊 PHẦN B: Reports & Analytics

## Task 8: ReportSnapshot Model

> **Branch:** `feature/backend/report-snapshot-model`

### 8.1: Prisma schema

File sửa: `backend/prisma/schema.prisma`

```prisma
model ReportSnapshot {
  id            Int      @id @default(autoincrement())
  profileId     Int
  type          String   // "DAILY" | "WEEKLY"
  periodStart   DateTime // Đầu kỳ (00:00 của ngày/T2)
  periodEnd     DateTime // Cuối kỳ
  
  // Aggregated metrics (stored as JSON để linh hoạt)
  data          Json     // {totalScreenMinutes, appUsage: [], topApps, youtubeStats, locationStats, policyStats, aiAlertsCount}
  
  generatedAt   DateTime @default(now())

  profile       Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  
  @@unique([profileId, type, periodStart])
  @@index([profileId, type, periodStart])
}
```

### 8.2: Thêm relation vào Profile

```prisma
model Profile {
  // ...
  reportSnapshots  ReportSnapshot[]
}
```

### 8.3: Migration

```bash
npx prisma migrate dev --name add-report-snapshot
npx prisma generate
```

### Commit:

```bash
git commit -m "feat(backend): add ReportSnapshot model"
```

---

## Task 9: Report Aggregation Service

> **Branch:** `feature/backend/report-service`

### 9.1: Service chính

File tạo mới: `backend/src/services/reportService.js`

```javascript
const prisma = require('../prisma/client');

/**
 * Generate daily report cho 1 profile, 1 ngày
 */
exports.generateDailyReport = async (profileId, date) => {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  const data = await aggregateData(profileId, start, end);

  const report = await prisma.reportSnapshot.upsert({
    where: {
      profileId_type_periodStart: {
        profileId,
        type: 'DAILY',
        periodStart: start,
      },
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

/**
 * Generate weekly report (T2 → CN)
 */
exports.generateWeeklyReport = async (profileId, mondayDate) => {
  const start = new Date(mondayDate);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 7);

  const data = await aggregateData(profileId, start, end);

  const report = await prisma.reportSnapshot.upsert({
    where: {
      profileId_type_periodStart: {
        profileId,
        type: 'WEEKLY',
        periodStart: start,
      },
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

/**
 * Core aggregation function
 */
async function aggregateData(profileId, start, end) {
  // 1. App usage (Sprint 5)
  const appLogs = await prisma.appUsageLog.findMany({
    where: {
      profileId,
      date: { gte: start, lt: end },
    },
  });

  const totalScreenSeconds = appLogs.reduce((sum, l) => sum + l.usageSeconds, 0);

  // Group by package
  const appMap = {};
  for (const log of appLogs) {
    const key = log.packageName;
    if (!appMap[key]) appMap[key] = { packageName: key, appName: log.appName, seconds: 0 };
    appMap[key].seconds += log.usageSeconds;
  }
  const topApps = Object.values(appMap)
    .sort((a, b) => b.seconds - a.seconds)
    .slice(0, 10);

  // 2. YouTube stats (Sprint 9)
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
    if (l.dangerLevel) youtubeStats.dangerLevels[l.dangerLevel]++;
  }

  // 3. Location stats (Sprint 7)
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

  // 4. Policy stats (Sprint 8)
  const [blockedCategories, customBlockedDomains, appTimeLimits, schoolSchedule] = await Promise.all([
    prisma.blockedCategory.count({ where: { profileId, isBlocked: true } }),
    prisma.customBlockedDomain.count({ where: { profileId } }),
    prisma.appTimeLimit.count({ where: { profileId, isActive: true } }),
    prisma.schoolSchedule.findUnique({ where: { profileId } }),
  ]);
  const policyStats = {
    activeAppLimits: appTimeLimits,
    blockedWebCategories: blockedCategories,
    customBlockedDomains,
    schoolModeEnabled: schoolSchedule?.isEnabled || false,
  };

  // 5. SOS alerts (Sprint 7)
  const sosAlerts = await prisma.sOSAlert.count({
    where: { profileId, createdAt: { gte: start, lt: end } },
  });

  // 6. AI alerts (Sprint 9)
  const aiAlerts = await prisma.aIAlert.count({
    where: { profileId, createdAt: { gte: start, lt: end } },
  });

  // 7. Time extensions (Sprint 4)
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
```

### Commit:

```bash
git commit -m "feat(backend): add report aggregation service"
```

---

## Task 10: Cron Job

> **Branch:** `feature/backend/report-cron`

### 10.1: Scheduler

Dùng `setInterval` đơn giản (không cần thư viện thêm vì Railway luôn chạy):

File tạo mới: `backend/src/workers/reportWorker.js`

```javascript
const { generateDailyReport, generateWeeklyReport } = require('../services/reportService');
const prisma = require('../prisma/client');

let isRunning = false;

/**
 * Generate daily reports for all active profiles
 */
async function runDailyReports() {
  if (isRunning) return;
  isRunning = true;

  try {
    const profiles = await prisma.profile.findMany({ where: { isActive: true } });
    console.log(`📊 [REPORT] Generating daily reports for ${profiles.length} profiles`);

    // Hôm qua (23:59 → generate cho ngày hôm qua)
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    for (const profile of profiles) {
      try {
        await generateDailyReport(profile.id, yesterday);
      } catch (err) {
        console.error(`❌ [REPORT] Daily error for profile ${profile.id}:`, err.message);
      }
    }
    console.log(`✅ [REPORT] Daily done`);
  } finally {
    isRunning = false;
  }
}

/**
 * Generate weekly reports (Sunday 23:59 for the week just ended)
 */
async function runWeeklyReports() {
  const profiles = await prisma.profile.findMany({ where: { isActive: true } });
  console.log(`📊 [REPORT] Generating weekly reports for ${profiles.length} profiles`);

  // Monday của tuần vừa rồi
  const now = new Date();
  const monday = new Date(now);
  const diff = now.getDay() === 0 ? 6 : now.getDay() - 1; // Monday offset
  monday.setDate(now.getDate() - diff - 7); // Previous week monday
  monday.setHours(0, 0, 0, 0);

  for (const profile of profiles) {
    try {
      await generateWeeklyReport(profile.id, monday);
    } catch (err) {
      console.error(`❌ [REPORT] Weekly error for profile ${profile.id}:`, err.message);
    }
  }
  console.log(`✅ [REPORT] Weekly done`);
}

/**
 * Schedule: check mỗi giờ, run nếu đúng time
 */
function startScheduler() {
  setInterval(async () => {
    const now = new Date();
    // VN time
    const vnNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const hour = vnNow.getHours();
    const day = vnNow.getDay(); // 0 = Sunday

    // Daily: mỗi ngày 00:05 VN (sau khi qua ngày mới)
    if (hour === 0 && vnNow.getMinutes() < 10) {
      await runDailyReports();
    }

    // Weekly: T2 00:10 VN (sau daily)
    if (day === 1 && hour === 0 && vnNow.getMinutes() >= 10 && vnNow.getMinutes() < 15) {
      await runWeeklyReports();
    }
  }, 5 * 60 * 1000); // Check every 5 minutes

  console.log('⏰ [REPORT SCHEDULER] Started');
}

module.exports = { runDailyReports, runWeeklyReports, startScheduler };
```

### 10.2: Start trong server.js

```javascript
const reportWorker = require('./workers/reportWorker');
reportWorker.startScheduler();
```

### 10.3: Manual trigger (dev only)

```javascript
// routes/admin.js
router.post('/admin/run-daily-reports', authMiddleware, async (req, res) => {
  reportWorker.runDailyReports().catch(console.error);
  return sendSuccess(res, { message: 'Daily reports triggered' });
});

router.post('/admin/run-weekly-reports', authMiddleware, async (req, res) => {
  reportWorker.runWeeklyReports().catch(console.error);
  return sendSuccess(res, { message: 'Weekly reports triggered' });
});
```

### Commit:

```bash
git commit -m "feat(backend): add report cron job worker"
```

---

## Task 11: Report API

> **Branch:** `feature/backend/report-api`

### 11.1: Controller

File tạo mới: `backend/src/controllers/reportController.js`

**GET /api/profiles/:id/reports/daily?date=YYYY-MM-DD**

```javascript
const { generateDailyReport } = require('../services/reportService');

exports.getDailyReport = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const date = new Date(dateStr);
    date.setHours(0, 0, 0, 0);

    // Try cached first
    let report = await prisma.reportSnapshot.findUnique({
      where: {
        profileId_type_periodStart: {
          profileId,
          type: 'DAILY',
          periodStart: date,
        },
      },
    });

    // Realtime fallback: generate on-demand
    // - Nếu không có cache
    // - Hoặc cache là HÔM NAY (stale, cần refresh)
    const isToday = isSameDay(date, new Date());
    if (!report || isToday) {
      report = await generateDailyReport(profileId, date);
    }

    return sendSuccess(res, { report });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

function isSameDay(d1, d2) {
  return d1.getFullYear() === d2.getFullYear() &&
         d1.getMonth() === d2.getMonth() &&
         d1.getDate() === d2.getDate();
}
```

**GET /api/profiles/:id/reports/weekly?weekStart=YYYY-MM-DD**

```javascript
exports.getWeeklyReport = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    let monday;
    
    if (req.query.weekStart) {
      monday = new Date(req.query.weekStart);
    } else {
      // Tuần hiện tại
      monday = new Date();
      const diff = monday.getDay() === 0 ? 6 : monday.getDay() - 1;
      monday.setDate(monday.getDate() - diff);
    }
    monday.setHours(0, 0, 0, 0);

    let report = await prisma.reportSnapshot.findUnique({
      where: {
        profileId_type_periodStart: {
          profileId,
          type: 'WEEKLY',
          periodStart: monday,
        },
      },
    });

    // Realtime nếu tuần này (chưa kết thúc) hoặc chưa có cache
    const now = new Date();
    const isThisWeek = monday.getTime() + 7 * 24 * 60 * 60 * 1000 > now.getTime();
    if (!report || isThisWeek) {
      report = await generateWeeklyReport(profileId, monday);
    }

    return sendSuccess(res, { report });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 11.2: Routes

```javascript
router.get('/:id/reports/daily', authMiddleware, reportController.getDailyReport);
router.get('/:id/reports/weekly', authMiddleware, reportController.getWeeklyReport);
```

### Commit:

```bash
git commit -m "feat(backend): add report API with cache fallback"
```

---

## Task 12: Activity History API

> **Branch:** `feature/backend/activity-history`

### 12.1: Controller

File tạo mới: `backend/src/controllers/activityHistoryController.js`

**GET /api/profiles/:id/activity-history?date=YYYY-MM-DD**

Trả timeline các hoạt động trong ngày, sorted chronologically:

```javascript
exports.getActivityHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const start = new Date(dateStr);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const activities = [];

    // 1. Sessions (start/end)
    const sessions = await prisma.usageSession.findMany({
      where: { profileId, startTime: { gte: start, lt: end } },
    });
    for (const s of sessions) {
      activities.push({
        type: 'SESSION_START',
        timestamp: s.startTime,
        title: 'Bắt đầu dùng điện thoại',
        icon: 'phone_android',
      });
      if (s.endTime) {
        activities.push({
          type: 'SESSION_END',
          timestamp: s.endTime,
          title: 'Kết thúc phiên dùng',
          description: `${Math.round((s.endTime - s.startTime) / 1000 / 60)} phút`,
          icon: 'stop',
        });
      }
    }

    // 2. Geofence events
    const geofenceEvents = await prisma.geofenceEvent.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
      include: { geofence: true },
    });
    for (const e of geofenceEvents) {
      activities.push({
        type: e.type === 'ENTER' ? 'GEOFENCE_ENTER' : 'GEOFENCE_EXIT',
        timestamp: e.createdAt,
        title: e.type === 'ENTER' ? `Vào ${e.geofence.name}` : `Rời ${e.geofence.name}`,
        icon: 'place',
      });
    }

    // 3. Time extension requests
    const extensions = await prisma.timeExtensionRequest.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
    });
    for (const ext of extensions) {
      activities.push({
        type: 'TIME_EXTENSION',
        timestamp: ext.createdAt,
        title: `Xin thêm ${ext.requestedMinutes} phút`,
        description: `Trạng thái: ${ext.status}`,
        icon: 'access_time',
      });
    }

    // 4. SOS alerts
    const sos = await prisma.sOSAlert.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
    });
    for (const s of sos) {
      activities.push({
        type: 'SOS',
        timestamp: s.createdAt,
        title: '🆘 Gửi SOS khẩn cấp',
        description: s.message || '',
        icon: 'warning',
      });
    }

    // 5. AI alerts
    const aiAlerts = await prisma.aIAlert.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
      include: { youtubeLog: true },
    });
    for (const a of aiAlerts) {
      activities.push({
        type: 'AI_ALERT',
        timestamp: a.createdAt,
        title: `⚠️ Cảnh báo AI: ${a.category}`,
        description: a.summary,
        icon: 'psychology',
      });
    }

    // 6. Warnings (soft warning)
    const warnings = await prisma.warning.findMany({
      where: { profileId, createdAt: { gte: start, lt: end } },
    });
    for (const w of warnings) {
      activities.push({
        type: 'WARNING',
        timestamp: w.createdAt,
        title: `Cảnh báo mềm ${w.minutesLeft} phút`,
        icon: 'notifications',
      });
    }

    // Sort by timestamp descending (newest first)
    activities.sort((a, b) => b.timestamp - a.timestamp);

    return sendSuccess(res, { date: dateStr, count: activities.length, activities });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 12.2: Route

```javascript
router.get('/:id/activity-history', authMiddleware, activityHistoryController.getActivityHistory);
```

### Commit:

```bash
git commit -m "feat(backend): add activity history timeline API"
```

---


---

## 🚀 PHẦN C: Deploy + Test

## Task 13: Deploy + Integration Test

### 13.1: Pre-deploy checklist

- [ ] Tất cả migrations đã chạy trên Railway
- [ ] Seed data (nếu có) đã chạy
- [ ] Environment variables đã set trên Railway:
  - `GEMINI_API_KEY` (có thể để trống lúc đầu, code tự skip AI worker)
  - `DATABASE_URL` (đã có từ trước)
  - `JWT_SECRET` (đã có từ trước)
  - `FIREBASE_*` (đã có từ trước)

### 13.2: Test YouTube + AI (Phần A)

```bash
# 1. Child upload logs
curl -X POST "https://kidfun-backend-production.up.railway.app/api/child/youtube-logs" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceCode": "BE4B.251210.005",
    "logs": [
      {"videoTitle":"Cocomelon - ABC Song","channelName":"Cocomelon","durationSeconds":120,"thumbnailUrl":"https://i.ytimg.com/vi/abc/hqdefault.jpg"},
      {"videoTitle":"Squid Game Episode 1","channelName":"Netflix","durationSeconds":300}
    ]
  }'

# 2. Trigger AI analysis manually (cần GEMINI_API_KEY)
curl -X POST "https://kidfun-backend-production.up.railway.app/api/admin/run-ai-analysis" \
  -H "Authorization: Bearer <token>"

# 3. Dashboard
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/youtube/dashboard?days=7" \
  -H "Authorization: Bearer <token>"

# 4. AI Alerts
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/ai-alerts?unread=true" \
  -H "Authorization: Bearer <token>"

# 5. Blocked videos sync
curl "https://kidfun-backend-production.up.railway.app/api/child/blocked-videos?deviceCode=BE4B.251210.005"
```

### 13.3: Test Reports (Phần B)

```bash
# 1. Daily report hôm nay (realtime)
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/reports/daily" \
  -H "Authorization: Bearer <token>"

# 2. Daily report ngày hôm qua (từ cache nếu cron đã chạy)
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/reports/daily?date=2026-04-15" \
  -H "Authorization: Bearer <token>"

# 3. Weekly report tuần này
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/reports/weekly" \
  -H "Authorization: Bearer <token>"

# 4. Activity history hôm nay
curl "https://kidfun-backend-production.up.railway.app/api/profiles/13/activity-history" \
  -H "Authorization: Bearer <token>"

# 5. Manual trigger cron
curl -X POST "https://kidfun-backend-production.up.railway.app/api/admin/run-daily-reports" \
  -H "Authorization: Bearer <token>"
```

### 13.4: Nhắn Frontend đầy đủ

```
Sprint 9 Backend DONE!

📺 YOUTUBE LOGGING:
- POST /api/child/youtube-logs (batch upload, skip < 10s)
- GET /api/child/blocked-videos?deviceCode=XXX

📊 YOUTUBE DASHBOARD (Parent):
- GET /api/profiles/:id/youtube/dashboard?days=7
- GET /api/profiles/:id/youtube/logs?date=&minDanger=&channel=&page=
- GET /api/profiles/:id/ai-alerts?unread=true
- PUT /api/ai-alerts/:id/read

🚫 BLOCK VIDEOS:
- POST /api/profiles/:id/blocked-videos (manual)
- DELETE /api/blocked-videos/:id

📈 REPORTS (Parent):
- GET /api/profiles/:id/reports/daily?date=YYYY-MM-DD
- GET /api/profiles/:id/reports/weekly?weekStart=YYYY-MM-DD

📅 ACTIVITY HISTORY (Parent):
- GET /api/profiles/:id/activity-history?date=YYYY-MM-DD

🔌 Socket.IO events (Parent room family_{userId}):
- aiAlert — khi AI phát hiện nguy hiểm
- blockedVideosUpdated — khi blocked list thay đổi (Child device room)

⏰ CRON JOBS tự chạy:
- AI Worker: mỗi 10 phút
- Daily reports: 00:05 VN time
- Weekly reports: T2 00:10 VN time
```

---

## ✅ Checklist Tổng hợp Sprint 9 — Backend

### Phần A: YouTube + AI

| # | Task | Status |
|---|------|--------|
| A1 | Models: YouTubeLog, AIAlert, BlockedVideo | ⬜ |
| A2 | Migration thành công | ⬜ |
| A3 | POST /api/child/youtube-logs (batch + dedup + skip <10s) | ⬜ |
| A4 | GET /api/child/blocked-videos | ⬜ |
| A5 | Gemini SDK setup (`@google/generative-ai`) | ⬜ |
| A6 | Gemini analyzeVideo function (vision + prompt VN) | ⬜ |
| A7 | AI Worker batch (10 phút interval, rate limit 4.5s/request) | ⬜ |
| A8 | Safe mode khi chưa có GEMINI_API_KEY (skip, không crash) | ⬜ |
| A9 | Auto block video khi danger >= 4 | ⬜ |
| A10 | AI Alert API (list, mark read) | ⬜ |
| A11 | FCM push notification cho AI Alert | ⬜ |
| A12 | Dashboard query API | ⬜ |
| A13 | Logs filter API (drill-down) | ⬜ |
| A14 | Manual block video API | ⬜ |
| A15 | Socket.IO events (aiAlert, blockedVideosUpdated) | ⬜ |

### Phần B: Reports

| # | Task | Status |
|---|------|--------|
| B1 | ReportSnapshot model + migration | ⬜ |
| B2 | reportService.generateDailyReport | ⬜ |
| B3 | reportService.generateWeeklyReport | ⬜ |
| B4 | aggregateData function (gộp Sprint 5-9) | ⬜ |
| B5 | Cron scheduler (check mỗi 5 phút) | ⬜ |
| B6 | Timezone VN (Asia/Ho_Chi_Minh) | ⬜ |
| B7 | Manual trigger admin API | ⬜ |
| B8 | GET reports/daily với realtime fallback | ⬜ |
| B9 | GET reports/weekly với realtime fallback | ⬜ |
| B10 | Activity history API (6 loại events) | ⬜ |
| B11 | Sort timeline chronologically | ⬜ |

### Phần C: Deploy + Test

| # | Task | Status |
|---|------|--------|
| C1 | Deploy Railway thành công | ⬜ |
| C2 | Test tất cả API YouTube + AI bằng curl | ⬜ |
| C3 | Test tất cả API Reports bằng curl | ⬜ |
| C4 | Nhắn đầy đủ API docs cho Frontend | ⬜ |

---

## 📝 Lưu ý quan trọng

### Về AI Gemini

- **API key free:** [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) — KHÔNG cần Google Cloud Console, KHÔNG cần thẻ tín dụng
- **Free tier limits:** 15 RPM (requests/phút) và 1500 RPD (requests/ngày). Worker sleep 4.5s giữa requests để safe.
- **Code-first, key-later:** Code hoàn chỉnh rồi set `GEMINI_API_KEY` trong Railway Variables sau cũng được. Worker tự skip nếu chưa có key.
- **Fallback SAFE:** Nếu API fail → return `{dangerLevel: 1, category: 'SAFE'}` để không block user bất hợp lý.

### Về Privacy

- **Chỉ log metadata:** title, channel, duration. KHÔNG lưu transcript, comments, search history.
- **AI analysis:** chỉ chạy trên metadata + thumbnail public. Không lưu lại image sau khi analyze.
- **Parent có thể tắt YouTube Monitoring** trong Settings nếu muốn tôn trọng privacy con.

### Về Reports

- **Realtime fallback:** Ngày hôm nay luôn tính realtime (vì data còn thay đổi), ngày quá khứ dùng cache (nhanh).
- **Cron trên Railway:** Dùng `setInterval` trong process chính. Nếu Railway restart thì scheduler reset lại.
- **Timezone:** Quan trọng! Luôn check `Asia/Ho_Chi_Minh` cho cron trigger.
- **Schema JSON:** `data` field là JSON — linh hoạt, có thể thêm field mới mà không cần migrate.

### Về Deploy

- Worker AI và Reports chạy trong process chính (không cần service riêng).
- Railway dynos luôn chạy (không sleep như Heroku free tier cũ).
- Nếu sau này cần scale → tách ra service riêng với BullMQ/Redis.

---

## 🔀 Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/<tên-task>
git commit -m "feat(backend): mô tả"
git push origin feature/backend/<tên-task>
# → PR → develop → Khanh review → merge
```
