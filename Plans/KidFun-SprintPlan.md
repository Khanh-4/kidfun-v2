# KidFun V3 — Sprint Plan (10 Sprints)

> **Đồ Án Cơ Sở — Nhóm 60 HUTECH**
> **Đề tài:** Ứng dụng di động kiểm soát thời gian sử dụng thiết bị của trẻ em
> **Chuyên ngành:** Công Nghệ Phần Mềm

---

## Thông tin chung

| Mục | Chi tiết |
|-----|----------|
| **Nhóm** | 2 người |
| **Phân công** | Khanh — Backend · Bạn — Frontend/Mobile |
| **Sprint** | 10 sprints × 1 tuần |
| **Checkpoint** | Sprint 6 — GVHD đánh giá giữa kỳ |
| **Mục tiêu cuối** | Bảo vệ trước hội đồng với sản phẩm hoàn chỉnh |

### Tech Stack chốt

| Tầng | Công nghệ |
|------|-----------|
| Mobile | Flutter 3.x (Dart) + Riverpod |
| Native Android | Kotlin (UsageStats, Accessibility, DevicePolicy) |
| Backend | Node.js + Express.js |
| ORM + Database | Prisma ORM + PostgreSQL (Supabase) |
| Server | Oracle Cloud VM ARM (free vĩnh viễn) |
| Real-time | Socket.IO |
| Push Notification | Firebase Cloud Messaging |
| Maps | Google Maps Platform |
| AI | Claude API |

### Phân loại tính năng

**P0 — Must-have (Sprint 1–6, cần có để demo giữa kỳ):**
- Auth (JWT, đăng ký/đăng nhập)
- Quản lý hồ sơ trẻ (CRUD)
- Quản lý thiết bị + liên kết QR code
- Giới hạn thời gian theo ngày (7 ngày/tuần)
- Cảnh báo mềm (Soft Warning 30/15/5 phút) ★ USP
- Xin thêm giờ real-time (Socket.IO) ★ USP
- Lock screen khi hết giờ
- App usage tracking (Android — UsageStatsManager)
- App blocking cơ bản (Android — AccessibilityService)
- Backend deploy cloud (Oracle VM + Supabase PostgreSQL)
- Push notification cơ bản (FCM)

**P1 — Should-have (Sprint 7–9, hoàn thiện cho bảo vệ):**
- Per-app time limit
- School Mode
- GPS tracking + bản đồ
- Geofencing (vùng an toàn + cảnh báo)
- Nút SOS
- Web filtering (VPN Android)
- Chặn website theo danh mục
- Reports + biểu đồ thống kê
- Daily/Weekly report engine

**P2 — Nice-to-have (Sprint 10 + nếu vượt tiến độ):**
- AI Content Analysis (Claude API)
- Call/SMS/Notification monitoring
- YouTube monitoring
- iOS native (FamilyControls, ManagedSettings)
- Email báo cáo định kỳ
- i18n (Vietnamese/English)

---

## SPRINT 1 — Nền tảng & Khởi động

**Sprint Goal:** Setup toàn bộ project, deploy backend lên cloud, Flutter app chạy được trên Android thật.

### Backend (Khanh)
- [ ] Tạo repo mới cho V3 (monorepo: `backend/`, `mobile/`)
- [ ] Migration codebase V2 backend sang project mới
- [ ] Migration SQLite → PostgreSQL (Prisma schema update, thay đổi datasource)
- [ ] Setup Supabase project, lấy connection string
- [ ] Prisma migrate lên Supabase PostgreSQL
- [ ] Setup Oracle Cloud VM ARM (Ubuntu, Node.js, PM2, Nginx)
- [ ] Deploy backend lên Oracle VM, test API health check
- [ ] Setup Firebase project (FCM)
- [ ] Viết API contract document (endpoint list cho Frontend tham khảo)

