# KidFun V3 — Sprint 8: Web Filtering, School Mode & Per-app Limits — BACKEND (Khanh)

> **Sprint Goal:** Mở rộng quản lý — chặn web, chế độ học tập, giới hạn theo từng app
> **Branch gốc:** `develop`
> **Scope:** Custom domains + Categories, Per-app limit với cảnh báo 5 phút, School Mode template + override

---

## Tổng quan Sprint 8 — Backend Tasks

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 1** | Database models mở rộng | Không |
| **Task 2** | Per-app Time Limit API | Task 1 |
| **Task 3** | Web Filtering API (categories + custom + seed data) | Task 1 |
| **Task 4** | School Schedule API (template + override) | Task 1 |
| **Task 5** | Child sync APIs (lấy limits + blocked domains + school mode) | Task 2, 3, 4 |
| **Task 6** | Socket.IO events + push notifications | Task 2–5 |
| **Task 7** | Deploy + Integration test | Task 1–6 |

---

## Task 1: Database Models

> **Branch:** `feature/backend/sprint8-models`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/sprint8-models
```

### 1.1: Prisma schema

File sửa: `backend/prisma/schema.prisma`

```prisma
// Per-app time limit
model AppTimeLimit {
  id                Int      @id @default(autoincrement())
  profileId         Int
  packageName       String
  appName           String?
  dailyLimitMinutes Int      // Giới hạn/ngày cho app này
  isActive          Boolean  @default(true)
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt

  profile           Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  @@unique([profileId, packageName])
}

// Web category (seeded: Người lớn, Bạo lực, Cờ bạc, Social Media, Gaming)
model WebCategory {
  id          Int      @id @default(autoincrement())
  name        String   @unique    // "adult", "violence", "gambling", "social_media", "gaming"
  displayName String               // "Người lớn", "Bạo lực",...
  description String?
  domains     WebCategoryDomain[]
  blockedBy   BlockedCategory[]
}

// Domains trong mỗi category (seed từ DB)
model WebCategoryDomain {
  id         Int         @id @default(autoincrement())
  categoryId Int
  domain     String
  category   WebCategory @relation(fields: [categoryId], references: [id], onDelete: Cascade)

  @@unique([categoryId, domain])
}

// Parent toggle category on/off cho profile, có thể override từng domain
model BlockedCategory {
  id         Int         @id @default(autoincrement())
  profileId  Int
  categoryId Int
  isBlocked  Boolean     @default(true)
  // Override: domains trong category này mà Parent muốn CHO PHÉP (whitelist)
  overrides  CategoryOverride[]
  createdAt  DateTime    @default(now())

  profile    Profile     @relation(fields: [profileId], references: [id], onDelete: Cascade)
  category   WebCategory @relation(fields: [categoryId], references: [id], onDelete: Cascade)
  @@unique([profileId, categoryId])
}

// Override: bỏ chặn 1 domain cụ thể trong 1 category
model CategoryOverride {
  id                Int             @id @default(autoincrement())
  blockedCategoryId Int
  domain            String          // Domain được WHITELIST (cho phép dù category bị chặn)
  blockedCategory   BlockedCategory @relation(fields: [blockedCategoryId], references: [id], onDelete: Cascade)

  @@unique([blockedCategoryId, domain])
}

// Custom domains do Parent tự thêm (ngoài category)
model CustomBlockedDomain {
  id         Int      @id @default(autoincrement())
  profileId  Int
  domain     String
  reason     String?
  createdAt  DateTime @default(now())

  profile    Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  @@unique([profileId, domain])
}

// School schedule template (áp dụng cho các ngày trong tuần)
model SchoolSchedule {
  id          Int      @id @default(autoincrement())
  profileId   Int      @unique   // 1 profile chỉ có 1 schedule
  isEnabled   Boolean  @default(true)
  // Template: weekdays (T2-T6) giống nhau
  templateStartTime String? // "07:00"
  templateEndTime   String? // "11:30"
  // Override manual từ Parent (tạm tắt/bật)
  manualOverride String? // null | "FORCE_ON" | "FORCE_OFF"
  overrideUntil  DateTime? // Hết hiệu lực lúc nào
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  profile       Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  daySchedules  SchoolDaySchedule[]
  allowedApps   AllowedSchoolApp[]
}

