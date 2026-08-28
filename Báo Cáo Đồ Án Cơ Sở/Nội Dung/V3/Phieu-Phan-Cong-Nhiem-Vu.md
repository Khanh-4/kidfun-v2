# PHIẾU PHÂN CÔNG NHIỆM VỤ
## Đồ Án Cơ Sở — KidFun: Ứng Dụng Quản Lý Sử Dụng Thiết Bị Di Động

---

## I. THÔNG TIN CHUNG

| Thông tin | Chi tiết |
|-----------|----------|
| **Trường** | Trường Đại học Công nghệ TP. HCM (HUTECH) |
| **Khoa** | Công nghệ Thông tin |
| **Ngành / Chuyên ngành** | Công nghệ Thông tin / Công nghệ Phần mềm |
| **Tên đề tài** | Ứng dụng quản lý sử dụng thiết bị di động — KidFun |
| **Giảng viên hướng dẫn** | ThS. Dương Thành Phết |
| **Nhóm** | Nhóm 8 |
| **Lớp** | 23DTHC1 |
| **Thời gian thực hiện** | Học kỳ 2 năm học 2025–2026 (10 sprint × ~1 tuần) |
| **Repository** | https://github.com/Khanh-4/kidfun-v2 |
| **Tổng Pull Request đã merge** | > 260 PR |

---

## II. DANH SÁCH THÀNH VIÊN

| STT | Họ và Tên | MSSV | Vai Trò |
|-----|-----------|------|---------|
| 1 | **Cao Duy Quốc Khánh** | 2380601019 | Trưởng nhóm — Backend Lead & Android Native Lead |
| 2 | **Đinh Bùi Tuấn Anh** | 2380600035 | Thành viên — Mobile Flutter UI Lead |

> **Phân chia mảng chính:** Khánh phụ trách toàn bộ **Backend** và **Android Native Kotlin**; Tuấn Anh phụ trách toàn bộ **Mobile Flutter UI** (màn hình, tính năng, Riverpod providers). Hai thành viên cùng nhau thiết kế hệ thống, viết tài liệu và kiểm thử end-to-end.

---

## III. PHÂN CÔNG THEO LĨNH VỰC KỸ THUẬT

### 3.1. Cao Duy Quốc Khánh — Backend + Android Native Kotlin

#### A. Backend (`backend/`)

- Thiết kế và triển khai toàn bộ REST API (hơn 60 endpoint) với kiến trúc MVC — Express.js
- Thiết kế schema Prisma ORM: **32 bảng** PostgreSQL (User, Profile, Device, Session, FCMToken, TimeLimit, UsageSession, UsageLog, AppTimeLimit, AppUsageLog, TimeExtensionRequest, BlockedWebsite, Application, BlockedApp, WebCategory, WebCategoryDomain, BlockedCategory, CategoryOverride, CustomBlockedDomain, LocationLog, Geofence, GeofenceEvent, SOSAlert, SchoolSchedule, SchoolDaySchedule, AllowedSchoolApp, YouTubeLog, AIAlert, BlockedVideo, Warning, Notification, ReportSnapshot)
- Socket.IO — cấu hình room `family_{userId}`, toàn bộ sự kiện real-time Parent ↔ Child
- Xác thực JWT (24h expiry), bcrypt salt=10, rate limiting (200 req/min global, 20 attempts/15min auth endpoint)
- Firebase Admin SDK — gửi FCM push notification (xin thêm giờ, SOS, AI alert)
- Google OAuth 2.0 — luồng đăng nhập Google (native in-app redirect)
- Tích hợp AI: Groq Cloud (Llama 4 Scout) làm provider chính + OpenRouter làm fallback — phân tích metadata YouTube
- Background workers: AI analysis worker, daily report worker, weekly report worker
- Nodemailer — gửi OTP email reset mật khẩu
- Triển khai Railway (chính) + Oracle Cloud ARM Always Free (dự phòng demo/bảo vệ)
- Viết unit test (59 test case) + integration test (10 test case) — Jest, ~90% coverage