### Frontend (Bạn)
- [ ] Cài Flutter SDK, Android Studio, Dart
- [ ] Tạo Flutter project (`kidfun_mobile`)
- [ ] Setup cấu trúc thư mục (features-first architecture)
- [ ] Setup Riverpod, Dio (HTTP client), go_router (navigation)
- [ ] Tạo theme, colors, typography cho app
- [ ] Build màn hình Splash + Onboarding (UI tĩnh)
- [ ] Chạy thử trên Android thật
- [ ] Đọc tài liệu: Flutter basics, Riverpod, Dio

### Deliverable Sprint 1
- ✅ Backend V2 chạy trên Oracle VM + Supabase PostgreSQL
- ✅ Flutter project chạy được trên Android thật
- ✅ API contract document

### Báo cáo tuần 1 (Phiếu tiến độ)
> Khởi tạo project mới. Backend: migration SQLite → PostgreSQL (Supabase), deploy lên Oracle Cloud VM. Frontend: setup Flutter project, cấu trúc thư mục, chạy thử trên thiết bị Android thật.

---

## SPRINT 2 — Auth & Profile Management

**Sprint Goal:** Hoàn thành luồng Auth end-to-end (đăng ký → đăng nhập → quên MK) và quản lý hồ sơ trẻ trên mobile.

### Backend (Khanh)
- [ ] Review + refactor Auth API từ V2 (đảm bảo hoạt động trên PostgreSQL)
- [ ] Thêm API: refresh token, logout
- [ ] Thêm FCM token registration API (`POST /api/fcm-tokens`)
- [ ] Setup Firebase Admin SDK cho push notification
- [ ] Test toàn bộ Auth + Profile API trên Supabase
- [ ] Deploy update lên Oracle VM

### Frontend (Bạn)
- [ ] Màn hình Login (email + password, JWT storage với flutter_secure_storage)
- [ ] Màn hình Register
- [ ] Màn hình Forgot Password
- [ ] Kết nối Auth API với Dio + Riverpod (AuthProvider, AuthState)
- [ ] Màn hình Profile List (danh sách hồ sơ con)
- [ ] Màn hình Create/Edit Profile
- [ ] Xóa profile (confirm dialog)
- [ ] Auto-login nếu có token hợp lệ
- [ ] FCM setup trong Flutter (firebase_messaging package)

### Deliverable Sprint 2
- ✅ Luồng Auth hoàn chỉnh trên mobile
- ✅ CRUD hồ sơ trẻ trên mobile
- ✅ Push notification cơ bản hoạt động

### Báo cáo tuần 2 (Phiếu tiến độ)
> Auth system hoàn chỉnh (đăng ký, đăng nhập, quên mật khẩu, JWT). Quản lý hồ sơ trẻ (tạo/sửa/xóa). Tích hợp Firebase Cloud Messaging cho push notification.

---

## SPRINT 3 — Device Management & Socket.IO

**Sprint Goal:** Liên kết thiết bị qua QR code, Socket.IO real-time hoạt động giữa Parent App và Child App.

### Backend (Khanh)
- [ ] Refactor Device API: generate QR code data (thay vì device code text)
- [ ] Socket.IO setup trên Oracle VM (Nginx WebSocket proxy config)
- [ ] Test Socket.IO qua internet (không chỉ LAN như V2)
- [ ] Mở rộng Socket.IO events: connection status, device online/offline
- [ ] API: lấy trạng thái online/offline của thiết bị con

### Frontend (Bạn)
- [ ] **Parent App:** Màn hình Device List
- [ ] **Parent App:** Tạo thiết bị mới + hiển thị QR code (qr_flutter package)
- [ ] **Parent App:** Gán thiết bị cho profile
- [ ] **Child App:** Màn hình Link Device bằng QR scan (mobile_scanner package)
- [ ] **Child App:** Màn hình Child Dashboard (hiển thị thời gian còn lại)
- [ ] Socket.IO client setup (socket_io_client package)
- [ ] Kết nối Socket.IO: joinFamily, connection status

### Deliverable Sprint 3
- ✅ Liên kết thiết bị Parent ↔ Child qua QR code
- ✅ Socket.IO real-time hoạt động qua internet
- ✅ Child App hiển thị dashboard cơ bản

