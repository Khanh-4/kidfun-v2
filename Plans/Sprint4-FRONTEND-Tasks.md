# KidFun V3 — Sprint 4: Time Management & Soft Warning — FRONTEND (Flutter)

> **Sprint Goal:** Tính năng cốt lõi — giới hạn thời gian, cảnh báo mềm, xin thêm giờ
> **Đây là 2 USP chính của KidFun** ★
> **API Server:** https://kidfun-backend-production.up.railway.app
> **Branch gốc:** `develop`

---

## Tổng quan Sprint 4 — Frontend Tasks

| Task | Nội dung | Phụ thuộc (Backend) |
|------|----------|---------------------|
| **Task 1** | Parent: Time Settings screen | Backend Task 1 (Time Limit API) |
| **Task 2** | Child: Countdown timer + Session management | Backend Task 2 (Session API) |
| **Task 3** | Child: Soft Warning system ★ | Backend Task 4 (Warning API) |
| **Task 4** | Child: Xin thêm giờ UI ★ | Backend Task 5 (Extension API) |
| **Task 5** | Parent: Nhận + duyệt xin thêm giờ | Backend Task 5 |
| **Task 6** | Integration test | Backend Task 6 |

> **Lưu ý:** Mỗi task frontend phụ thuộc backend tương ứng. Nếu backend chưa deploy → dùng mock data trước, đổi sang API thật sau.

---

## Task 1: Parent App — Time Settings Screen

**Branch:** `feature/mobile/time-settings`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/time-settings
```

### 1.1: Thiết kế giao diện

```
┌─────────────────────────────────┐
│ ← Giới hạn thời gian — Bé An   │
├─────────────────────────────────┤
│                                 │
│ Thứ 2                           │
│ ████████████░░░░  1h 30m        │
│                                 │
│ Thứ 3                           │
│ ████████████░░░░  1h 30m        │
│                                 │
│ Thứ 4                           │
│ ████████████░░░░  1h 30m        │
│                                 │
│ Thứ 5                           │
│ ████████████░░░░  1h 30m        │
│                                 │
│ Thứ 6                           │
│ ████████████████░  2h 00m       │
│                                 │
│ Thứ 7                           │
│ ██████████████████  2h 30m      │
│                                 │
│ Chủ nhật                        │
│ ██████████████████  2h 30m      │
│                                 │
│     [ 💾 Lưu thay đổi ]        │
│                                 │
└─────────────────────────────────┘
```

### 1.2: Yêu cầu

- [ ] AppBar: "Giới hạn thời gian — {tên trẻ}"
- [ ] 7 hàng, mỗi hàng = 1 ngày trong tuần
- [ ] Mỗi hàng có Slider (0 → 300 phút, bước 15 phút) + hiển thị "Xh Ym"
- [ ] Nút toggle bật/tắt giới hạn cho từng ngày
- [ ] Nút "Lưu thay đổi" → gọi `PUT /api/profiles/:id/time-limits`
- [ ] Load data hiện tại khi vào screen (từ profile API)
- [ ] Hiển thị loading khi save, SnackBar thành công/lỗi
- [ ] Navigate vào từ Profile Detail hoặc Device Detail

### 1.3: Repository

File tạo mới: `mobile/lib/features/time_limit/data/time_limit_repository.dart`

```dart
class TimeLimitRepository {
  final _dio = DioClient.instance;

  Future<List<TimeLimitModel>> getTimeLimits(int profileId) async {
    final response = await _dio.get('/api/profiles/$profileId');
    final timeLimits = response.data['data']['profile']['timeLimits'] as List;
    return timeLimits.map((tl) => TimeLimitModel.fromJson(tl)).toList();
  }

  Future<void> updateTimeLimits(int profileId, List<TimeLimitModel> limits) async {
    await _dio.put('/api/profiles/$profileId/time-limits', data: {
      'timeLimits': limits.map((tl) => tl.toJson()).toList(),
    });
  }
}
```

### 1.4: Model

File tạo mới: `mobile/lib/shared/models/time_limit_model.dart`

```dart
class TimeLimitModel {
  final int dayOfWeek;    // 0 = CN, 1-6 = T2-T7
  final int limitMinutes;
  final bool isActive;