**Controllers đảm nhiệm:** `authController`, `profileController`, `deviceController`, `timeLimitController`, `childController`, `childPolicyController`, `extensionController`, `fcmController`, `geofenceController`, `locationController`, `sosController`, `monitoringController`, `activityHistoryController`, `blockedAppController`, `blockedSiteController`, `appTimeLimitController`, `appUsageController`, `webFilteringController`, `schoolScheduleController`, `reportController`, `youtubeController`, `aiAlertController`, `warningController`, `sessionController`

#### B. Android Native Kotlin (`mobile/android/app/src/main/kotlin/`)

- `KidFunService.kt` — ForegroundService chạy nền 24/7, vòng lặp kiểm soát thời gian sử dụng
- `AppBlockerService.kt` — AccessibilityService phát hiện app foreground + redirect về Home trong < 500 ms
- `UsageStatsHelper.kt` — UsageStatsManager đọc thống kê sử dụng từng app
- `DeviceAdminReceiver.kt` — DevicePolicyManager kích hoạt `lockNow()` khoá thiết bị
- `VpnFilterService.kt` — VpnService lọc domain/danh mục web
- `NotificationListenerService.kt` — giám sát thông báo từ các app khác
- `BootReceiver.kt` — tự khởi động lại KidFunService sau khi thiết bị reboot
- MethodChannel / EventChannel bridge: 4 namespace channels kết nối Flutter ↔ Kotlin

#### C. Mobile — Core Services & Architecture (`mobile/lib/core/`)

- `core/network/dio_client.dart` — Dio HTTP client với JWT interceptor tự động đính kèm Bearer token
- `core/services/socket_service.dart` — Socket.IO client singleton, join/leave room family
- `core/services/notification_service.dart` — FCM handler + flutter_local_notifications
- `core/services/location_service.dart` — geolocator, báo cáo GPS lên backend mỗi 5 phút
- `core/services/native_service.dart` — MethodChannel gọi xuống Kotlin, EventChannel nhận sự kiện native
- `core/services/policy_service.dart`, `app_lifecycle_service.dart`, `youtube_service.dart`
- `core/storage/secure_storage.dart` — flutter_secure_storage wrapper lưu JWT vào Android Keystore
- Cấu hình go_router (tất cả routes), ProviderScope Riverpod, `app.dart`, `main.dart`
- Cấu hình build: `build.gradle`, signing keystore, `mobile/.env`, Firebase `google-services.json`

---

### 3.2. Đinh Bùi Tuấn Anh — Mobile Flutter UI

> **Phạm vi:** toàn bộ tầng presentation (màn hình + Riverpod providers) của ứng dụng Flutter — cả Parent mode lẫn Child mode.

#### Parent Mode — Màn hình phụ huynh

- **Splash Screen** — kiểm tra JWT, điều hướng tự động
- **Login / Register / ForgotPassword** — đăng ký, đăng nhập email/mật khẩu
- **Màn hình chọn chế độ** — "Tôi là Phụ huynh / Tôi là Trẻ em"
- **Quản lý hồ sơ con** — tạo/sửa/xoá hồ sơ (avatar, tên, ngày sinh), swipe-to-edit ListView
- **Quản lý thiết bị** — danh sách thiết bị con, trạng thái online/offline, nút xoá
- **Sinh mã QR liên kết** — hiển thị QR fullscreen (qr_flutter)
- **Cài đặt giới hạn thời gian** — 7 hàng ngày tuần, Switch + Slider 0–1440 phút, Gradual Reduction
- **Chặn ứng dụng** — danh sách app con (sort theo thời gian dùng), Switch bật/tắt từng app
- **Giới hạn per-app** — chọn app + đặt số phút riêng
- **Chặn website** — nhập domain / chọn danh mục
- **Chế độ Học (School Mode)** — cài lịch học + whitelist app được phép
- **Bản đồ vị trí** — Mapbox fullscreen, marker vị trí hiện tại, polyline lịch sử ngày, circle overlay geofence
- **Quản lý geofence** — tạo/sửa/xoá vùng an toàn trên bản đồ
- **Phê duyệt xin thêm giờ** — popup Dialog real-time (nhận qua Socket.IO), slider chỉnh số phút duyệt
- **Nhận cảnh báo SOS** — push priority cao, hiển thị vị trí + phát ghi âm
- **Nhận cảnh báo AI** — thông báo nội dung YouTube nguy hiểm
- **Lịch sử YouTube** — danh sách video đã xem + badge kết quả AI
- **Báo cáo thống kê** — biểu đồ fl_chart theo ngày/tuần
- **Lịch sử hoạt động** — log app/web đã sử dụng
- **Tài khoản** — cài đặt tài khoản phụ huynh, đăng xuất