### Báo cáo tuần 3 (Phiếu tiến độ)
> Quản lý thiết bị với liên kết QR code. Thiết lập Socket.IO real-time qua internet (Parent ↔ Server ↔ Child). Child App: màn hình dashboard hiển thị thông tin cơ bản.

---

## SPRINT 4 — Time Management & Soft Warning ★

**Sprint Goal:** Tính năng cốt lõi — giới hạn thời gian, cảnh báo mềm, xin thêm giờ. Đây là 2 USP chính của KidFun.

### Backend (Khanh)
- [ ] Review + test Time Limit API trên PostgreSQL
- [ ] Mở rộng Socket.IO: timeLimitUpdated event qua internet
- [ ] Bonus minutes API: approve/reject + Socket.IO response
- [ ] Warning log API (ghi nhận cảnh báo đã gửi)
- [ ] Push notification khi trẻ xin thêm giờ (FCM)
- [ ] Usage session API: start, heartbeat, end

### Frontend (Bạn)
- [ ] **Parent App:** Màn hình Time Settings (7 ngày/tuần, slider giờ)
- [ ] **Parent App:** Nhận notification xin thêm giờ + approve/reject UI
- [ ] **Child App:** Countdown timer real-time (đếm ngược thời gian còn lại)
- [ ] **Child App:** Soft Warning system — hiển thị cảnh báo ở mốc 30/15/5 phút ★
- [ ] **Child App:** Xin thêm giờ UI (nhập lý do, gửi qua Socket.IO) ★
- [ ] **Child App:** Nhận response approve/reject real-time
- [ ] **Child App:** Session management (heartbeat mỗi 60s)

### Deliverable Sprint 4
- ✅ Giới hạn thời gian hoạt động end-to-end
- ✅ Cảnh báo mềm 30/15/5 phút ★
- ✅ Xin thêm giờ real-time ★
- ✅ Push notification khi trẻ xin giờ

### Báo cáo tuần 4 (Phiếu tiến độ)
> Tính năng cốt lõi: giới hạn thời gian theo ngày, hệ thống cảnh báo mềm (Soft Warning) ở mốc 30/15/5 phút, xin thêm giờ real-time qua Socket.IO với push notification.

---

## SPRINT 5 — Native Android & Lock Screen

**Sprint Goal:** Tích hợp Android native APIs — theo dõi app usage, chặn app, lock screen. Child App hoạt động như app parental control thực thụ.

### Backend (Khanh)
- [ ] App usage log API: `POST /api/child/app-usage` (nhận batch usage data)
- [ ] App blocking API: CRUD blacklist/whitelist theo profile
- [ ] Blocked apps sync API cho Child App
- [ ] Usage log query API cho Parent App (theo ngày, theo app)
- [ ] Gradual reduction logic (giảm dần thời gian)

### Frontend (Bạn)
- [ ] **Android Native (Kotlin):** UsageStatsManager — thu thập app usage data
- [ ] **Android Native (Kotlin):** AccessibilityService — phát hiện app foreground + chặn app
- [ ] **Android Native (Kotlin):** DevicePolicyManager — lock screen khi hết giờ
- [ ] **Android Native (Kotlin):** ForegroundService — chạy nền 24/7
- [ ] **Child App:** Lock screen fullscreen (kiosk mode) khi hết giờ
- [ ] **Child App:** Gửi app usage data lên backend (batch sync)
- [ ] **Parent App:** Màn hình App Blocking (blacklist/whitelist)
- [ ] Flutter ↔ Kotlin communication qua MethodChannel/EventChannel

### Deliverable Sprint 5
- ✅ Android native: theo dõi app usage, chặn app, lock screen
- ✅ Child App chạy nền liên tục (foreground service)
- ✅ Parent quản lý danh sách app bị chặn

### Báo cáo tuần 5 (Phiếu tiến độ)
> Tích hợp Android native APIs: UsageStatsManager (theo dõi ứng dụng), AccessibilityService (chặn app), DevicePolicyManager (khóa màn hình), ForegroundService (chạy nền 24/7). Parent App: quản lý danh sách chặn ứng dụng.

