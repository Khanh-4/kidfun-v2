# KidFun V3 — Sprint 10: Polish, Testing & Bảo vệ — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** Fix bugs UI/UX, polish, test trên nhiều thiết bị, build APK signed, chuẩn bị demo bảo vệ
> **Branch gốc:** `develop`
> **Deadline:** 24/05/2026
> **KHÔNG thêm tính năng mới** — chỉ fix + polish + test

---

## Tổng quan Sprint 10 — Frontend Tasks

| Task | Nội dung | Ưu tiên |
|------|----------|---------|
| **Task 1** | Fix bugs từ logs + testing | 🔴 CRITICAL |
| **Task 2** | UI/UX polish | 🟠 HIGH |
| **Task 3** | Handle device not linked gracefully | 🟠 HIGH |
| **Task 4** | Test trên nhiều thiết bị | 🟡 MEDIUM |
| **Task 5** | Build APK release (signed) | 🔴 CRITICAL |
| **Task 6** | Chuẩn bị demo bảo vệ | 🔴 CRITICAL |

---

## Task 1: Fix Bugs

> **Branch:** `fix/mobile/sprint10-bugfix`

### 1.1: Handle Socket disconnect gracefully

**Vấn đề:** Parent app bị disconnect Socket.IO liên tục (13 lần trong 1 session).

**Fix:** Tăng reconnect delay + hiện indicator nhỏ thay vì spam reconnect:

```dart
// socket_service.dart
socket = io(baseUrl, OptionBuilder()
  .setTransports(['websocket'])
  .enableReconnection()
  .setReconnectionDelay(5000)      // 5s thay vì 1s
  .setReconnectionDelayMax(30000)  // Max 30s
  .setReconnectionAttempts(50)     // Giới hạn attempts
  .build()
);

// UI indicator nhỏ
socket.onDisconnect((_) {
  setState(() => _isConnected = false);
});
socket.onConnect((_) {
  setState(() => _isConnected = true);
});
```

Hiện dot nhỏ trên AppBar:

```dart
AppBar(
  title: Text('KidFun'),
  actions: [
    if (!_isConnected)
      Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(Icons.cloud_off, color: Colors.orange, size: 18),
      ),
  ],
)
```

### 1.2: Heartbeat interval tăng lên

**Vấn đề:** Heartbeat 30s + response 5-6s = quá tải.

**Fix:** Tăng interval từ 30s → 60s:

```dart
Timer.periodic(const Duration(seconds: 60), (_) => _sendHeartbeat());
```

### 1.3: Fix countdown accuracy khi heartbeat chậm

Nếu heartbeat response chậm (5s), countdown có thể bị jump:

```dart
// Dùng local timer cho countdown, chỉ sync với server khi nhận heartbeat
void _onHeartbeatResponse(int serverRemaining) {
  final localRemaining = _remainingSeconds;
  final diff = (serverRemaining - localRemaining).abs();
  
  // Chỉ sync nếu lệch > 10 giây (tránh jump)
  if (diff > 10) {
    setState(() => _remainingSeconds = serverRemaining);
  }
}
```

### Commit:

```bash
git checkout develop && git pull origin develop
git checkout -b fix/mobile/sprint10-bugfix
git commit -m "fix(mobile): socket reconnect delay, heartbeat interval, countdown sync"
git push origin fix/mobile/sprint10-bugfix
```
→ PR → develop → merge

---

## Task 2: UI/UX Polish

> **Branch:** `chore/mobile/ui-polish`

### 2.1: Loading states kiểm tra toàn bộ

