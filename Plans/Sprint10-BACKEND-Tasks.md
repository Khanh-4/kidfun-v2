# KidFun V3 — Sprint 10: Polish, Testing & Bảo vệ — BACKEND (Khanh)

> **Sprint Goal:** Fix bugs, optimize performance, security audit, seed data demo, chuẩn bị bảo vệ hội đồng
> **Branch gốc:** `develop`
> **Deadline:** 24/05/2026 (hoàn thành) → 25-31/05 nộp báo cáo → 01-14/06 bảo vệ
> **KHÔNG thêm tính năng mới** — chỉ fix + optimize + polish + tài liệu

---

## Tổng quan Sprint 10 — Backend Tasks

| Task | Nội dung | Ưu tiên |
|------|----------|---------|
| **Task 1** | Fix bugs từ Railway logs | 🔴 CRITICAL |
| **Task 2** | Performance optimization | 🟠 HIGH |
| **Task 3** | Security audit | 🟠 HIGH |
| **Task 4** | Seed data demo cho bảo vệ | 🟠 HIGH |
| **Task 5** | API documentation | 🟡 MEDIUM |
| **Task 6** | Database backup + RLS | 🟡 MEDIUM |
| **Task 7** | Final deploy + E2E test | 🔴 CRITICAL |

---

## Task 1: Fix Bugs từ Railway Logs

> **Branch:** `fix/backend/sprint10-bugfix`

### Bug 1.1 (CRITICAL): Prisma P2025 — Device.update() khi Socket disconnect

**Vấn đề:** Khi child disconnect, `socketService.js:283` gọi `prisma.device.update()` để set `isOnline=false`, nhưng device record không tồn tại → crash handler.

**File sửa:** `backend/src/services/socketService.js`

```javascript
// CŨ (crash khi device không tồn tại):
await prisma.device.update({
  where: { deviceCode },
  data: { isOnline: false, lastSeen: new Date() },
});

// MỚI (safe — không throw khi 0 records):
await prisma.device.updateMany({
  where: { deviceCode },
  data: { isOnline: false, lastSeen: new Date() },
});
```

### Bug 1.2 (HIGH): Device chưa link nhưng Child app vẫn gửi requests liên tục

**Vấn đề:** Device `UKQ1.231207.002` không tồn tại trong DB → tất cả child API trả 404 → app cứ retry.

**File sửa:** `backend/src/services/socketService.js` — joinDevice handler

```javascript
// Trong joinDevice handler, khi device không tồn tại:
socket.on('joinDevice', async (data) => {
  const device = await prisma.device.findFirst({ where: { deviceCode: data.deviceCode } });
  if (!device) {
    console.warn(`⚠️ [SOCKET] joinDevice: No device found for code ${data.deviceCode}`);
    // MỚI: Emit error event cho client biết
    socket.emit('deviceError', {
      code: 'DEVICE_NOT_FOUND',
      message: 'Thiết bị chưa được liên kết. Vui lòng quét mã QR từ ứng dụng phụ huynh.',
    });
    return;
  }
  // ... tiếp tục join room ...
});
```

### Bug 1.3 (MEDIUM): AI Worker spam log "No videos to analyze"

**File sửa:** `backend/src/workers/aiAnalysisWorker.js`

```javascript
// CŨ:
if (logs.length === 0) {
  console.log('✅ [AI WORKER] No videos to analyze');
  return;
}

// MỚI: Chỉ log 1 lần / 6 lần chạy (mỗi 1 giờ thay vì mỗi 10 phút)
let emptyRunCount = 0;
if (logs.length === 0) {
  emptyRunCount++;
  if (emptyRunCount % 6 === 1) {
    console.log('✅ [AI WORKER] No videos to analyze (checking every 10 min)');
  }
  return;
}
emptyRunCount = 0; // Reset khi có videos
```

### Commit:

```bash
git checkout develop && git pull origin develop
git checkout -b fix/backend/sprint10-bugfix
git commit -m "fix(backend): P2025 disconnect crash, device not found emit, AI worker log spam"
git push origin fix/backend/sprint10-bugfix
```
→ PR → develop → merge

---

## Task 2: Performance Optimization

