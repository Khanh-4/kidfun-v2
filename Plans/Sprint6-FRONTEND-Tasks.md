# KidFun V3 — Sprint 6: Demo Giữa Kỳ ★ CHECKPOINT — FRONTEND (Flutter + Kotlin)

> **Sprint Goal:** Fix bug, polish UI, test end-to-end, build APK cho GVHD đánh giá
> **QUAN TRỌNG:** KHÔNG thêm tính năng mới — chỉ fix + polish + test
> **Branch gốc:** `develop`

---

## Tổng quan Sprint 6 — Frontend Tasks

| Task | Nội dung | Ưu tiên |
|------|----------|---------|
| **Task 1** | Fix bugs UI/UX từ Sprint 1–5 | 🔴 CRITICAL |
| **Task 2** | Polish UI (loading, errors, empty states) | 🟠 HIGH |
| **Task 3** | Test end-to-end trên thiết bị thật | 🔴 CRITICAL |
| **Task 4** | Build APK release | 🟠 HIGH |
| **Task 5** | Chuẩn bị demo | 🟡 MEDIUM |

---

## Task 1: Fix Bugs UI/UX

> **Branch:** `fix/mobile/sprint6-bugfix`

### Bugs đã biết cần fix/verify:

**1.1: Transport close — Parent Socket disconnect liên tục**

Trạng thái: REST API fallback đã hoạt động (Test 5 pass). Nhưng Socket vẫn bị disconnect → chấp nhận cho demo, dùng fallback.

Cần verify:
- [ ] Parent mở app → xin giờ hoạt động (qua REST fallback nếu Socket mất)
- [ ] timeLimitUpdated event hoạt động (Child nhận limit mới)

**1.2: Soft warning có thể trigger nhiều lần**

Kiểm tra: Child dashboard có guard flag cho mỗi mốc (30/15/5) không? Mỗi mốc chỉ trigger 1 lần.

```dart
// Cần có:
bool _warned30 = false;
bool _warned15 = false;
bool _warned5 = false;

void _checkWarning(int remaining) {
  if (remaining <= 30 * 60 && !_warned30) {
    _warned30 = true;
    _showWarning('30 phút');
  }
  // ...
}
```

**1.3: Input field giới hạn thời gian — hiển thị bị cắt số**

Bạn test đã báo: vị trí nhập tùy chỉnh cần nới rộng hơn cho số 2-3 chữ số.

Fix: Tăng width của TextField.

```dart
SizedBox(
  width: 80, // Thay vì 60-70
  child: TextField(
    // ...
  ),
)
```

**1.4: Dialog xin giờ — nút "Từ chối" styling**

Bạn test đã báo: nút "Từ chối" cần style giống nút "Duyệt".

Fix: Dùng ElevatedButton thay TextButton cho "Từ chối".

**1.5: Verify POST /api/child/warnings URL**

Backend đã thêm alias `/warnings`. Verify frontend gọi đúng URL:
- [ ] Logcat: `POST /api/child/warnings 201` (không phải 404)

### Commit:

```bash
git checkout develop && git pull origin develop
git checkout -b fix/mobile/sprint6-bugfix
git commit -m "fix(mobile): sprint 6 bugfix — warning guard, input width, button styling"
git push origin fix/mobile/sprint6-bugfix
```
→ PR → develop → merge

---

## Task 2: Polish UI

> **Branch:** `chore/mobile/polish-ui`

### 2.1: Loading states

Kiểm tra TẤT CẢ screens có loading indicator khi fetch data:

| Screen | Loading | Empty State |
|--------|---------|-------------|
| Login | ⬜ Spinner khi đang login | ⬜ Error message rõ ràng |
| Profile List | ⬜ Skeleton/spinner | ⬜ "Chưa có hồ sơ con" |
| Device List | ⬜ Spinner | ⬜ "Chưa có thiết bị" |
| Time Settings | ⬜ Spinner khi lưu | ⬜ SnackBar thành công/lỗi |
| Child Dashboard | ⬜ Spinner khi load limit | ⬜ Countdown "--:--" khi đang load |
| App Blocking | ⬜ Spinner | ⬜ "Chưa có dữ liệu app" |
| Usage Reports | ⬜ Spinner | ⬜ "Chưa có dữ liệu" |

