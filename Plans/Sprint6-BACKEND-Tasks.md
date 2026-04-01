# KidFun V3 — Sprint 6: Demo Giữa Kỳ ★ CHECKPOINT — BACKEND (Khanh)

> **Sprint Goal:** Hoàn thiện, fix bug, seed data demo, đảm bảo luồng chính chạy mượt cho GVHD đánh giá
> **QUAN TRỌNG:** Đây là sprint demo — KHÔNG thêm tính năng mới, chỉ fix + polish + test
> **Branch gốc:** `develop`
> **Deadline:** Demo cho GVHD

---

## Tổng quan Sprint 6 — Backend Tasks

| Task | Nội dung | Ưu tiên |
|------|----------|---------|
| **Task 1** | Fix tất cả bugs còn lại từ Sprint 1–5 | 🔴 CRITICAL |
| **Task 2** | API error handling + validation hoàn chỉnh | 🟠 HIGH |
| **Task 3** | Seed data cho demo | 🟠 HIGH |
| **Task 4** | Test toàn bộ API (Postman collection) | 🟡 MEDIUM |
| **Task 5** | Đảm bảo server ổn định (Railway + Supabase) | 🟡 MEDIUM |
| **Task 6** | Viết tài liệu API | 🟢 LOW |

---

## Task 1: Fix Tất Cả Bugs Còn Lại

> **Branch:** `fix/backend/sprint6-bugfix`

### Bugs đã biết cần verify/fix:

**1.1: Transport close (Socket.IO)**

Vấn đề: Parent vẫn bị disconnect liên tục (transport close) trên Railway.

Giải pháp đã áp dụng:
- pingInterval: 5000 → thử tăng lên 25000 (default Socket.IO)
- pingTimeout: 3000 → thử tăng lên 20000
- REST API fallback cho pending extension requests ✅

Cần verify: Test với pingInterval/pingTimeout mới. Nếu vẫn bị → chấp nhận và dựa vào REST fallback. Lúc demo thì kết nối LAN sẽ ổn định hơn.

```javascript
// server.js — thử config mới
const io = new Server(httpServer, {
  cors: { origin: '*' },
  pingInterval: 25000,
  pingTimeout: 20000,
  transports: ['websocket', 'polling'], // Cho phép cả polling làm fallback
});
```

**1.2: POST /api/child/warnings route**

Vấn đề: Frontend gọi `/api/child/warnings` (số nhiều) → 404.

Fix: Thêm alias route.

```javascript
// routes/child.js
router.post('/warning', childController.logWarning);
router.post('/warnings', childController.logWarning); // Alias
```

**1.3: Verify remainingSeconds chính xác**

Cần test: Start session → đợi 90 giây → heartbeat → verify `remainingSeconds` ≠ `remainingMinutes * 60`.

**1.4: Verify bonus minutes từ xin thêm giờ**

Cần test: Child xin 15 phút → Parent duyệt → heartbeat → verify remaining tăng 15 phút.

### Cách tìm bugs khác:

```bash
# Dùng GitNexus để scan
npx gitnexus analyze
# Trong Claude Code:
# query({query: "error handling catch"})
# query({query: "TODO FIXME HACK"})

# Grep tìm potential issues
grep -rn "TODO\|FIXME\|HACK\|console.error" backend/src/ --include="*.js"
```

### Commit:

```bash
git checkout develop && git pull origin develop
git checkout -b fix/backend/sprint6-bugfix
# Fix xong:
git commit -m "fix(backend): sprint 6 bugfix round — warnings route, socket config"
git push origin fix/backend/sprint6-bugfix
```
→ PR → develop → merge

---

## Task 2: API Error Handling + Validation

> **Branch:** `chore/backend/api-validation`

### 2.1: Validate tất cả request body

Kiểm tra từng controller, đảm bảo:

```javascript
// Mẫu validation cho mọi POST/PUT endpoint
exports.someEndpoint = async (req, res) => {
  try {
    const { field1, field2 } = req.body;

    // ★ VALIDATE input
    if (!field1 || typeof field1 !== 'string') {
      return sendError(res, 'field1 is required and must be a string', 400);
    }

    // ... business logic ...
  } catch (err) {
    console.error('❌ [someEndpoint] Error:', err.message);
    return sendError(res, 'Internal server error', 500);
  }
};
```

### 2.2: Checklist endpoints cần validate