> **Branch:** `chore/backend/performance`

### 2.1: Heartbeat — giảm từ 5-6s xuống < 1s

**Vấn đề:** `POST /api/child/session/heartbeat` mất 5-6 giây.

**Nguyên nhân có thể:**
- Query tính `remainingSeconds` join nhiều bảng (TimeLimit, TimeExtensionRequest, UsageSession)
- Supabase free tier cold start / connection pool hết

**Fix 1: Cache today-limit trong memory**

```javascript
// backend/src/services/cacheService.js
const cache = new Map();
const CACHE_TTL = 60 * 1000; // 1 phút

exports.getCached = (key) => {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  return item.value;
};

exports.setCache = (key, value, ttlMs = CACHE_TTL) => {
  cache.set(key, { value, expiry: Date.now() + ttlMs });
};

exports.clearCache = (keyPrefix) => {
  for (const key of cache.keys()) {
    if (key.startsWith(keyPrefix)) cache.delete(key);
  }
};
```

**Fix 2: Dùng cache trong heartbeat**

```javascript
// heartbeatController.js
const { getCached, setCache } = require('../services/cacheService');

exports.heartbeat = async (req, res) => {
  const cacheKey = `heartbeat_${sessionId}`;
  const cached = getCached(cacheKey);
  if (cached) {
    return sendSuccess(res, cached);
  }

  // ... tính toán như cũ ...
  
  setCache(cacheKey, result, 30 * 1000); // Cache 30s
  return sendSuccess(res, result);
};
```

**Fix 3: Invalidate cache khi Parent thay đổi limit**

```javascript
// Khi update time limit:
clearCache(`heartbeat_`);  // Clear all heartbeat caches
```

### 2.2: today-limit — giảm từ 3-4s xuống < 1s

Tương tự, cache `today-limit` theo `deviceCode + ngày`:

```javascript
const cacheKey = `todaylimit_${deviceCode}_${new Date().toISOString().slice(0,10)}`;
```

### 2.3: Prisma connection pool

File sửa: `backend/src/prisma/client.js` (hoặc nơi khởi tạo PrismaClient)

```javascript
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
  // Tối ưu connection pool
  log: process.env.NODE_ENV === 'production' ? ['error'] : ['query', 'error'],
});
```

Trong `DATABASE_URL` thêm params:

```
?connection_limit=10&pool_timeout=20
```

### 2.4: Giảm tần suất heartbeat

Nếu heartbeat vẫn chậm sau cache, **tăng interval** từ Client:

Frontend task: đổi heartbeat interval từ 30s → 60s (1 phút). Đủ chính xác cho countdown.

### Commit:

```bash
git commit -m "chore(backend): add in-memory cache for heartbeat and today-limit"
```

---

## Task 3: Security Audit

> **Branch:** `chore/backend/security`

### 3.1: Input validation checklist

Kiểm tra TẤT CẢ controllers:

| Endpoint | Check |
|----------|-------|
| POST /api/auth/register | email format, password min 6, fullName required | ⬜ |
| POST /api/auth/login | email, password required | ⬜ |
| POST /api/profiles | profileName, dateOfBirth required | ⬜ |
| PUT /api/profiles/:id/time-limits | dayOfWeek 0-6 (parseInt!), limitMinutes >= 0 | ⬜ |
| POST /api/child/youtube-logs | logs array, deviceCode required | ⬜ |
| POST /api/child/sos | latitude/longitude number, deviceCode required | ⬜ |
| POST /api/profiles/:id/geofences | radius 50-5000, lat/lng number | ⬜ |
| POST /api/profiles/:id/app-time-limits | dailyLimitMinutes >= 0, packageName string | ⬜ |
| POST /api/profiles/:id/blocked-categories | categoryId parseInt, isBlocked boolean | ⬜ |
| PUT /api/profiles/:id/school-schedule | templateStartTime format HH:MM | ⬜ |

### 3.2: Rate limiting

```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

// General API limiter
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 phút
  max: 100, // 100 requests/phút/IP
  message: { success: false, message: 'Too many requests' },
});

// Auth limiter (chặn brute force)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 phút
  max: 10, // 10 attempts
  message: { success: false, message: 'Too many login attempts' },
});

app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
```