// Override cho từng ngày cụ thể (nếu khác template)
model SchoolDaySchedule {
  id         Int            @id @default(autoincrement())
  scheduleId Int
  dayOfWeek  Int            // 0=Sunday, 6=Saturday
  isEnabled  Boolean        @default(true)
  startTime  String         // "07:00"
  endTime    String         // "11:30"

  schedule   SchoolSchedule @relation(fields: [scheduleId], references: [id], onDelete: Cascade)
  @@unique([scheduleId, dayOfWeek])
}

// Apps được phép dùng trong giờ học
model AllowedSchoolApp {
  id          Int            @id @default(autoincrement())
  scheduleId  Int
  packageName String
  appName     String?
  createdAt   DateTime       @default(now())

  schedule    SchoolSchedule @relation(fields: [scheduleId], references: [id], onDelete: Cascade)
  @@unique([scheduleId, packageName])
}
```

### 1.2: Thêm relations vào Profile

```prisma
model Profile {
  // ... existing fields ...
  appTimeLimits         AppTimeLimit[]
  blockedCategories     BlockedCategory[]
  customBlockedDomains  CustomBlockedDomain[]
  schoolSchedule        SchoolSchedule?
}
```

### 1.3: Migration + Seed

```bash
npx prisma migrate dev --name add-sprint8-models
npx prisma generate
```

### 1.4: Seed data cho WebCategory

File tạo mới: `backend/prisma/seed-web-categories.js`

```javascript
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const CATEGORIES = [
  {
    name: 'adult',
    displayName: 'Người lớn',
    description: 'Nội dung 18+, khiêu dâm',
    domains: [
      'pornhub.com', 'xvideos.com', 'xnxx.com', 'xhamster.com',
      'redtube.com', 'youporn.com', 'sexvn.com', 'phimxxx.com',
    ],
  },
  {
    name: 'gambling',
    displayName: 'Cờ bạc',
    description: 'Cá cược, bài bạc trực tuyến',
    domains: [
      'bet365.com', 'fun88.com', 'w88.com', '188bet.com',
      'dafabet.com', '12bet.com', 'casino.com',
    ],
  },
  {
    name: 'violence',
    displayName: 'Bạo lực',
    description: 'Nội dung bạo lực, máu me',
    domains: [
      'liveleak.com', 'bestgore.com', 'documentingreality.com',
    ],
  },
  {
    name: 'social_media',
    displayName: 'Mạng xã hội',
    description: 'Facebook, Instagram, TikTok,...',
    domains: [
      'facebook.com', 'instagram.com', 'tiktok.com', 'twitter.com',
      'x.com', 'snapchat.com', 'threads.net',
    ],
  },
  {
    name: 'gaming',
    displayName: 'Game online',
    description: 'Web game, gaming platforms',
    domains: [
      'y8.com', 'friv.com', 'poki.com', 'miniclip.com',
      'crazygames.com', 'kizi.com',
    ],
  },
];