  TimeLimitModel({
    required this.dayOfWeek,
    required this.limitMinutes,
    this.isActive = true,
  });

  factory TimeLimitModel.fromJson(Map<String, dynamic> json) {
    return TimeLimitModel(
      dayOfWeek: json['dayOfWeek'] as int,
      limitMinutes: json['limitMinutes'] as int,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'limitMinutes': limitMinutes,
    'isActive': isActive,
  };

  String get dayName {
    const names = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    return names[dayOfWeek];
  }

  String get formattedTime {
    final hours = limitMinutes ~/ 60;
    final mins = limitMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}
```

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add time settings screen for parent app"
git push origin feature/mobile/time-settings
```
→ PR → develop → Khanh review → merge

---

## Task 2: Child App — Countdown Timer + Session

**Branch:** `feature/mobile/countdown-timer`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/countdown-timer
```

### 2.1: Cập nhật Child Dashboard — countdown thật

Thay placeholder "2:30:00" bằng countdown thật dựa trên remaining time từ API.

### 2.2: Session Management

Khi Child Dashboard mở:
1. Gọi `GET /api/child/today-limit?deviceCode=XXX` → lấy `remainingMinutes`
2. Gọi `POST /api/child/session/start` → nhận `sessionId`
3. Bắt đầu countdown từ `remainingMinutes`
4. Mỗi 60 giây → gọi `POST /api/child/session/heartbeat` → cập nhật `remainingMinutes` từ server
5. Khi app vào background → gọi `POST /api/child/session/end`
6. Khi app resume → start session mới + lấy remaining mới

### 2.3: Countdown logic

```dart
class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen> {
  int _remainingSeconds = 0;
  int? _sessionId;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final deviceCode = await SecureStorage.read(key: 'device_code');
    if (deviceCode == null) return;

    // 1. Lấy remaining time
    final todayLimit = await _repo.getTodayLimit(deviceCode);
    _remainingSeconds = todayLimit.remainingMinutes * 60;

    // 2. Start session
    _sessionId = await _repo.startSession(deviceCode);

    // 3. Bắt đầu countdown
    _startCountdown();

    // 4. Heartbeat mỗi 60s
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_sessionId != null) {
        final result = await _repo.heartbeat(_sessionId!);
        // Sync remaining time từ server (tránh drift)
        setState(() => _remainingSeconds = result.remainingMinutes * 60);
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);

        // Check soft warning milestones
        _checkSoftWarning();
      } else {
        // Hết giờ!
        _onTimeUp();
      }
    });
  }

  String get _formattedTime {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    // End session khi dispose
    if (_sessionId != null) {
      _repo.endSession(_sessionId!);
    }
    super.dispose();
  }
}
```

### 2.4: Listen timeLimitUpdated event

Nếu Parent thay đổi time limit khi Child đang dùng → cập nhật countdown:

```dart
SocketService.instance.socket.on('timeLimitUpdated', (data) {
  // Re-fetch remaining time từ server
  _refreshRemainingTime();
});
```

### 2.5: Test

- [ ] Mở Child Dashboard → countdown bắt đầu đúng
- [ ] Countdown đếm ngược mỗi giây
- [ ] Heartbeat gửi mỗi 60s (check Railway logs)
- [ ] Parent thay đổi time limit → Child countdown cập nhật
- [ ] Tắt app → mở lại → countdown tiếp tục đúng (không reset)

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add real countdown timer with session management"
git push origin feature/mobile/countdown-timer
```
→ PR → develop → Khanh review → merge

---

## Task 3: Child App — Soft Warning System ★

**Branch:** `feature/mobile/soft-warning`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/soft-warning
```

### 3.1: Hiển thị cảnh báo ở mốc 30/15/5 phút

Trong `_checkSoftWarning()` (từ Task 2):

```dart
final Set<int> _triggeredWarnings = {};