| Endpoint | Cần validate |
|----------|-------------|
| POST /api/auth/register | email format, password min 6 chars, fullName required |
| POST /api/auth/login | email, password required |
| POST /api/profiles | profileName, dateOfBirth required |
| PUT /api/profiles/:id/time-limits | timeLimits array, dayOfWeek (0-6), limitMinutes (>= 0) |
| POST /api/child/app-usage | deviceCode, usageData array |
| POST /api/child/session/start | deviceCode required |
| POST /api/child/session/heartbeat | sessionId required, must be int |
| POST /api/profiles/:id/blocked-apps | packageName required |

### 2.3: Consistent error response format

Đảm bảo TẤT CẢ errors trả format giống nhau:

```json
{
  "success": false,
  "message": "Mô tả lỗi rõ ràng",
  "code": "ERROR_CODE"
}
```

### Commit:

```bash
git commit -m "chore(backend): add input validation for all API endpoints"
```

---

## Task 3: Seed Data Cho Demo

> **Branch:** `chore/backend/seed-demo-data`

### 3.1: Tạo seed script

File tạo mới: `backend/prisma/seed-demo.js`

```javascript
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');
const prisma = new PrismaClient();

async function main() {
  // 1. Tạo tài khoản Parent demo
  const hashedPassword = await bcrypt.hash('demo123', 10);
  const parent = await prisma.user.upsert({
    where: { email: 'demo@kidfun.app' },
    update: {},
    create: {
      email: 'demo@kidfun.app',
      password: hashedPassword,
      fullName: 'Phụ Huynh Demo',
      phoneNumber: '0901234567',
    },
  });
  console.log('✅ Parent account:', parent.email);

  // 2. Tạo profile con
  const profile = await prisma.profile.upsert({
    where: { id: 100 }, // ID cố định cho demo
    update: {},
    create: {
      id: 100,
      userId: parent.id,
      profileName: 'Bé An',
      dateOfBirth: new Date('2018-06-15'),
      isActive: true,
    },
  });
  console.log('✅ Child profile:', profile.profileName);

  // 3. Tạo time limits (7 ngày)
  const daysConfig = [
    { day: 0, limit: 180 }, // CN: 3h
    { day: 1, limit: 90 },  // T2: 1.5h
    { day: 2, limit: 90 },  // T3: 1.5h
    { day: 3, limit: 120 }, // T4: 2h
    { day: 4, limit: 90 },  // T5: 1.5h
    { day: 5, limit: 120 }, // T6: 2h
    { day: 6, limit: 180 }, // T7: 3h
  ];

  for (const dc of daysConfig) {
    await prisma.timeLimit.upsert({
      where: { profileId_dayOfWeek: { profileId: profile.id, dayOfWeek: dc.day } },
      update: { dailyLimitMinutes: dc.limit, limitMinutes: dc.limit },
      create: {
        profileId: profile.id,
        dayOfWeek: dc.day,
        dailyLimitMinutes: dc.limit,
        limitMinutes: dc.limit,
        isActive: true,
      },
    });
  }
  console.log('✅ Time limits set for 7 days');

  // 4. Tạo usage data mẫu (7 ngày gần nhất)
  const apps = [
    { pkg: 'com.google.android.youtube', name: 'YouTube', base: 1800 },
    { pkg: 'com.zhiliaoapp.musically', name: 'TikTok', base: 1200 },
    { pkg: 'com.instagram.android', name: 'Instagram', base: 600 },
    { pkg: 'com.android.chrome', name: 'Chrome', base: 900 },
    { pkg: 'com.whatsapp', name: 'WhatsApp', base: 300 },
  ];

  for (let i = 0; i < 7; i++) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    date.setHours(0, 0, 0, 0);

    for (const app of apps) {
      const variance = Math.floor(Math.random() * 600) - 300; // ±5 phút
      await prisma.appUsageLog.upsert({
        where: {
          profileId_deviceId_packageName_date: {
            profileId: profile.id,
            deviceId: 1, // Sẽ update sau khi link device
            packageName: app.pkg,
            date,
          },
        },
        update: { usageSeconds: app.base + variance },
        create: {
          profileId: profile.id,
          deviceId: 1,
          packageName: app.pkg,
          appName: app.name,
          usageSeconds: Math.max(60, app.base + variance),
          date,
        },
      });
    }
  }
  console.log('✅ Usage data seeded for 7 days');

  console.log('\n🎉 Demo data ready!');
  console.log('📧 Login: demo@kidfun.app / demo123');
  console.log('👶 Profile: Bé An (ID: 100)');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

### 3.2: Chạy seed

```bash
node backend/prisma/seed-demo.js
```

### 3.3: Thêm script vào package.json

```json
{
  "scripts": {
    "seed:demo": "node prisma/seed-demo.js"
  }
}
```

### Commit:

```bash
git commit -m "chore(backend): add demo seed data script"
```

---

## Task 4: Test Toàn Bộ API (Postman Collection)

> Không cần branch riêng — tạo file Postman collection

### 4.1: Tạo Postman collection

Tạo collection `KidFun V3 API` với các folders:

| Folder | Endpoints |
|--------|-----------|
| Auth | POST /login, POST /register, POST /logout, POST /refresh-token |
| Profiles | GET /profiles, GET /profiles/:id, POST /profiles, PUT /profiles/:id, DELETE /profiles/:id |
| Time Limits | PUT /profiles/:id/time-limits, PUT /profiles/:id/time-limits/gradual |
| Devices | GET /devices, POST /generate-pairing-code, POST /link, DELETE /devices/:id |
| Child Session | GET /today-limit, POST /session/start, POST /session/heartbeat, POST /session/end |
| Child Warnings | POST /warnings |
| Extension Requests | POST /request (Socket.IO), GET /pending |
| App Usage | POST /child/app-usage, GET /profiles/:id/app-usage, GET /profiles/:id/app-usage/weekly |
| App Blocking | GET/POST/DELETE /profiles/:id/blocked-apps, GET /child/blocked-apps |
| FCM | POST /fcm-tokens/register, POST /fcm-tokens/unregister |

### 4.2: Test checklist

- [ ] Tất cả endpoints trả đúng status code
- [ ] 401 khi không có token
- [ ] 400 khi thiếu required fields
- [ ] 404 khi resource không tồn tại
- [ ] Không có 500 unexpected errors

---

## Task 5: Đảm Bảo Server Ổn Định

### 5.1: Railway health check

- [ ] Server restart không bị downtime > 30s
- [ ] Memory usage < 512MB
- [ ] Logs không có uncaught exceptions

### 5.2: Supabase

- [ ] Database connection ổn định
- [ ] RLS warnings → fix trước demo (chạy SQL bật RLS cho tất cả tables)
- [ ] Backup database trước demo

### 5.3: Fix Supabase RLS warnings

Vào Supabase Dashboard → SQL Editor:

```sql
ALTER TABLE public."User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Device" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Profile" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TimeLimit" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BlockedWebsite" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Application" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."UsageLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Warning" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Notification" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Session" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."UsageSession" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."FCMToken" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."TimeExtensionRequest" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."_prisma_migrations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."AppUsageLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BlockedApp" ENABLE ROW LEVEL SECURITY;
```

---

## Task 6: Tài Liệu API (Optional)

> Nếu có thời gian — viết README API hoặc export Postman docs.

File tạo: `backend/API-DOCS.md`

Bao gồm:
- Base URL
- Auth (JWT token)
- Mỗi endpoint: method, path, request body, response format
- Socket.IO events

---

## Checklist cuối Sprint 6 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | Fix warnings route (404) | ⬜ |
| 2 | Verify remainingSeconds chính xác | ⬜ |
| 3 | Verify bonus minutes hoạt động | ⬜ |
| 4 | Socket.IO config tối ưu cho demo | ⬜ |
| 5 | Input validation tất cả endpoints | ⬜ |
| 6 | Error response format nhất quán | ⬜ |
| 7 | Seed demo data script | ⬜ |
| 8 | Chạy seed trên production | ⬜ |
| 9 | Postman collection | ⬜ |
| 10 | Test tất cả endpoints | ⬜ |
| 11 | Bật RLS trên Supabase | ⬜ |
| 12 | Railway ổn định, không 500 | ⬜ |
| 13 | (Optional) API docs | ⬜ |

---

## Kịch bản Demo cho GVHD

> **Luồng demo (5-7 phút):**

1. **Đăng nhập** Parent app → `demo@kidfun.app`
2. **Xem profiles** → "Bé An" đã có sẵn
3. **Xem báo cáo** → biểu đồ usage 7 ngày (data mẫu)
4. **Đặt giới hạn** → set 3 phút cho hôm nay
5. **Liên kết thiết bị** → scan QR trên Child device
6. **Child dùng** → countdown 3 phút
7. **Soft warning** → hiện cảnh báo
8. **Xin thêm giờ** → Child xin 5 phút → Parent duyệt
9. **Chặn app** → Parent chặn YouTube → Child mở bị đẩy ra
10. **Hết giờ** → Lock screen
11. **Push notification** → Parent nhận thông báo

> **Tip demo:** Dùng WiFi chung để Socket.IO ổn định hơn Railway proxy.
