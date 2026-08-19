# Sprint 5 — Flow Test Plan
> **KidFun v2 — Native Android & Lock Screen**
> Ngày tạo: 2026-03-22

---

## Chuẩn bị trước khi test

- [ ] Build và cài app lên **thiết bị thật** (không dùng emulator cho UsageStats/Accessibility)
- [ ] Backend đang chạy và có thể kết nối từ thiết bị
- [ ] Đã có tài khoản phụ huynh + profile con + thiết bị con đã link
- [ ] Thiết bị con đã cài app KidFun bản mới nhất

---

## Flow 1: MethodChannel hoạt động

**Mục tiêu:** Xác nhận Flutter ↔ Kotlin giao tiếp được qua channel `com.kidfun.native`

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 1.1 | Mở app KidFun trên thiết bị con (role Child) | App khởi động bình thường, không crash |
| 1.2 | Kiểm tra logcat: tìm `[USAGE]`, `[BLOCKED]`, `[LOCK]` | Không có `MissingPluginException` |
| 1.3 | Kiểm tra logcat: tìm `startForegroundService` | Không có lỗi method not found |

---

## Flow 2: ForegroundService chạy nền

**Mục tiêu:** Service chạy 24/7, hiện notification, không bị kill

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 2.1 | Mở app Child Dashboard | Notification "KidFun đang hoạt động — Đang giám sát thiết bị" xuất hiện trong status bar |
| 2.2 | Vuốt app xuống background | Notification vẫn còn |
| 2.3 | Mở Recent Apps → swipe kill app | Notification vẫn còn (START_STICKY restart service) |
| 2.4 | Vào **Settings → Apps → KidFun → Battery** | Cho phép chạy background / tắt battery optimization |
| 2.5 | Restart thiết bị → mở lại app | Service tự start lại khi app mở |

---

## Flow 3: UsageStats Permission + Thu thập dữ liệu

**Mục tiêu:** App đọc được usage data và gửi lên server đúng

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 3.1 | Mở Child Dashboard lần đầu (chưa cấp quyền UsageStats) | Không crash; `hasUsageStatsPermission` trả về false, sync bị skip |
| 3.2 | Vào **Settings → Apps → Special app access → Usage access → KidFun** → bật ON | Quyền được cấp |
| 3.3 | Dùng YouTube/Chrome/Zalo khoảng **3–5 phút** | App được sử dụng |
| 3.4 | Chờ 5 phút (timer sync) hoặc force restart Child Dashboard | Log `[USAGE] Synced X apps to server` xuất hiện |
| 3.5 | **[Parent App]** Vào Profile → Báo cáo sử dụng → tab "Hôm nay" | Thấy YouTube/Chrome/Zalo với thời gian đúng |
| 3.6 | Kiểm tra tab "7 ngày qua" | Hiển thị top apps trong 7 ngày gần nhất |

---

## Flow 4: Accessibility Service + Chặn App

**Mục tiêu:** Parent chặn app → Child mở bị đẩy về Home

### 4a: Cấp quyền Accessibility

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4a.1 | Vào **Settings → Accessibility → Installed services → KidFun** | Thấy KidFun App Blocker trong danh sách |
| 4a.2 | Bật ON | Confirm dialog hiện ra → nhấn Allow |
| 4a.3 | Quay lại app | `isAccessibilityEnabled` trả về true trong logcat |

### 4b: Parent chặn app

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4b.1 | **[Parent App]** Vào Profile → Chặn app | Màn hình hiển thị danh sách apps đã dùng hôm nay |
| 4b.2 | Tìm YouTube → bật toggle "Chặn" | Toggle chuyển sang đỏ, loading indicator rồi xác nhận |
| 4b.3 | Backend: `POST /api/profiles/:id/blocked-apps` | Response 201, `blockedApp` được lưu vào DB |
| 4b.4 | **[Child Device]** Logcat: `blockedAppsUpdated` | `[BLOCKED] Synced 1 blocked apps` |
| 4b.5 | **[Child Device]** Mở YouTube | Bị đẩy ngay về Home Screen (< 1 giây) |
| 4b.6 | Thử mở YouTube lần 2 | Vẫn bị chặn |

