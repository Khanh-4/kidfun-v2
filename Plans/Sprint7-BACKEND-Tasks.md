# KidFun V3 — Sprint 7: GPS, Geofencing & SOS — BACKEND (Khanh)

> **Sprint Goal:** Tính năng vị trí & an toàn — GPS tracking real-time, geofencing, nút SOS với ghi âm
> **Branch gốc:** `develop`
> **Server:** https://kidfun-backend-production.up.railway.app
> **Scope:** GPS linh hoạt (30s foreground / 5min background), Geofence cảnh báo + lịch sử, SOS vị trí + ghi âm + gọi lại

---

## Tổng quan Sprint 7 — Backend Tasks

| Task | Nội dung | Phụ thuộc |
|------|----------|-----------|
| **Task 1** | Database models (Location, Geofence, SOS) | Không |
| **Task 2** | Location API (POST + GET current/history) | Task 1 |
| **Task 3** | Geofence CRUD API | Task 1 |
| **Task 4** | Geofence processing (ENTER/EXIT detection) | Task 1, 2 |
| **Task 5** | SOS Alert API + Audio Upload | Task 1 |
| **Task 6** | Socket.IO events (location, geofence, SOS) | Task 2–5 |
| **Task 7** | Push notification cho SOS + Geofence | Task 4, 5 |
| **Task 8** | Deploy + Integration test | Task 1–7 |

---

## Task 1: Database Models

> **Branch:** `feature/backend/location-models`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/location-models
```

### 1.1: Prisma schema

File sửa: `backend/prisma/schema.prisma`

```prisma
model LocationLog {
  id          Int      @id @default(autoincrement())
  profileId   Int
  deviceId    Int
  latitude    Float
  longitude   Float
  accuracy    Float?   // Độ chính xác GPS (mét)
  address     String?  // Optional, reverse geocode sau
  source      String   @default("GPS") // GPS, NETWORK, FUSED
  createdAt   DateTime @default(now())

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device      Device   @relation(fields: [deviceId], references: [id], onDelete: Cascade)

  @@index([profileId, createdAt])
}

model Geofence {
  id          Int      @id @default(autoincrement())
  profileId   Int
  name        String   // "Nhà", "Trường học", "Công viên"
  latitude    Float
  longitude   Float
  radius      Int      // Bán kính (mét)
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)
  events      GeofenceEvent[]
}

model GeofenceEvent {
  id          Int      @id @default(autoincrement())
  geofenceId  Int
  profileId   Int
  type        String   // "ENTER" | "EXIT"
  latitude    Float
  longitude   Float
  createdAt   DateTime @default(now())

  geofence    Geofence @relation(fields: [geofenceId], references: [id], onDelete: Cascade)
  profile     Profile  @relation(fields: [profileId], references: [id], onDelete: Cascade)

  @@index([profileId, createdAt])
}

model SOSAlert {
  id          Int       @id @default(autoincrement())
  profileId   Int
  deviceId    Int
  latitude    Float
  longitude   Float
  address     String?
  audioUrl    String?   // URL file ghi âm (Supabase Storage hoặc local)
  message     String?   // Optional message từ Child
  status      String    @default("ACTIVE") // ACTIVE | ACKNOWLEDGED | RESOLVED
  acknowledgedAt DateTime?
  resolvedAt  DateTime?
  createdAt   DateTime  @default(now())

  profile     Profile   @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device      Device    @relation(fields: [deviceId], references: [id], onDelete: Cascade)

  @@index([profileId, createdAt])
}
```

### 1.2: Thêm relations vào Profile và Device

```prisma
model Profile {
  // ... existing fields ...
  locationLogs    LocationLog[]
  geofences       Geofence[]
  geofenceEvents  GeofenceEvent[]
  sosAlerts       SOSAlert[]
}