---

## SPRINT 6 — Demo Giữa Kỳ ★ CHECKPOINT

**Sprint Goal:** Hoàn thiện, test, fix bug. Đảm bảo luồng chính chạy mượt cho GVHD đánh giá. Chuẩn bị demo.

### Backend (Khanh)
- [ ] Fix tất cả bug từ Sprint 1–5
- [ ] API error handling + validation hoàn chỉnh
- [ ] Test toàn bộ API (manual + Postman collection)
- [ ] Đảm bảo Oracle VM + Supabase ổn định
- [ ] Seed data cho demo (tài khoản demo, profile demo, usage data mẫu)
- [ ] Viết tài liệu API (Swagger/Postman)

### Frontend (Bạn)
- [ ] Fix tất cả bug UI/UX từ Sprint 1–5
- [ ] Test end-to-end trên Android thật: Auth → Profile → Device → Time Limit → Soft Warning → Xin giờ → Lock Screen
- [ ] Polish UI: loading states, error messages, empty states
- [ ] Build APK cho demo
- [ ] Test trên ít nhất 2 thiết bị Android (Parent + Child)

### Deliverable Sprint 6 (Demo cho GVHD)
- ✅ **Luồng demo chính:** Phụ huynh đăng nhập → tạo profile → tạo thiết bị → trẻ scan QR → đặt giới hạn giờ → trẻ dùng → nhận cảnh báo mềm 30/15/5 phút → xin thêm giờ → phụ huynh duyệt/từ chối → hết giờ → lock screen
- ✅ App usage tracking hoạt động
- ✅ App blocking hoạt động
- ✅ Push notification hoạt động
- ✅ APK chạy trên thiết bị thật

### Báo cáo tuần 6 (Phiếu tiến độ)
> **Đánh giá giữa kỳ.** Hoàn thiện và kiểm thử toàn bộ tính năng cốt lõi. Demo luồng chính end-to-end trên thiết bị Android thật: Auth, quản lý hồ sơ/thiết bị, giới hạn thời gian, cảnh báo mềm, xin thêm giờ real-time, khóa màn hình, theo dõi & chặn ứng dụng, push notification. Hoàn thành: __% (GVHD đánh giá).

---

## SPRINT 7 — GPS, Geofencing & SOS

**Sprint Goal:** Tính năng vị trí & an toàn — GPS tracking, geofencing, nút SOS.

### Backend (Khanh)
- [ ] Location models: LocationLog, Geofence, GeofenceEvent, SOSAlert (Prisma migrate)
- [ ] Location API: `POST /api/child/location` (nhận GPS từ Child)
- [ ] Location query API: lấy vị trí hiện tại + lịch sử
- [ ] Geofence CRUD API
- [ ] Geofence event processing: kiểm tra ENTER/EXIT dựa trên GPS + radius
- [ ] SOS Alert API: nhận SOS + push notification ngay cho Parent
- [ ] Socket.IO: location updates, SOS alerts real-time

### Frontend (Bạn)
- [ ] **Child App:** GPS tracking service (geolocator package, chạy nền)
- [ ] **Child App:** Gửi GPS lên backend định kỳ
- [ ] **Child App:** Nút SOS — gửi vị trí + alert
- [ ] **Parent App:** Màn hình Map — hiển thị vị trí trẻ real-time (google_maps_flutter)
- [ ] **Parent App:** Geofence UI — tạo/sửa/xóa vùng an toàn trên bản đồ
- [ ] **Parent App:** Nhận SOS alert (push notification + in-app alert)
- [ ] **Parent App:** Location history trên bản đồ

### Deliverable Sprint 7
- ✅ GPS tracking real-time trên bản đồ
- ✅ Geofencing (tạo vùng an toàn, cảnh báo khi ra khỏi)
- ✅ Nút SOS khẩn cấp

### Báo cáo tuần 7 (Phiếu tiến độ)
> GPS tracking real-time hiển thị trên Google Maps. Geofencing: tạo vùng an toàn, cảnh báo khi trẻ ra khỏi vùng. Nút SOS khẩn cấp gửi vị trí + alert cho phụ huynh qua push notification.