| Screen | Loading | Empty State | Error |
|--------|---------|-------------|-------|
| Login | ⬜ Spinner | ⬜ Error message | ⬜ SnackBar |
| Home / Dashboard | ⬜ Skeleton | ⬜ "Chưa có profile" | ⬜ Retry |
| Profile Detail | ⬜ Spinner | ⬜ N/A | ⬜ SnackBar |
| Time Settings | ⬜ Save indicator | ⬜ N/A | ⬜ Toast |
| Child Dashboard | ⬜ Countdown loading | ⬜ "Đang kết nối..." | ⬜ Offline mode |
| App Blocking | ⬜ Spinner | ⬜ "Chưa có app" | ⬜ Retry |
| Usage Reports | ⬜ Skeleton | ⬜ "Chưa có dữ liệu" | ⬜ Retry |
| Map / Location | ⬜ Map loading | ⬜ "Chưa có vị trí" | ⬜ Location error |
| Geofences | ⬜ Spinner | ⬜ "Chưa có vùng" | ⬜ SnackBar |
| YouTube Dashboard | ⬜ Skeleton | ⬜ "Chưa có video" | ⬜ Retry |
| Reports Daily/Weekly | ⬜ Skeleton | ⬜ "Không có data" | ⬜ Retry |
| Activity History | ⬜ Spinner | ⬜ "Không có hoạt động" | ⬜ Pull refresh |
| AI Alerts | ⬜ Spinner | ⬜ "Không có cảnh báo" | ⬜ Retry |
| SOS History | ⬜ Spinner | ⬜ "Không có SOS" | ⬜ N/A |
| Web Filtering | ⬜ Spinner | ⬜ Categories loaded | ⬜ SnackBar |
| School Mode | ⬜ Save indicator | ⬜ N/A | ⬜ Toast |
| Per-app Limits | ⬜ Spinner | ⬜ "Chưa đặt giới hạn" | ⬜ SnackBar |

### 2.2: Consistency check

- [ ] Font: nhất quán toàn app (14-16sp body, 18-20sp title)
- [ ] Colors: primary blue, success green, error red, warning orange
- [ ] Padding/margin: 16px standard
- [ ] AppBar title format nhất quán
- [ ] Button style nhất quán (ElevatedButton primary, TextButton secondary)
- [ ] Bottom navigation icons + labels đúng
- [ ] Splash screen / logo KidFun

### 2.3: Animation nhẹ (nếu có thời gian)

```dart
// Page transitions
MaterialPageRoute → CupertinoPageRoute (iOS-style slide)

// List item animation
AnimatedList thay ListView (items fade in)

// Countdown number change
AnimatedSwitcher cho số countdown
```

### Commit:

```bash
git commit -m "chore(mobile): UI polish — loading states, consistency, animations"
```

---

## Task 3: Handle Device Not Linked

> **Branch:** `fix/mobile/device-not-linked`

### 3.1: Listen deviceError event từ Socket

```dart
SocketService.instance.socket.on('deviceError', (data) {
  if (data['code'] == 'DEVICE_NOT_FOUND') {
    showDialog(
      context: NavigatorService.navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Thiết bị chưa liên kết'),
        content: const Text('Thiết bị này chưa được liên kết với tài khoản phụ huynh. Vui lòng quét mã QR từ ứng dụng phụ huynh.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(_);
              // Navigate to QR scan screen
            },
            child: const Text('Liên kết ngay'),
          ),
        ],
      ),
    );
  }
});
```

### 3.2: Child API 404 graceful handling

```dart
// Trong mọi child API call:
try {
  final response = await dio.get('/api/child/today-limit', ...);
} on DioException catch (e) {
  if (e.response?.statusCode == 404) {
    // Device chưa link → hiện dialog hướng dẫn
    _showDeviceNotLinkedDialog();
    return; // Không retry
  }
  // Các lỗi khác → retry
}
```

### 3.3: Stop polling khi device not linked

```dart
bool _isDeviceLinked = true;

void _onDeviceNotFound() {
  _isDeviceLinked = false;
  // Stop tất cả timers
  _heartbeatTimer?.cancel();
  _policyTimer?.cancel();
  _youtubeUploadTimer?.cancel();
  _locationTimer?.cancel();
}
```

### Commit:

```bash
git commit -m "fix(mobile): handle device not linked gracefully, stop polling on 404"
```

---

## Task 4: Test Trên Nhiều Thiết Bị

### 4.1: Test matrix

| Thiết bị | Android | Màn hình | Test | ✅ |
|----------|---------|----------|------|---|
| Thiết bị chính (Child) | Android 10+ | Normal | Full test | ⬜ |
| Thiết bị phụ (Parent) | Android 9+ | Normal | Full test | ⬜ |
| Emulator Pixel 5 | API 30 | 1080x2340 | UI check | ⬜ |
| Emulator Pixel 3a | API 29 | 1080x2220 | UI check | ⬜ |
| Emulator nhỏ (nếu có) | API 28 | 720x1280 | Responsive | ⬜ |