model Device {
  // ... existing fields ...
  locationLogs    LocationLog[]
  sosAlerts       SOSAlert[]
}
```

### 1.3: Migration

```bash
npx prisma migrate dev --name add-location-geofence-sos
npx prisma generate
```

### Commit:

```bash
git add -A
git commit -m "feat(backend): add Location, Geofence, SOS models"
git push origin feature/backend/location-models
```
→ PR → develop → merge

---

## Task 2: Location API

> **Branch:** `feature/backend/location-api`

### 2.1: Location Controller

File tạo mới: `backend/src/controllers/locationController.js`

**POST /api/child/location** — Child gửi GPS

```javascript
exports.postLocation = async (req, res) => {
  try {
    const { deviceCode, latitude, longitude, accuracy, source } = req.body;

    if (!deviceCode || typeof latitude !== 'number' || typeof longitude !== 'number') {
      return sendError(res, 'Invalid location data', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    const log = await prisma.locationLog.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        latitude,
        longitude,
        accuracy: accuracy || null,
        source: source || 'GPS',
      },
    });

    // Notify Parent qua Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.to(`family_${device.profile.userId}`).emit('locationUpdated', {
        profileId: device.profile.id,
        latitude,
        longitude,
        accuracy,
        timestamp: log.createdAt,
      });
    }

    // Kiểm tra geofence events (Task 4)
    await checkGeofenceEvents(device.profile.id, latitude, longitude, io);

    return sendSuccess(res, { id: log.id }, 201);
  } catch (err) {
    console.error('❌ [postLocation] Error:', err.message);
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/location/current** — Parent lấy vị trí hiện tại

```javascript
exports.getCurrentLocation = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const latest = await prisma.locationLog.findFirst({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
    });

    if (!latest) {
      return sendError(res, 'No location data yet', 404);
    }

    return sendSuccess(res, { location: latest });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/location/history?date=YYYY-MM-DD** — Lịch sử

```javascript
exports.getLocationHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const startOfDay = new Date(dateStr);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const history = await prisma.locationLog.findMany({
      where: {
        profileId,
        createdAt: { gte: startOfDay, lt: endOfDay },
      },
      orderBy: { createdAt: 'asc' },
    });

    return sendSuccess(res, { date: dateStr, count: history.length, history });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 2.2: Routes

```javascript
// routes/child.js
router.post('/location', locationController.postLocation);

// routes/profiles.js
router.get('/:id/location/current', authMiddleware, locationController.getCurrentLocation);
router.get('/:id/location/history', authMiddleware, locationController.getLocationHistory);
```

### 2.3: Test

```bash
curl -X POST "https://kidfun-backend-production.up.railway.app/api/child/location" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceCode": "BE4B.251210.005",
    "latitude": 10.762622,
    "longitude": 106.660172,
    "accuracy": 10.5
  }'
```

### Commit:

```bash
git commit -m "feat(backend): add location tracking API"
```

---

## Task 3: Geofence CRUD API

> **Branch:** `feature/backend/geofence-crud`

### 3.1: Geofence Controller

File tạo mới: `backend/src/controllers/geofenceController.js`

**GET /api/profiles/:id/geofences** — List

```javascript
exports.getGeofences = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const geofences = await prisma.geofence.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, { geofences });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**POST /api/profiles/:id/geofences** — Tạo mới

```javascript
exports.createGeofence = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { name, latitude, longitude, radius } = req.body;

    if (!name || typeof latitude !== 'number' || typeof longitude !== 'number' || !radius) {
      return sendError(res, 'Missing required fields', 400);
    }

    if (radius < 50 || radius > 5000) {
      return sendError(res, 'Radius must be between 50 and 5000 meters', 400);
    }

    const geofence = await prisma.geofence.create({
      data: { profileId, name, latitude, longitude, radius, isActive: true },
    });

    return sendSuccess(res, { geofence }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**PUT /api/geofences/:id** — Cập nhật

```javascript
exports.updateGeofence = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const { name, latitude, longitude, radius, isActive } = req.body;

    const geofence = await prisma.geofence.update({
      where: { id },
      data: {
        name: name ?? undefined,
        latitude: latitude ?? undefined,
        longitude: longitude ?? undefined,
        radius: radius ?? undefined,
        isActive: isActive ?? undefined,
      },
    });

    return sendSuccess(res, { geofence });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**DELETE /api/geofences/:id** — Xóa

```javascript
exports.deleteGeofence = async (req, res) => {
  try {
    await prisma.geofence.delete({ where: { id: parseInt(req.params.id) } });
    return sendSuccess(res, { message: 'Geofence deleted' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/geofences/events?date=YYYY-MM-DD** — Lịch sử ENTER/EXIT

```javascript
exports.getGeofenceEvents = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const startOfDay = new Date(dateStr);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const events = await prisma.geofenceEvent.findMany({
      where: {
        profileId,
        createdAt: { gte: startOfDay, lt: endOfDay },
      },
      include: { geofence: true },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, { events });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 3.2: Routes

```javascript
router.get('/:id/geofences', authMiddleware, geofenceController.getGeofences);
router.post('/:id/geofences', authMiddleware, geofenceController.createGeofence);
router.get('/:id/geofences/events', authMiddleware, geofenceController.getGeofenceEvents);
// Đặt trong router riêng cho geofences:
router.put('/geofences/:id', authMiddleware, geofenceController.updateGeofence);
router.delete('/geofences/:id', authMiddleware, geofenceController.deleteGeofence);
```

### Commit:

```bash
git commit -m "feat(backend): add geofence CRUD and events query"
```

---

## Task 4: Geofence Processing (ENTER/EXIT Detection)

> **Branch:** `feature/backend/geofence-processing`

### 4.1: Haversine distance helper

File tạo mới: `backend/src/utils/geoUtils.js`

```javascript
// Tính khoảng cách 2 điểm GPS (mét)
exports.haversineDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371000; // Earth radius in meters
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};
```

### 4.2: Geofence state cache

Backend cần nhớ trạng thái in/out của mỗi profile với mỗi geofence để phát hiện ENTER/EXIT.

```javascript
// backend/src/services/geofenceService.js
const { haversineDistance } = require('../utils/geoUtils');

// In-memory cache: { "profileId_geofenceId": true/false (isInside) }
const geofenceState = new Map();

exports.checkGeofenceEvents = async (profileId, lat, lng, io) => {
  const geofences = await prisma.geofence.findMany({
    where: { profileId, isActive: true },
  });

  for (const fence of geofences) {
    const distance = haversineDistance(lat, lng, fence.latitude, fence.longitude);
    const isInside = distance <= fence.radius;
    const cacheKey = `${profileId}_${fence.id}`;
    const wasInside = geofenceState.get(cacheKey);

    // First check hoặc không thay đổi → skip
    if (wasInside === undefined) {
      geofenceState.set(cacheKey, isInside);
      continue;
    }
    if (wasInside === isInside) continue;

    // State thay đổi → tạo event
    const eventType = isInside ? 'ENTER' : 'EXIT';
    geofenceState.set(cacheKey, isInside);

    const event = await prisma.geofenceEvent.create({
      data: {
        geofenceId: fence.id,
        profileId,
        type: eventType,
        latitude: lat,
        longitude: lng,
      },
    });

    // Emit Socket.IO + push notification
    const profile = await prisma.profile.findUnique({
      where: { id: profileId },
      include: { user: true },
    });

    if (io) {
      io.to(`family_${profile.userId}`).emit('geofenceEvent', {
        eventId: event.id,
        type: eventType,
        geofenceName: fence.name,
        profileName: profile.profileName,
        latitude: lat,
        longitude: lng,
        timestamp: event.createdAt,
      });
    }

    // Push notification (Task 7)
    await sendGeofencePushNotification(profile, fence, eventType);
  }
};
```

### 4.3: Import vào locationController

```javascript
// locationController.js
const { checkGeofenceEvents } = require('../services/geofenceService');

// Trong postLocation, sau khi lưu log:
await checkGeofenceEvents(device.profile.id, latitude, longitude, io);
```

### Commit:

```bash
git commit -m "feat(backend): add geofence ENTER/EXIT detection logic"
```

---

## Task 5: SOS Alert API + Audio Upload

> **Branch:** `feature/backend/sos-alert`

### 5.1: Thêm multer cho file upload

```bash
npm install multer
```

### 5.2: Cấu hình upload

File tạo mới: `backend/src/middlewares/uploadMiddleware.js`

```javascript
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '../../uploads/sos-audio');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.m4a';
    cb(null, `sos_${Date.now()}${ext}`);
  },
});

exports.uploadAudio = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/m4a', 'audio/x-m4a', 'audio/wav'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Invalid audio format'));
  },
});
```

### 5.3: Serve static file audio

File sửa: `backend/src/server.js`

```javascript
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
```

### 5.4: SOS Controller

File tạo mới: `backend/src/controllers/sosController.js`

**POST /api/child/sos** — Gửi SOS (multipart/form-data)

```javascript
exports.createSOS = async (req, res) => {
  try {
    const { deviceCode, latitude, longitude, message } = req.body;

    if (!deviceCode || !latitude || !longitude) {
      return sendError(res, 'Missing required fields', 400);
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: { include: { user: true } } },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    // Audio file từ multer
    const audioUrl = req.file ? `/uploads/sos-audio/${req.file.filename}` : null;

    const sos = await prisma.sOSAlert.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        audioUrl,
        message: message || null,
        status: 'ACTIVE',
      },
    });

    // Emit Socket.IO ngay lập tức
    const io = req.app.get('io');
    if (io) {
      io.to(`family_${device.profile.userId}`).emit('sosAlert', {
        sosId: sos.id,
        profileId: device.profile.id,
        profileName: device.profile.profileName,
        latitude: sos.latitude,
        longitude: sos.longitude,
        audioUrl: sos.audioUrl ? `${req.protocol}://${req.get('host')}${sos.audioUrl}` : null,
        message: sos.message,
        timestamp: sos.createdAt,
      });
    }

    // Push notification CRITICAL
    await sendSOSPushNotification(device.profile.user, device.profile, sos);

    return sendSuccess(res, { sos }, 201);
  } catch (err) {
    console.error('❌ [SOS] Error:', err.message);
    return sendError(res, err.message, 500);
  }
};
```

**GET /api/profiles/:id/sos** — Lịch sử SOS

```javascript
exports.getSOSHistory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const alerts = await prisma.sOSAlert.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return sendSuccess(res, { alerts });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**PUT /api/sos/:id/acknowledge** — Parent xác nhận đã nhận

