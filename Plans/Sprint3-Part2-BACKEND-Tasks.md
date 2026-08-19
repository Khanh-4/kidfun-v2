# KidFun V3 — Sprint 3 Phần 2: BACKEND (Khanh)

> **Mục tiêu:** Socket.IO hoạt động qua internet (Railway), device online/offline tracking
> **Quan trọng:** Đây là nền tảng cho Sprint 4 (Soft Warning + Xin thêm giờ real-time)
> **Branch gốc:** `develop`

---

## Task 1: Verify Socket.IO hoạt động trên Railway

**Branch:** `feature/backend/socket-io-internet`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/socket-io-internet
```

### 1.1: Kiểm tra Socket.IO config hiện tại

- [ ] Mở `backend/src/services/socketService.js` (hoặc file tương tự chứa Socket.IO)
- [ ] Verify Socket.IO đã được attach vào HTTP server
- [ ] Verify CORS config cho phép tất cả origin (`*`)
- [ ] Kiểm tra server.js dùng `server.listen()` (KHÔNG PHẢI `app.listen()`)

Cấu trúc đúng phải là:
```javascript
const http = require('http');
const app = express();
const server = http.createServer(app);
const { Server } = require('socket.io');
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

// QUAN TRỌNG: phải dùng server.listen, KHÔNG PHẢI app.listen
server.listen(PORT, HOST, () => { ... });
```

- [ ] Nếu đang dùng `app.listen()` → đổi sang `server.listen()`

### 1.2: Tạo file test Socket.IO qua internet

File tạo tạm: `backend/test-socket.js`

```javascript
const { io } = require('socket.io-client');

const socket = io('https://kidfun-backend-production.up.railway.app', {
  transports: ['websocket'],
});

socket.on('connect', () => {
  console.log('✅ Connected! Socket ID:', socket.id);
  socket.emit('joinFamily', { userId: 1 });
  console.log('📡 Joined family room');
});

socket.on('connect_error', (err) => {
  console.log('❌ Connection error:', err.message);
});

socket.on('disconnect', (reason) => {
  console.log('🔌 Disconnected:', reason);
});

