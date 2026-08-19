# KidFun V3 — Sprint 3 Phần 2: Socket.IO Real-time & Device Status

> **Mục tiêu:** Socket.IO hoạt động qua internet (Railway), Parent biết Child online/offline, Child có dashboard cơ bản
> **Quan trọng:** Đây là nền tảng cho Sprint 4 (Soft Warning + Xin thêm giờ real-time)

---

## BACKEND (Khanh)

### Task 1: Verify Socket.IO hoạt động trên Railway

**Branch:** `feature/backend/socket-io-internet`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/backend/socket-io-internet
```

#### 1.1: Kiểm tra Socket.IO config hiện tại

- [ ] Mở `backend/src/services/socketService.js` (hoặc file tương tự)
- [ ] Verify Socket.IO đã được attach vào HTTP server
- [ ] Verify CORS config cho phép tất cả origin (`*`)
- [ ] Kiểm tra Socket.IO có listen đúng events từ V2 không:
  - `joinFamily`
  - `requestTimeExtension`
  - `respondTimeExtension`
  - `removeDevice`

#### 1.2: Test Socket.IO trên Railway

Test nhanh bằng cách tạo file test:

```javascript
// test-socket.js (chạy local, kết nối tới Railway)
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

// Đợi 5 giây rồi disconnect
setTimeout(() => {
  socket.disconnect();
  process.exit(0);
}, 5000);
```

```bash
cd backend
node test-socket.js
```

- [ ] Nếu thấy "✅ Connected!" → Socket.IO hoạt động qua internet
- [ ] Nếu lỗi → cần debug (xem task 1.3)
- [ ] Xóa file test sau khi verify

#### 1.3: Fix Socket.IO nếu cần

Nếu không kết nối được, kiểm tra:

- [ ] Railway có hỗ trợ WebSocket không (có — Railway hỗ trợ native)
- [ ] Server có attach Socket.IO đúng không:

```javascript
// server.js — phải có dạng như này:
const http = require('http');
const app = require('./app'); // hoặc express()
const server = http.createServer(app);
const { Server } = require('socket.io');
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

// QUAN TRỌNG: phải dùng server.listen, KHÔNG PHẢI app.listen
server.listen(PORT, HOST, () => { ... });
```

- [ ] Nếu đang dùng `app.listen()` → đổi sang `server.listen()`

---

### Task 2: Thêm Device Online/Offline Events

#### 2.1: Mở rộng Socket.IO events

File sửa: `backend/src/services/socketService.js`

```javascript
// Khi Child connect
socket.on('joinDevice', async ({ deviceCode }) => {
  // Lưu socket.id + deviceCode mapping
  socket.deviceCode = deviceCode;
  socket.join(`device_${deviceCode}`);
  
  // Tìm device → lấy userId (owner)
  const device = await prisma.device.findFirst({ where: { deviceCode } });
  if (device) {
    // Update lastSeen
    await prisma.device.update({
      where: { id: device.id },
      data: { lastSeen: new Date(), isOnline: true }
    });
    
    // Notify Parent
    io.to(`family_${device.userId}`).emit('deviceOnline', {
      deviceId: device.id,
      profileId: device.profileId,
      deviceName: device.deviceName,
    });
  }
});

// Khi Child disconnect
socket.on('disconnect', async () => {
  if (socket.deviceCode) {
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
    }
  }
});
```

- [ ] Implement `joinDevice` event
- [ ] Implement disconnect → `deviceOffline`
- [ ] Cập nhật `joinFamily` event (Parent join room `family_{userId}`)

#### 2.2: Thêm fields vào Device model

File sửa: `backend/prisma/schema.prisma`

Thêm vào model Device:
```prisma
model Device {
  // ... fields hiện tại ...
  isOnline   Boolean   @default(false)
  lastSeen   DateTime?
}
```

- [ ] Chạy migration: `npx prisma migrate dev --name add-device-online-status`
- [ ] Verify trên Supabase

#### 2.3: Device Status API

File sửa: `backend/src/controllers/deviceController.js`

- [ ] Thêm endpoint `GET /api/devices/:id/status`
  - Auth: JWT
  - Response: `{ device, isOnline, lastSeen }`

- [ ] Sửa endpoint `GET /api/devices` — thêm `isOnline` và `lastSeen` vào response

---

### Task 3: Deploy + Test

- [ ] Deploy lên Railway
- [ ] Test Socket.IO từ local (dùng test-socket.js)
- [ ] Test device online/offline flow
- [ ] Xóa file test-socket.js

### Commit & Push

```bash
git add -A
git commit -m "feat(backend): add Socket.IO device online/offline, device status API"
git push origin feature/backend/socket-io-internet
```
→ PR → develop → merge

---

## FRONTEND (Bạn)

### Task 1: Socket.IO Client Setup

**Branch:** `feature/mobile/socket-io-client`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/socket-io-client
```

#### 1.1: Cài package

```yaml
# pubspec.yaml - thêm
dependencies:
  socket_io_client: ^2.0.3+1
```

```bash
flutter pub get
```

#### 1.2: Tạo Socket Service