### 3.3: Helmet (HTTP security headers)

```bash
npm install helmet
```

```javascript
const helmet = require('helmet');
app.use(helmet());
```

### 3.4: JWT security

- [ ] Token expiry hợp lý (1-7 ngày, không để forever)
- [ ] Refresh token mechanism (nếu có)
- [ ] Không lưu JWT trong logs

### 3.5: SQL injection

Prisma ORM đã tự động escape inputs → an toàn. Nhưng kiểm tra:
- [ ] Không có raw SQL query nào (`prisma.$queryRaw`)
- [ ] Nếu có → dùng parameterized queries

### Commit:

```bash
git commit -m "chore(backend): add rate limiting, helmet, input validation"
```

---

## Task 4: Seed Data Demo cho Bảo vệ

> **Branch:** `chore/backend/seed-defense-data`

### 4.1: Mục tiêu

Tạo bộ data đẹp, đủ để demo trước hội đồng:
- Tài khoản Parent (demo@kidfun.app / demo123)
- Profile con "Bé An" với đủ loại data
- 7 ngày usage data mẫu (app usage, YouTube, location, geofence events)
- Vài AI alerts mẫu (để Dashboard có nội dung)
- School schedule mẫu
- Web filtering categories đã bật

### 4.2: Seed script

File tạo/sửa: `backend/prisma/seed-defense.js`