#### Child Mode — Màn hình trẻ em

- **Quét QR liên kết** — camera mở mobile_scanner, kết nối với hồ sơ phụ huynh
- **Wizard cấp quyền đặc biệt** — hướng dẫn từng bước: Usage Access → Accessibility → Device Admin → Display over apps → GPS/Camera/Mic
- **Child Dashboard** — đồng hồ đếm ngược lớn ở giữa, màu gradient (xanh → vàng → cam → đỏ nhấp nháy theo remainingMinutes)
- **Soft Warning popup** — AlertDialog tại 3 mốc 30/15/5 phút + HapticFeedback + âm thanh (audioplayers)
- **Lock Screen Kiosk Mode** — fullscreen immersive sticky, ẩn StatusBar & NavigationBar, chỉ hiện nút "Xin thêm giờ"
- **Xin thêm giờ** — TextField lý do (≥ 10 ký tự), gửi qua Socket.IO, nhận phản hồi real-time, tự mở Lock Screen khi được duyệt
- **Nút SOS** — nhấn giữ 2 giây → gửi vị trí + ghi âm 5 giây

---

## IV. PHÂN CÔNG THEO SPRINT

### Sprint 1 — Setup Nền Tảng & Thiết Kế Hệ Thống

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Khảo sát thực trạng, nghiên cứu API Android (UsageStats, Accessibility, DevicePolicy, VPN, Notification) | Khánh |
| Lựa chọn tech stack toàn bộ hệ thống | Khánh |
| Khởi tạo monorepo GitHub, cấu hình feature-branch workflow, CI/CD | Khánh |
| Setup backend Railway + Supabase PostgreSQL, cấu hình `.env` | Khánh |
| Khởi tạo Flutter project, cấu hình Riverpod + go_router + Dio + `.env`, build.gradle | Khánh |
| Lập danh sách yêu cầu chức năng (FR-01 → FR-28) và phi chức năng (NFR) | Cả hai |
| Thiết kế sơ đồ Use Case, Class Diagram (32 lớp), ERD (32 bảng) | Cả hai |
| Thiết kế wireframe các màn hình mobile | Tuấn Anh |

---

### Sprint 2 — Auth + Quản Lý Hồ Sơ

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: `authController` — đăng ký/đăng nhập email/mật khẩu, JWT, bcrypt | Khánh |
| Backend: Nodemailer OTP reset mật khẩu | Khánh |
| Backend: `profileController` — CRUD hồ sơ con | Khánh |
| Backend: Prisma schema migration User, Profile (seed đầu tiên) | Khánh |
| Mobile: `secure_storage.dart` lưu JWT, `dio_client.dart` JWT interceptor | Khánh |
| Mobile: `main.dart`, `app.dart`, cấu hình go_router routes xác thực | Khánh |
| Mobile: Splash Screen (kiểm tra JWT, auto-navigate) | Tuấn Anh |
| Mobile: Màn hình Login / Register / ForgotPassword | Tuấn Anh |
| Mobile: Màn hình chọn chế độ "Tôi là Phụ huynh / Tôi là Trẻ em" | Tuấn Anh |
| Mobile: Màn hình quản lý hồ sơ con (tạo/sửa/xoá, avatar, ngày sinh) | Tuấn Anh |