### 2.2: Error handling UI

```dart
// Mẫu error handling cho mọi screen
try {
  final data = await api.fetchSomething();
  setState(() => _data = data);
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: ${e.toString()}'),
        backgroundColor: Colors.red,
        action: SnackBarAction(label: 'Thử lại', onPressed: _reload),
      ),
    );
  }
}
```

### 2.3: Consistency check

- [ ] Font size nhất quán (title 18-20, body 14-16)
- [ ] Color scheme nhất quán (primary blue, success green, error red)
- [ ] Padding/margin nhất quán (16px standard)
- [ ] AppBar title format nhất quán
- [ ] Button style nhất quán (ElevatedButton primary, TextButton secondary)

### Commit:

```bash
git commit -m "chore(mobile): polish UI — loading states, error handling, consistency"
```

---

## Task 3: Test End-to-End

> **QUAN TRỌNG:** Test trên ít nhất 2 thiết bị Android (1 Parent + 1 Child)
> Không dùng emulator cho phần native (UsageStats, Accessibility)

### Luồng demo chính — test từ đầu đến cuối:

| # | Bước | Expected | ✅ |
|---|------|----------|---|
| 1 | Parent: Đăng ký tài khoản mới | Thành công, vào Home | ⬜ |
| 2 | Parent: Tạo profile "Bé An" | Hiện trong danh sách | ⬜ |
| 3 | Parent: Tạo mã QR liên kết | QR code hiện lên | ⬜ |
| 4 | Child: Mở app → scan QR | Liên kết thành công | ⬜ |
| 5 | Parent: Thấy thiết bị "Online" | Green dot | ⬜ |
| 6 | Parent: Đặt giới hạn 5 phút | Lưu thành công | ⬜ |
| 7 | Child: Countdown hiện 5:00 | Đếm ngược chính xác | ⬜ |
| 8 | Child: Cảnh báo mềm 5 phút | Dialog hiện đúng mốc | ⬜ |
| 9 | Child: Xin thêm 10 phút | Dialog "Đang chờ..." | ⬜ |
| 10 | Parent: Nhận dialog xin giờ | Hiện tên con + lý do | ⬜ |
| 11 | Parent: Duyệt | Thành công | ⬜ |
| 12 | Child: Countdown +10 phút | Tăng đúng | ⬜ |
| 13 | Parent: Chặn YouTube | Toggle đỏ | ⬜ |
| 14 | Child: Mở YouTube | Bị đẩy về Home | ⬜ |
| 15 | Parent: Bỏ chặn | Toggle xanh | ⬜ |
| 16 | Child: Mở YouTube | Vào bình thường | ⬜ |
| 17 | Child: Hết giờ | Lock screen + dialog | ⬜ |
| 18 | Parent: Xem báo cáo sử dụng | Biểu đồ đúng | ⬜ |
| 19 | Parent: Nhận push notification | Thông báo "Hết giờ" | ⬜ |
| 20 | Child: Force close → mở lại | Service restart, countdown tiếp | ⬜ |

### Edge cases cần test:

| # | Case | Expected | ✅ |
|---|------|----------|---|
| E1 | Mất mạng giữa chừng | Countdown local tiếp tục | ⬜ |
| E2 | Time limit = 0 | Lock ngay lập tức | ⬜ |
| E3 | Xin giờ bị từ chối | Countdown không đổi | ⬜ |
| E4 | Parent đổi limit khi Child đang dùng | Child cập nhật real-time | ⬜ |
| E5 | Restart thiết bị | ForegroundService restart | ⬜ |

---

## Task 4: Build APK Release

> **Branch:** `release/sprint6-demo`

### 4.1: Chuẩn bị build

```bash
# Clean build
cd mobile
flutter clean
flutter pub get

# Build APK release
flutter build apk --release
```

### 4.2: Verify APK

- [ ] File APK: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Size < 50MB
- [ ] Cài được trên thiết bị Android 8+ (API 26+)
- [ ] Không crash khi mở
- [ ] Tất cả tính năng hoạt động trên APK release (không chỉ debug)

