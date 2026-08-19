# KidFun V3 — Sprint 4: Time Management & Soft Warning — BACKEND (Khanh)

> **Sprint Goal:** Tính năng cốt lõi — giới hạn thời gian, cảnh báo mềm, xin thêm giờ
> **Đây là 2 USP chính của KidFun** ★
> **Branch gốc:** `develop`
> **Server:** https://kidfun-backend-production.up.railway.app

---

## Tổng quan Sprint 4 — Backend Tasks

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 1** | Review + test Time Limit API trên PostgreSQL | Không |
| **Task 2** | Usage Session API (start, heartbeat, end) | Task 1 |
| **Task 3** | Socket.IO: timeLimitUpdated event | Task 1 |
| **Task 4** | Soft Warning: Warning log API | Task 2 |
| **Task 5** | Xin thêm giờ API + Socket.IO + FCM | Task 3, 4 |
| **Task 6** | Deploy + Integration test | Task 1–5 |

---

## Task 1: Review + Test Time Limit API

> V2 đã có Time Limit API. Cần verify nó hoạt động đúng trên PostgreSQL + chuẩn hóa response.

**Branch:** `feature/backend/time-limit-review`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/time-limit-review
```

### 1.1: Kiểm tra Prisma schema

Mở `backend/prisma/schema.prisma` — verify model `TimeLimit` đã có:

```prisma
model TimeLimit {
  id          Int      @id @default(autoincrement())
  profileId   Int
  dayOfWeek   Int      // 0 = Chủ nhật, 1-6 = Thứ 2 - Thứ 7
  limitMinutes Int     // Số phút giới hạn/ngày
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
}
```

- [ ] Verify model TimeLimit tồn tại
- [ ] Verify có relation với Profile
- [ ] Nếu thiếu field nào → thêm + migrate

### 1.2: Test các endpoints hiện có

- [ ] `GET /api/profiles/:id` — verify trả về `timeLimits` array (7 ngày)
- [ ] `PUT /api/profiles/:id/time-limits` — set time limits cho 7 ngày

Test data mẫu:
```bash
# Set time limits cho profile (7 ngày)
curl -X PUT https://kidfun-backend-production.up.railway.app/api/profiles/1/time-limits \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "timeLimits": [
      { "dayOfWeek": 0, "limitMinutes": 120 },
      { "dayOfWeek": 1, "limitMinutes": 90 },
      { "dayOfWeek": 2, "limitMinutes": 90 },
      { "dayOfWeek": 3, "limitMinutes": 90 },
      { "dayOfWeek": 4, "limitMinutes": 90 },
      { "dayOfWeek": 5, "limitMinutes": 150 },
      { "dayOfWeek": 6, "limitMinutes": 150 }
    ]
  }'

# Get profile → kiểm tra timeLimits
curl -X GET https://kidfun-backend-production.up.railway.app/api/profiles/1 \
  -H "Authorization: Bearer <token>"
```

- [ ] Response đúng format `{ success: true, data: { ... } }`
- [ ] Data trên Supabase đúng

### 1.3: Thêm endpoint lấy time limit hôm nay (cho Child App)

File sửa: `backend/src/controllers/childController.js` (hoặc tạo mới nếu chưa có)

```javascript
// GET /api/child/today-limit
// Auth: JWT (child device token) hoặc query by deviceCode
// Response: { success: true, data: { limitMinutes, usedMinutes, remainingMinutes, dayOfWeek } }