---

### Sprint 3 — Quản Lý Thiết Bị + QR Liên Kết + Socket.IO

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: `deviceController` — tạo deviceCode, liên kết thiết bị, trạng thái online/offline | Khánh |
| Backend: `socketService.js` — Socket.IO rooms `family_{userId}`, sự kiện connect/disconnect, policyUpdate | Khánh |
| Backend: Prisma schema Device, Session | Khánh |
| Mobile: `socket_service.dart` — kết nối Socket.IO, join/leave room family | Khánh |
| Mobile: Màn hình quản lý thiết bị (danh sách, trạng thái online/offline, xoá) | Tuấn Anh |
| Mobile: Màn hình sinh mã QR liên kết (qr_flutter, hiển thị fullscreen) | Tuấn Anh |
| Mobile: Màn hình quét QR phía Child (camera mobile_scanner, wizard liên kết) | Tuấn Anh |

---

### Sprint 4 — Giới Hạn Thời Gian + Soft Warning + Xin Thêm Giờ ★ (USP)

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: `timeLimitController` — CRUD giới hạn theo ngày tuần (unique `[profileId, dayOfWeek]`) | Khánh |
| Backend: `extensionController` — xử lý yêu cầu xin thêm giờ | Khánh |
| Backend: Socket events xin thêm giờ end-to-end: `requestTimeExtension` → `timeExtensionRequest` → `respondTimeExtension` → `timeExtensionResponse` | Khánh |
| Backend: FCM push "Xin thêm giờ" với action button Đồng ý / Từ chối | Khánh |
| Backend: Prisma schema TimeLimit, TimeExtensionRequest | Khánh |
| Mobile: `notification_service.dart` — nhận FCM, xử lý action button phê duyệt | Khánh |
| Mobile: Màn hình cài đặt giới hạn thời gian (7 hàng ngày tuần, Switch + Slider) | Tuấn Anh |
| Mobile: Child Dashboard — đồng hồ đếm ngược màu gradient, kết nối EventChannel | Tuấn Anh |
| Mobile: Soft Warning popup + HapticFeedback + audioplayers tại 30/15/5 phút | Tuấn Anh |
| Mobile: Màn hình xin thêm giờ (TextField lý do ≥ 10 ký tự), nhận phản hồi real-time | Tuấn Anh |
| Mobile: Popup phê duyệt phía phụ huynh (Dialog real-time, slider số phút duyệt) | Tuấn Anh |

---

### Sprint 5 — Android Native + Lock Screen Kiosk Mode

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Kotlin: `KidFunService.kt` — ForegroundService chạy nền, vòng lặp kiểm soát thời gian | Khánh |
| Kotlin: `UsageStatsHelper.kt` — UsageStatsManager đọc thống kê sử dụng app | Khánh |
| Kotlin: `AppBlockerService.kt` — AccessibilityService phát hiện + redirect Home < 500ms | Khánh |
| Kotlin: `DeviceAdminReceiver.kt` — DevicePolicyManager.lockNow() khoá thiết bị | Khánh |
| Kotlin: `BootReceiver.kt` — tự khởi động lại KidFunService sau reboot | Khánh |
| Kotlin: MethodChannel / EventChannel bridge Flutter ↔ Kotlin (4 namespace channels) | Khánh |
| Mobile: `native_service.dart` — gọi MethodChannel, lắng nghe EventChannel | Khánh |
| Mobile: Lock Screen Kiosk Mode fullscreen (immersive sticky, ẩn StatusBar/NavigationBar) | Tuấn Anh |
| Mobile: Wizard cấp quyền đặc biệt (Usage Access, Accessibility, Device Admin, Display over apps) | Tuấn Anh |

---

