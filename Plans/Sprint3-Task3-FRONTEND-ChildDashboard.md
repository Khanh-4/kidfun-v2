# KidFun V3 — Sprint 3 Task 3: Child App Dashboard — FRONTEND (Flutter)

> **Mục tiêu:** Xây dựng Role Selection, Child Dashboard, và auto-detect role khi mở app
> **Quan trọng:** Hoàn thành task này để Sprint 3 DONE 100%, sẵn sàng cho Sprint 4
> **API Server:** https://kidfun-backend-production.up.railway.app
> **Branch gốc:** `develop`

---

## Tổng quan

Hiện tại app chỉ có flow Parent (login → dashboard). Cần thêm:

1. **Role Selection** — Khi mở app lần đầu, user chọn "Phụ huynh" hoặc "Trẻ em"
2. **Child Dashboard** — Giao diện cho trẻ sau khi link device
3. **Auto-detect role** — Mở lại app → tự nhận biết Parent hay Child → vào đúng flow

```
App mở → kiểm tra storage
  ├── Có JWT token      → Parent flow (Home/Dashboard)
  ├── Có device_code    → Child flow (Child Dashboard)
  └── Không có gì       → Role Selection screen
```

---

## Task 1: Role Selection Screen

**Branch:** `feature/mobile/role-selection`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/role-selection
```

### 1.1: Tạo screen

File tạo mới: `mobile/lib/features/auth/screens/role_selection_screen.dart`

Thiết kế giao diện:

```
┌─────────────────────────────┐
│                             │
│        🏠 KidFun            │
│                             │
│   Bạn muốn sử dụng app     │
│   với vai trò nào?          │
│                             │
│  ┌─────────────────────┐    │
│  │  👨‍👩‍👧  Phụ huynh       │    │
│  │  Quản lý thiết bị   │    │
│  │  của con             │    │
│  └─────────────────────┘    │
│                             │
│  ┌─────────────────────────┐│
│  │  👶  Trẻ em             ││
│  │  Kết nối với thiết bị   ││
│  │  của phụ huynh          ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

Yêu cầu:
- [ ] 2 nút lớn, dễ nhấn (Card hoặc ElevatedButton lớn)
- [ ] Icon/illustration cho mỗi vai trò
- [ ] Màu sắc thân thiện, vui tươi (app cho gia đình)
- [ ] Nhấn "Phụ huynh" → navigate sang `/login`
- [ ] Nhấn "Trẻ em" → navigate sang `/child/scan` (scan QR / nhập mã)
- [ ] Không có nút back (đây là screen đầu tiên)