void _checkSoftWarning() {
  final remainingMinutes = _remainingSeconds ~/ 60;

  // Mốc 30 phút
  if (remainingMinutes == 30 && !_triggeredWarnings.contains(30)) {
    _triggeredWarnings.add(30);
    _showWarningDialog('SOFT_30', 'Còn 30 phút', 'Con còn 30 phút sử dụng thiết bị hôm nay.');
  }

  // Mốc 15 phút
  if (remainingMinutes == 15 && !_triggeredWarnings.contains(15)) {
    _triggeredWarnings.add(15);
    _showWarningDialog('SOFT_15', 'Còn 15 phút', 'Con còn 15 phút. Hãy hoàn thành việc đang làm nhé!');
  }

  // Mốc 5 phút
  if (remainingMinutes == 5 && !_triggeredWarnings.contains(5)) {
    _triggeredWarnings.add(5);
    _showWarningDialog('SOFT_5', 'Còn 5 phút!', 'Con còn 5 phút. Sắp hết giờ rồi!');
  }
}
```

### 3.2: Warning Dialog

```dart
void _showWarningDialog(String type, String title, String message) {
  // Ghi log warning lên server
  _repo.logWarning(deviceCode: _deviceCode, type: type);

  // Hiển thị dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );
}
```

### 3.3: Hết giờ (TIME_UP)

```dart
void _onTimeUp() {
  _countdownTimer?.cancel();
  _heartbeatTimer?.cancel();
  if (_sessionId != null) _repo.endSession(_sessionId!);

  // Log warning
  _repo.logWarning(deviceCode: _deviceCode, type: 'TIME_UP');

  // Hiện màn hình khóa (fullscreen, không thoát được)
  // Sprint 5 sẽ implement lock screen thật bằng Kotlin
  // Tạm thời hiện dialog không dismiss được
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => WillPopScope(
      onWillPop: () async => false, // Chặn nút back
      child: AlertDialog(
        title: const Text('⏰ Hết giờ!'),
        content: const Text(
          'Thời gian sử dụng thiết bị hôm nay đã hết.\nHãy nghỉ ngơi nhé!',
          style: TextStyle(fontSize: 16),
        ),
        // Không có nút dismiss
      ),
    ),
  );
}
```

### 3.4: Test

- [ ] Đặt time limit 2 phút (để test nhanh)
- [ ] Countdown chạy → hiện warning dialog lúc còn 1 phút (test với mốc nhỏ)
- [ ] Hết giờ → hiện "Hết giờ!" dialog không thoát được
- [ ] Railway logs thấy POST /api/child/warning
- [ ] Parent nhận push notification + Socket.IO event `softWarning`

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add soft warning system at 30/15/5 min milestones"
git push origin feature/mobile/soft-warning
```
→ PR → develop → Khanh review → merge

---

## Task 4: Child App — Xin Thêm Giờ ★

**Branch:** `feature/mobile/request-time-extension`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/request-time-extension
```

### 4.1: UI xin thêm giờ

Thay placeholder "Xin thêm giờ" trong Child Dashboard bằng logic thật:

```dart
void _showRequestDialog() {
  int requestMinutes = 15;
  final reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Xin thêm giờ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Con muốn xin thêm bao nhiêu phút?'),
            const SizedBox(height: 16),
            // Chọn số phút
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [15, 30, 45, 60].map((min) {
                return ChoiceChip(
                  label: Text('$min phút'),
                  selected: requestMinutes == min,
                  onSelected: (_) => setDialogState(() => requestMinutes = min),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Lý do
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                hintText: 'VD: Con đang làm bài tập...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendTimeExtensionRequest(requestMinutes, reasonController.text);
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    ),
  );
}
```

### 4.2: Gửi request qua Socket.IO

```dart
void _sendTimeExtensionRequest(int minutes, String reason) {
  SocketService.instance.socket.emit('requestTimeExtension', {
    'deviceCode': _deviceCode,
    'requestMinutes': minutes,
    'reason': reason,
  });

  setState(() => _waitingForResponse = true);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Đã gửi yêu cầu cho phụ huynh. Đang chờ phản hồi...')),
  );
}
```

### 4.3: Nhận response từ Parent

```dart
// Trong initState hoặc _initSession:
SocketService.instance.socket.on('timeExtensionResponse', (data) {
  final approved = data['approved'] as bool;
  final responseMinutes = data['responseMinutes'] as int? ?? 0;

  setState(() => _waitingForResponse = false);

  if (approved) {
    // Cộng thêm thời gian vào countdown
    setState(() => _remainingSeconds += responseMinutes * 60);
    _showResultDialog(true, responseMinutes);
  } else {
    _showResultDialog(false, 0);
  }
});