### Sprint 6 — Demo Giữa Kỳ (Checkpoint GVHD)

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Chuẩn bị seed dữ liệu mẫu, test luồng Parent ↔ Child end-to-end trên 2 thiết bị Android thật | Cả hai |
| Sửa các lỗi phát sinh từ buổi demo | Cả hai |
| Viết báo cáo tiến độ Sprint 1–5 cho GVHD | Cả hai |
| Tinh chỉnh UX/UI sau phản hồi GVHD | Cả hai |

---

### Sprint 7 — GPS + Geofencing + SOS

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: `locationController` — nhận và lưu GPS từ thiết bị Child | Khánh |
| Backend: `geofenceController` — CRUD geofence (circle), phát hiện enter/exit, emit alert | Khánh |
| Backend: `sosController` — xử lý SOS alert, emit vào room family, FCM priority-high | Khánh |
| Backend: Prisma schema LocationLog, Geofence, GeofenceEvent, SOSAlert | Khánh |
| Mobile: `location_service.dart` — geolocator, gửi GPS mỗi 5 phút | Khánh |
| Mobile: Màn hình bản đồ Mapbox (marker vị trí, polyline lịch sử, circle overlay geofence) | Tuấn Anh |
| Mobile: Màn hình quản lý geofence — tạo/sửa/xoá vùng an toàn trên bản đồ | Tuấn Anh |
| Mobile: Nút SOS phía Child (nhấn giữ 2 giây → gửi vị trí + ghi âm 5 giây) | Tuấn Anh |
| Mobile: Màn hình nhận cảnh báo SOS phía phụ huynh | Tuấn Anh |

---

### Sprint 8 — Web Filter + School Mode + Per-app Time Limit

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Kotlin: `VpnFilterService.kt` — VpnService lọc domain/danh mục web | Khánh |
| Kotlin: `NotificationListenerService.kt` — giám sát thông báo từ các app | Khánh |
| Backend: `webFilteringController` — quản lý BlockedWebsite, WebCategory, BlockedCategory | Khánh |
| Backend: `schoolScheduleController` — SchoolSchedule, SchoolDaySchedule, AllowedSchoolApp | Khánh |
| Backend: `appTimeLimitController` + `appUsageController` — giới hạn per-app, AppTimeLimit, AppUsageLog | Khánh |
| Backend: Prisma schema 11 bảng mới (BlockedWebsite, WebCategory, WebCategoryDomain, BlockedCategory, CategoryOverride, CustomBlockedDomain, SchoolSchedule, SchoolDaySchedule, AllowedSchoolApp, AppTimeLimit, AppUsageLog) | Khánh |
| Mobile: Màn hình chặn ứng dụng (danh sách app sort theo thời gian dùng, Switch bật/tắt) | Tuấn Anh |
| Mobile: Màn hình giới hạn per-app (chọn app + đặt số phút) | Tuấn Anh |
| Mobile: Màn hình chặn website (nhập domain / chọn danh mục) | Tuấn Anh |
| Mobile: Màn hình chế độ Học (School Mode — lịch học + whitelist app) | Tuấn Anh |

---

### Sprint 9 — Reports + AI YouTube + Notification Monitoring

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: `youtubeController` — nhận YouTubeLog, kích hoạt AI worker | Khánh |
| Backend: AI worker — Groq Cloud (Llama 4 Scout) chính + OpenRouter fallback, phân tích metadata video | Khánh |
| Backend: switch AI provider Gemini → Groq + OpenRouter | Khánh |
| Backend: `reportController` — daily/weekly report snapshot (ReportSnapshot) | Khánh |
| Backend: `aiAlertController` — quản lý AIAlert, `warningController` | Khánh |
| Backend: Prisma schema YouTubeLog, AIAlert, BlockedVideo, ReportSnapshot | Khánh |
| Mobile (Kotlin): YouTube tracker qua AccessibilityService — 3-tier title extraction, debounce events, guard stale root window | Khánh |
| Mobile (Kotlin): Fix Compose UI fragment navigation, stale root window, YouTube Shorts tracking | Khánh |
| Mobile: `youtube_service.dart` — gửi YouTubeLog lên backend | Khánh |
| Mobile: Màn hình báo cáo thống kê (biểu đồ fl_chart theo ngày/tuần) | Tuấn Anh |
| Mobile: Màn hình lịch sử YouTube (danh sách video + badge kết quả AI) | Tuấn Anh |
| Mobile: Màn hình lịch sử hoạt động (log app/web đã sử dụng) | Tuấn Anh |