### 4.2: Responsive test

- [ ] Text không bị cắt / overflow trên màn nhỏ
- [ ] Charts render đúng trên mọi kích thước
- [ ] Dialog không bị tràn
- [ ] Keyboard không che input fields
- [ ] Landscape orientation xử lý đúng (hoặc lock portrait)

### 4.3: Permission test

| Permission | Cách xin | Deny → behavior | ✅ |
|-----------|---------|-----------------|---|
| Usage Stats | Settings redirect | Hiện hướng dẫn bật lại | ⬜ |
| Accessibility | Settings redirect | Hiện warning | ⬜ |
| Location (foreground) | Runtime dialog | Features disabled gracefully | ⬜ |
| Location (background) | Separate dialog | GPS foreground only | ⬜ |
| Record Audio | Runtime dialog | SOS không ghi âm, vẫn gửi vị trí | ⬜ |
| Notification | Runtime dialog (Android 13+) | App vẫn chạy, không push | ⬜ |
| Device Admin | System dialog | Lock screen disabled | ⬜ |

---

## Task 5: Build APK Release (Signed)

> **Branch:** `release/v1.0`

### 5.1: Tạo keystore (nếu chưa có)

```bash
keytool -genkey -v -keystore kidfun-release.keystore \
  -alias kidfun -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass kidfun2026 -keypass kidfun2026 \
  -dname "CN=KidFun, OU=HUTECH, O=Nhom60, L=HCM, S=HCM, C=VN"
```

### 5.2: Config signing

File tạo: `mobile/android/key.properties`

```properties
storePassword=kidfun2026
keyPassword=kidfun2026
keyAlias=kidfun
storeFile=../../kidfun-release.keystore
```

File sửa: `mobile/android/app/build.gradle.kts` — thêm signing config

### 5.3: Build