```javascript
exports.acknowledgeSOS = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const sos = await prisma.sOSAlert.update({
      where: { id },
      data: { status: 'ACKNOWLEDGED', acknowledgedAt: new Date() },
    });
    return sendSuccess(res, { sos });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

**PUT /api/sos/:id/resolve** — Parent đánh dấu đã giải quyết

```javascript
exports.resolveSOS = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const sos = await prisma.sOSAlert.update({
      where: { id },
      data: { status: 'RESOLVED', resolvedAt: new Date() },
    });
    return sendSuccess(res, { sos });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
```

### 5.5: Routes

```javascript
// routes/child.js
const { uploadAudio } = require('../middlewares/uploadMiddleware');
router.post('/sos', uploadAudio.single('audio'), sosController.createSOS);

// routes/profiles.js
router.get('/:id/sos', authMiddleware, sosController.getSOSHistory);

// routes/sos.js (hoặc gộp)
router.put('/sos/:id/acknowledge', authMiddleware, sosController.acknowledgeSOS);
router.put('/sos/:id/resolve', authMiddleware, sosController.resolveSOS);
```

### Commit:

```bash
git commit -m "feat(backend): add SOS alert API with audio upload"
```

---

## Task 6: Socket.IO Events

> Gộp vào các task trên, không cần branch riêng

### Events emit:

| Event | Payload | Room | Khi nào |
|-------|---------|------|---------|
| `locationUpdated` | `{profileId, latitude, longitude, accuracy, timestamp}` | `family_{userId}` | Child gửi location mới |
| `geofenceEvent` | `{eventId, type, geofenceName, profileName, lat, lng, timestamp}` | `family_{userId}` | Detect ENTER/EXIT |
| `sosAlert` | `{sosId, profileId, profileName, lat, lng, audioUrl, message, timestamp}` | `family_{userId}` | Child bấm SOS |
| `sosAcknowledged` | `{sosId}` | `device_{deviceCode}` | Parent xác nhận |

### Verify:

```javascript
// Trong socketService.js hoặc server.js, kiểm tra handlers không cần thêm mới
// Chỉ cần emit đúng room
```

---

## Task 7: Push Notifications

> **Branch:** `feature/backend/location-push-notifications`

### 7.1: Helper functions

File sửa: `backend/src/services/fcmService.js`

```javascript
exports.sendGeofencePushNotification = async (profile, geofence, eventType) => {
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: { userId: profile.userId },
    });

    if (tokens.length === 0) return;

    const title = eventType === 'ENTER' 
      ? `${profile.profileName} đã vào ${geofence.name}`
      : `${profile.profileName} đã rời ${geofence.name}`;
    
    const body = eventType === 'ENTER'
      ? `Con đã đến ${geofence.name} an toàn`
      : `Con vừa rời khỏi ${geofence.name}`;

    await admin.messaging().sendEachForMulticast({
      tokens: tokens.map(t => t.token),
      notification: { title, body },
      data: {
        type: 'GEOFENCE_EVENT',
        eventType,
        profileId: String(profile.id),
        geofenceId: String(geofence.id),
      },
      android: { priority: 'high' },
    });
  } catch (err) {
    console.error('❌ [FCM Geofence] Error:', err.message);
  }
};