void _showResultDialog(bool approved, int minutes) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(approved ? '✅ Được duyệt!' : '❌ Bị từ chối'),
      content: Text(approved
          ? 'Phụ huynh đã cho thêm $minutes phút!'
          : 'Phụ huynh đã từ chối yêu cầu.'),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

### 4.4: Test

- [ ] Nhấn "Xin thêm giờ" → hiện dialog chọn phút + nhập lý do
- [ ] Gửi request → hiện "Đang chờ phản hồi..."
- [ ] Parent approve → Child nhận response → countdown tăng thêm
- [ ] Parent reject → Child nhận response → hiện "Bị từ chối"

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add time extension request UI for child app"
git push origin feature/mobile/request-time-extension
```
→ PR → develop → Khanh review → merge

---

## Task 5: Parent App — Nhận + Duyệt Xin Thêm Giờ

**Branch:** `feature/mobile/approve-extension`

```bash
git checkout develop && git pull origin develop
git checkout -b feature/mobile/approve-extension
```

### 5.1: Listen timeExtensionRequest event

Trong `SocketService` hoặc Provider, listen event từ server:

```dart
SocketService.instance.socket.on('timeExtensionRequest', (data) {
  // Hiện in-app notification / dialog
  // data: { requestId, profileName, deviceName, requestMinutes, reason }
});
```

### 5.2: In-app notification khi nhận request

Khi Parent đang dùng app → hiện banner hoặc dialog:

```dart
void _onTimeExtensionRequest(Map<String, dynamic> data) {
  final requestId = data['requestId'] as int;
  final profileName = data['profileName'] as String;
  final requestMinutes = data['requestMinutes'] as int;
  final reason = data['reason'] as String? ?? '';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('⏳ $profileName xin thêm giờ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xin thêm: $requestMinutes phút'),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lý do: $reason', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _respondExtension(requestId, false, 0);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Từ chối'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _respondExtension(requestId, true, requestMinutes);
          },
          child: Text('Duyệt ($requestMinutes phút)'),
        ),
      ],
    ),
  );
}