```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

### 5.4: Verify APK

- [ ] File: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Size < 50MB
- [ ] Cài được trên thiết bị Android 8+ (API 26+)
- [ ] Không crash khi mở
- [ ] Tất cả tính năng hoạt động trên release build
- [ ] Proguard/R8 không strip critical classes

### 5.5: Backup APK

Lưu APK vào Google Drive / USB — phòng trường hợp laptop hỏng.

### Commit:

```bash
git commit -m "release(mobile): v1.0 signed APK build"
```

---

## Task 6: Chuẩn Bị Demo Bảo vệ

### 6.1: Thiết bị demo

- [ ] Thiết bị Parent: sạc đầy, WiFi ổn, đã cài APK release
- [ ] Thiết bị Child: sạc đầy, WiFi ổn, đã cấp đủ permissions, đã cài APK release
- [ ] Cáp backup (nếu cần cast màn hình lên projector)
- [ ] Hotspot điện thoại phòng WiFi trường không ổn

### 6.2: Tài khoản demo

```
📧 Email: demo@kidfun.app
🔑 Password: demo123
👶 Profile: Bé An
⏰ Time limits: 7 ngày đã set
📊 Usage data: 7 ngày mẫu
📺 YouTube logs: có sẵn với AI analysis
🌐 Web Filter: Người lớn + Cờ bạc đã bật
📚 School Mode: T2-T6 07:00-11:30
```

### 6.3: Kịch bản demo (7-10 phút)

| # | Bước | Thời gian | Ai thao tác |
|---|------|-----------|-------------|
| 1 | Giới thiệu app + đăng nhập Parent | 30s | Khanh |
| 2 | Xem báo cáo tuần (Reports) → biểu đồ đẹp | 45s | Khanh |
| 3 | Xem Activity History timeline | 30s | Khanh |
| 4 | Đặt giới hạn 3 phút → liên kết Child | 30s | Khanh + Bạn |
| 5 | Child countdown → cảnh báo mềm → xin thêm giờ | 60s | Bạn |
| 6 | Parent duyệt xin giờ | 15s | Khanh |
| 7 | Parent chặn YouTube → Child bị kick | 30s | Cả 2 |
| 8 | Bật School Mode → Child chỉ dùng Zoom | 30s | Cả 2 |
| 9 | Xem GPS trên bản đồ Mapbox | 20s | Khanh |
| 10 | Child bấm SOS → Parent nhận alert + nghe âm | 45s | Cả 2 |
| 11 | Xem YouTube Dashboard + AI alerts | 45s | Khanh |
| 12 | Web Filtering: chặn domain → Chrome blocked | 30s | Cả 2 |
| **Total** | | **~7 phút** | |

### 6.4: Plan B (nếu lỗi lúc demo)

| Tình huống | Giải pháp |
|------------|-----------|
| WiFi không ổn | Bật hotspot từ điện thoại |
| Backend down | Restart Railway (< 30s) |
| Socket disconnect | Giải thích REST fallback cho hội đồng |
| APK crash | Demo trên debug build |
| Push notification không đến | Show Railway logs thay thế |
| AI analysis chưa có | Chỉ sang seed data có sẵn results |
| Thiết bị thật lỗi | Chuyển sang emulator (đã setup sẵn) |

### 6.5: Câu hỏi hội đồng có thể hỏi + trả lời gợi ý

| Câu hỏi | Trả lời |
|---------|---------|
| Sao không dùng VPN filter? | AccessibilityService đơn giản hơn, đủ cho phần lớn browsers. VPN tốn pin, conflict với VPN khác. |
| Privacy? Có spy con quá mức không? | Chỉ log metadata (title, channel), không log transcript/comments. Parent có thể tắt YouTube Monitoring. |
| AI có chính xác không? | Groq Llama 4 Scout + vision analysis. Có thể false positive → Parent manual unblock. Fallback OpenRouter nếu Groq fail. |
| Sao heartbeat chậm? | Supabase free tier latency. Đã implement in-memory cache giảm từ 5s → <1s. |
| Trẻ có thể bypass không? | Force close → ForegroundService restart. Tắt Accessibility → app hiện hướng dẫn bật lại. Uninstall → cần Device Admin. |
| Tại sao chọn tech stack này? | Node.js phổ biến, Prisma type-safe ORM, Flutter cross-platform (tương lai iOS), Socket.IO real-time mượt. |

---

## ✅ Checklist Tổng hợp Sprint 10 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | Fix Socket reconnect delay (5s, max 30s) | ⬜ |
| 2 | Fix heartbeat interval 30s → 60s | ⬜ |
| 3 | Fix countdown sync (chỉ update khi lệch > 10s) | ⬜ |
| 4 | Connection indicator trên AppBar | ⬜ |
| 5 | Handle deviceError (device not linked) dialog | ⬜ |
| 6 | Stop polling khi device not linked | ⬜ |
| 7 | Child API 404 graceful handling | ⬜ |
| 8 | Loading states tất cả screens | ⬜ |
| 9 | Empty states tất cả screens | ⬜ |
| 10 | Error handling + retry tất cả screens | ⬜ |
| 11 | UI consistency (font, color, padding, buttons) | ⬜ |
| 12 | Test trên thiết bị chính | ⬜ |
| 13 | Test trên emulator | ⬜ |
| 14 | Responsive check (nhỏ/lớn) | ⬜ |
| 15 | Permission deny handling | ⬜ |
| 16 | Keystore tạo | ⬜ |
| 17 | APK release build thành công | ⬜ |
| 18 | APK cài + chạy trên 2 thiết bị | ⬜ |
| 19 | Thiết bị demo sẵn sàng (sạc đầy, WiFi, permissions) | ⬜ |
| 20 | Kịch bản demo rehearsal 2-3 lần | ⬜ |
| 21 | Plan B sẵn sàng | ⬜ |
| 22 | Chuẩn bị trả lời câu hỏi hội đồng | ⬜ |

---

## 🔀 Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b fix/mobile/<tên>      # Bugfix
git checkout -b chore/mobile/<tên>    # Polish
git checkout -b release/<tên>         # Release build
git commit -m "fix/chore/release(mobile): mô tả"
git push origin <branch>
# → PR → develop → merge
```