---

## SPRINT 8 — Web Filtering, School Mode & Per-app Limits

**Sprint Goal:** Mở rộng quản lý — lọc web, chế độ học tập, giới hạn theo từng app.

### Backend (Khanh)
- [ ] AppTimeLimit model + API: CRUD per-app time limit
- [ ] SchoolSchedule + AllowedSchoolApp models + API
- [ ] WebCategory + BlockedCategory models + API
- [ ] Custom URL blacklist/whitelist API (mở rộng từ V2 BlockedWebsite)
- [ ] School Mode logic: kiểm tra lịch học + app whitelist

### Frontend (Bạn)
- [ ] **Android Native (Kotlin):** VpnService — web content filtering (chặn domain)
- [ ] **Parent App:** Màn hình Per-app Time Limit (chọn app + đặt giờ)
- [ ] **Parent App:** Màn hình School Mode (đặt lịch học + app được phép)
- [ ] **Parent App:** Màn hình Web Filtering (danh mục + custom URL)
- [ ] **Child App:** Nhận + áp dụng per-app limit
- [ ] **Child App:** School Mode activation (chỉ cho phép app trong whitelist)
- [ ] **Child App:** VPN web filter hoạt động

### Deliverable Sprint 8
- ✅ Per-app time limit
- ✅ School Mode
- ✅ Web filtering qua VPN

### Báo cáo tuần 8 (Phiếu tiến độ)
> Giới hạn thời gian theo từng ứng dụng (per-app time limit). Chế độ học tập (School Mode) — chỉ cho phép app học tập trong giờ học. Lọc nội dung web qua VPN (chặn theo danh mục + custom URL).

---

## SPRINT 9 — Reports, AI Analysis & Monitoring

**Sprint Goal:** Báo cáo thống kê + AI content analysis + giám sát giao tiếp.

### Backend (Khanh)
- [ ] Daily/Weekly report generation engine (cron job hoặc node-schedule)
- [ ] Report API: summary data cho biểu đồ (app usage, screen time, location)
- [ ] NotificationLog model + API
- [ ] AI pipeline: Claude API integration — phân tích nội dung notification
- [ ] AIAnalysis + AIAlert models + API
- [ ] Danger classification logic (BULLY, SEXUAL, DRUG, VIOLENCE, SELF_HARM)
- [ ] Auto-alert cho Parent khi phát hiện nội dung nguy hiểm
- [ ] (Nếu kịp) CallLog, SMSLog models + API

### Frontend (Bạn)
- [ ] **Android Native (Kotlin):** NotificationListenerService — capture all notifications
- [ ] **Parent App:** Màn hình Reports — biểu đồ app usage, screen time (fl_chart package)
- [ ] **Parent App:** Màn hình Activity History
- [ ] **Parent App:** Màn hình AI Alerts — danh sách cảnh báo nguy hiểm
- [ ] **Parent App:** Notification log viewer
- [ ] **Child App:** Gửi notification data lên backend
- [ ] (Nếu kịp) **Android Native:** CallLog + SMS reader
- [ ] (Nếu kịp) **Parent App:** Call/SMS log viewer

### Deliverable Sprint 9
- ✅ Reports với biểu đồ thống kê
- ✅ AI Content Analysis hoạt động
- ✅ Notification monitoring
- ✅ (Bonus) Call/SMS monitoring

### Báo cáo tuần 9 (Phiếu tiến độ)
> Báo cáo thống kê hàng ngày/tuần với biểu đồ (app usage, screen time). AI Content Analysis tích hợp Claude API — phân tích notification, phát hiện nội dung nguy hiểm, tự động cảnh báo phụ huynh. Giám sát notification từ tất cả ứng dụng.

---

## SPRINT 10 — Polish, Testing & Bảo vệ

**Sprint Goal:** Hoàn thiện toàn bộ, test kỹ, chuẩn bị bảo vệ trước hội đồng.