void _respondExtension(int requestId, bool approved, int minutes) {
  SocketService.instance.socket.emit('respondTimeExtension', {
    'requestId': requestId,
    'approved': approved,
    'responseMinutes': minutes,
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(approved ? 'Đã duyệt thêm $minutes phút' : 'Đã từ chối')),
  );
}
```

### 5.3: Xử lý khi Parent không mở app (Push notification)

Khi Parent không mở app → nhận FCM push notification. Nhấn notification → mở app → xem pending requests:

```dart
// Trong Firebase message handler:
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  if (message.data['type'] == 'time_extension') {
    // Navigate sang pending requests screen
    context.go('/extension-requests');
  }
});
```

### 5.4: (Tùy chọn) Pending Requests Screen

Nếu có thời gian, tạo screen hiển thị danh sách requests đang chờ:

- [ ] Gọi `GET /api/extension-requests/pending`
- [ ] Hiển thị list: tên trẻ, số phút, lý do, nút Duyệt/Từ chối

### 5.5: Test

- [ ] Child gửi request → Parent nhận dialog trong app
- [ ] Parent approve → Child nhận response
- [ ] Parent reject → Child nhận response
- [ ] Parent không mở app → nhận push notification
- [ ] Nhấn push notification → mở app → xử lý request

### Commit & Push

```bash
git add -A
git commit -m "feat(mobile): add time extension approve/reject UI for parent app"
git push origin feature/mobile/approve-extension
```
→ PR → develop → Khanh review → merge

---

## Task 6: Integration Test

Test end-to-end trên 2 thiết bị Android:

### Flow chính:

1. [ ] **Parent** login → vào Home
2. [ ] **Parent** vào profile → Time Settings → đặt 5 phút (để test nhanh)
3. [ ] **Child** mở app → vào Child Dashboard → countdown bắt đầu từ 5:00
4. [ ] Countdown đếm ngược mỗi giây
5. [ ] Còn 30s (mock mốc 30 phút) → hiện Soft Warning dialog
6. [ ] **Child** nhấn "Xin thêm giờ" → chọn 15 phút → gửi
7. [ ] **Parent** nhận dialog xin giờ → nhấn "Duyệt"
8. [ ] **Child** nhận response → countdown tăng thêm 15 phút
9. [ ] Hết giờ → hiện "Hết giờ!" (không thoát được)
10. [ ] **Parent** thay đổi time limit → **Child** countdown cập nhật real-time

### Edge cases:

11. [ ] Child tắt app → mở lại → countdown tiếp tục đúng
12. [ ] Parent reject xin giờ → Child hiện "Bị từ chối"
13. [ ] Time limit = 0 phút → Child hiện "Hết giờ" ngay
14. [ ] Mất mạng → reconnect → countdown sync lại từ server

---

## Checklist cuối Sprint 4 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | Time Settings screen hoạt động (7 ngày/tuần) | ⬜ |
| 2 | Slider 0-300 phút, bước 15 phút | ⬜ |
| 3 | Save time limits → API thành công | ⬜ |
| 4 | Child countdown timer hoạt động | ⬜ |
| 5 | Session start/heartbeat/end hoạt động | ⬜ |
| 6 | Heartbeat mỗi 60s sync remaining time | ⬜ |
| 7 | Soft Warning dialog ở mốc 30/15/5 phút ★ | ⬜ |
| 8 | Warning log gửi lên server | ⬜ |
| 9 | "Hết giờ!" dialog khi countdown = 0 | ⬜ |
| 10 | Xin thêm giờ UI (chọn phút + lý do) ★ | ⬜ |
| 11 | Gửi request qua Socket.IO | ⬜ |
| 12 | Nhận response + cập nhật countdown | ⬜ |
| 13 | Parent nhận in-app dialog xin giờ | ⬜ |
| 14 | Parent approve/reject qua Socket.IO | ⬜ |
| 15 | Push notification khi Parent không mở app | ⬜ |
| 16 | timeLimitUpdated event cập nhật countdown | ⬜ |
| 17 | Tất cả code pushed lên develop | ⬜ |

---

## Socket.IO Events cần sử dụng

### Child listen:

| Event | Khi nào | Xử lý |
|-------|---------|-------|
| `timeLimitUpdated` | Parent thay đổi time limit | Re-fetch remaining, cập nhật countdown |
| `timeExtensionResponse` | Parent trả lời xin giờ | approved → cộng thêm phút, rejected → thông báo |

### Child emit:

| Event | Khi nào | Data |
|-------|---------|------|
| `requestTimeExtension` | Nhấn "Xin thêm giờ" | `{ deviceCode, requestMinutes, reason }` |

### Parent listen:

| Event | Khi nào | Xử lý |
|-------|---------|-------|
| `timeExtensionRequest` | Child xin thêm giờ | Hiện dialog approve/reject |
| `softWarning` | Child nhận cảnh báo | Hiện thông báo (tuỳ chọn) |

### Parent emit:

| Event | Khi nào | Data |
|-------|---------|------|
| `respondTimeExtension` | Nhấn Duyệt/Từ chối | `{ requestId, approved, responseMinutes }` |

---

## API Endpoints cần gọi

| Method | Endpoint | Ai gọi | Khi nào |
|--------|----------|--------|---------|
| GET | `/api/child/today-limit?deviceCode=XXX` | Child | Mở dashboard |
| POST | `/api/child/session/start` | Child | Bắt đầu dùng |
| POST | `/api/child/session/heartbeat` | Child | Mỗi 60s |
| POST | `/api/child/session/end` | Child | Thoát app |
| POST | `/api/child/warning` | Child | Hiện warning |
| PUT | `/api/profiles/:id/time-limits` | Parent | Save time settings |

---

## Quy tắc Git (nhắc lại)

```bash
# Mỗi task = 1 branch riêng
git checkout develop && git pull origin develop
git checkout -b feature/mobile/<tên-task>

# Code + commit thường xuyên
git add -A
git commit -m "feat(mobile): mô tả ngắn"

# Push + tạo PR
git push origin feature/mobile/<tên-task>
# → GitHub tạo PR → target develop → Khanh review → merge

# KHÔNG push thẳng develop
# KHÔNG code trên develop
```