### 1.2: Code tham khảo

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Title
              const Icon(Icons.family_restroom, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'KidFun',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn muốn sử dụng app với vai trò nào?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Nút Phụ huynh
              _RoleCard(
                icon: Icons.admin_panel_settings,
                title: 'Phụ huynh',
                subtitle: 'Quản lý thiết bị của con',
                color: Colors.blue,
                onTap: () => context.go('/login'),
              ),
              const SizedBox(height: 20),

              // Nút Trẻ em
              _RoleCard(
                icon: Icons.child_care,
                title: 'Trẻ em',
                subtitle: 'Kết nối với thiết bị của phụ huynh',
                color: Colors.orange,
                onTap: () => context.go('/child/scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add role selection screen (parent/child)"
git push origin feature/mobile/role-selection
```
→ PR → develop → Khanh review → merge

---

## Task 2: Child Dashboard Screen

**Branch:** `feature/mobile/child-dashboard`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/child-dashboard
```

### 2.1: Tạo screen

File tạo mới: `mobile/lib/features/device/screens/child_dashboard_screen.dart`

Thiết kế giao diện (thân thiện cho trẻ 6-15 tuổi):

```
┌─────────────────────────────┐
│                             │
│   👋 Xin chào, Bé An!      │
│                             │
│   ┌─────────────────────┐   │
│   │                     │   │
│   │     ⏰ 2:30:00      │   │
│   │   Thời gian còn lại │   │
│   │    (placeholder)     │   │
│   │                     │   │
│   └─────────────────────┘   │
│                             │
│   🟢 Đã kết nối             │
│                             │
│   ┌─────────────────────┐   │
│   │  ⏰ Xin thêm giờ    │   │
│   │    (placeholder)     │   │
│   └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

Yêu cầu:
- [ ] Hiển thị tên trẻ (profile name) — lấy từ SecureStorage hoặc device info đã lưu khi link
- [ ] Thời gian còn lại: hiện **"2:30:00"** placeholder lớn ở giữa (Sprint 4 mới có countdown thật)
- [ ] Trạng thái kết nối: 🟢 "Đã kết nối" / 🔴 "Mất kết nối" — dựa trên `SocketService.instance.isConnected`
- [ ] Nút "Xin thêm giờ" — placeholder, nhấn chỉ hiện SnackBar "Tính năng sẽ có trong bản cập nhật tiếp theo" (Sprint 4 mới hoạt động)
- [ ] Font lớn, nhiều màu sắc, icons vui tươi (app cho trẻ em)
- [ ] **KHÔNG có nút logout/back** — trẻ không tự thoát được
- [ ] Kết nối Socket.IO tự động: đọc `device_code` từ SecureStorage → gọi `SocketService.instance.joinDevice(deviceCode)`

### 2.2: Code tham khảo

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/secure_storage.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen> {
  String _profileName = 'Bé';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initChild();
  }

  Future<void> _initChild() async {
    // Lấy thông tin đã lưu
    final deviceCode = await SecureStorage.read(key: 'device_code');
    final profileName = await SecureStorage.read(key: 'profile_name');

    if (profileName != null) {
      setState(() => _profileName = profileName);
    }

    // Kết nối Socket.IO
    if (deviceCode != null) {
      SocketService.instance.joinDevice(deviceCode);
    }

    // Listen connection status
    SocketService.instance.socket.on('connect', (_) {
      if (mounted) setState(() => _isConnected = true);
    });
    SocketService.instance.socket.on('disconnect', (_) {
      if (mounted) setState(() => _isConnected = false);
    });

    setState(() => _isConnected = SocketService.instance.isConnected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // Light blue background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Greeting
              Text(
                'Xin chào, $_profileName! 👋',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Time remaining (placeholder)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.timer, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      '2:30:00',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Thời gian còn lại',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Connection status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected ? 'Đã kết nối' : 'Mất kết nối',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Request time button (placeholder)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng sẽ có trong bản cập nhật tiếp theo'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_alarm, size: 24),
                  label: const Text(
                    'Xin thêm giờ',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2.3: Lưu profile name khi link device

File sửa: `mobile/lib/features/device/data/device_repository.dart`

Khi Child link device thành công, backend trả về thông tin profile. Lưu lại:

```dart
Future<void> linkDevice(String deviceCode) async {
  final response = await _dio.post('/api/devices/link', data: {
    'deviceCode': deviceCode,
  });

  if (response.data['success'] == true) {
    // Lưu device_code
    await SecureStorage.write(key: 'device_code', value: deviceCode);

    // Lưu profile name nếu có
    final device = response.data['data']?['device'];
    final profile = device?['profile'];
    if (profile != null && profile['profileName'] != null) {
      await SecureStorage.write(key: 'profile_name', value: profile['profileName']);
    }

    // Kết nối Socket.IO
    SocketService.instance.joinDevice(deviceCode);
  }
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add child dashboard screen with connection status"
git push origin feature/mobile/child-dashboard
```
→ PR → develop → Khanh review → merge

---

## Task 3: Auto-detect Role + Navigation Update

**Branch:** `feature/mobile/auto-detect-role`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/auto-detect-role
```

### 3.1: Cập nhật GoRouter

File sửa: `mobile/lib/app.dart` (hoặc file chứa GoRouter config)

Thêm routes mới:

```dart
// Routes cần có:
// /role-selection   → RoleSelectionScreen (chọn Phụ huynh / Trẻ em)
// /login            → LoginScreen
// /register         → RegisterScreen
// /forgot-password  → ForgotPasswordScreen
// /home             → ParentDashboard (sau login)
// /profiles         → ProfileListScreen
// /devices          → DeviceListScreen
// /child/scan       → ScanQRScreen (Child nhập mã / quét QR)
// /child/dashboard  → ChildDashboardScreen
```

```dart
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    // ... Auth routes ...
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // ... Parent routes ...
    GoRoute(
      path: '/home',
      builder: (context, state) => const ParentDashboardScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DeviceListScreen(),
    ),
    // ... Child routes ...
    GoRoute(
      path: '/child/scan',
      builder: (context, state) => const ScanQRScreen(),
    ),
    GoRoute(
      path: '/child/dashboard',
      builder: (context, state) => const ChildDashboardScreen(),
    ),
  ],
);
```

### 3.2: Cập nhật Splash Screen — auto-detect role

File sửa: `mobile/lib/features/auth/screens/splash_screen.dart` (hoặc nơi check auth khi mở app)

```dart
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _detectRole();
  }

  Future<void> _detectRole() async {
    // Đợi 1 chút cho splash hiển thị
    await Future.delayed(const Duration(seconds: 1));

    final token = await SecureStorage.getToken();
    final deviceCode = await SecureStorage.read(key: 'device_code');

    if (!mounted) return;

    if (token != null) {
      // ★ CÓ JWT TOKEN → Parent flow
      // Verify token còn hợp lệ không
      try {
        // Gọi API verify hoặc refresh token
        // Nếu thành công → vào Home
        context.go('/home');
      } catch (e) {
        // Token hết hạn / invalid → clear và về login
        await SecureStorage.clearAll();
        context.go('/login');
      }
    } else if (deviceCode != null) {
      // ★ CÓ DEVICE CODE → Child flow
      // Tự động kết nối Socket.IO
      SocketService.instance.joinDevice(deviceCode);
      context.go('/child/dashboard');
    } else {
      // ★ KHÔNG CÓ GÌ → Lần đầu mở app
      context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 80, color: Colors.blue),
            SizedBox(height: 16),
            Text('KidFun', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

### 3.3: Cập nhật flow sau link device thành công

Khi Child nhập mã / quét QR thành công → navigate sang Child Dashboard (không phải quay lại Role Selection):

```dart
// Trong ScanQRScreen hoặc InputCodeScreen, sau khi link thành công:
await deviceRepository.linkDevice(deviceCode);
if (mounted) {
  context.go('/child/dashboard'); // ← Navigate sang Child Dashboard
}
```

### 3.4: Cập nhật flow sau login thành công

Đảm bảo sau login, Parent joinFamily rồi vào Home:

```dart
// Trong AuthProvider hoặc LoginScreen, sau khi login thành công:
SocketService.instance.joinFamily(user.id);
context.go('/home');
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add auto-detect role, update navigation for parent/child flows"
git push origin feature/mobile/auto-detect-role
```
→ PR → develop → Khanh review → merge

---

## Integration Test

Test trên 2 thiết bị Android (hoặc 1 thật + 1 emulator):

### Flow Parent:

1. [ ] Cài app lần đầu → thấy Role Selection
2. [ ] Chọn "Phụ huynh" → vào Login
3. [ ] Login thành công → vào Home
4. [ ] Tắt app → mở lại → tự động vào Home (auto-login, skip Role Selection)
5. [ ] Logout → về Login (hoặc Role Selection)

### Flow Child:

6. [ ] Cài app lần đầu → thấy Role Selection
7. [ ] Chọn "Trẻ em" → vào Scan QR / Nhập mã
8. [ ] Nhập mã thành công → vào Child Dashboard
9. [ ] Child Dashboard hiện: tên trẻ, thời gian placeholder, 🟢 Đã kết nối
10. [ ] Tắt app → mở lại → tự động vào Child Dashboard (auto-detect deviceCode)
11. [ ] Parent thấy device 🟢 Online khi Child mở app

### Edge cases:

12. [ ] Clear app data → mở app → thấy Role Selection (reset về ban đầu)
13. [ ] Child mất mạng → hiện 🔴 Mất kết nối → có mạng lại → 🟢 Đã kết nối

---

## Checklist cuối Sprint 3 Task 3

| # | Task | Status |
|---|------|--------|
| 1 | Role Selection screen tạo xong | ⬜ |
| 2 | Nhấn "Phụ huynh" → Login | ⬜ |
| 3 | Nhấn "Trẻ em" → Scan QR / Nhập mã | ⬜ |
| 4 | Child Dashboard screen tạo xong | ⬜ |
| 5 | Child Dashboard hiện tên trẻ | ⬜ |
| 6 | Child Dashboard hiện thời gian placeholder | ⬜ |
| 7 | Child Dashboard hiện trạng thái kết nối | ⬜ |
| 8 | Nút "Xin thêm giờ" placeholder | ⬜ |
| 9 | Child Dashboard KHÔNG có nút logout/back | ⬜ |
| 10 | Auto-detect: có JWT → Parent Home | ⬜ |
| 11 | Auto-detect: có device_code → Child Dashboard | ⬜ |
| 12 | Auto-detect: không có gì → Role Selection | ⬜ |
| 13 | GoRouter routes cập nhật đầy đủ | ⬜ |
| 14 | Lưu profile_name khi link device | ⬜ |
| 15 | Socket.IO auto-connect cho Child khi mở lại app | ⬜ |
| 16 | Tất cả code pushed lên develop | ⬜ |

---

## Ghi chú

- **Backend không cần thay đổi gì** cho task này — tất cả đều ở frontend
- Child Dashboard chỉ là placeholder cho Sprint 4 — thời gian countdown, xin thêm giờ sẽ implement ở Sprint 4
- Nếu dùng Cursor: paste file này vào Chat → bảo "Implement Task 1 trước" → Cursor sẽ hiểu context
- **Thứ tự làm khuyến nghị:** Task 1 (Role Selection) → Task 3 (Navigation/Auto-detect) → Task 2 (Child Dashboard) — vì navigation cần có trước khi test Child Dashboard