exports.getTodayLimit = async (req, res) => {
  try {
    const { deviceCode } = req.query; // hoặc lấy từ JWT

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: { timeLimits: true }
        }
      }
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not found or not linked to profile', 404);
    }

    const today = new Date().getDay(); // 0 = Sunday
    const todayLimit = device.profile.timeLimits.find(tl => tl.dayOfWeek === today);

    // Tính thời gian đã dùng hôm nay (từ UsageSession)
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const sessions = await prisma.usageSession.findMany({
      where: {
        profileId: device.profile.id,
        startTime: { gte: startOfDay },
      },
    });

    const usedMinutes = sessions.reduce((total, s) => {
      const end = s.endTime || new Date();
      const diff = (end - s.startTime) / 60000;
      return total + diff;
    }, 0);

    const limitMinutes = todayLimit?.limitMinutes || 0;
    const remainingMinutes = Math.max(0, limitMinutes - Math.round(usedMinutes));

    return sendSuccess(res, {
      profileId: device.profile.id,
      profileName: device.profile.profileName,
      dayOfWeek: today,
      limitMinutes,
      usedMinutes: Math.round(usedMinutes),
      remainingMinutes,
      isActive: todayLimit?.isActive ?? false,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

File sửa: `backend/src/routes/child.js` (hoặc tạo mới)

- [ ] Thêm `GET /today-limit` → childController.getTodayLimit
- [ ] Mount route: `app.use('/api/child', childRoutes)` trong server.js

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): review time limit API, add GET /api/child/today-limit"
git push origin feature/backend/time-limit-review
```
→ PR → develop → merge

---

## Task 2: Usage Session API

> Theo dõi thời gian sử dụng thực tế của trẻ. Child App gửi heartbeat mỗi 60s.

**Branch:** `feature/backend/usage-session`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/usage-session
```

### 2.1: Thêm UsageSession model (nếu chưa có)

File sửa: `backend/prisma/schema.prisma`

```prisma
model UsageSession {
  id          Int       @id @default(autoincrement())
  profileId   Int
  deviceId    Int
  startTime   DateTime  @default(now())
  endTime     DateTime?
  isActive    Boolean   @default(true)
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt

  profile     Profile   @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device      Device    @relation(fields: [deviceId], references: [id], onDelete: Cascade)
}
```

- [ ] Thêm `usageSessions UsageSession[]` vào model Profile và Device
- [ ] Chạy migration:

```bash
npx prisma migrate dev --name add-usage-session
npx prisma generate
```

### 2.2: Session Controller

File tạo mới: `backend/src/controllers/sessionController.js`

**POST /api/child/session/start** — Child bắt đầu phiên sử dụng

```javascript
exports.startSession = async (req, res) => {
  try {
    const { deviceCode } = req.body;

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    // Đóng session cũ nếu còn active (phòng trường hợp app crash)
    await prisma.usageSession.updateMany({
      where: { deviceId: device.id, isActive: true },
      data: { isActive: false, endTime: new Date() },
    });

    // Tạo session mới
    const session = await prisma.usageSession.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
      },
    });

    return sendSuccess(res, { sessionId: session.id }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/child/session/heartbeat** — Child ping mỗi 60 giây

```javascript
exports.heartbeat = async (req, res) => {
  try {
    const { sessionId } = req.body;

    const session = await prisma.usageSession.findUnique({
      where: { id: sessionId },
      include: {
        profile: { include: { timeLimits: true } },
      },
    });

    if (!session || !session.isActive) {
      return sendError(res, 'Session not found or inactive', 404);
    }

    // Cập nhật updatedAt (chứng minh session vẫn active)
    await prisma.usageSession.update({
      where: { id: sessionId },
      data: { updatedAt: new Date() },
    });

    // Tính remaining time
    const today = new Date().getDay();
    const todayLimit = session.profile.timeLimits.find(tl => tl.dayOfWeek === today);
    const limitMinutes = todayLimit?.limitMinutes || 0;

    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const sessions = await prisma.usageSession.findMany({
      where: {
        profileId: session.profileId,
        startTime: { gte: startOfDay },
      },
    });

    const usedMinutes = sessions.reduce((total, s) => {
      const end = s.endTime || new Date();
      return total + (end - s.startTime) / 60000;
    }, 0);

    const remainingMinutes = Math.max(0, limitMinutes - Math.round(usedMinutes));

    return sendSuccess(res, {
      sessionId,
      remainingMinutes,
      limitMinutes,
      usedMinutes: Math.round(usedMinutes),
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/child/session/end** — Child kết thúc phiên

```javascript
exports.endSession = async (req, res) => {
  try {
    const { sessionId } = req.body;

    await prisma.usageSession.update({
      where: { id: sessionId },
      data: { isActive: false, endTime: new Date() },
    });

    return sendSuccess(res, { message: 'Session ended' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 2.3: Routes

File sửa: `backend/src/routes/child.js`

```javascript
router.post('/session/start', sessionController.startSession);
router.post('/session/heartbeat', sessionController.heartbeat);
router.post('/session/end', sessionController.endSession);
```

### 2.4: Test

- [ ] Start session → nhận sessionId
- [ ] Heartbeat → nhận remainingMinutes đúng
- [ ] End session → session đóng
- [ ] Start session mới → session cũ tự động đóng

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add usage session API (start, heartbeat, end)"
git push origin feature/backend/usage-session
```
→ PR → develop → merge

---

## Task 3: Socket.IO — timeLimitUpdated Event

> Khi Parent thay đổi time limit → Child nhận được ngay lập tức qua Socket.IO.

**Branch:** `feature/backend/socket-time-limit`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/socket-time-limit
```

### 3.1: Emit event khi Parent cập nhật time limit

File sửa: Controller xử lý `PUT /api/profiles/:id/time-limits`

Sau khi update thành công, emit event cho tất cả devices của profile đó:

```javascript
// Sau khi update time limits thành công:

// Tìm tất cả devices thuộc profile này
const devices = await prisma.device.findMany({
  where: { profileId: parseInt(req.params.id) },
});

const io = req.app.get('io'); // hoặc getIO()
if (io) {
  // Emit cho từng device room
  devices.forEach(device => {
    io.to(`device_${device.deviceCode}`).emit('timeLimitUpdated', {
      profileId: parseInt(req.params.id),
      timeLimits: updatedTimeLimits, // Array 7 ngày
    });
  });

  // Cũng emit cho Parent room
  io.to(`family_${req.user.id}`).emit('timeLimitUpdated', {
    profileId: parseInt(req.params.id),
    timeLimits: updatedTimeLimits,
  });

  console.log(`⏰ Time limits updated for profile ${req.params.id} → notified devices`);
}
```

### 3.2: Test

- [ ] Parent set time limit → Child nhận event `timeLimitUpdated`
- [ ] Event data chứa đúng `profileId` và `timeLimits` array

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): emit timeLimitUpdated event via Socket.IO"
git push origin feature/backend/socket-time-limit
```
→ PR → develop → merge

---

## Task 4: Soft Warning — Warning Log API

> Ghi nhận khi hệ thống gửi cảnh báo mềm cho trẻ (30/15/5 phút).

**Branch:** `feature/backend/warning-log`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/warning-log
```

### 4.1: Verify Warning model

Kiểm tra `backend/prisma/schema.prisma` — model Warning từ V2:

```prisma
model Warning {
  id          Int      @id @default(autoincrement())
  profileId   Int
  type        String   // SOFT_30 | SOFT_15 | SOFT_5 | TIME_UP
  message     String?
  createdAt   DateTime @default(now())

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
}
```

Nếu chưa có → thêm + migrate.

### 4.2: Warning Controller

File tạo mới: `backend/src/controllers/warningController.js`

**POST /api/child/warning** — Child App gửi khi hiển thị warning

```javascript
exports.logWarning = async (req, res) => {
  try {
    const { deviceCode, type, message } = req.body;
    // type: SOFT_30 | SOFT_15 | SOFT_5 | TIME_UP

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const warning = await prisma.warning.create({
      data: {
        profileId: device.profile.id,
        type,
        message: message || `Cảnh báo ${type} cho ${device.profile.profileName}`,
      },
    });

    // Notify Parent qua Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.to(`family_${device.userId}`).emit('softWarning', {
        profileId: device.profile.id,
        profileName: device.profile.profileName,
        type,
        message: warning.message,
        createdAt: warning.createdAt,
      });
    }

    // Push notification cho Parent (FCM)
    const { sendPushToUser } = require('../services/firebaseService');
    const warningLabels = {
      SOFT_30: '30 phút',
      SOFT_15: '15 phút',
      SOFT_5: '5 phút',
      TIME_UP: 'Hết giờ',
    };

    await sendPushToUser(device.userId, {
      title: `⏰ ${device.profile.profileName}`,
      body: `Còn ${warningLabels[type] || type} sử dụng thiết bị`,
      data: { type: 'soft_warning', profileId: String(device.profile.id), warningType: type },
    });

    return sendSuccess(res, { warningId: warning.id }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/warnings** — Parent xem lịch sử cảnh báo

```javascript
exports.getWarnings = async (req, res) => {
  try {
    const warnings = await prisma.warning.findMany({
      where: { profileId: parseInt(req.params.id) },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return sendSuccess(res, { warnings });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 4.3: Helper — sendPushToUser

File sửa: `backend/src/services/firebaseService.js`

Thêm hàm gửi push cho tất cả devices của 1 user:

```javascript
async function sendPushToUser(userId, { title, body, data = {} }) {
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: { userId },
    });

    if (tokens.length === 0) return;

    const tokenStrings = tokens.map(t => t.token);
    await sendToMultipleTokens(tokenStrings, title, body, data);
  } catch (err) {
    console.error('Push to user failed:', err.message);
  }
}

module.exports = { initFirebase, sendPushNotification, sendToMultipleTokens, sendPushToUser };
```

### 4.4: Routes

```javascript
// child.js
router.post('/warning', warningController.logWarning);

// profiles.js (hoặc routes phù hợp)
router.get('/:id/warnings', authMiddleware, warningController.getWarnings);
```

### 4.5: Test

- [ ] POST /api/child/warning → tạo warning log
- [ ] Parent nhận event `softWarning` qua Socket.IO
- [ ] Parent nhận push notification (FCM)
- [ ] GET /api/profiles/:id/warnings → trả danh sách

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add soft warning log API with Socket.IO + FCM notification"
git push origin feature/backend/warning-log
```
→ PR → develop → merge

---

## Task 5: Xin Thêm Giờ API + Socket.IO + FCM ★

> USP #2 — Trẻ xin thêm giờ kèm lý do → Phụ huynh duyệt/từ chối real-time.

**Branch:** `feature/backend/time-extension`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/time-extension
```

### 5.1: Thêm TimeExtensionRequest model (nếu chưa có)

File sửa: `backend/prisma/schema.prisma`

```prisma
model TimeExtensionRequest {
  id             Int       @id @default(autoincrement())
  profileId      Int
  deviceId       Int
  requestMinutes Int       // Số phút xin thêm
  reason         String?   // Lý do
  status         String    @default("PENDING") // PENDING | APPROVED | REJECTED
  responseMinutes Int?     // Số phút Parent cho (có thể khác requestMinutes)
  respondedAt    DateTime?
  createdAt      DateTime  @default(now())

  profile        Profile   @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device         Device    @relation(fields: [deviceId], references: [id], onDelete: Cascade)
}
```

- [ ] Thêm `timeExtensionRequests TimeExtensionRequest[]` vào model Profile và Device
- [ ] Chạy migration:

```bash
npx prisma migrate dev --name add-time-extension-request
npx prisma generate
```

### 5.2: Socket.IO Events cho xin thêm giờ

File sửa: `backend/src/services/socketService.js`

Thêm vào trong `io.on('connection')`:

```javascript
// ========== XIN THÊM GIỜ (từ V2, cập nhật cho V3) ==========

// Child xin thêm giờ
socket.on('requestTimeExtension', async ({ deviceCode, requestMinutes, reason }) => {
  try {
    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) return;

    // Tạo request trong DB
    const request = await prisma.timeExtensionRequest.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        requestMinutes,
        reason: reason || '',
      },
    });

    // Notify Parent qua Socket.IO
    io.to(`family_${device.userId}`).emit('timeExtensionRequest', {
      requestId: request.id,
      profileId: device.profile.id,
      profileName: device.profile.profileName,
      deviceName: device.deviceName,
      requestMinutes,
      reason: reason || '',
      createdAt: request.createdAt,
    });

    // Push notification cho Parent
    const { sendPushToUser } = require('./firebaseService');
    await sendPushToUser(device.userId, {
      title: `⏳ ${device.profile.profileName} xin thêm giờ`,
      body: `Xin thêm ${requestMinutes} phút${reason ? ': ' + reason : ''}`,
      data: {
        type: 'time_extension',
        requestId: String(request.id),
        profileId: String(device.profile.id),
      },
    });

    console.log(`⏳ Time extension request: ${device.profile.profileName} xin ${requestMinutes} phút`);

  } catch (err) {
    console.error('requestTimeExtension error:', err.message);
  }
});

