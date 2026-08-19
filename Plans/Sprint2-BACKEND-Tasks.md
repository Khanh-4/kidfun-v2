# KidFun V3 — Sprint 2 Tasks: BACKEND (Khanh)

> **Thời gian:** 1 tuần
> **Branch gốc:** `develop`
> **Server:** https://kidfun-backend-production.up.railway.app
> **Database:** Supabase PostgreSQL

---

## Ngày 1-2: Auth API Refactor

**Branch:** `feature/backend/auth-refactor`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/auth-refactor
```

### Task 1.1: Thêm Refresh Token

File sửa: `backend/src/controllers/authController.js`

- [ ] Sửa `/login` — response thêm `refreshToken` (JWT sign với secret riêng, expire 7d)
- [ ] Sửa `/register` — response thêm `refreshToken`
- [ ] Tạo endpoint `POST /api/auth/refresh-token`
  - Input: `{ refreshToken }`
  - Verify refresh token → tạo access token mới + refresh token mới
  - Output: `{ success: true, data: { token, refreshToken } }`
- [ ] Tạo endpoint `POST /api/auth/logout`
  - Input: JWT header
  - Output: `{ success: true, data: { message: "Logged out" } }`

### Task 1.2: Chuẩn hóa Response Format

File tạo mới: `backend/src/middleware/responseHandler.js`

Tất cả API phải trả về cùng format:
```json
// Success
{ "success": true, "data": { ... } }

// Error  
{ "success": false, "message": "Mô tả lỗi", "code": "ERROR_CODE" }
```

- [ ] Tạo helper functions: `sendSuccess(res, data, status)` và `sendError(res, message, status, code)`
- [ ] Áp dụng vào `authController.js`
- [ ] Áp dụng vào `profileController.js`
- [ ] Áp dụng vào `deviceController.js`
- [ ] Áp dụng vào `childController.js`
- [ ] Áp dụng vào `blockedSiteController.js`
- [ ] Áp dụng vào `monitoringController.js`

### Task 1.3: Thêm route mới

File sửa: `backend/src/routes/auth.js`

- [ ] Thêm `POST /refresh-token` → authController.refreshToken
- [ ] Thêm `POST /logout` → authController.logout (cần JWT middleware)

### Task 1.4: Test Auth API

- [ ] Test register → nhận `{ success, data: { token, refreshToken, user } }`
- [ ] Test login → nhận `{ success, data: { token, refreshToken, user } }`
- [ ] Test refresh-token → nhận token mới
- [ ] Test login sai password → nhận `{ success: false, message: "..." }`
- [ ] Test với token hết hạn → 401
- [ ] Test refresh với refresh token hết hạn → 401
- [ ] Lưu test collection (Postman hoặc Thunder Client)

### Commit & Push
```bash
git add -A
git commit -m "feat(backend): add refresh token, logout API, standardize response format"
git push origin feature/backend/auth-refactor
```
→ GitHub tạo PR → target `develop` → tự review → merge

---

## Ngày 3-4: Firebase Admin SDK + FCM Token API

**Branch:** `feature/backend/fcm-setup`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/fcm-setup
```

### Task 2.1: Cài Firebase Admin SDK

```bash
cd backend
npm install firebase-admin
```

### Task 2.2: Tạo Firebase Service

File tạo mới: `backend/src/services/firebaseService.js`

```javascript
// Pseudocode — implement chi tiết
const admin = require('firebase-admin');

// Local: đọc file
// Production: đọc env FIREBASE_SERVICE_ACCOUNT (JSON string)
function initFirebase() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    const serviceAccount = require('../../firebase-service-account.json');
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
}

async function sendPushNotification(token, title, body, data = {}) {
  // admin.messaging().send({ token, notification: { title, body }, data })
}

async function sendToMultipleTokens(tokens, title, body, data = {}) {
  // admin.messaging().sendEachForMulticast({ tokens, notification, data })
}
```

- [ ] Implement `initFirebase()`
- [ ] Implement `sendPushNotification(token, title, body, data)`
- [ ] Implement `sendToMultipleTokens(tokens, title, body, data)`
- [ ] Gọi `initFirebase()` trong `server.js` khi server start
- [ ] Handle lỗi khi Firebase chưa config (dev mode không có key)

### Task 2.3: Thêm FCMToken model vào Prisma

File sửa: `backend/prisma/schema.prisma`

Thêm model mới:
```prisma
model FCMToken {
  id        Int      @id @default(autoincrement())
  userId    Int
  deviceId  Int?
  token     String   @unique
  platform  String   // ANDROID | IOS
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user   User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  device Device? @relation(fields: [deviceId], references: [id], onDelete: SetNull)
}
```

- [ ] Thêm `fcmTokens FCMToken[]` vào model `User`
- [ ] Thêm `fcmTokens FCMToken[]` vào model `Device`
- [ ] Chạy migration:
```bash
npx prisma migrate dev --name add-fcm-token
npx prisma generate
```
- [ ] Verify table `FCMToken` xuất hiện trên Supabase Dashboard

### Task 2.4: FCM Token Controller + Routes

File tạo mới: `backend/src/controllers/fcmController.js`

- [ ] `registerToken(req, res)` — POST /api/fcm-tokens/register
  - JWT auth required
  - Input: `{ token, platform, deviceId? }`
  - Logic: upsert (nếu token đã tồn tại → update userId/deviceId)
  - Output: `{ success: true, data: { message: "Token registered" } }`

