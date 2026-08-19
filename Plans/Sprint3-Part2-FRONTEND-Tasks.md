# KidFun V3 — Sprint 3 Phần 2: FRONTEND (Flutter)

> **Mục tiêu:** Socket.IO kết nối qua internet, Device List real-time, Child Dashboard cơ bản
> **API Server:** https://kidfun-backend-production.up.railway.app
> **Branch gốc:** `develop`

---

## Task 1: Socket.IO Client Setup

**Branch:** `feature/mobile/socket-io-client`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/socket-io-client
```

### 1.1: Cài package

```yaml
# pubspec.yaml - thêm
dependencies:
  socket_io_client: ^2.0.3+1
```

```bash
flutter pub get
```

### 1.2: Tạo Socket Service

File tạo mới: `mobile/lib/core/network/socket_service.dart`

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;
  
  // Callbacks
  Function(Map<String, dynamic>)? onDeviceOnlineCallback;
  Function(Map<String, dynamic>)? onDeviceOfflineCallback;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  SocketService._();

  IO.Socket get socket {
    if (_socket == null) {
      _socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.on('connect', (_) {
        print('🟢 Socket connected: ${_socket!.id}');
      });

      _socket!.on('disconnect', (_) {
        print('🔴 Socket disconnected');
      });

      _socket!.on('connect_error', (err) {
        print('❌ Socket error: $err');
      });

      // Device events
      _socket!.on('deviceOnline', (data) {
        print('📱 Device online: $data');
        onDeviceOnlineCallback?.call(Map<String, dynamic>.from(data));
      });

      _socket!.on('deviceOffline', (data) {
        print('📱 Device offline: $data');
        onDeviceOfflineCallback?.call(Map<String, dynamic>.from(data));
      });

      // Events cho Sprint 4 (placeholder)
      _socket!.on('timeLimitUpdated', (data) {
        print('⏰ Time limit updated: $data');
      });

      _socket!.on('timeExtensionResponse', (data) {
        print('⏳ Time extension response: $data');
      });
    }
    return _socket!;
  }

  /// Parent: join family room sau khi login
  void joinFamily(int userId) {
    socket.connect();
    socket.emit('joinFamily', {'userId': userId});
    print('👨‍👩‍👧 Joined family room for user $userId');
  }

  /// Child: join device room sau khi link
  void joinDevice(String deviceCode) {
    socket.connect();
    socket.emit('joinDevice', {'deviceCode': deviceCode});
    print('📱 Joined device room: $deviceCode');
  }

  /// Kiểm tra kết nối
  bool get isConnected => _socket?.connected ?? false;

  /// Disconnect (khi logout)
  void disconnect() {
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    print('🔌 Socket disconnected and destroyed');
  }
}
```

### 1.3: Kết nối Socket sau Login

File sửa: `mobile/lib/features/auth/providers/auth_provider.dart`

Sau khi login/register thành công:

```dart
// Trong login() hoặc register(), sau khi lưu token:
final user = UserModel.fromJson(data['user']);
SocketService.instance.joinFamily(user.id);
```

Khi logout:

```dart
// Trong logout():
SocketService.instance.disconnect();
```

- [ ] Thêm joinFamily sau login thành công
- [ ] Thêm disconnect khi logout
- [ ] Test: login → thấy "🟢 Socket connected" trong logs

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add Socket.IO client service with device events"
git push origin feature/mobile/socket-io-client
```
→ PR → develop → Khanh review → merge

---

## Task 2: Parent App — Device List Screen

**Branch:** `feature/mobile/device-list`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/device-list
```