// Parent phản hồi (approve/reject)
socket.on('respondTimeExtension', async ({ requestId, approved, responseMinutes }) => {
  try {
    const request = await prisma.timeExtensionRequest.update({
      where: { id: requestId },
      data: {
        status: approved ? 'APPROVED' : 'REJECTED',
        responseMinutes: approved ? (responseMinutes || null) : null,
        respondedAt: new Date(),
      },
      include: {
        device: true,
        profile: true,
      },
    });

    // Notify Child qua Socket.IO
    io.to(`device_${request.device.deviceCode}`).emit('timeExtensionResponse', {
      requestId: request.id,
      approved,
      responseMinutes: approved ? (responseMinutes || request.requestMinutes) : 0,
      status: request.status,
    });

    console.log(`⏳ Time extension ${approved ? 'APPROVED' : 'REJECTED'}: ${request.profile.profileName} → ${responseMinutes || request.requestMinutes} phút`);

  } catch (err) {
    console.error('respondTimeExtension error:', err.message);
  }
});
```

### 5.3: REST API cho xin thêm giờ (backup/history)

File tạo mới: `backend/src/controllers/extensionController.js`

```javascript
// GET /api/profiles/:id/extension-requests — Lịch sử xin thêm giờ
exports.getExtensionRequests = async (req, res) => {
  try {
    const requests = await prisma.timeExtensionRequest.findMany({
      where: { profileId: parseInt(req.params.id) },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return sendSuccess(res, { requests });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/extension-requests/pending — Các request đang chờ duyệt (cho Parent)
exports.getPendingRequests = async (req, res) => {
  try {
    const profiles = await prisma.profile.findMany({
      where: { userId: req.user.id },
      select: { id: true },
    });
    const profileIds = profiles.map(p => p.id);

    const requests = await prisma.timeExtensionRequest.findMany({
      where: {
        profileId: { in: profileIds },
        status: 'PENDING',
      },
      include: {
        profile: { select: { profileName: true } },
        device: { select: { deviceName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, { requests });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 5.4: Routes

```javascript
// profiles.js
router.get('/:id/extension-requests', authMiddleware, extensionController.getExtensionRequests);

// Tạo route mới hoặc thêm vào existing
router.get('/extension-requests/pending', authMiddleware, extensionController.getPendingRequests);
```

### 5.5: Test

Test với 2 socket clients (giả lập Parent + Child):

```javascript
// test-extension.js
const { io } = require('socket.io-client');
const URL = 'https://kidfun-backend-production.up.railway.app';

// Parent
const parent = io(URL, { transports: ['websocket'] });
parent.on('connect', () => {
  parent.emit('joinFamily', { userId: 1 });
  console.log('👨‍👩‍👧 Parent joined');
});
parent.on('timeExtensionRequest', (data) => {
  console.log('⏳ Received request:', data);
  // Auto-approve for testing
  setTimeout(() => {
    parent.emit('respondTimeExtension', {
      requestId: data.requestId,
      approved: true,
      responseMinutes: data.requestMinutes,
    });
    console.log('✅ Approved!');
  }, 3000);
});

// Child
const child = io(URL, { transports: ['websocket'] });
child.on('connect', () => {
  child.emit('joinDevice', { deviceCode: 'ABC123' }); // Thay code thật
  console.log('📱 Child joined');
  // Gửi request sau 2 giây
  setTimeout(() => {
    child.emit('requestTimeExtension', {
      deviceCode: 'ABC123',
      requestMinutes: 30,
      reason: 'Con đang làm bài tập',
    });
    console.log('⏳ Sent request');
  }, 2000);
});
child.on('timeExtensionResponse', (data) => {
  console.log('📱 Response received:', data);
});
```

- [ ] Child gửi request → Parent nhận `timeExtensionRequest` event
- [ ] Parent approve → Child nhận `timeExtensionResponse` event
- [ ] Request lưu trong DB đúng status
- [ ] Push notification gửi cho Parent

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add time extension request API with Socket.IO + FCM"
git push origin feature/backend/time-extension
```
→ PR → develop → merge

---

## Task 6: Deploy + Integration Test

**Branch:** `fix/backend/sprint4-polish`

```bash
git checkout develop && git pull origin develop
git checkout -b fix/backend/sprint4-polish
```

### 6.1: Deploy

- [ ] Push tất cả code lên develop
- [ ] Verify Railway deploy thành công
- [ ] Test health check

### 6.2: Nhắn bạn Frontend

```
Sprint 4 Backend đã ready!

API mới:
- GET /api/child/today-limit?deviceCode=XXX → remaining time hôm nay
- POST /api/child/session/start { deviceCode }
- POST /api/child/session/heartbeat { sessionId }
- POST /api/child/session/end { sessionId }
- POST /api/child/warning { deviceCode, type, message }
- GET /api/profiles/:id/warnings
- GET /api/profiles/:id/extension-requests

Socket.IO events mới:
- Emit 'timeLimitUpdated' → khi Parent thay đổi time limit
- Listen 'requestTimeExtension' { deviceCode, requestMinutes, reason }
- Emit 'timeExtensionRequest' → cho Parent khi Child xin giờ
- Listen 'respondTimeExtension' { requestId, approved, responseMinutes }
- Emit 'timeExtensionResponse' → cho Child khi Parent trả lời
- Emit 'softWarning' → cho Parent khi Child nhận warning
```

### Commit & Push

```bash
git add -A
git commit -m "chore(backend): sprint 4 polish and deploy"
git push origin fix/backend/sprint4-polish
```
→ PR → develop → merge

---

## Checklist cuối Sprint 4 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | Time Limit API hoạt động trên PostgreSQL | ⬜ |
| 2 | GET /api/child/today-limit trả remaining time | ⬜ |
| 3 | UsageSession model + migration | ⬜ |
| 4 | POST /api/child/session/start hoạt động | ⬜ |
| 5 | POST /api/child/session/heartbeat trả remainingMinutes | ⬜ |
| 6 | POST /api/child/session/end hoạt động | ⬜ |
| 7 | timeLimitUpdated event emit khi Parent update | ⬜ |
| 8 | Warning model verified | ⬜ |
| 9 | POST /api/child/warning + Socket.IO + FCM | ⬜ |
| 10 | TimeExtensionRequest model + migration | ⬜ |
| 11 | requestTimeExtension Socket.IO event | ⬜ |
| 12 | respondTimeExtension Socket.IO event | ⬜ |
| 13 | FCM push khi Child xin thêm giờ | ⬜ |
| 14 | FCM push khi Soft Warning | ⬜ |
| 15 | Deploy Railway thành công | ⬜ |
| 16 | Nhắn Frontend API ready | ⬜ |

---

## Quy tắc Git (nhắc lại)

```bash
# Mỗi task = 1 branch riêng
git checkout develop && git pull origin develop
git checkout -b feature/backend/<tên-task>

# Code + commit thường xuyên
git add -A
git commit -m "feat(backend): mô tả ngắn"

# Push + tạo PR
git push origin feature/backend/<tên-task>
# → GitHub tạo PR → target develop → tự review → merge

# Xong task → quay về develop, tạo branch mới
git checkout develop && git pull origin develop
```
