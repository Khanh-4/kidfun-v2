# KidFun V3 — Sprint 5: Native Android & Lock Screen — BACKEND (Khanh)

> **Sprint Goal:** Xây dựng API hỗ trợ app usage tracking, app blocking, và gradual reduction
> **Quan trọng:** Sprint 6 là demo giữa kỳ — Sprint 5 cần hoàn thành sớm để có thời gian test
> **Branch gốc:** `develop`
> **Server:** https://kidfun-backend-production.up.railway.app

---

## Tổng quan Sprint 5 — Backend Tasks

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 1** | App Usage Log API (nhận batch data từ Child) | Không |
| **Task 2** | App Blocking API (CRUD blacklist/whitelist) | Không |
| **Task 3** | Blocked Apps Sync API (Child lấy danh sách chặn) | Task 2 |
| **Task 4** | Usage Log Query API (Parent xem thống kê) | Task 1 |
| **Task 5** | Gradual Reduction Logic | Task 1 |
| **Task 6** | Deploy + Integration test | Task 1–5 |

---

## Task 1: App Usage Log API

> Child App gửi batch app usage data lên server định kỳ.

**Branch:** `feature/backend/app-usage-log`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/app-usage-log
```

### 1.1: Thêm AppUsageLog model

File sửa: `backend/prisma/schema.prisma`

```prisma
model AppUsageLog {
  id            Int      @id @default(autoincrement())
  profileId     Int
  deviceId      Int
  packageName   String   // com.youtube.android, com.instagram.android, etc.
  appName       String?  // Tên hiển thị (YouTube, Instagram)
  usageSeconds  Int      // Thời gian dùng (giây)
  date          DateTime // Ngày (không có giờ, dùng để group by)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  profile       Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device        Device   @relation(fields: [deviceId], references: [id], onDelete: Cascade)

  @@unique([profileId, deviceId, packageName, date])
}
```

- [ ] Thêm `appUsageLogs AppUsageLog[]` vào model Profile và Device
- [ ] Chạy migration:

```bash
npx prisma migrate dev --name add-app-usage-log
npx prisma generate
```

### 1.2: App Usage Controller

File tạo mới: `backend/src/controllers/appUsageController.js`

**POST /api/child/app-usage** — Nhận batch usage data từ Child

```javascript
exports.syncAppUsage = async (req, res) => {
  try {
    const { deviceCode, usageData } = req.body;
    // usageData: [{ packageName, appName, usageSeconds }]

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Upsert mỗi app usage (cộng dồn nếu đã có record hôm nay)
    const results = await Promise.all(
      usageData.map(async (usage) => {
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
            appName: usage.appName || undefined,
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

    return sendSuccess(res, { synced: results.length }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 1.3: Routes

```javascript
// routes/child.js
router.post('/app-usage', appUsageController.syncAppUsage);
```

### 1.4: Test

```bash
curl -X POST "https://kidfun-backend-production.up.railway.app/api/child/app-usage" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceCode": "BE4B.251210.005",
    "usageData": [
      { "packageName": "com.youtube.android", "appName": "YouTube", "usageSeconds": 600 },
      { "packageName": "com.instagram.android", "appName": "Instagram", "usageSeconds": 300 }
    ]
  }'
```

- [ ] Response 201 với `synced: 2`
- [ ] Data đúng trên Supabase

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add app usage log API with batch sync"
git push origin feature/backend/app-usage-log
```
→ PR → develop → merge

---

## Task 2: App Blocking API

> Parent quản lý danh sách app bị chặn (blacklist) hoặc cho phép (whitelist) theo profile.

**Branch:** `feature/backend/app-blocking`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/app-blocking
```

### 2.1: Thêm BlockedApp model

File sửa: `backend/prisma/schema.prisma`

```prisma
model BlockedApp {
  id          Int      @id @default(autoincrement())
  profileId   Int
  packageName String   // com.youtube.android
  appName     String?  // YouTube
  isBlocked   Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)

  @@unique([profileId, packageName])
}
```

- [ ] Thêm `blockedApps BlockedApp[]` vào model Profile
- [ ] Chạy migration

### 2.2: Blocked App Controller

File tạo mới: `backend/src/controllers/blockedAppController.js`

**GET /api/profiles/:id/blocked-apps** — Lấy danh sách app bị chặn

```javascript
exports.getBlockedApps = async (req, res) => {
  try {
    const blockedApps = await prisma.blockedApp.findMany({
      where: { profileId: parseInt(req.params.id) },
      orderBy: { appName: 'asc' },
    });
    return sendSuccess(res, { blockedApps });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/blocked-apps** — Thêm app vào blacklist

```javascript
exports.addBlockedApp = async (req, res) => {
  try {
    const { packageName, appName } = req.body;
    const profileId = parseInt(req.params.id);

    const blockedApp = await prisma.blockedApp.upsert({
      where: { profileId_packageName: { profileId, packageName } },
      update: { isBlocked: true, appName },
      create: { profileId, packageName, appName, isBlocked: true },
    });

    // Notify Child devices qua Socket.IO
    const devices = await prisma.device.findMany({ where: { profileId } });
    const io = req.app.get('io');
    if (io) {
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('blockedAppsUpdated', { profileId });
      });
    }

    return sendSuccess(res, { blockedApp }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**DELETE /api/profiles/:id/blocked-apps/:packageName** — Bỏ chặn app

```javascript
exports.removeBlockedApp = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const packageName = decodeURIComponent(req.params.packageName);

    await prisma.blockedApp.deleteMany({
      where: { profileId, packageName },
    });

    // Notify Child
    const devices = await prisma.device.findMany({ where: { profileId } });
    const io = req.app.get('io');
    if (io) {
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('blockedAppsUpdated', { profileId });
      });
    }

    return sendSuccess(res, { message: 'App unblocked' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 2.3: Routes

```javascript
// routes/profiles.js
router.get('/:id/blocked-apps', authMiddleware, blockedAppController.getBlockedApps);
router.post('/:id/blocked-apps', authMiddleware, blockedAppController.addBlockedApp);
router.delete('/:id/blocked-apps/:packageName', authMiddleware, blockedAppController.removeBlockedApp);
```

### 2.4: Test

- [ ] POST thêm YouTube vào blacklist → 201
- [ ] GET danh sách → thấy YouTube
- [ ] DELETE bỏ chặn → thành công
- [ ] Socket.IO emit `blockedAppsUpdated` cho Child

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add app blocking CRUD API with Socket.IO notification"
git push origin feature/backend/app-blocking
```
→ PR → develop → merge

---

## Task 3: Blocked Apps Sync API cho Child

> Child App lấy danh sách app bị chặn để enforce trên device.

**Branch:** `feature/backend/blocked-apps-sync`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/blocked-apps-sync
```

### 3.1: Endpoint cho Child

**GET /api/child/blocked-apps?deviceCode=XXX**

```javascript
exports.getBlockedAppsForChild = async (req, res) => {
  try {
    const { deviceCode } = req.query;

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: { include: { blockedApps: true } } },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const blockedPackages = device.profile.blockedApps
      .filter(app => app.isBlocked)
      .map(app => ({
        packageName: app.packageName,
        appName: app.appName,
      }));

    return sendSuccess(res, { blockedApps: blockedPackages });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 3.2: Route

```javascript
// routes/child.js
router.get('/blocked-apps', blockedAppController.getBlockedAppsForChild);
```

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add blocked apps sync API for child devices"
git push origin feature/backend/blocked-apps-sync
```
→ PR → develop → merge

---

## Task 4: Usage Log Query API cho Parent

> Parent xem thống kê app usage của con theo ngày/tuần.

**Branch:** `feature/backend/usage-query`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/usage-query
```

### 4.1: Endpoints

**GET /api/profiles/:id/app-usage?date=2026-03-22** — Usage theo ngày

```javascript
exports.getDailyUsage = async (req, res) => {
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
      apps: usage.map(u => ({
        packageName: u.packageName,
        appName: u.appName,
        usageMinutes: Math.round(u.usageSeconds / 60),
        usageSeconds: u.usageSeconds,
      })),
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/app-usage/weekly** — Usage 7 ngày gần nhất

```javascript
exports.getWeeklyUsage = async (req, res) => {
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
    usage.forEach(u => {
      const key = u.date.toISOString().split('T')[0];
      if (!dailyTotals[key]) dailyTotals[key] = 0;
      dailyTotals[key] += u.usageSeconds;
    });

    // Group by app (top 10)
    const appTotals = {};
    usage.forEach(u => {
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
    return sendError(res, err.message, 500);
  }
};
```

### 4.2: Routes

```javascript
// routes/profiles.js
router.get('/:id/app-usage', authMiddleware, appUsageController.getDailyUsage);
router.get('/:id/app-usage/weekly', authMiddleware, appUsageController.getWeeklyUsage);
```

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add app usage query API (daily + weekly stats)"
git push origin feature/backend/usage-query
```
→ PR → develop → merge

---

## Task 5: Gradual Reduction Logic

> Giảm dần thời gian sử dụng mỗi tuần (ví dụ: từ 3h xuống 2h trong 4 tuần).

**Branch:** `feature/backend/gradual-reduction`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/gradual-reduction
```

### 5.1: Kiểm tra TimeLimit model

Model TimeLimit đã có các fields cho gradual reduction:

```
isGradual       Boolean  @default(false)
gradualTarget   Int?     // Mục tiêu cuối cùng (phút)
gradualWeeks    Int?     // Số tuần để giảm
gradualStartDate DateTime?
```

### 5.2: Logic tính limit hiện tại

Trong `childController.js` hàm `getTodayLimit`, thêm logic:

```javascript
// Sau khi lấy todayLimit:
let effectiveLimit = todayLimit.dailyLimitMinutes || 0;

if (todayLimit.isGradual && todayLimit.gradualTarget != null 
    && todayLimit.gradualWeeks && todayLimit.gradualStartDate) {
  const startDate = new Date(todayLimit.gradualStartDate);
  const now = new Date();
  const weeksElapsed = Math.floor((now - startDate) / (7 * 24 * 60 * 60 * 1000));
  
  if (weeksElapsed < todayLimit.gradualWeeks) {
    const originalLimit = todayLimit.dailyLimitMinutes;
    const target = todayLimit.gradualTarget;
    const reduction = (originalLimit - target) * (weeksElapsed / todayLimit.gradualWeeks);
    effectiveLimit = Math.round(originalLimit - reduction);
  } else {
    effectiveLimit = todayLimit.gradualTarget;
  }
}
```

### 5.3: API để Parent bật gradual reduction

**PUT /api/profiles/:id/time-limits/gradual**

```javascript
exports.setGradualReduction = async (req, res) => {
  try {
    const { dayOfWeek, targetMinutes, weeks } = req.body;
    const profileId = parseInt(req.params.id);

    await prisma.timeLimit.updateMany({
      where: { profileId, dayOfWeek: parseInt(dayOfWeek) },
      data: {
        isGradual: true,
        gradualTarget: targetMinutes,
        gradualWeeks: weeks,
        gradualStartDate: new Date(),
      },
    });

    return sendSuccess(res, { message: 'Gradual reduction enabled' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add gradual reduction logic for time limits"
git push origin feature/backend/gradual-reduction
```
→ PR → develop → merge

---

## Task 6: Deploy + Nhắn Frontend

- [ ] Deploy tất cả lên Railway
- [ ] Test APIs bằng curl
- [ ] Nhắn bạn Frontend:

```
Sprint 5 Backend đã ready!

API mới:
- POST /api/child/app-usage { deviceCode, usageData: [{packageName, appName, usageSeconds}] }
- GET /api/child/blocked-apps?deviceCode=XXX
- GET /api/profiles/:id/blocked-apps
- POST /api/profiles/:id/blocked-apps { packageName, appName }
- DELETE /api/profiles/:id/blocked-apps/:packageName
- GET /api/profiles/:id/app-usage?date=YYYY-MM-DD
- GET /api/profiles/:id/app-usage/weekly

Socket.IO events mới:
- Emit 'blockedAppsUpdated' { profileId } → khi Parent thêm/xóa blocked app
```

---

## Checklist cuối Sprint 5 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | AppUsageLog model + migration | ⬜ |
| 2 | POST /api/child/app-usage (batch sync) | ⬜ |
| 3 | BlockedApp model + migration | ⬜ |
| 4 | GET/POST/DELETE /api/profiles/:id/blocked-apps | ⬜ |
| 5 | GET /api/child/blocked-apps (child sync) | ⬜ |
| 6 | blockedAppsUpdated Socket.IO event | ⬜ |
| 7 | GET /api/profiles/:id/app-usage (daily) | ⬜ |
| 8 | GET /api/profiles/:id/app-usage/weekly | ⬜ |
| 9 | Gradual reduction logic trong getTodayLimit | ⬜ |
| 10 | PUT /api/profiles/:id/time-limits/gradual | ⬜ |
| 11 | Deploy Railway | ⬜ |
| 12 | Nhắn Frontend | ⬜ |

---

## Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/<tên-task>
# Code + commit
git commit -m "feat(backend): mô tả"
git push origin feature/backend/<tên-task>
# → PR → develop → merge
```