### 4c: Parent bỏ chặn

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 4c.1 | **[Parent App]** Tắt toggle YouTube | Toggle chuyển về bình thường |
| 4c.2 | **[Child Device]** Chờ socket event `blockedAppsUpdated` | `[BLOCKED] Synced 0 blocked apps` |
| 4c.3 | **[Child Device]** Mở YouTube | Vào bình thường, không bị chặn |

---

## Flow 5: DevicePolicyManager + Lock Screen

**Mục tiêu:** Khi hết giờ, màn hình thiết bị con bị khóa ngay lập tức

### 5a: Cấp quyền Device Admin

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5a.1 | Lần đầu gọi `lockScreen` (khi hết giờ) | Mở dialog "Kích hoạt Device Admin" |
| 5a.2 | Nhấn **Kích hoạt** | KidFun được thêm vào Device Admins |
| 5a.3 | Kiểm tra: **Settings → Security → Device Admin Apps** | Thấy KidFun trong danh sách |

### 5b: Lock screen khi hết giờ

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5b.1 | **[Parent App]** Đặt time limit 2 phút cho profile con | Limit được lưu |
| 5b.2 | **[Child Device]** Mở Child Dashboard → chờ đếm ngược | Countdown hiện đúng |
| 5b.3 | Countdown đến 0 | Màn hình thiết bị **bị khóa ngay lập tức** (lock screen native) |
| 5b.4 | Mở khóa điện thoại bằng PIN/vân tay | Vào lại app, dialog "⏰ Hết giờ!" vẫn hiện (backup) |
| 5b.5 | Logcat: `[LOCK]` | Không có `lockScreen error` |

### 5c: Lock screen khi Device Admin chưa cấp

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 5c.1 | Revoke Device Admin → để hết giờ | `lockScreen` trả về false, dialog Admin xuất hiện |
| 5c.2 | Dialog "⏰ Hết giờ!" vẫn hiện | Fallback dialog chặn tương tác vẫn hoạt động |

---

## Flow 6: Blocked Apps Sync Real-time (Socket.IO)

**Mục tiêu:** Khi Parent thay đổi, Child cập nhật ngay không cần restart

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 6.1 | Child Dashboard đang mở, socket connected | Green dot hiện |
| 6.2 | **[Parent]** Chặn app mới (VD: TikTok) | Server emit `blockedAppsUpdated` |
| 6.3 | **[Child]** Logcat trong vòng 1–2 giây | `blockedAppsUpdated received — re-syncing blocked apps` |
| 6.4 | **[Child]** Thử mở TikTok | Bị chặn ngay, không cần restart app |
| 6.5 | **[Parent]** Bỏ chặn TikTok | Child nhận event, TikTok vào được bình thường |

---

## Flow 7: Parent App Blocking UI

**Mục tiêu:** UI chặn app và báo cáo hoạt động đúng

### 7a: Màn hình Chặn App

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7a.1 | **[Parent]** Profiles → chọn profile → nhấn "Chặn app" | Màn hình AppBlockingScreen mở |
| 7a.2 | Chưa có usage data | Empty state: "Chưa có dữ liệu app" với hướng dẫn |
| 7a.3 | Sau khi Child gửi usage data | Danh sách apps hiện ra, sắp xếp theo thời gian dùng |
| 7a.4 | Section "Đang bị chặn" | Apps đã block hiển thị riêng ở trên, màu đỏ |
| 7a.5 | Kéo refresh | Reload dữ liệu mới nhất |
| 7a.6 | Toggle block → loading spinner → done | Toggle chuyển màu đúng, không bị double-tap |

### 7b: Màn hình Báo cáo Sử dụng