### 2.1: Device Model

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
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      deviceCode: json['deviceCode'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen']) 
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  /// Copy with — dùng để cập nhật online/offline mà không gọi API lại
  DeviceModel copyWith({bool? isOnline, DateTime? lastSeen}) {
    return DeviceModel(
      id: id,
      userId: userId,
      profileId: profileId,
      deviceName: deviceName,
      deviceCode: deviceCode,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
```

### 2.2: Device Repository

File tạo mới: `mobile/lib/features/device/data/device_repository.dart`

```dart
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/device_model.dart';

class DeviceRepository {
  final _dio = DioClient.instance;

  Future<List<DeviceModel>> getDevices() async {
    final response = await _dio.get('/api/devices');
    final data = response.data['data'];
    final devices = data['devices'] as List;
    return devices.map((d) => DeviceModel.fromJson(d)).toList();
  }

  Future<DeviceModel> createDevice(String name, {int? profileId}) async {
    final response = await _dio.post('/api/devices', data: {
      'deviceName': name,
      if (profileId != null) 'profileId': profileId,
    });
    return DeviceModel.fromJson(response.data['data']['device']);
  }

  Future<DeviceModel> assignProfile(int deviceId, int profileId) async {
    final response = await _dio.put('/api/devices/$deviceId', data: {
      'profileId': profileId,
    });
    return DeviceModel.fromJson(response.data['data']['device']);
  }

  Future<void> deleteDevice(int id) async {
    await _dio.delete('/api/devices/$id');
  }
}
```

- [ ] Implement tất cả methods
- [ ] Handle errors (try-catch)

### 2.3: Device Provider (Riverpod)

File tạo mới: `mobile/lib/features/device/providers/device_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_repository.dart';
import '../../../shared/models/device_model.dart';
import '../../../core/network/socket_service.dart';

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier();
});

// States
sealed class DeviceState {}
class DeviceLoading extends DeviceState {}
class DeviceLoaded extends DeviceState {
  final List<DeviceModel> devices;
  DeviceLoaded(this.devices);
}
class DeviceError extends DeviceState {
  final String message;
  DeviceError(this.message);
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final _repo = DeviceRepository();

  DeviceNotifier() : super(DeviceLoading()) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    SocketService.instance.onDeviceOnlineCallback = (data) {
      _updateDeviceStatus(data['deviceId'] as int, true);
    };

    SocketService.instance.onDeviceOfflineCallback = (data) {
      _updateDeviceStatus(data['deviceId'] as int, false);
    };
  }

  void _updateDeviceStatus(int deviceId, bool isOnline) {
    if (state is DeviceLoaded) {
      final devices = (state as DeviceLoaded).devices;
      final updated = devices.map((d) {
        if (d.id == deviceId) {
          return d.copyWith(isOnline: isOnline, lastSeen: DateTime.now());
        }
        return d;
      }).toList();
      state = DeviceLoaded(updated);
    }
  }

  Future<void> fetchDevices() async {
    state = DeviceLoading();
    try {
      final devices = await _repo.getDevices();
      state = DeviceLoaded(devices);
    } catch (e) {
      state = DeviceError(e.toString());
    }
  }

  Future<void> createDevice(String name, {int? profileId}) async {
    await _repo.createDevice(name, profileId: profileId);
    await fetchDevices(); // Refresh list
  }

  Future<void> assignProfile(int deviceId, int profileId) async {
    await _repo.assignProfile(deviceId, profileId);
    await fetchDevices();
  }

  Future<void> deleteDevice(int id) async {
    await _repo.deleteDevice(id);
    await fetchDevices();
  }
}
```

- [ ] Implement provider với real-time updates từ Socket.IO
- [ ] `_updateDeviceStatus` cập nhật UI ngay khi nhận event, không cần gọi API

### 2.4: Device List Screen

File tạo mới: `mobile/lib/features/device/screens/device_list_screen.dart`

- [ ] AppBar: "Thiết bị" + nút "+" (thêm device)
- [ ] ListView hiển thị devices dạng Card:
  ```
  ┌─────────────────────────────────┐
  │ 🟢 Điện thoại Bé An            │
  │    Profile: Bé An               │
  │    Online                       │
  ├─────────────────────────────────┤
  │ 🔴 Tablet Bé Bình              │
  │    Profile: Chưa gán            │
  │    Last seen: 5 phút trước      │
  └─────────────────────────────────┘
  ```
- [ ] Icon xanh 🟢 khi online, đỏ 🔴 khi offline
- [ ] **Cập nhật real-time** — không cần refresh, tự đổi icon khi nhận Socket.IO event
- [ ] Nhấn card → bottom sheet: Gán profile / Xóa thiết bị
- [ ] Nhấn "+" → tạo device mới → hiện QR code
- [ ] Pull to refresh
- [ ] Empty state: "Chưa có thiết bị nào"

### 2.5: Gán Device cho Profile

- [ ] Bottom sheet khi nhấn device card
- [ ] Dropdown chọn profile (lấy từ profile list đã có)
- [ ] Gọi API `PUT /api/devices/:id` với `{ profileId }`
- [ ] Cập nhật UI ngay

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add device list screen with real-time online/offline status"
git push origin feature/mobile/device-list
```
→ PR → develop