```javascript
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('demo123', 10);
  
  // 1. Parent account
  const parent = await prisma.user.upsert({
    where: { email: 'demo@kidfun.app' },
    update: {},
    create: { email: 'demo@kidfun.app', password: hashedPassword, fullName: 'Phụ Huynh Demo', phoneNumber: '0901234567' },
  });

  // 2. Child profile
  const profile = await prisma.profile.upsert({
    where: { id: 100 },
    update: {},
    create: { id: 100, userId: parent.id, profileName: 'Bé An', dateOfBirth: new Date('2018-06-15'), isActive: true },
  });

  // 3. Time limits 7 ngày
  for (let day = 0; day < 7; day++) {
    const limit = [180, 90, 90, 120, 90, 120, 180][day]; // CN 3h, T2-T6 1.5-2h, T7 3h
    await prisma.timeLimit.upsert({
      where: { profileId_dayOfWeek: { profileId: 100, dayOfWeek: day } },
      update: { dailyLimitMinutes: limit, limitMinutes: limit },
      create: { profileId: 100, dayOfWeek: day, dailyLimitMinutes: limit, limitMinutes: limit, isActive: true },
    });
  }

  // 4. App usage 7 ngày
  const apps = [
    { pkg: 'com.google.android.youtube', name: 'YouTube', base: 1800 },
    { pkg: 'com.zhiliaoapp.musically', name: 'TikTok', base: 1200 },
    { pkg: 'com.android.chrome', name: 'Chrome', base: 900 },
    { pkg: 'com.whatsapp', name: 'WhatsApp', base: 300 },
    { pkg: 'com.mojang.minecraftpe', name: 'Minecraft', base: 600 },
  ];
  for (let i = 0; i < 7; i++) {
    const date = new Date(); date.setDate(date.getDate() - i); date.setHours(0,0,0,0);
    for (const app of apps) {
      const variance = Math.floor(Math.random() * 600) - 300;
      await prisma.appUsageLog.create({
        data: { profileId: 100, deviceId: 1, packageName: app.pkg, appName: app.name, usageSeconds: Math.max(60, app.base + variance), date },
      }).catch(() => {}); // Skip duplicates
    }
  }

  // 5. YouTube logs mẫu
  const ytVideos = [
    { title: 'Cocomelon - Wheels on the Bus', channel: 'Cocomelon', danger: 1, category: 'SAFE', summary: 'Bài hát thiếu nhi an toàn' },
    { title: 'Minecraft Survival Ep.50', channel: 'Dream', danger: 1, category: 'SAFE', summary: 'Gameplay Minecraft phù hợp mọi lứa tuổi' },
    { title: 'Scary Videos Compilation', channel: 'Unknown', danger: 4, category: 'DISTURBING', summary: 'Nội dung đáng sợ, không phù hợp trẻ em' },
    { title: 'Baby Shark Dance', channel: 'Pinkfong', danger: 1, category: 'SAFE', summary: 'Nhạc thiếu nhi phổ biến' },
    { title: 'GTA 5 Funny Moments', channel: 'Gamer', danger: 3, category: 'VIOLENCE', summary: 'Game bạo lực nhẹ, không phù hợp trẻ dưới 13' },
  ];
  for (let i = 0; i < 7; i++) {
    const date = new Date(); date.setDate(date.getDate() - i);
    for (const v of ytVideos.slice(0, 3 + Math.floor(Math.random() * 3))) {
      await prisma.youTubeLog.create({
        data: {
          profileId: 100, deviceId: 1, videoTitle: v.title, channelName: v.channel,
          watchedAt: new Date(date.getTime() + Math.random() * 43200000),
          durationSeconds: 60 + Math.floor(Math.random() * 300),
          isAnalyzed: true, dangerLevel: v.danger, category: v.category, aiSummary: v.summary,
        },
      }).catch(() => {});
    }
  }

  // 6. AI Alert mẫu (cho video nguy hiểm)
  const dangerousLogs = await prisma.youTubeLog.findMany({
    where: { profileId: 100, dangerLevel: { gte: 4 } }, take: 3,
  });
  for (const log of dangerousLogs) {
    await prisma.aIAlert.create({
      data: { profileId: 100, youtubeLogId: log.id, dangerLevel: log.dangerLevel, category: log.category, summary: log.aiSummary },
    }).catch(() => {});
  }

  // 7. Geofence mẫu
  await prisma.geofence.upsert({
    where: { id: 100 }, update: {},
    create: { id: 100, profileId: 100, name: 'Nhà', latitude: 10.762622, longitude: 106.660172, radius: 200, isActive: true },
  });
  await prisma.geofence.upsert({
    where: { id: 101 }, update: {},
    create: { id: 101, profileId: 100, name: 'Trường học', latitude: 10.770, longitude: 106.665, radius: 300, isActive: true },
  });

  // 8. School schedule mẫu
  await prisma.schoolSchedule.upsert({
    where: { profileId: 100 }, update: {},
    create: {
      profileId: 100, isEnabled: true, templateStartTime: '07:00', templateEndTime: '11:30',
      daySchedules: {
        create: [
          { dayOfWeek: 0, isEnabled: false, startTime: '00:00', endTime: '00:00' },
          { dayOfWeek: 6, isEnabled: false, startTime: '00:00', endTime: '00:00' },
        ],
      },
      allowedApps: {
        create: [
          { packageName: 'com.zoom.us', appName: 'Zoom' },
          { packageName: 'com.google.android.apps.classroom', appName: 'Google Classroom' },
        ],
      },
    },
  });

  // 9. Blocked web categories
  const adultCat = await prisma.webCategory.findFirst({ where: { name: 'adult' } });
  const gamblingCat = await prisma.webCategory.findFirst({ where: { name: 'gambling' } });
  if (adultCat) {
    await prisma.blockedCategory.upsert({
      where: { profileId_categoryId: { profileId: 100, categoryId: adultCat.id } },
      update: {}, create: { profileId: 100, categoryId: adultCat.id, isBlocked: true },
    });
  }
  if (gamblingCat) {
    await prisma.blockedCategory.upsert({
      where: { profileId_categoryId: { profileId: 100, categoryId: gamblingCat.id } },
      update: {}, create: { profileId: 100, categoryId: gamblingCat.id, isBlocked: true },
    });
  }

  // 10. Per-app limit mẫu
  await prisma.appTimeLimit.upsert({
    where: { profileId_packageName: { profileId: 100, packageName: 'com.google.android.youtube' } },
    update: {}, create: { profileId: 100, packageName: 'com.google.android.youtube', appName: 'YouTube', dailyLimitMinutes: 60 },
  });

  console.log('🎉 Defense demo data seeded!');
  console.log('📧 Login: demo@kidfun.app / demo123');
  console.log('👶 Profile: Bé An (ID: 100)');
}

main().catch(console.error).finally(() => prisma.$disconnect());
```

