# KidFun V3 — Sprint 4 BUGFIX — FRONTEND (Flutter)

> **Dựa trên:** Test results + Railway logs + code review
> **Số bugs:** 2 bugs chính + 1 vấn đề phụ

---

## Tóm tắt bugs

| # | Bug | File | Nguyên nhân |
|---|-----|------|-------------|
| 1 | Time Settings crash: `NoSuchMethodError: '[]' called on null` | `time_limit_repository.dart` | API response structure không khớp — code gọi `data['profile']['timeLimits']` nhưng API trả `data` trực tiếp không có tầng `profile` |
| 2 | Parent không nhận request xin thêm giờ | `socket_service.dart` | Parent app KHÔNG listen event `timeExtensionRequest` ở screen nào cả — `SocketService` có listener list nhưng không screen nào register callback |
| phụ | Parent Socket bị disconnect liên tục (`transport close`) | `socket_service.dart` | Transport `polling` gây reconnect loop trên Railway |

---

## Bug 1: Time Settings crash — `NoSuchMethodError`

### Nguyên nhân chính xác

File `time_limit_repository.dart`, dòng 9-11:

```dart
final data = response.data['data'];
final profile = data['profile'];          // ← BUG: 'profile' không tồn tại
final timeLimitsRaw = profile['timeLimits'] as List;  // ← crash ở đây vì profile = null
```

API `GET /api/profiles/:id` trả response dạng:

```json
{
  "success": true,
  "data": {
    "id": 2,
    "profileName": "Bé An",
    "timeLimits": [...]
  }
}
```

Code đang expect `data.profile.timeLimits` (3 tầng) nhưng API trả `data.timeLimits` (2 tầng). Không có tầng `profile` ở giữa.

### Fix

File sửa: `mobile/lib/features/time_limit/data/time_limit_repository.dart`

```dart
// ❌ SAI (code hiện tại):
final data = response.data['data'];
final profile = data['profile'];
final timeLimitsRaw = profile['timeLimits'] as List;

// ✅ ĐÚNG (fix):
final data = response.data['data'];
final timeLimitsRaw = data['timeLimits'] as List? ?? [];
```

**Code đầy đủ sau khi fix:**

```dart
import '../../../core/network/dio_client.dart';
import '../../../shared/models/time_limit_model.dart';

class TimeLimitRepository {
  final _dio = DioClient.instance;

  Future<List<TimeLimitModel>> getTimeLimits(int profileId) async {
    final response = await _dio.get('/api/profiles/$profileId');
    final data = response.data['data'];

    // API trả data trực tiếp, KHÔNG có tầng 'profile'
    // data = { id, profileName, timeLimits: [...] }
    final timeLimitsRaw = data['timeLimits'] as List? ?? [];

    return timeLimitsRaw.map((tl) => TimeLimitModel.fromJson(tl)).toList();
  }

  Future<void> updateTimeLimits(int profileId, List<TimeLimitModel> limits) async {
    await _dio.put('/api/profiles/$profileId/time-limits', data: {
      'timeLimits': limits.map((tl) => tl.toJson()).toList(),
    });
  }
}
```

### Cách verify

1. Sửa file → build app → vào Time Settings screen
2. Phải thấy 7 ngày với slider, không crash
3. Nếu timeLimits chưa có data → hiện 7 ngày với giá trị 0

---

## Bug 2: Parent không nhận request xin thêm giờ

### Nguyên nhân chính xác

Nhìn vào `socket_service.dart` dòng 153-160 — `SocketService` **có** listen event `timeExtensionRequest` và dispatch cho `_timeExtensionRequestListeners`:

```dart
_socket!.on('timeExtensionRequest', (data) {
  print('⏰ [SOCKET] RECEIVED timeExtensionRequest: $data');
  final mapData = Map<String, dynamic>.from(data as Map);
  for (final cb in List.from(_timeExtensionRequestListeners)) {
    cb(mapData);
  }
});
```