---

## Task 3: Child App — Dashboard Cơ Bản

**Branch:** `feature/mobile/child-dashboard`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/child-dashboard
```

### 3.1: Role Selection

Khi mở app lần đầu (chưa login, chưa link device):
- [ ] Màn hình chọn vai trò: "Tôi là Phụ huynh" / "Tôi là Trẻ em"
- [ ] Phụ huynh → Login screen (flow hiện tại)
- [ ] Trẻ em → Scan QR screen (link device)

### 3.2: Child Dashboard Screen

File tạo mới: `mobile/lib/features/device/screens/child_dashboard_screen.dart`

- [ ] Giao diện thân thiện, nhiều màu sắc, font lớn (cho trẻ 6-15 tuổi)
- [ ] Hiển thị:
  - Tên trẻ (profile name) + avatar
  - Thời gian còn lại: **"2:30:00"** (placeholder lớn ở giữa, Sprint 4 mới có countdown thật)
  - Trạng thái kết nối: 🟢 "Đã kết nối" / 🔴 "Mất kết nối"
- [ ] Nút "Xin thêm giờ" (placeholder, Sprint 4 mới hoạt động)
- [ ] Không có nút logout/back (trẻ không tự thoát được)

### 3.3: Kết nối Socket.IO cho Child

- [ ] Sau khi link device thành công → lưu `deviceCode` vào SecureStorage
- [ ] Mở app lại → đọc `deviceCode` → tự động `SocketService.instance.joinDevice(deviceCode)`
- [ ] Hiển thị trạng thái kết nối dựa trên `SocketService.instance.isConnected`
- [ ] Reconnect tự động khi mất kết nối

### 3.4: Navigation Update

Cập nhật GoRouter:
```dart
// Routes mới:
// /role-selection   → chọn Phụ huynh / Trẻ em
// /child/scan       → scan QR (đã có)
// /child/dashboard  → child dashboard

// Logic:
// App mở → check SecureStorage
//   → Có JWT token → Parent flow (home)
//   → Có deviceCode → Child flow (child/dashboard)
//   → Không có gì → Role selection
```

- [ ] Thêm routes mới
- [ ] Auto-detect role khi mở app

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add child dashboard, role selection, socket auto-connect"
git push origin feature/mobile/child-dashboard
```
→ PR → develop

---

## Checklist cuối Sprint 3 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | `socket_io_client` cài + kết nối được Railway | ⬜ |
| 2 | SocketService singleton hoạt động | ⬜ |
| 3 | Parent: joinFamily sau login | ⬜ |
| 4 | Parent: disconnect khi logout | ⬜ |
| 5 | Parent: Device List screen | ⬜ |
| 6 | Parent: Device online/offline hiện real-time (🟢/🔴) | ⬜ |
| 7 | Parent: Gán device cho profile | ⬜ |
| 8 | Child: Role selection screen | ⬜ |
| 9 | Child: Dashboard cơ bản | ⬜ |
| 10 | Child: joinDevice sau link / khi mở app | ⬜ |
| 11 | Child: Reconnect tự động | ⬜ |
| 12 | Tất cả code pushed lên develop | ⬜ |

---

## Integration Test (cả 2 người cùng test)

Cần 2 điện thoại Android (hoặc 1 thật + 1 emulator):

1. [ ] **Parent** login → thấy "🟢 Socket connected" trong logs
2. [ ] **Parent** tạo device → hiện QR code
3. [ ] **Child** scan QR → link thành công → vào Child Dashboard
4. [ ] **Parent** Device List → thấy device 🟢 Online
5. [ ] **Child** tắt app → **Parent** thấy device 🔴 Offline
6. [ ] **Child** mở lại app → **Parent** thấy 🟢 Online lại
7. [ ] **Parent** gán device cho profile → hiển thị đúng

---

## Tài liệu tham khảo

- socket_io_client: https://pub.dev/packages/socket_io_client
- Socket.IO events từ Backend:
  - Emit: `joinFamily { userId }`, `joinDevice { deviceCode }`
  - Listen: `deviceOnline { deviceId, profileId, deviceName }`, `deviceOffline { deviceId }`
- API: `GET /api/devices` giờ trả thêm `isOnline`, `lastSeen`