setTimeout(() => {
  socket.disconnect();
  process.exit(0);
}, 5000);
```

```bash
cd backend
npm install socket.io-client --save-dev
node test-socket.js
```

- [ ] Thấy "✅ Connected!" → Socket.IO qua internet OK
- [ ] Nếu "❌ Connection error" → cần fix (xem 1.1)
- [ ] Xóa `test-socket.js` sau khi verify

---

## Task 2: Thêm Device Online/Offline

### 2.1: Thêm fields vào Device model

File sửa: `backend/prisma/schema.prisma`

Thêm vào model Device:
```prisma
model Device {
  // ... fields hiện tại ...
  isOnline   Boolean   @default(false)
  lastSeen   DateTime?
}
```

```bash
npx prisma migrate dev --name add-device-online-status
npx prisma generate
```

- [ ] Verify trên Supabase: Device table có cột `isOnline` và `lastSeen`

### 2.2: Mở rộng Socket.IO events

File sửa: `backend/src/services/socketService.js`

Thêm events mới:

```javascript
io.on('connection', (socket) => {
  console.log('🔌 Client connected:', socket.id);

  // === PARENT EVENTS ===
  
  // Parent join family room
  socket.on('joinFamily', ({ userId }) => {
    socket.join(`family_${userId}`);
    socket.userId = userId;
    console.log(`👨‍👩‍👧 Parent ${userId} joined family room`);
  });

  // === CHILD EVENTS ===
  
  // Child join device room
  socket.on('joinDevice', async ({ deviceCode }) => {
    socket.deviceCode = deviceCode;
    socket.join(`device_${deviceCode}`);
    console.log(`📱 Device ${deviceCode} joined`);

    try {
      const device = await prisma.device.findFirst({ 
        where: { deviceCode },
        include: { profile: true }
      });
      
      if (device) {
        // Update status online
        await prisma.device.update({
          where: { id: device.id },
          data: { isOnline: true, lastSeen: new Date() }
        });

        // Notify Parent
        io.to(`family_${device.userId}`).emit('deviceOnline', {
          deviceId: device.id,
          profileId: device.profileId,
          deviceName: device.deviceName,
        });
        
        console.log(`🟢 Device ${device.deviceName} is ONLINE`);
      }
    } catch (err) {
      console.error('joinDevice error:', err);
    }
  });

  // === DISCONNECT ===
  
  socket.on('disconnect', async () => {
    console.log('🔌 Client disconnected:', socket.id);
    
    if (socket.deviceCode) {
      try {
        const device = await prisma.device.findFirst({ 
          where: { deviceCode: socket.deviceCode } 
        });
        
        if (device) {
          await prisma.device.update({
            where: { id: device.id },
            data: { isOnline: false, lastSeen: new Date() }
          });

          io.to(`family_${device.userId}`).emit('deviceOffline', {
            deviceId: device.id,
          });
          
          console.log(`🔴 Device ${device.deviceName} is OFFLINE`);
        }
      } catch (err) {
        console.error('disconnect error:', err);
      }
    }
  });

  // === GIỮ NGUYÊN EVENTS CŨ TỪ V2 ===
  // requestTimeExtension, respondTimeExtension, removeDevice, etc.
});
```

- [ ] Implement `joinDevice` event → update isOnline = true → emit `deviceOnline`
- [ ] Implement disconnect → update isOnline = false → emit `deviceOffline`
- [ ] Giữ nguyên `joinFamily` event (đã có từ V2)
- [ ] Giữ nguyên events cũ (requestTimeExtension, respondTimeExtension...)

### 2.3: Reset all devices offline khi server restart

Thêm vào `server.js` khi server start:

```javascript
// Reset all devices to offline when server starts
prisma.device.updateMany({
  data: { isOnline: false }
}).then(() => {
  console.log('📱 All devices reset to offline');
});
```

- [ ] Implement reset on server start

---

## Task 3: Device Status API

### 3.1: Thêm status endpoint

File sửa: `backend/src/controllers/deviceController.js`

- [ ] Sửa `GET /api/devices` — response thêm `isOnline` và `lastSeen` cho mỗi device
- [ ] Thêm `GET /api/devices/:id/status`:
  - Auth: JWT
  - Response:
```json
{
  "success": true,
  "data": {
    "device": { "id": 1, "deviceName": "...", ... },
    "isOnline": true,
    "lastSeen": "2026-03-14T13:00:00.000Z"
  }
}
```

### 3.2: Thêm route

File sửa: `backend/src/routes/devices.js`

- [ ] Thêm `GET /:id/status` → deviceController.getDeviceStatus

---

## Task 4: Deploy + Test

- [ ] Deploy lên Railway
- [ ] Test Socket.IO từ local (dùng test-socket.js hoặc Postman WebSocket)
- [ ] Verify trên Railway logs:
  - Thấy "🔌 Client connected" khi có client kết nối
  - Thấy "🟢 Device ... is ONLINE" khi Child join
  - Thấy "🔴 Device ... is OFFLINE" khi Child disconnect
- [ ] Test API: `GET /api/devices` trả `isOnline` đúng

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add Socket.IO device online/offline, device status API"
git push origin feature/backend/socket-io-internet
```
→ PR → develop → merge

---

## Task 5: Nhắn bạn Frontend

Khi deploy xong, gửi message:

```
Socket.IO Sprint 3 đã ready! 

Kết nối: wss://kidfun-backend-production.up.railway.app
Transport: websocket

Events:
- Parent sau login: emit 'joinFamily' { userId }
- Child sau link: emit 'joinDevice' { deviceCode }
- Listen 'deviceOnline' { deviceId, profileId, deviceName }
- Listen 'deviceOffline' { deviceId }

API mới:
- GET /api/devices → giờ trả thêm isOnline, lastSeen
- GET /api/devices/:id/status → trạng thái chi tiết
```

---

## Checklist cuối Sprint 3 — Backend

| # | Task | Status |
|---|------|--------|
| 1 | Socket.IO kết nối được từ internet (Railway) | ⬜ |
| 2 | joinFamily event hoạt động | ⬜ |
| 3 | joinDevice event hoạt động | ⬜ |
| 4 | deviceOnline event gửi cho Parent | ⬜ |
| 5 | deviceOffline event gửi cho Parent | ⬜ |
| 6 | Device model có isOnline + lastSeen | ⬜ |
| 7 | Reset all offline khi server restart | ⬜ |
| 8 | GET /api/devices trả isOnline | ⬜ |
| 9 | GET /api/devices/:id/status hoạt động | ⬜ |
| 10 | Deploy Railway thành công | ⬜ |
| 11 | Nhắn Frontend Socket.IO ready | ⬜ |

---

## Ghi chú kỹ thuật

### Railway + WebSocket
Railway hỗ trợ WebSocket native, không cần config đặc biệt. Chỉ cần đảm bảo server dùng `http.createServer()` + `server.listen()`.

### Socket.IO Rooms
```
family_{userId}  → Parent nhận events về tất cả devices của mình
device_{deviceCode} → Gửi events cho 1 device cụ thể
```

### Prisma trong Socket.IO handlers
Import prisma client ở đầu file socketService.js:
```javascript
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
```
Hoặc import từ shared instance nếu đã có.
