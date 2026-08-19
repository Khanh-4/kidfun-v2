# KidFun V3 — Sprint 4 BUGFIX Round 3 — FRONTEND (Flutter)

> **Dựa trên:** Test results lần 3 + Railway logs
> **CRITICAL:** Transport close VẪN CHƯA FIX — cần verify + flutter clean

---

## Tình trạng hiện tại

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| Test 1 | ✅ Pass | + suggestions cải thiện UX |
| Test 2 | ❌ Fail | Child hiện 2h thay vì time limit đã set |
| Test 3 | ⏳ Block | Do Test 2 |
| Test 4 | ⏳ Block | Do Test 2 |
| Test 5 | ❌ Fail | Parent không nhận request (transport close) |
| Test 6 | ⏳ Block | Do Test 5 |
| Test 7 | ❌ Fail | Child không nhận timeLimitUpdated |
| Test 8 | ✅ Pass | Delay + làm tròn phút |
| Test 9 | ⏳ Block | Do Test 5 |
| Test 10.3 | ✅ Pass | Làm tròn phút |

**Root cause chung: Transport close chưa fix → Parent disconnect liên tục → mất events.**

---

## Bug CRITICAL: Transport close VẪN CHƯA CÓ HIỆU LỰC

Railway logs VẪN cho thấy:
```
❌ Client disconnected: xxx — Reason: transport close
❌ Client disconnected: xxx — Reason: transport close
```

Cả Parent LẪN Child đều bị. Fix `['websocket']` only chưa có hiệu lực.

### Kiểm tra NGAY

**Bước 1:** Pull code mới nhất:
```bash
git checkout develop
git pull origin develop
```

**Bước 2:** Mở file `mobile/lib/core/network/socket_service.dart`, tìm `setTransports`:

```
Nếu thấy: .setTransports(['websocket', 'polling'])  → CHƯA FIX!
Phải là:   .setTransports(['websocket'])             → ĐÃ FIX
```

**Bước 3:** Nếu đã đúng `['websocket']` nhưng vẫn bị → phải **flutter clean**:

```bash
cd mobile
flutter clean
flutter pub get
flutter run
```

**`flutter clean` là BẮT BUỘC** — nếu không clean, Flutter có thể dùng cache build cũ (vẫn chứa code `polling`).

**Bước 4:** Sau khi build xong, kiểm tra Railway logs:
- Parent connect → **KHÔNG** disconnect trong vài phút
- Nếu vẫn disconnect → có thể là vấn đề mạng, thử đổi WiFi hoặc dùng 4G

---

## Bug: Child hiện 2 giờ thay vì time limit đã set (Test 2)

### Phân tích

Có 2 khả năng:

**Khả năng A — Backend timezone sai:** Server Railway dùng UTC, Việt Nam là UTC+7. Parent set time limit cho "Thứ 2" nhưng server nghĩ hôm nay là "Chủ nhật" (UTC) → lấy time limit sai ngày → trả default 120 phút (2h).

→ **Khanh đang fix backend** (xem file `Sprint4-BUGFIX-Round3-BACKEND.md`)

**Khả năng B — Frontend dùng default thay vì API response:**

Kiểm tra file `child_dashboard_screen.dart`, hàm `_initSession()`:

```dart
final todayLimit = await _childRepo.getTodayLimit(_deviceCode!);
setState(() {
  _remainingSeconds = todayLimit.remainingMinutes * 60;
});
```

Thêm debug log để verify:

```dart
final todayLimit = await _childRepo.getTodayLimit(_deviceCode!);
print('📊 [DEBUG] todayLimit response: remainingMinutes=${todayLimit.remainingMinutes}, limitMinutes=${todayLimit.limitMinutes}');
setState(() {
  _remainingSeconds = todayLimit.remainingMinutes * 60;
});
print('📊 [DEBUG] _remainingSeconds set to: $_remainingSeconds');
```

Nếu log hiện `remainingMinutes=120` → backend trả sai (Bug A, Khanh fix).
Nếu log hiện `remainingMinutes=5` nhưng countdown vẫn 2h → frontend parse sai.

### Fix (Frontend — sau khi Khanh fix backend)

Kiểm tra `ChildRepository.getTodayLimit()` parse response đúng:

```dart
Future<TodayLimitModel> getTodayLimit(String deviceCode) async {
  final response = await _dio.get('/api/child/today-limit?deviceCode=$deviceCode');
  final data = response.data['data'];
  
  print('📊 [DEBUG] getTodayLimit raw data: $data');
  
  return TodayLimitModel(
    remainingMinutes: (data['remainingMinutes'] as int?) ?? 0,
    remainingSeconds: (data['remainingSeconds'] as int?),  // Có thể null nếu backend chưa fix
    limitMinutes: (data['limitMinutes'] as int?) ?? 0,
    // ... các field khác
  );
}
```