---

### Sprint 10 — Polish + Testing + Build APK Release + Báo Cáo

| Nhiệm vụ | Người thực hiện |
|----------|----------------|
| Backend: rate limiting 200 req/min global, 20 attempts/15min auth | Khánh |
| Backend: in-memory cache cho `calcRemaining` (heartbeat + today-limit) | Khánh |
| Backend: trust proxy cho Railway deployment | Khánh |
| Backend: seed dữ liệu demo bảo vệ | Khánh |
| Backend: fix P2025 disconnect crash, device not found emit, AI worker log spam | Khánh |
| Mobile: Google Sign-In native (in-app account picker — revert từ Chrome Custom Tab) | Khánh |
| Mobile: fix per-app limit enforcement delay, YouTube resume tracking | Khánh |
| Mobile: socket reconnect delay 5s/max 30s, heartbeat countdown sync | Khánh |
| Mobile: handle device not linked gracefully, stop polling on 404 | Khánh |
| Build APK release: `flutter build apk --split-per-abi`, ký `kidfun-release.keystore` | Khánh |
| Viết unit test backend (59 test case Jest) + integration test (10 test case) | Khánh |
| Mobile: UI/UX polish toàn bộ app — standardize error states, loading states | Tuấn Anh |
| Mobile: Màn hình tài khoản phụ huynh (đổi mật khẩu, đăng xuất) | Tuấn Anh |
| Manual end-to-end test trên 2 thiết bị Android thật (vivo iQOO Neo9 + Xiaomi Mi 11T Pro) | Cả hai |
| Viết báo cáo Đồ án Cơ sở V3 (5 chương hoàn chỉnh) | Cả hai |
| Chuẩn bị slide thuyết trình bảo vệ | Cả hai |

---

## V. THỐNG KÊ TỔNG HỢP

### 5.1. Kết quả đạt được

| Hạng mục | Số lượng |
|----------|---------|
| Tổng Pull Request đã merge | > 260 |
| Số Sprint hoàn thành | 10 / 10 |
| Màn hình Flutter | > 50 màn hình |
| Class Kotlin native | > 10 class |
| Bảng database (Prisma schema) | 32 bảng |
| REST API endpoint | > 60 endpoint |
| Use Case | 28 UC |
| Yêu cầu chức năng | 28 FR |
| Unit test backend (Jest) | 59 test case |
| Integration test API | 10 test case |
| Manual end-to-end test | 30 test case |
| Tỷ lệ test PASS | 99/100 (98.9%) |

### 5.2. Phân chia công việc tổng quan

| Thành viên | Mảng chính | Tỷ lệ ước tính |
|------------|-----------|----------------|
| Cao Duy Quốc Khánh | Backend Node.js/Express/Prisma + Android Native Kotlin + Mobile Core Services + DevOps + AI | ~60% |
| Đinh Bùi Tuấn Anh | Mobile Flutter UI — toàn bộ màn hình & Riverpod providers (Parent mode + Child mode) | ~40% |

### 5.3. Thiết bị kiểm thử

| Thiết bị | Android | Mục đích |
|----------|---------|---------|
| vivo iQOO Neo9 | Android 16 | Test thiết bị Child (Snapdragon 8 Gen 2) |
| Xiaomi Mi 11T Pro | Android 14 | Test thiết bị Parent (Dimensity 1200-Ultra) |

---

## VI. CÔNG NGHỆ SỬ DỤNG

### Mobile Flutter