File tạo mới: `mobile/lib/core/network/socket_service.dart`

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  IO.Socket get socket {
    _socket ??= IO.io(ApiConstants.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    return _socket!;
  }

  // Parent: join family room
  void joinFamily(int userId) {
    socket.connect();
    socket.emit('joinFamily', {'userId': userId});
  }

  // Child: join device room
  void joinDevice(String deviceCode) {
    socket.connect();
    socket.emit('joinDevice', {'deviceCode': deviceCode});
  }

  // Listen device online
  void onDeviceOnline(Function(Map<String, dynamic>) callback) {
    socket.on('deviceOnline', (data) => callback(Map<String, dynamic>.from(data)));
  }

  // Listen device offline
  void onDeviceOffline(Function(Map<String, dynamic>) callback) {
    socket.on('deviceOffline', (data) => callback(Map<String, dynamic>.from(data)));
  }

  // Disconnect
  void disconnect() {
    _socket?.disconnect();
  }

  // Check connected
  bool get isConnected => _socket?.connected ?? false;
}
```

#### 1.3: Test kết nối Socket.IO

- [ ] Sau khi login thành công → gọi `SocketService.instance.joinFamily(userId)`
- [ ] Thêm log để verify: `socket.on('connect', (_) => print('Socket connected!'))`
- [ ] Test trên Android thật → thấy "Socket connected!" trong logs

---

### Task 2: Parent App — Device List Screen

**Branch:** `feature/mobile/device-list`

#### 2.1: Device Model

File tạo mới: `mobile/lib/shared/models/device_model.dart`

```dart
class DeviceModel {
  final int id;
  final int userId;
  final int? profileId;
  final String deviceName;
  final String deviceCode;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.userId,
    this.profileId,
    required this.deviceName,
    required this.deviceCode,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      profileId: json['profileId'] as int?,
      deviceName: json['deviceName'] as String,
      deviceCode: json['deviceCode'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
```

#### 2.2: Device Repository

File tạo mới: `mobile/lib/features/device/data/device_repository.dart`

- [ ] `getDevices()` → GET /api/devices
- [ ] `createDevice(name, profileId?)` → POST /api/devices
- [ ] `assignProfile(deviceId, profileId)` → PUT /api/devices/:id
- [ ] `deleteDevice(id)` → DELETE /api/devices/:id
- [ ] `getDeviceStatus(id)` → GET /api/devices/:id/status

#### 2.3: Device List Screen

File tạo mới: `mobile/lib/features/device/screens/device_list_screen.dart`

- [ ] AppBar: "Thiết bị" + nút "+"
- [ ] ListView hiển thị devices dạng Card:
  - Tên thiết bị
  - Trạng thái: 🟢 Online / 🔴 Offline (cập nhật real-time qua Socket.IO)
  - Profile được gán (nếu có)
  - Last seen (nếu offline)
- [ ] Nhấn "+" → tạo device mới → hiện QR code
- [ ] Nhấn device → xem chi tiết / gán profile / xóa
- [ ] Pull to refresh

#### 2.4: Real-time status update

- [ ] Listen `deviceOnline` event → cập nhật icon xanh
- [ ] Listen `deviceOffline` event → cập nhật icon đỏ
- [ ] Không cần refresh thủ công, tự cập nhật

---

### Task 3: Child App — Dashboard Cơ Bản

**Branch:** `feature/mobile/child-dashboard`

#### 3.1: Child Dashboard Screen

File tạo mới: `mobile/lib/features/device/screens/child_dashboard_screen.dart`

- [ ] Hiển thị tên trẻ (profile name)
- [ ] Hiển thị thời gian còn lại (placeholder, Sprint 4 mới có countdown thật)
- [ ] Trạng thái kết nối: "Đã kết nối" / "Mất kết nối"
- [ ] Nút "Xin thêm giờ" (placeholder, Sprint 4 mới hoạt động)
- [ ] Giao diện thân thiện, nhiều màu sắc (app cho trẻ em)

#### 3.2: Kết nối Socket.IO cho Child

- [ ] Sau khi link device thành công → tự động `SocketService.instance.joinDevice(deviceCode)`
- [ ] Hiển thị trạng thái kết nối real-time
- [ ] Reconnect tự động khi mất kết nối

---

### Task 4: Gán thiết bị cho profile

**Branch:** `feature/mobile/assign-device-profile`

#### 4.1: Assign Profile UI

- [ ] Trong Device List, mỗi device card có dropdown/button chọn profile
- [ ] Gọi `PUT /api/devices/:id` với `{ profileId }` khi chọn
- [ ] Cập nhật UI ngay sau khi gán

---

## Checklist cuối Sprint 3

### Backend (Khanh)
| # | Task | Status |
|---|------|--------|
| 1 | Socket.IO kết nối được từ internet (Railway) | ⬜ |
| 2 | joinFamily event hoạt động | ⬜ |
| 3 | joinDevice event hoạt động | ⬜ |
| 4 | deviceOnline event gửi cho Parent | ⬜ |
| 5 | deviceOffline event gửi cho Parent | ⬜ |
| 6 | Device model có isOnline + lastSeen | ⬜ |
| 7 | GET /api/devices trả isOnline | ⬜ |
| 8 | GET /api/devices/:id/status hoạt động | ⬜ |
| 9 | Deploy Railway thành công | ⬜ |

### Frontend (Bạn)
| # | Task | Status |
|---|------|--------|
| 1 | socket_io_client cài + kết nối được Railway | ⬜ |
| 2 | SocketService singleton hoạt động | ⬜ |
| 3 | Parent: joinFamily sau login | ⬜ |
| 4 | Parent: Device List screen | ⬜ |
| 5 | Parent: Device online/offline real-time | ⬜ |
| 6 | Parent: Gán device cho profile | ⬜ |
| 7 | Child: Dashboard cơ bản | ⬜ |
| 8 | Child: joinDevice sau link | ⬜ |
| 9 | Child: Reconnect tự động | ⬜ |

### Integration Test
- [ ] Parent login → Socket connected
- [ ] Child link device → Parent thấy device online 🟢
- [ ] Child tắt app → Parent thấy device offline 🔴
- [ ] Child mở lại → Parent thấy online lại 🟢
- [ ] Gán device cho profile → cập nhật đúng