exports.sendSOSPushNotification = async (user, profile, sos) => {
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: { userId: user.id },
    });

    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens: tokens.map(t => t.token),
      notification: {
        title: `🆘 SOS KHẨN CẤP từ ${profile.profileName}`,
        body: 'Con đang cần giúp đỡ! Nhấn để xem vị trí.',
      },
      data: {
        type: 'SOS_ALERT',
        sosId: String(sos.id),
        profileId: String(profile.id),
        latitude: String(sos.latitude),
        longitude: String(sos.longitude),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'sos_critical',
          sound: 'default',
          priority: 'max',
        },
      },
    });
  } catch (err) {
    console.error('❌ [FCM SOS] Error:', err.message);
  }
};
```

### Commit:

```bash
git commit -m "feat(backend): add push notifications for geofence and SOS"
```

---

## Task 8: Deploy + Integration Test

### 8.1: Deploy Railway

- [ ] Merge tất cả branches vào develop
- [ ] Railway auto-deploy
- [ ] Verify server logs không có error

### 8.2: Test bằng curl

```bash
# 1. POST location
curl -X POST "https://kidfun-backend-production.up.railway.app/api/child/location" \
  -H "Content-Type: application/json" \
  -d '{"deviceCode":"BE4B.251210.005","latitude":10.762622,"longitude":106.660172,"accuracy":10}'