| Thư viện | Phiên bản | Mục đích |
|----------|-----------|---------|
| Flutter | 3.19.x | Framework mobile chính |
| Dart | 3.3.x | Ngôn ngữ Flutter |
| flutter_riverpod | 2.x | State management |
| go_router | 13.x | Điều hướng khai báo |
| dio | 5.x | HTTP client + JWT interceptor |
| flutter_secure_storage | 9.x | Lưu JWT vào Android Keystore |
| socket_io_client | 2.x | Socket.IO real-time |
| firebase_messaging | 14.x | FCM push notification |
| mapbox_maps_flutter | 2.x | Bản đồ + geofence |
| fl_chart | 0.67.x | Biểu đồ thống kê |
| geolocator | 11.x | GPS tracking |
| qr_flutter | 4.x | Sinh mã QR |
| mobile_scanner | 5.x | Quét QR bằng camera |
| audioplayers | 5.x | Âm thanh cảnh báo mềm |

### Android Native (Kotlin)

| API Android | Mục đích |
|-------------|---------|
| UsageStatsManager | Đọc thống kê sử dụng từng app |
| AccessibilityService | Phát hiện + chặn app, YouTube tracker |
| DevicePolicyManager | Khoá thiết bị (lockNow) |
| ForegroundService | Chạy nền 24/7 |
| VpnService | Lọc domain/danh mục web |
| NotificationListenerService | Giám sát thông báo |
| MethodChannel / EventChannel | Bridge Flutter ↔ Kotlin |

### Backend

| Công nghệ | Phiên bản | Mục đích |
|-----------|-----------|---------|
| Node.js | 20.x LTS | Runtime |
| Express.js | 4.x | REST API framework |
| Prisma ORM | 5.x | Database ORM + migrations |
| PostgreSQL | 15.x | Cơ sở dữ liệu quan hệ (Supabase) |
| Socket.IO | 4.x | Real-time Parent ↔ Child |
| JSON Web Token | — | Xác thực (24h expiry) |
| bcryptjs | — | Hash mật khẩu (salt=10) |
| Firebase Admin SDK | — | FCM server-side push |
| Groq Cloud | — | Llama 4 Scout AI (provider chính) |
| OpenRouter | — | Llama 4 Scout AI (fallback) |
| Nodemailer | — | Gửi OTP email |
| express-rate-limit | — | Rate limiting chống brute force |

### Cloud & DevOps

| Dịch vụ | Mục đích |
|---------|---------|
| Railway | PaaS host backend Node.js (chính) |
| Supabase | PostgreSQL + PgBouncer |
| Oracle Cloud ARM | Backend dự phòng demo/bảo vệ |
| Firebase | FCM + Google Sign-In |
| Mapbox | Bản đồ + geofence |
| GitHub + GitHub Actions | Mã nguồn + CI/CD (npm test + flutter test) |

---

## VII. QUY TRÌNH LÀM VIỆC

### Git Workflow
- Mỗi task = 1 feature branch: `feat/<area>/<tên-task>` hoặc `fix/<area>/<tên-task>`
- Mỗi branch = 1 PR → base: `develop`
- Tuấn Anh: tạo PR → Khánh review → approve → merge
- Khánh: tạo PR → self-review → merge (bypass branch protection)
- Định kỳ merge `develop` → `main` sau kiểm thử toàn diện
- Tổng > 260 PR đã merge trong 10 sprint

### Commit Convention (Conventional Commits)
```
feat(area): mô tả chức năng mới
fix(area):  mô tả sửa lỗi
chore(area): cài đặt, cấu hình, refactor
docs:       cập nhật tài liệu
```

### Kiểm thử
- Unit test + integration test backend: Jest (~90% coverage)
- Manual end-to-end test: 2 thiết bị Android thật, kiểm thử toàn bộ luồng Parent ↔ Child
- CI: `npm test` + `flutter test` chạy tự động trên mỗi PR

---

*Thành phố Hồ Chí Minh, tháng 06 năm 2026*

*Nhóm 8 — Lớp 23DTHC1 — Trường Đại học Công nghệ TP. HCM*