| # | Bước | Kết quả kỳ vọng |
|---|------|-----------------|
| 7b.1 | **[Parent]** Profiles → chọn profile → nhấn "Báo cáo sử dụng" | AppUsageReportScreen mở với 2 tabs |
| 7b.2 | Tab "Hôm nay" | Danh sách top apps, có thanh progress bar màu sắc |
| 7b.3 | Mỗi app hiện: tên, package, thời gian, % tổng | Dữ liệu đúng với thực tế |
| 7b.4 | Nhấn "Đổi ngày" → chọn hôm qua | Reload đúng ngày |
| 7b.5 | Tab "7 ngày qua" | Top 10 apps tổng hợp 7 ngày qua |
| 7b.6 | Kéo refresh tab "7 ngày qua" | Dữ liệu reload |

---

## Flow 8: Full Integration Test

**Mục tiêu:** Toàn bộ luồng từ đầu đến cuối hoạt động cùng nhau

| # | Kịch bản | Kết quả kỳ vọng |
|---|----------|-----------------|
| 8.1 | Fresh install → mở app Child → cấp đủ 3 quyền (UsageStats, Accessibility, Device Admin) | Không crash ở bất kỳ bước nào |
| 8.2 | Child dùng YouTube 5 phút → đợi 5 phút sync | Parent thấy "YouTube: 5 phút" trong báo cáo |
| 8.3 | Parent chặn YouTube → Child thử mở | Bị đẩy về Home ngay |
| 8.4 | Parent đặt giới hạn 3 phút → đợi hết giờ | Lock screen + dialog hết giờ |
| 8.5 | Parent xin thêm 10 phút từ app → Child nhận | Countdown reset +10 phút, lock screen mở |
| 8.6 | Kill app Child → mở lại | ForegroundService đã restart, countdown tiếp tục đúng |
| 8.7 | Tắt WiFi (offline) → đợi kết nối lại | Red dot → Green dot; dữ liệu sync lại |

---

## Lỗi thường gặp & Cách xử lý

| Lỗi | Nguyên nhân | Fix |
|-----|-------------|-----|
| `MissingPluginException: No implementation found for method getAppUsage` | Channel name sai hoặc chưa build native | Clean build: `flutter clean && flutter build apk` |
| `UsageStats trả về empty` | Chưa cấp quyền PACKAGE_USAGE_STATS | Vào Settings → Usage Access → bật KidFun |
| `AccessibilityService không chặn app` | Service chưa được bật trong Settings | Settings → Accessibility → KidFun → ON |
| `lockScreen không làm gì` | Device Admin chưa được cấp | Settings → Security → Device Admins → tick KidFun |
| `blockedAppsUpdated không nhận` | Socket không connected | Kiểm tra green dot trên Child Dashboard |
| App bị crash khi toggle block | Network error hoặc profileId sai | Kiểm tra token còn hạn, backend running |
| ForegroundService bị kill sau vài phút | Battery optimization bật | Settings → Battery → KidFun → Unrestricted |

---

## Checklist cuối Sprint 5 — Frontend

| # | Hạng mục | ✅ |
|---|----------|----|
| 1 | MethodChannel không crash | ⬜ |
| 2 | ForegroundService hiện notification 24/7 | ⬜ |
| 3 | UsageStats thu thập đúng (> 1 phút) | ⬜ |
| 4 | Usage data sync lên server mỗi 5 phút | ⬜ |
| 5 | AccessibilityService chặn app ngay lập tức | ⬜ |
| 6 | blockedAppsUpdated cập nhật real-time | ⬜ |
| 7 | DevicePolicyManager lock screen khi hết giờ | ⬜ |
| 8 | Fallback dialog vẫn hiện nếu chưa có Device Admin | ⬜ |
| 9 | Parent: App Blocking UI toggle đúng | ⬜ |
| 10 | Parent: Báo cáo sử dụng hiện đúng dữ liệu | ⬜ |
| 11 | Full flow 8.1 → 8.7 pass hết | ⬜ |