# 2. Tạo geofence
curl -X POST "https://kidfun-backend-production.up.railway.app/api/profiles/13/geofences" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"Nhà","latitude":10.762622,"longitude":106.660172,"radius":200}'

# 3. POST location trong geofence → kiểm tra ENTER event
# 4. POST location ngoài geofence → kiểm tra EXIT event

# 5. Test SOS với audio
curl -X POST "https://kidfun-backend-production.up.railway.app/api/child/sos" \
  -F "deviceCode=BE4B.251210.005" \
  -F "latitude=10.762622" \
  -F "longitude=106.660172" \
  -F "audio=@test.m4a"
```

### 8.3: Nhắn Frontend

```
Sprint 7 Backend ready!

API mới:
📍 LOCATION:
- POST /api/child/location { deviceCode, latitude, longitude, accuracy }
- GET /api/profiles/:id/location/current
- GET /api/profiles/:id/location/history?date=YYYY-MM-DD

🏠 GEOFENCE:
- GET /api/profiles/:id/geofences
- POST /api/profiles/:id/geofences { name, latitude, longitude, radius }
- PUT /api/geofences/:id { name, latitude, longitude, radius, isActive }
- DELETE /api/geofences/:id
- GET /api/profiles/:id/geofences/events?date=YYYY-MM-DD

🆘 SOS:
- POST /api/child/sos (multipart: deviceCode, latitude, longitude, message, audio file)
- GET /api/profiles/:id/sos
- PUT /api/sos/:id/acknowledge
- PUT /api/sos/:id/resolve

🔌 Socket.IO events (Parent lắng nghe):
- locationUpdated
- geofenceEvent  
- sosAlert
```

---

## Checklist cuối Sprint 7 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | LocationLog, Geofence, GeofenceEvent, SOSAlert models | ⬜ |
| 2 | Prisma migration thành công | ⬜ |
| 3 | POST /api/child/location | ⬜ |
| 4 | GET location current + history | ⬜ |
| 5 | Geofence CRUD API | ⬜ |
| 6 | Geofence ENTER/EXIT detection + haversine | ⬜ |
| 7 | Geofence event storage + query | ⬜ |
| 8 | SOS API với multer audio upload | ⬜ |
| 9 | Static serve /uploads/sos-audio | ⬜ |
| 10 | Socket.IO: locationUpdated, geofenceEvent, sosAlert | ⬜ |
| 11 | Push notification: geofence + SOS | ⬜ |
| 12 | Test tất cả API bằng curl | ⬜ |
| 13 | Deploy Railway | ⬜ |

---

## Lưu ý quan trọng

- **Geofence state cache** in-memory sẽ mất khi restart server. Chấp nhận cho đồ án, production nên dùng Redis.
- **SOS audio** lưu local trên Railway → ephemeral storage, sẽ mất khi redeploy. Cho đồ án OK, nếu cần persistent thì dùng Supabase Storage.
- **Haversine formula** chính xác cho radius nhỏ (< 10km), OK cho geofence gia đình.
- **Location accuracy** — GPS trong nhà kém, radius geofence nên >= 100m để tránh false positive.