**NHƯNG** — không có screen nào ở Parent app gọi `addTimeExtensionRequestListener()` để đăng ký callback. `_timeExtensionRequestListeners` list luôn rỗng → event nhận được nhưng không ai xử lý.

Ngoài ra, Railway logs **không thấy** dòng `⏰ [SOCKET] RECEIVED timeExtensionRequest` → có thể server cũng không nhận được event `requestTimeExtension` từ Child. Kiểm tra `child_dashboard_screen.dart` dòng 366:

```dart
SocketService.instance.socket.emit('requestTimeExtension', {
  'deviceCode': _deviceCode,
  'requestMinutes': minutes,
  'reason': reason,
});
```

Code emit đúng event name. Nhưng vấn đề có thể là **Child socket đã disconnect trước khi emit** (do `transport close` liên tục).

### Fix — 2 phần

#### Phần A: Parent app — Register listener cho timeExtensionRequest

Cần thêm listener ở **screen chính của Parent** (Home/Dashboard hoặc nơi Parent luôn ở khi dùng app).

File sửa: Screen chính Parent (ví dụ `parent_home_screen.dart` hoặc `parent_dashboard_screen.dart` hoặc `home_screen.dart`)

Thêm vào `initState`:

```dart
@override
void initState() {
  super.initState();
  // ... code hiện tại ...

  // ★ Register listener xin thêm giờ
  SocketService.instance.addTimeExtensionRequestListener(_onTimeExtensionRequest);
}

void _onTimeExtensionRequest(Map<String, dynamic> data) {
  if (!mounted) return;

  final requestId = data['requestId'] as int?;
  final profileName = data['profileName'] as String? ?? 'Con';
  final requestMinutes = data['requestMinutes'] as int? ?? 15;
  final reason = data['reason'] as String? ?? '';

  print('⏳ [PARENT] Time extension request received: $data');

  showDialog(
    context: context,
    barrierDismissible: false,
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
            _respondExtension(requestId!, false, 0);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Từ chối'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _respondExtension(requestId!, true, requestMinutes);
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
    SnackBar(content: Text(approved ? '✅ Đã duyệt thêm $minutes phút' : '❌ Đã từ chối')),
  );
}

@override
void dispose() {
  // ★ Xóa listener khi dispose
  SocketService.instance.removeTimeExtensionRequestListener(_onTimeExtensionRequest);
  super.dispose();
}
```

**Quan trọng:** Listener phải được đăng ký ở screen **luôn tồn tại** khi Parent dùng app (ví dụ: HomeScreen, ShellRoute wrapper). Nếu đăng ký ở screen con (DeviceListScreen) thì khi navigate đi sẽ mất listener.

#### Phần B: Verify Child emit đúng

Kiểm tra khi Child nhấn "Gửi yêu cầu":
1. Flutter console Child phải thấy log: `emit requestTimeExtension`
2. Railway logs phải thấy: `⏳ Time extension request:` (từ server socketService.js)

Nếu Railway logs **KHÔNG thấy** → Child socket có thể bị disconnect trước khi emit. Xem Bug phụ bên dưới.

### Cách verify

1. Parent login → ở Home screen
2. Child nhấn "Xin thêm giờ" → chọn 15 phút → gửi
3. Parent phải thấy dialog hiện lên trong 3 giây
4. Railway logs phải thấy:
   ```
   ⏳ Time extension request: Bé An xin 15 phút
   ⏰ [SOCKET] RECEIVED timeExtensionRequest (listeners: 1)    ← SỐ 1, KHÔNG PHẢI 0
   ```

---

## Bug phụ: Parent Socket disconnect liên tục

### Triệu chứng trong Railway logs

```
🔌 [SOCKET] Client connected: xxx
👨‍👩‍👧 [SOCKET] parent joined family_1
❌ [SOCKET] Client disconnected: xxx — Reason: transport close
🔌 [SOCKET] Client connected: yyy    ← reconnect ngay
👨‍👩‍👧 [SOCKET] parent joined family_1
❌ [SOCKET] Client disconnected: yyy — Reason: transport close
```