- [ ] `unregisterToken(req, res)` — DELETE /api/fcm-tokens/unregister
  - JWT auth required
  - Input: `{ token }`
  - Logic: xóa FCM token
  - Output: `{ success: true, data: { message: "Token removed" } }`

File tạo mới: `backend/src/routes/fcm.js`

- [ ] POST `/register` → fcmController.registerToken
- [ ] DELETE `/unregister` → fcmController.unregisterToken

File sửa: `backend/src/server.js`

- [ ] Import và mount: `app.use('/api/fcm-tokens', fcmRoutes)`

### Task 2.5: Test FCM

- [ ] Register token qua API → verify trên Supabase
- [ ] Gửi test notification qua Firebase Console
- [ ] Gọi `sendPushNotification()` trong code → verify nhận được
- [ ] Test unregister → token bị xóa

### Commit & Push
```bash
git add -A
git commit -m "feat(backend): add Firebase Admin SDK, FCM token API, push notification service"
git push origin feature/backend/fcm-setup
```
→ PR → develop → merge

---

## Ngày 5-6: Verify Profile API + Deploy + Docs

**Branch:** `feature/backend/sprint2-polish`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/sprint2-polish
```

### Task 3.1: Test toàn bộ Profile API trên PostgreSQL

- [ ] `GET /api/profiles` → trả danh sách (array rỗng nếu chưa có)
- [ ] `POST /api/profiles` → tạo profile `{ profileName: "Bé An", dateOfBirth: "2015-06-15" }`
- [ ] `GET /api/profiles/:id` → trả chi tiết profile vừa tạo
- [ ] `PUT /api/profiles/:id` → sửa tên thành "Bé An Nguyễn"
- [ ] `DELETE /api/profiles/:id` → xóa profile
- [ ] `PUT /api/profiles/:id/time-limits` → set time limits 7 ngày
- [ ] Test validation:
  - [ ] Tạo profile không có tên → error
  - [ ] Lấy profile không tồn tại → 404
  - [ ] Sửa profile của user khác → 403
- [ ] Verify data đúng trên Supabase Dashboard

### Task 3.2: Deploy lên Railway

- [ ] Push tất cả code lên develop
- [ ] Kiểm tra Railway tự deploy hay cần deploy manual
- [ ] Test health check: `GET /api/health`
- [ ] Test auth: `POST /api/auth/register` trên production URL
- [ ] Test profile: `GET /api/profiles` trên production URL
- [ ] Test FCM token: `POST /api/fcm-tokens/register` trên production URL

### Task 3.3: Nhắn bạn Frontend

Khi deploy xong, gửi message cho bạn:

```
API Sprint 2 đã ready! Test tại:
https://kidfun-backend-production.up.railway.app

Endpoints có:
- POST /api/auth/register
- POST /api/auth/login
- POST /api/auth/refresh-token
- POST /api/auth/logout
- POST /api/auth/forgot-password
- GET/POST/PUT/DELETE /api/profiles
- POST /api/fcm-tokens/register

Response format: { success: true/false, data/message }
Auth: gửi header Authorization: Bearer <token>
```

### Commit & Push
```bash
git add -A
git commit -m "chore(backend): verify profile API, deploy sprint 2"
git push origin feature/backend/sprint2-polish
```
→ PR → develop → merge

---

## Ngày 7: Integration Test

- [ ] Test cùng bạn Frontend (nếu bạn đã có Auth screens)
- [ ] Kiểm tra CORS: mobile app gọi API không bị block
- [ ] Kiểm tra Socket.IO: Flutter client kết nối được
- [ ] Fix bất kỳ bug nào phát hiện
- [ ] Đảm bảo Railway stable, không crash

---

## Checklist cuối Sprint 2 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | POST /api/auth/register trả refresh token | ⬜ |
| 2 | POST /api/auth/login trả refresh token | ⬜ |
| 3 | POST /api/auth/refresh-token hoạt động | ⬜ |
| 4 | POST /api/auth/logout hoạt động | ⬜ |
| 5 | Response format chuẩn hóa tất cả API | ⬜ |
| 6 | FCMToken model + migration thành công | ⬜ |
| 7 | POST /api/fcm-tokens/register hoạt động | ⬜ |
| 8 | Firebase push notification gửi được | ⬜ |
| 9 | Profile CRUD verified trên PostgreSQL | ⬜ |
| 10 | Deploy thành công trên Railway | ⬜ |
| 11 | Nhắn Frontend API đã ready | ⬜ |

---

## Ghi chú kỹ thuật

### Refresh Token Implementation
```javascript
// Tạo refresh token (khác secret với access token)
const refreshToken = jwt.sign(
  { userId: user.id },
  process.env.JWT_SECRET + '_refresh', // hoặc dùng secret riêng
  { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
);
```

### Firebase Init (handle cả local + production)
```javascript
// server.js
const { initFirebase } = require('./services/firebaseService');

// Init Firebase (skip nếu không có config — dev mode)
try {
  initFirebase();
  console.log('🔥 Firebase initialized');
} catch (err) {
  console.warn('⚠️ Firebase not configured:', err.message);
}
```

### CORS cho Mobile
```javascript
// server.js — đảm bảo CORS cho mobile
const cors = require('cors');
app.use(cors({
  origin: process.env.SOCKET_CORS_ORIGIN === '*' ? true : process.env.SOCKET_CORS_ORIGIN?.split(','),
  credentials: true
}));
```