---

## Bug: Child không nhận timeLimitUpdated (Test 7)

### Phân tích

Railway logs cho thấy:
```
📣 [SOCKET] External Notification: family_1 -> timeLimitUpdated
⏰ Time limits updated for profile 13 → notified devices
```

Server emit event thành công. Nhưng Child vẫn không cập nhật → 2 khả năng:

**Khả năng A:** Child bị `transport close` đúng lúc → mất event (giống Bug transport close).

**Khả năng B:** Backend emit event cho `family_1` room nhưng Child ở `device_XXX` room. Kiểm tra backend code — nếu `timeLimitUpdated` chỉ emit cho `family_` room (Parent), Child không nhận.

### Fix (Frontend)

Thêm fallback: sau khi nhận `timeLimitUpdated`, cũng gọi API để lấy data mới (đã có trong code hiện tại):

```dart
SocketService.instance.socket.on('timeLimitUpdated', (data) {
  print('🔔 [SOCKET] timeLimitUpdated received');
  _initSession(); // Re-fetch từ API
});
```

Code này **đã đúng**. Nếu không hoạt động → do transport close. Fix transport close trước.

**Thêm fallback:** Poll API mỗi 60s (trong heartbeat callback đã có) — khi heartbeat response trả `remainingMinutes` khác biệt lớn → có thể Parent đã thay đổi limit.

---

## Suggestions cải thiện Test 1 (UX)

Bạn test đề xuất 3 cải thiện cho Time Settings screen. Đây là nice-to-have, **không block** Sprint 4:

### 1. Cho phép nhập số phút tùy ý

Thêm nút "Tùy chỉnh" bên cạnh slider:

```dart
Row(
  children: [
    Expanded(
      child: Slider(
        min: 0, max: 480, // 8 giờ
        divisions: 96,     // Bước 5 phút
        value: limitMinutes.toDouble(),
        onChanged: (v) => setState(() => limitMinutes = v.round()),
      ),
    ),
    // Nút nhập tay
    SizedBox(
      width: 70,
      child: TextField(
        keyboardType: TextInputType.number,
        controller: TextEditingController(text: '$limitMinutes'),
        onSubmitted: (v) {
          final mins = int.tryParse(v) ?? 0;
          setState(() => limitMinutes = mins.clamp(0, 720));
        },
        decoration: const InputDecoration(suffixText: 'ph'),
      ),
    ),
  ],
)
```

### 2. Tăng max từ 5h lên 8h hoặc 12h

```dart
// Đổi max slider:
Slider(
  min: 0,
  max: 720,   // 12 giờ (thay vì 300 = 5 giờ)
  divisions: 144, // Bước 5 phút
  // ...
)
```

### 3. Nút "Áp dụng cho tất cả"

```dart
ElevatedButton.icon(
  onPressed: () {
    final value = timeLimits[0].limitMinutes; // Lấy giá trị ngày đầu tiên
    setState(() {
      for (int i = 0; i < 7; i++) {
        timeLimits[i] = timeLimits[i].copyWith(limitMinutes: value);
      }
    });
  },
  icon: const Icon(Icons.copy_all),
  label: const Text('Áp dụng cho tất cả các ngày'),
)
```

---

## Thứ tự fix

```
1. Transport close (CRITICAL)
   ├── Verify ['websocket'] đã merge
   ├── flutter clean && flutter run (BẮT BUỘC)
   └── Verify Railway logs: không disconnect liên tục

2. Đợi Khanh fix backend (timezone + remainingSeconds)

3. Thêm debug logs cho getTodayLimit
   └── Verify Child parse response đúng

4. (Optional) UX improvements cho Time Settings
```

---

## Checklist

| # | Fix | Status |
|---|-----|--------|
| 1 | Verify `setTransports(['websocket'])` trong code | ⬜ |
| 2 | `flutter clean && flutter pub get && flutter run` | ⬜ |
| 3 | Railway logs: Parent KHÔNG disconnect liên tục | ⬜ |
| 4 | Railway logs: Child KHÔNG disconnect liên tục | ⬜ |
| 5 | Thêm debug log trong getTodayLimit (xem response) | ⬜ |
| 6 | Sau Khanh fix backend: Child hiện đúng time limit | ⬜ |
| 7 | Sau Khanh fix backend: Countdown chính xác đến giây | ⬜ |
| 8 | Test 5: Parent nhận dialog xin giờ | ⬜ |
| 9 | (Optional) Slider max → 8h hoặc 12h | ⬜ |
| 10 | (Optional) Nút nhập phút tùy ý | ⬜ |
| 11 | (Optional) Nút "Áp dụng tất cả" | ⬜ |