Lặp lại liên tục, mỗi vài chục giây.

### Nguyên nhân

File `socket_service.dart` dòng 81:

```dart
.setTransports(['websocket', 'polling'])
```

Khi set cả `websocket` và `polling`, Socket.IO có thể bắt đầu bằng `polling` (HTTP long-polling) rồi upgrade lên `websocket`. Trên Railway, polling transport hoạt động không ổn định → gây `transport close`.

### Fix

```dart
// ❌ SAI (gây reconnect loop):
.setTransports(['websocket', 'polling'])

// ✅ ĐÚNG (chỉ dùng websocket):
.setTransports(['websocket'])
```

**Code đầy đủ:**

```dart
_socket = IO.io(ApiConstants.baseUrl, IO.OptionBuilder()
  .setTransports(['websocket'])     // ← Chỉ websocket, bỏ polling
  .enableAutoConnect()
  .enableReconnection()
  .setReconnectionAttempts(99999)
  .setReconnectionDelay(2000)
  .build()
);
```

Railway hỗ trợ WebSocket native, không cần polling fallback.

### Cách verify

Sau khi fix, Railway logs phải thấy Parent connect **1 lần** và giữ kết nối lâu (không còn disconnect/reconnect liên tục):

```
🔌 [SOCKET] Client connected: xxx
👨‍👩‍👧 [SOCKET] parent joined family_1
(không còn ❌ disconnect liên tục)
```

---

## Thứ tự fix

1. **Bug 1 (Time Limit crash)** — Fix nhanh nhất, chỉ sửa 1 dòng
2. **Bug phụ (transport close)** — Sửa 1 dòng, giúp Socket.IO ổn định → test Bug 2 chính xác hơn
3. **Bug 2 (Parent không nhận request)** — Cần thêm listener ở Parent screen

### Branch khuyến nghị

Có thể gộp cả 3 vào 1 branch:

```bash
git checkout develop && git pull origin develop
git checkout -b fix/mobile/sprint4-bugs
```

Commit theo từng bug:
```bash
git add -A
git commit -m "fix(mobile): fix time limit repository response parsing"

git add -A
git commit -m "fix(mobile): use websocket-only transport to prevent disconnect loop"

git add -A
git commit -m "feat(mobile): add timeExtensionRequest listener in parent home screen"

git push origin fix/mobile/sprint4-bugs
```
→ PR → develop → Khanh review → merge

---

## Sau khi fix — Test lại

Chạy lại Flow Test theo thứ tự:

1. [ ] **Test 1** (Time Settings) — phải pass (Bug 1 fixed)
2. [ ] **Test 5** (Xin thêm giờ) — phải pass (Bug 2 fixed)
3. [ ] **Test 3, 4, 6, 7** — phụ thuộc Test 1, nên test lại
4. [ ] **Test 9** — về note máy Trung Quốc kill app: đây là hành vi bình thường của OS, không phải bug app. Có thể test bằng cách minimize app thay vì force close.
5. [ ] Kiểm tra Railway logs — Parent không còn disconnect liên tục

---

## Checklist

| # | Fix | Status |
|---|-----|--------|
| 1 | `time_limit_repository.dart`: bỏ tầng `profile`, dùng `data['timeLimits']` | ⬜ |
| 2 | `socket_service.dart`: đổi transport sang `['websocket']` only | ⬜ |
| 3 | Parent Home screen: `addTimeExtensionRequestListener` + dialog UI | ⬜ |
| 4 | Parent Home screen: `respondTimeExtension` emit khi approve/reject | ⬜ |
| 5 | Parent Home screen: `removeTimeExtensionRequestListener` trong dispose | ⬜ |
| 6 | Test 1 pass (Time Settings không crash) | ⬜ |
| 7 | Test 5 pass (Parent nhận dialog xin giờ) | ⬜ |
| 8 | Railway logs: Parent không disconnect liên tục | ⬜ |