### Chạy:

```bash
node backend/prisma/seed-defense.js
```

### Commit:

```bash
git commit -m "chore(backend): add defense demo seed data"
```

---

## Task 5: API Documentation

> **Branch:** `docs/backend/api-docs`

### 5.1: Tạo file API docs

File tạo: `backend/API-DOCS.md`

Bao gồm tất cả endpoints từ Sprint 1-9:

| Module | Endpoints |
|--------|-----------|
| Auth | register, login, logout, refresh-token |
| Profiles | CRUD profiles |
| Time Limits | CRUD time limits, gradual reduction |
| Devices | list, generate-pairing-code, link, delete |
| Child Session | today-limit, start, heartbeat, end |
| Extension Requests | request (Socket.IO), pending |
| App Usage | POST batch, GET daily/weekly |
| App Blocking | CRUD blocked apps |
| Location | POST location, GET current/history |
| Geofences | CRUD geofences, GET events |
| SOS | POST sos (multipart), GET history, acknowledge, resolve |
| Web Filtering | categories, blocked-categories, custom-domains, overrides |
| School Mode | schedule CRUD, manual override |
| Per-app Limits | CRUD app-time-limits |
| YouTube | POST logs, GET blocked-videos |
| Dashboard | GET youtube/dashboard, youtube/logs |
| AI Alerts | GET alerts, PUT read |
| Reports | GET daily, weekly |
| Activity History | GET activity-history |
| Admin | run-ai-analysis, run-daily/weekly-reports, ai-status |
| FCM | register, unregister |

### 5.2: Format mỗi endpoint

```
### POST /api/auth/login
**Auth:** Không cần
**Body:** { email: string, password: string }
**Response 200:** { success: true, data: { token: string, user: {...} } }
**Response 401:** { success: false, message: "Invalid credentials" }
```

### Commit:

```bash
git commit -m "docs(backend): add comprehensive API documentation"
```

---

## Task 6: Database Backup + RLS

> **Branch:** `chore/backend/db-security`

### 6.1: Bật RLS Supabase

Vào Supabase Dashboard → SQL Editor:

```sql
-- Bật RLS cho tất cả tables
ALTER TABLE public."User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Device" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Profile" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TimeLimit" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Session" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."UsageSession" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."FCMToken" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TimeExtensionRequest" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."AppUsageLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BlockedApp" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."LocationLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Geofence" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."GeofenceEvent" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."SOSAlert" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."AppTimeLimit" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."WebCategory" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."WebCategoryDomain" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BlockedCategory" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."CategoryOverride" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."CustomBlockedDomain" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."SchoolSchedule" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."SchoolDaySchedule" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."AllowedSchoolApp" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."YouTubeLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."AIAlert" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BlockedVideo" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ReportSnapshot" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Warning" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."_prisma_migrations" ENABLE ROW LEVEL SECURITY;

-- Policy cho service role (Prisma dùng service role, bypass RLS)
-- Không cần tạo policies vì Prisma kết nối bằng service role key
```

**Lưu ý:** Prisma dùng `DATABASE_URL` với service role key → bypass RLS. Bật RLS chỉ để bảo vệ nếu ai đó truy cập Supabase client trực tiếp.

### 6.2: Backup trước bảo vệ

```bash
# Dùng Supabase Dashboard → Database → Backups → Download backup
# Hoặc pg_dump (nếu có psql)
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
```

---

## Task 7: Final Deploy + E2E Test

### 7.1: Merge tất cả branches

```bash
git checkout develop && git pull origin develop
# Merge all sprint 10 branches
# → PR → develop → merge
```

### 7.2: Deploy Railway

- [ ] Railway auto-deploy từ develop
- [ ] Verify logs không có errors mới
- [ ] Chạy seed-defense.js trên production

### 7.3: E2E Test toàn bộ tính năng