async function main() {
  for (const cat of CATEGORIES) {
    const category = await prisma.webCategory.upsert({
      where: { name: cat.name },
      update: { displayName: cat.displayName, description: cat.description },
      create: { name: cat.name, displayName: cat.displayName, description: cat.description },
    });

    for (const domain of cat.domains) {
      await prisma.webCategoryDomain.upsert({
        where: { categoryId_domain: { categoryId: category.id, domain } },
        update: {},
        create: { categoryId: category.id, domain },
      });
    }

    console.log(`✅ ${cat.displayName}: ${cat.domains.length} domains`);
  }
  console.log('\n🎉 Web categories seeded!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
```

Chạy: `node backend/prisma/seed-web-categories.js`

### Commit:

```bash
git commit -m "feat(backend): add sprint 8 models and seed web categories"
git push origin feature/backend/sprint8-models
```
→ PR → develop → merge

---

## Task 2: Per-app Time Limit API

> **Branch:** `feature/backend/per-app-limit`

### 2.1: Controller

File tạo mới: `backend/src/controllers/appTimeLimitController.js`

**GET /api/profiles/:id/app-time-limits** — List

```javascript
exports.getAppTimeLimits = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const limits = await prisma.appTimeLimit.findMany({
      where: { profileId, isActive: true },
      orderBy: { appName: 'asc' },
    });
    return sendSuccess(res, { limits });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/app-time-limits** — Thêm/cập nhật

```javascript
exports.upsertAppTimeLimit = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { packageName, appName, dailyLimitMinutes } = req.body;

    if (!packageName || typeof dailyLimitMinutes !== 'number' || dailyLimitMinutes < 0) {
      return sendError(res, 'Invalid data', 400);
    }

    const limit = await prisma.appTimeLimit.upsert({
      where: { profileId_packageName: { profileId, packageName } },
      update: { dailyLimitMinutes, appName, isActive: true },
      create: { profileId, packageName, appName, dailyLimitMinutes, isActive: true },
    });

    // Notify Child
    const io = req.app.get('io');
    const devices = await prisma.device.findMany({ where: { profileId } });
    if (io) {
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('appTimeLimitUpdated', { profileId });
      });
    }

    return sendSuccess(res, { limit }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**DELETE /api/profiles/:id/app-time-limits/:packageName** — Xóa limit

```javascript
exports.deleteAppTimeLimit = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const packageName = decodeURIComponent(req.params.packageName);

    await prisma.appTimeLimit.deleteMany({
      where: { profileId, packageName },
    });

    const io = req.app.get('io');
    const devices = await prisma.device.findMany({ where: { profileId } });
    if (io) {
      devices.forEach(d => {
        io.to(`device_${d.deviceCode}`).emit('appTimeLimitUpdated', { profileId });
      });
    }

    return sendSuccess(res, { message: 'Deleted' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/child/app-time-limits?deviceCode=XXX** — Child sync

```javascript
exports.getChildAppTimeLimits = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: { include: { appTimeLimits: { where: { isActive: true } } } } },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    // Lấy usage hôm nay để tính remaining
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayUsage = await prisma.appUsageLog.findMany({
      where: { profileId: device.profile.id, date: today },
    });

    const limits = device.profile.appTimeLimits.map(limit => {
      const usage = todayUsage.find(u => u.packageName === limit.packageName);
      const usedSeconds = usage?.usageSeconds || 0;
      const remainingSeconds = Math.max(0, limit.dailyLimitMinutes * 60 - usedSeconds);
      return {
        packageName: limit.packageName,
        appName: limit.appName,
        dailyLimitMinutes: limit.dailyLimitMinutes,
        usedSeconds,
        remainingSeconds,
      };
    });

    return sendSuccess(res, { limits });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 2.2: Routes

```javascript
router.get('/:id/app-time-limits', authMiddleware, appTimeLimitController.getAppTimeLimits);
router.post('/:id/app-time-limits', authMiddleware, appTimeLimitController.upsertAppTimeLimit);
router.delete('/:id/app-time-limits/:packageName', authMiddleware, appTimeLimitController.deleteAppTimeLimit);

// Child side
router.get('/app-time-limits', appTimeLimitController.getChildAppTimeLimits);
```

### Commit:

```bash
git commit -m "feat(backend): add per-app time limit API"
```

---

## Task 3: Web Filtering API

> **Branch:** `feature/backend/web-filtering`

### 3.1: Controller

File tạo mới: `backend/src/controllers/webFilteringController.js`

**GET /api/web-categories** — Lấy tất cả categories (cho Parent UI)

```javascript
exports.getCategories = async (req, res) => {
  try {
    const categories = await prisma.webCategory.findMany({
      include: { domains: { select: { domain: true } } },
      orderBy: { displayName: 'asc' },
    });
    return sendSuccess(res, { categories });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/blocked-categories** — Lấy status per-profile

```javascript
exports.getBlockedCategories = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const blocked = await prisma.blockedCategory.findMany({
      where: { profileId },
      include: { 
        category: { include: { domains: true } },
        overrides: true,
      },
    });
    return sendSuccess(res, { blockedCategories: blocked });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/blocked-categories** — Toggle category

```javascript
exports.toggleCategory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { categoryId, isBlocked } = req.body;

    const blocked = await prisma.blockedCategory.upsert({
      where: { profileId_categoryId: { profileId, categoryId: parseInt(categoryId) } },
      update: { isBlocked },
      create: { profileId, categoryId: parseInt(categoryId), isBlocked },
    });

    notifyChildDomainsUpdated(req.app.get('io'), profileId);
    return sendSuccess(res, { blocked }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/blocked-categories/:categoryId/override** — Whitelist 1 domain

```javascript
exports.addCategoryOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const categoryId = parseInt(req.params.categoryId);
    const { domain } = req.body;

    const blocked = await prisma.blockedCategory.findUnique({
      where: { profileId_categoryId: { profileId, categoryId } },
    });

    if (!blocked) return sendError(res, 'Category not configured for this profile', 404);

    const override = await prisma.categoryOverride.upsert({
      where: { blockedCategoryId_domain: { blockedCategoryId: blocked.id, domain } },
      update: {},
      create: { blockedCategoryId: blocked.id, domain },
    });

    notifyChildDomainsUpdated(req.app.get('io'), profileId);
    return sendSuccess(res, { override }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**DELETE /api/profiles/:id/blocked-categories/:categoryId/override/:domain**

```javascript
exports.removeCategoryOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const categoryId = parseInt(req.params.categoryId);
    const domain = decodeURIComponent(req.params.domain);

    const blocked = await prisma.blockedCategory.findUnique({
      where: { profileId_categoryId: { profileId, categoryId } },
    });
    if (!blocked) return sendError(res, 'Not found', 404);

    await prisma.categoryOverride.deleteMany({
      where: { blockedCategoryId: blocked.id, domain },
    });

    notifyChildDomainsUpdated(req.app.get('io'), profileId);
    return sendSuccess(res, { message: 'Removed' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**Custom domains:**

```javascript
exports.getCustomDomains = async (req, res) => {
  // GET /api/profiles/:id/custom-blocked-domains
  const profileId = parseInt(req.params.id);
  const domains = await prisma.customBlockedDomain.findMany({ where: { profileId } });
  return sendSuccess(res, { domains });
};

exports.addCustomDomain = async (req, res) => {
  // POST /api/profiles/:id/custom-blocked-domains { domain, reason }
  const profileId = parseInt(req.params.id);
  const { domain, reason } = req.body;

  const created = await prisma.customBlockedDomain.upsert({
    where: { profileId_domain: { profileId, domain } },
    update: { reason },
    create: { profileId, domain, reason },
  });

  notifyChildDomainsUpdated(req.app.get('io'), profileId);
  return sendSuccess(res, { domain: created }, 201);
};

exports.deleteCustomDomain = async (req, res) => {
  // DELETE /api/profiles/:id/custom-blocked-domains/:domain
  const profileId = parseInt(req.params.id);
  const domain = decodeURIComponent(req.params.domain);

  await prisma.customBlockedDomain.deleteMany({ where: { profileId, domain } });
  notifyChildDomainsUpdated(req.app.get('io'), profileId);
  return sendSuccess(res, { message: 'Removed' });
};
```

### 3.2: Helper notify

```javascript
function notifyChildDomainsUpdated(io, profileId) {
  if (!io) return;
  prisma.device.findMany({ where: { profileId } }).then(devices => {
    devices.forEach(d => {
      io.to(`device_${d.deviceCode}`).emit('blockedDomainsUpdated', { profileId });
    });
  });
}
```

### 3.3: Child sync — GET danh sách domains đã tính toán

**GET /api/child/blocked-domains?deviceCode=XXX**

```javascript
exports.getChildBlockedDomains = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: {
            blockedCategories: {
              where: { isBlocked: true },
              include: {
                category: { include: { domains: true } },
                overrides: true,
              },
            },
            customBlockedDomains: true,
          },
        },
      },
    });

    if (!device || !device.profile) return sendError(res, 'Device not linked', 404);

    // Tính danh sách domain cuối cùng
    const blockedDomains = new Set();

    // Từ categories bị block (trừ đi overrides)
    for (const bc of device.profile.blockedCategories) {
      const overrideSet = new Set(bc.overrides.map(o => o.domain));
      for (const d of bc.category.domains) {
        if (!overrideSet.has(d.domain)) blockedDomains.add(d.domain);
      }
    }

    // Thêm custom domains
    for (const cd of device.profile.customBlockedDomains) {
      blockedDomains.add(cd.domain);
    }

    return sendSuccess(res, {
      domains: Array.from(blockedDomains).sort(),
      count: blockedDomains.size,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add web filtering API with categories and custom domains"
```

---

## Task 4: School Schedule API

> **Branch:** `feature/backend/school-mode`

### 4.1: Controller

File tạo mới: `backend/src/controllers/schoolScheduleController.js`

**GET /api/profiles/:id/school-schedule**

```javascript
exports.getSchedule = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const schedule = await prisma.schoolSchedule.findUnique({
      where: { profileId },
      include: { daySchedules: true, allowedApps: true },
    });
    return sendSuccess(res, { schedule });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**PUT /api/profiles/:id/school-schedule** — Cài đặt template + override

```javascript
exports.upsertSchedule = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const {
      isEnabled,
      templateStartTime,
      templateEndTime,
      dayOverrides,  // [{ dayOfWeek, startTime, endTime, isEnabled }]
      allowedApps,   // [{ packageName, appName }]
    } = req.body;

    // Upsert schedule
    const schedule = await prisma.schoolSchedule.upsert({
      where: { profileId },
      update: { isEnabled, templateStartTime, templateEndTime },
      create: { profileId, isEnabled, templateStartTime, templateEndTime },
    });

    // Xóa tất cả day overrides cũ, tạo lại
    await prisma.schoolDaySchedule.deleteMany({ where: { scheduleId: schedule.id } });
    if (dayOverrides && dayOverrides.length > 0) {
      await prisma.schoolDaySchedule.createMany({
        data: dayOverrides.map(d => ({
          scheduleId: schedule.id,
          dayOfWeek: parseInt(d.dayOfWeek),
          startTime: d.startTime,
          endTime: d.endTime,
          isEnabled: d.isEnabled ?? true,
        })),
      });
    }

    // Xóa + tạo allowed apps
    await prisma.allowedSchoolApp.deleteMany({ where: { scheduleId: schedule.id } });
    if (allowedApps && allowedApps.length > 0) {
      await prisma.allowedSchoolApp.createMany({
        data: allowedApps.map(a => ({
          scheduleId: schedule.id,
          packageName: a.packageName,
          appName: a.appName,
        })),
      });
    }

    notifyChildScheduleUpdated(req.app.get('io'), profileId);

    const updated = await prisma.schoolSchedule.findUnique({
      where: { profileId },
      include: { daySchedules: true, allowedApps: true },
    });
    return sendSuccess(res, { schedule: updated });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/school-schedule/override** — Manual override

```javascript
exports.manualOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { action, durationMinutes } = req.body;
    // action: "FORCE_ON" | "FORCE_OFF" | "CLEAR"

    const overrideUntil = action === 'CLEAR' ? null
      : new Date(Date.now() + (durationMinutes || 60) * 60 * 1000);

    const schedule = await prisma.schoolSchedule.update({
      where: { profileId },
      data: {
        manualOverride: action === 'CLEAR' ? null : action,
        overrideUntil,
      },
    });

    notifyChildScheduleUpdated(req.app.get('io'), profileId);
    return sendSuccess(res, { schedule });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 4.2: Child sync — Trạng thái School Mode hiện tại

**GET /api/child/school-mode?deviceCode=XXX**

```javascript
exports.getChildSchoolMode = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: {
            schoolSchedule: {
              include: { daySchedules: true, allowedApps: true },
            },
          },
        },
      },
    });

    if (!device?.profile?.schoolSchedule) {
      return sendSuccess(res, { isActive: false, allowedApps: [] });
    }

    const s = device.profile.schoolSchedule;

    // Check manual override
    if (s.manualOverride && s.overrideUntil && new Date() < s.overrideUntil) {
      return sendSuccess(res, {
        isActive: s.manualOverride === 'FORCE_ON',
        reason: 'MANUAL_OVERRIDE',
        allowedApps: s.allowedApps,
      });
    }

    if (!s.isEnabled) {
      return sendSuccess(res, { isActive: false, allowedApps: [] });
    }

    // Tính toán theo lịch
    const now = new Date();
    const vnNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const today = vnNow.getDay();
    const currentTime = `${String(vnNow.getHours()).padStart(2, '0')}:${String(vnNow.getMinutes()).padStart(2, '0')}`;

    // Ưu tiên day override, fallback template
    const override = s.daySchedules.find(d => d.dayOfWeek === today);
    const start = override?.startTime || s.templateStartTime;
    const end = override?.endTime || s.templateEndTime;
    const enabled = override ? override.isEnabled : true;

    const isActive = enabled && start && end 
      && currentTime >= start && currentTime < end;

    return sendSuccess(res, {
      isActive,
      reason: 'SCHEDULED',
      startTime: start,
      endTime: end,
      allowedApps: s.allowedApps,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add school schedule API with template + override"
```

---

## Task 5: Child Sync APIs (Tổng hợp)

Đã viết trong các task trên:
- `GET /api/child/app-time-limits?deviceCode=XXX`
- `GET /api/child/blocked-domains?deviceCode=XXX`
- `GET /api/child/school-mode?deviceCode=XXX`

Tạo thêm 1 endpoint tổng hợp cho tiện:

**GET /api/child/policy?deviceCode=XXX** — Tất cả policy 1 request

```javascript
exports.getChildPolicy = async (req, res) => {
  try {
    const { deviceCode } = req.query;
    
    // Gọi song song 3 endpoints
    const [appLimitsRes, domainsRes, schoolModeRes] = await Promise.all([
      getAppLimitsData(deviceCode),
      getBlockedDomainsData(deviceCode),
      getSchoolModeData(deviceCode),
    ]);

    return sendSuccess(res, {
      appTimeLimits: appLimitsRes,
      blockedDomains: domainsRes,
      schoolMode: schoolModeRes,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

---

## Task 6: Socket.IO Events + Push Notifications

### Socket.IO events:

| Event | Room | Payload |
|-------|------|---------|
| `appTimeLimitUpdated` | `device_{code}` | `{profileId}` |
| `blockedDomainsUpdated` | `device_{code}` | `{profileId}` |
| `schoolScheduleUpdated` | `device_{code}` | `{profileId}` |
| `appTimeLimitWarning` | `family_{userId}` | `{profileName, packageName, appName, remainingMinutes}` |

### Push notification — khi app hết giờ riêng:

Trong heartbeat hoặc AppUsage sync, backend check nếu app vừa vượt limit:

```javascript
// Khi update AppUsageLog, check vs AppTimeLimit:
if (usedSeconds >= limitMinutes * 60 && !alreadyNotified) {
  // Send FCM push cho Parent
  await sendAppLimitExceededPush(profile.userId, {
    profileName: profile.profileName,
    appName: limit.appName,
    packageName: limit.packageName,
  });
}
```

---

## Task 7: Deploy + Test

### Test bằng curl:

```bash
# 1. Seed web categories
node backend/prisma/seed-web-categories.js

# 2. Set per-app limit
curl -X POST "https://kidfun-backend-production.up.railway.app/api/profiles/13/app-time-limits" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"packageName":"com.google.android.youtube","appName":"YouTube","dailyLimitMinutes":30}'

# 3. Toggle category Social Media
curl -X POST "https://kidfun-backend-production.up.railway.app/api/profiles/13/blocked-categories" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"categoryId":4,"isBlocked":true}'

# 4. Child sync policy
curl "https://kidfun-backend-production.up.railway.app/api/child/policy?deviceCode=BE4B.251210.005"

# 5. School mode
curl -X PUT "https://kidfun-backend-production.up.railway.app/api/profiles/13/school-schedule" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "isEnabled": true,
    "templateStartTime": "07:00",
    "templateEndTime": "11:30",
    "dayOverrides": [
      {"dayOfWeek": 0, "isEnabled": false, "startTime": "00:00", "endTime": "00:00"},
      {"dayOfWeek": 6, "isEnabled": false, "startTime": "00:00", "endTime": "00:00"}
    ],
    "allowedApps": [
      {"packageName":"com.zoom.us","appName":"Zoom"},
      {"packageName":"com.google.android.gm","appName":"Gmail"}
    ]
  }'
```

### Nhắn Frontend:

```
Sprint 8 Backend ready!

⏰ PER-APP TIME LIMIT:
- GET/POST /api/profiles/:id/app-time-limits
- DELETE /api/profiles/:id/app-time-limits/:packageName
- GET /api/child/app-time-limits?deviceCode=XXX

🌐 WEB FILTERING:
- GET /api/web-categories
- GET/POST /api/profiles/:id/blocked-categories
- POST/DELETE /api/profiles/:id/blocked-categories/:categoryId/override[/:domain]
- GET/POST/DELETE /api/profiles/:id/custom-blocked-domains
- GET /api/child/blocked-domains?deviceCode=XXX

📚 SCHOOL MODE:
- GET/PUT /api/profiles/:id/school-schedule
- POST /api/profiles/:id/school-schedule/override
- GET /api/child/school-mode?deviceCode=XXX

🎯 UNIFIED (khuyên dùng):
- GET /api/child/policy?deviceCode=XXX (tất cả trong 1 request)

🔌 Socket.IO events:
- appTimeLimitUpdated, blockedDomainsUpdated, schoolScheduleUpdated
- appTimeLimitWarning (cảnh báo 5 phút)
```

---

## Checklist cuối Sprint 8 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | Models: AppTimeLimit, WebCategory, WebCategoryDomain, BlockedCategory, CategoryOverride, CustomBlockedDomain, SchoolSchedule, SchoolDaySchedule, AllowedSchoolApp | ⬜ |
| 2 | Migration + seed web categories | ⬜ |
| 3 | Per-app limit CRUD + Child sync | ⬜ |
| 4 | Web categories API (toggle + override) | ⬜ |
| 5 | Custom blocked domains API | ⬜ |
| 6 | Child blocked-domains sync (tính toán categories + overrides + custom) | ⬜ |
| 7 | School schedule API (template + day overrides + allowed apps) | ⬜ |
| 8 | Manual override API với thời hạn | ⬜ |
| 9 | Child school-mode sync (tính trạng thái hiện tại) | ⬜ |
| 10 | Unified /api/child/policy endpoint | ⬜ |
| 11 | Socket.IO events | ⬜ |
| 12 | Push notification cho app limit warning | ⬜ |
| 13 | Deploy + Test curl | ⬜ |