### Backend (Khanh)
- [ ] Fix tất cả bug còn lại
- [ ] Performance optimization: caching, rate limiting, query optimization
- [ ] Security audit: input validation, SQL injection, JWT security
- [ ] API documentation hoàn chỉnh (Swagger)
- [ ] Load testing cơ bản
- [ ] Seed data đẹp cho demo bảo vệ
- [ ] Backup database strategy

### Frontend (Bạn)
- [ ] Fix tất cả bug UI/UX
- [ ] UI polish: animation, transition, responsive
- [ ] Test trên nhiều thiết bị Android (khác nhau kích thước màn hình)
- [ ] Build APK release (signed)
- [ ] (Nếu kịp) iOS Parent App build qua Codemagic
- [ ] Chuẩn bị demo flow cho bảo vệ

### Cả nhóm
- [ ] Viết báo cáo đồ án
- [ ] Chuẩn bị slide thuyết trình
- [ ] Rehearse demo
- [ ] Test end-to-end toàn bộ tính năng

### Deliverable Sprint 10 (Bảo vệ hội đồng)
- ✅ Sản phẩm hoàn chỉnh chạy trên Android thật
- ✅ Toàn bộ tính năng P0 + P1 hoạt động
- ✅ P2 (AI, monitoring) hoạt động (tuỳ tiến độ Sprint 9)
- ✅ APK release
- ✅ Báo cáo đồ án
- ✅ Slide thuyết trình

### Báo cáo tuần 10 (Phiếu tiến độ)
> Hoàn thiện toàn bộ tính năng. Kiểm thử end-to-end, tối ưu hiệu năng, kiểm tra bảo mật. Build APK release. Hoàn thành báo cáo đồ án và slide thuyết trình. Sẵn sàng bảo vệ trước hội đồng.

---

## Tổng quan tiến độ

```
Sprint  1  ██░░░░░░░░  Nền tảng & Khởi động
Sprint  2  ████░░░░░░  Auth & Profile
Sprint  3  ██████░░░░  Device & Socket.IO
Sprint  4  ████████░░  Time Management & Soft Warning ★
Sprint  5  ██████████  Native Android & Lock Screen
Sprint  6  ██████████  ★ CHECKPOINT — Demo giữa kỳ
Sprint  7  ██████████  GPS, Geofencing & SOS
Sprint  8  ██████████  Web Filter, School Mode, Per-app
Sprint  9  ██████████  Reports, AI & Monitoring
Sprint 10  ██████████  Polish & Bảo vệ
```

### Nguyên tắc vượt tiến độ
- Hoàn thành sprint hiện tại sớm → kéo task sprint tiếp theo vào làm
- Ghi nhận rõ trong báo cáo tuần: "Hoàn thành Sprint X + bắt đầu Sprint X+1"
- Vượt tiến độ = nhiều thời gian hơn cho Sprint 10 (polish + test kỹ hơn)

---

## Ghi chú kỹ thuật

### Backend — Khanh
- Prisma schema V2 giữ nguyên 10 models, thêm dần models mới theo sprint
- Oracle VM: dùng PM2 để quản lý process, Nginx reverse proxy + WebSocket
- Supabase: chỉ dùng PostgreSQL, không dùng Supabase Auth/Realtime
- FCM: Firebase Admin SDK gửi push notification server-side

### Frontend — Bạn
- Flutter architecture: features-first (`lib/features/auth/`, `lib/features/profile/`...)
- State management: Riverpod (StateNotifier + AsyncNotifier)
- HTTP: Dio + interceptor (auto attach JWT, refresh token)
- Navigation: go_router
- Native Android: Kotlin code trong `android/app/src/main/kotlin/`
- Flutter ↔ Kotlin: MethodChannel + EventChannel

### Tài liệu tham khảo Flutter (cho bạn Frontend)
- Flutter docs: https://docs.flutter.dev
- Riverpod docs: https://riverpod.dev
- Android UsageStatsManager: https://developer.android.com/reference/android/app/usage/UsageStatsManager
- Android AccessibilityService: https://developer.android.com/reference/android/accessibilityservice/AccessibilityService