| # | Tính năng | Sprint | Test | ✅ |
|---|-----------|--------|------|---|
| 1 | Đăng ký/đăng nhập | 1-3 | Login demo@kidfun.app | ⬜ |
| 2 | Tạo profile con | 1-3 | Profile "Bé An" hiện | ⬜ |
| 3 | Liên kết thiết bị | 1-3 | QR scan thành công | ⬜ |
| 4 | Đặt giới hạn thời gian | 4 | Set 5 phút, countdown chạy | ⬜ |
| 5 | Cảnh báo mềm | 4 | 5 phút → dialog warning | ⬜ |
| 6 | Xin thêm giờ | 4 | Child xin → Parent duyệt → +time | ⬜ |
| 7 | Chặn app | 5 | Block YouTube → kick Home | ⬜ |
| 8 | Báo cáo sử dụng app | 5 | Biểu đồ usage 7 ngày | ⬜ |
| 9 | Lock screen hết giờ | 5 | Hết time → lock | ⬜ |
| 10 | GPS vị trí | 7 | Map hiện marker con | ⬜ |
| 11 | Geofence | 7 | Tạo vùng → ENTER/EXIT alert | ⬜ |
| 12 | SOS | 7 | Bấm SOS → Parent nhận alert | ⬜ |
| 13 | Web filtering | 8 | Chặn category → Chrome blocked | ⬜ |
| 14 | School mode | 8 | Trong giờ học → chỉ allowed apps | ⬜ |
| 15 | Per-app limit | 8 | YouTube 5 phút → warning → block | ⬜ |
| 16 | YouTube tracking | 9 | Xem video → log lên server | ⬜ |
| 17 | AI analysis | 9 | Worker phân tích → dashboard hiện | ⬜ |
| 18 | AI alert | 9 | Video nguy hiểm → push + block | ⬜ |
| 19 | Daily report | 9 | Charts + summary đúng | ⬜ |
| 20 | Weekly report | 9 | 7-day bar chart | ⬜ |
| 21 | Activity history | 9 | Timeline events đúng | ⬜ |
| 22 | Push notification | All | FCM hoạt động | ⬜ |

### 7.4: Kịch bản demo bảo vệ (7-10 phút)

1. **[Parent]** Đăng nhập → xem profile "Bé An"
2. **[Parent]** Xem Reports → biểu đồ usage tuần
3. **[Parent]** Đặt giới hạn 3 phút
4. **[Child]** Countdown → cảnh báo mềm → xin thêm giờ
5. **[Parent]** Duyệt xin giờ
6. **[Parent]** Chặn YouTube → **[Child]** bị kick
7. **[Parent]** Bật School Mode → **[Child]** chỉ dùng Zoom
8. **[Parent]** Xem vị trí GPS trên bản đồ
9. **[Child]** Bấm SOS → **[Parent]** nhận alert + nghe ghi âm
10. **[Parent]** Xem YouTube Dashboard → AI alerts
11. **[Parent]** Xem Activity History timeline

---

## ✅ Checklist Tổng hợp Sprint 10 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | Fix P2025 disconnect crash (updateMany) | ⬜ |
| 2 | Fix device not found emit error event | ⬜ |
| 3 | Fix AI Worker log spam | ⬜ |
| 4 | In-memory cache cho heartbeat | ⬜ |
| 5 | In-memory cache cho today-limit | ⬜ |
| 6 | Prisma connection pool optimize | ⬜ |
| 7 | Input validation tất cả endpoints | ⬜ |
| 8 | Rate limiting (express-rate-limit) | ⬜ |
| 9 | Helmet security headers | ⬜ |
| 10 | JWT expiry check | ⬜ |
| 11 | Seed defense demo data | ⬜ |
| 12 | Chạy seed trên production | ⬜ |
| 13 | API documentation (API-DOCS.md) | ⬜ |
| 14 | Bật RLS Supabase | ⬜ |
| 15 | Backup database | ⬜ |
| 16 | Deploy Railway thành công | ⬜ |
| 17 | E2E test 22 tính năng pass | ⬜ |
| 18 | Kịch bản demo rehearsal | ⬜ |

---

## 🔀 Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b fix/backend/<tên>      # Bugfix
git checkout -b chore/backend/<tên>    # Optimize/polish
git checkout -b docs/backend/<tên>     # Documentation
git commit -m "fix/chore/docs(backend): mô tả"
git push origin <branch>
# → PR → develop → merge
```