### 4.3: Kiểm tra AndroidManifest

Verify tất cả permissions đã khai báo:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Verify tất cả services/receivers có `android:exported`:

```xml
<service android:name=".services.KidFunService" android:exported="false" .../>
<service android:name=".services.AppBlockerService" android:exported="true" .../>
<receiver android:name=".receivers.KidFunDeviceAdminReceiver" android:exported="false" .../>
```

### 4.4: Test APK trên 2 thiết bị

- [ ] Thiết bị 1 (Parent): Cài APK → login → tất cả màn hình hoạt động
- [ ] Thiết bị 2 (Child): Cài APK → scan QR → native services hoạt động
- [ ] Test cross-device: Parent chặn app → Child bị chặn ngay

### Commit:

```bash
git add -A
git commit -m "release(mobile): sprint 6 demo APK build"
git push origin release/sprint6-demo
```

---

## Task 5: Chuẩn Bị Demo

### 5.1: Thiết bị demo

- [ ] Thiết bị Parent: sạc đầy, WiFi ổn định
- [ ] Thiết bị Child: sạc đầy, WiFi ổn định, đã cấp đủ 3 quyền
- [ ] Backup thiết bị: emulator (nếu thiết bị thật lỗi)

### 5.2: Tài khoản demo

```
📧 Email: demo@kidfun.app
🔑 Password: demo123
👶 Profile: Bé An
⏰ Time limits: đã set sẵn 7 ngày
📊 Usage data: 7 ngày mẫu
```

### 5.3: Kịch bản demo (5-7 phút)

1. **[Parent]** Đăng nhập → xem profile "Bé An"
2. **[Parent]** Xem báo cáo sử dụng → biểu đồ đẹp (data mẫu)
3. **[Parent]** Đặt giới hạn 3 phút cho hôm nay
4. **[Parent]** Tạo QR → **[Child]** Scan QR → Liên kết thành công
5. **[Child]** Countdown 3 phút → Soft warning
6. **[Child]** Xin thêm 5 phút → **[Parent]** Duyệt → Countdown +5 phút
7. **[Parent]** Chặn YouTube → **[Child]** Mở YouTube → Bị đẩy ra
8. **[Child]** Hết giờ → Lock screen
9. **[Parent]** Nhận push notification "Hết giờ"

### 5.4: Plan B (nếu lỗi lúc demo)

| Tình huống | Giải pháp |
|------------|-----------|
| Socket.IO disconnect | REST fallback + giải thích cho GVHD |
| Thiết bị thật lỗi | Chuyển sang emulator (đã setup sẵn) |
| Backend down | Restart Railway, có backup local (localhost:3001) |
| Push notification không đến | Show Railway logs thay thế |
| APK crash | Demo trên debug build |

---

## Checklist cuối Sprint 6 — Frontend

| # | Task | Status |
|---|------|--------|
| 1 | Fix soft warning guard flags | ⬜ |
| 2 | Fix input width giới hạn thời gian | ⬜ |
| 3 | Fix nút "Từ chối" styling | ⬜ |
| 4 | Verify /api/child/warnings không 404 | ⬜ |
| 5 | Loading states tất cả screens | ⬜ |
| 6 | Error handling UI nhất quán | ⬜ |
| 7 | E2E test 20 bước pass | ⬜ |
| 8 | Edge cases 5 bước pass | ⬜ |
| 9 | APK release build thành công | ⬜ |
| 10 | APK cài + chạy trên 2 thiết bị | ⬜ |
| 11 | Thiết bị demo sẵn sàng | ⬜ |
| 12 | Kịch bản demo đã rehearsal | ⬜ |

---

## Quy tắc Git

```bash
git checkout develop && git pull origin develop
git checkout -b fix/mobile/<tên>      # Bugfix
git checkout -b chore/mobile/<tên>    # Polish
git checkout -b release/<tên>         # Release build
git commit -m "fix(mobile): mô tả"
git push origin <branch>
# → PR → develop → Khanh review → merge
```
