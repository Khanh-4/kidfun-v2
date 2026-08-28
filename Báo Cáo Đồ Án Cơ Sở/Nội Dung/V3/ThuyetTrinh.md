# THUYẾT TRÌNH ĐỒ ÁN CƠ SỞ — KIDFUN
## Nội dung 10–12 Slides (bao gồm slide Class Diagram riêng)

---

## SLIDE 1 — TỔNG QUAN ĐỀ TÀI

**Tiêu đề chính:**
> # KidFun
> ### Ứng Dụng Quản Lý Sử Dụng Thiết Bị Di Động

**Thông tin:**

| | |
|---|---|
| **Trường** | Trường Đại học Công nghệ TP. HCM (HUTECH) |
| **Khoa / Ngành** | Công nghệ Thông tin — Công nghệ Phần mềm |
| **GVHD** | ThS. Dương Thành Phết |
| **Nhóm** | Nhóm 8 — Lớp 23DTHC1 |
| **Sinh viên** | Cao Duy Quốc Khánh (2380601019) |
| | Đinh Bùi Tuấn Anh (2380600035) |

**Ghi chú trình bày:**
- Slide này đặt ảnh chụp màn hình app (Parent mode + Child mode) ở nửa phải để tạo ấn tượng đầu tiên.
- Nhấn mạnh tên sản phẩm và tagline: *"Kiểm soát thông minh — Cảnh báo nhẹ nhàng"*.

---

## SLIDE 2 — PHÂN TÍCH THỊ TRƯỜNG & ĐỐI THỦ

**Tiêu đề:** So sánh tính năng (Feature Matrix)

**Bảng ma trận tính năng:**

| Tiêu chí | Google Family Link | Kaspersky Safe Kids | Qustodio | **KidFun** |
|---|:---:|:---:|:---:|:---:|
| Giao diện tiếng Việt | Một phần | ✗ | ✗ | **✓** |
| Hoàn toàn miễn phí | ✓ | ✗ (có phí Pro) | ✗ (có phí) | **✓** |
| Soft Warning (cảnh báo dần) | ✗ | ✗ | ✗ | **✓** |
| Trẻ xin thêm giờ real-time | Hạn chế | ✗ | ✗ | **✓** |
| Nút SOS khẩn cấp | ✗ | ✗ | ✗ | **✓** |
| AI phân tích YouTube | ✗ | ✗ | ✗ | **✓** |
| Lọc web bằng VPN | ✓ | ✓ | ✓ | **✓** |
| Chế độ học bài (School Mode) | Cơ bản | ✗ | ✓ | **✓** |
| Tối ưu cho thị trường Việt Nam | ✗ | ✗ | ✗ | **✓** |

**Điểm nổi bật để nhấn:** KidFun là giải pháp duy nhất trong bảng có **cả 9 tiêu chí** — đặc biệt là 3 tính năng không đối thủ nào có: **Soft Warning + Xin thêm giờ real-time + SOS**.

---

## SLIDE 3 — BÀI TOÁN & GIẢI PHÁP

**Tiêu đề:** Vấn đề — Giải pháp

### Bài toán (trái slide):
- **80%** phụ huynh Việt Nam lo ngại con sử dụng thiết bị quá mức nhưng thiếu công cụ phù hợp.
- Các giải pháp hiện có trên thị trường:
  - Giao diện tiếng Anh → phụ huynh không quen dùng
  - Yêu cầu phí hàng tháng → rào cản tài chính
  - Cắt quyền truy cập **đột ngột** → trẻ phản ứng tiêu cực, không học cách tự quản lý

### Giải pháp — KidFun (phải slide):
- **Triết lý "Soft Warning":** Cảnh báo dần dần tại mốc 30 phút / 15 phút / 5 phút thay vì cắt đột ngột.
- **Giao tiếp 2 chiều thời gian thực:** Trẻ gửi yêu cầu xin thêm giờ kèm lý do → phụ huynh nhận thông báo ngay trên điện thoại và phê duyệt/từ chối tức thì.
- **Dành riêng cho Việt Nam:** Giao diện tiếng Việt, miễn phí hoàn toàn.
- **Tích hợp AI:** Tự động phân tích nội dung YouTube trẻ xem, cảnh báo video không phù hợp.

---

## SLIDE 4 — SƠ ĐỒ USE CASE TỔNG QUAN

**Tiêu đề:** Sơ đồ Use Case — Tổng quan hệ thống

**Nội dung:**
- Chèn hình: `diagrams/Hinh-3.2.1.1-UseCase-TongQuan.png`
- Sơ đồ bao gồm **3 tác nhân** chính:
  - **Phụ huynh (Parent):** Quản lý hồ sơ con, cấu hình giới hạn, theo dõi vị trí, xem báo cáo, phê duyệt xin thêm giờ, nhận cảnh báo SOS/AI.
  - **Trẻ em (Child):** Sử dụng thiết bị trong giới hạn, xin thêm giờ, gửi SOS.
  - **Hệ thống (System/AI):** Phân tích YouTube, sinh báo cáo tự động, gửi push notification.

**Ghi chú trình bày:**
- Giới thiệu nhanh qua sơ đồ tổng quát, không đọc từng Use Case.
- Nhấn mạnh tổng cộng có **hơn 25 chức năng** được hệ thống hỗ trợ.

---

## SLIDE 5 — SƠ ĐỒ ACTIVITY: LUỒNG XIN THÊM GIỜ

**Tiêu đề:** Sơ đồ Activity — Luồng "Xin Thêm Giờ" (Tính năng đặc trưng)

**Nội dung:**
- Chèn hình: `diagrams/Hinh-3.5.3.1-Activity-XinThemGio.png`

**Tại sao chọn luồng này:**
- Đây là tính năng **đặc trưng nhất** của KidFun — không đối thủ nào có.
- Thể hiện sự phức tạp về mặt nghiệp vụ: giao tiếp 2 thiết bị, có timeout, có trường hợp từ chối/phê duyệt.
- Liên quan trực tiếp đến triết lý Soft Warning.

**Luồng chính (tóm tắt bằng lời):**
1. Trẻ chạm nút "Xin thêm giờ" → nhập lý do.
2. Backend lưu yêu cầu → gửi FCM push đến điện thoại phụ huynh.
3. Phụ huynh mở thông báo → phê duyệt hoặc từ chối.
4. Socket.IO đẩy kết quả về thiết bị trẻ ngay lập tức.
5. Nếu phê duyệt → cộng thêm giờ; từ chối → giữ nguyên khoá.

---

## SLIDE 6 — SƠ ĐỒ SEQUENCE: LUỒNG XIN THÊM GIỜ

**Tiêu đề:** Sơ đồ Sequence — Trình tự tương tác "Xin Thêm Giờ"

**Nội dung:**
- Chèn hình: `diagrams/Hinh-3.4.4.1-Sequence-XinThemGio.png`

**Các đối tượng tham gia:**
- `Child App` → `Backend API` → `Socket.IO` → `Parent App` → `FCM Service`

**Điểm nhấn kỹ thuật:**
- Sử dụng **Socket.IO** cho real-time 2 chiều (dưới 1 giây).
- **Firebase FCM** làm kênh dự phòng khi app phụ huynh đang chạy nền/đóng.
- Backend validate trạng thái yêu cầu để tránh approve trùng hoặc race condition.

---

## SLIDE 7 — THIẾT KẾ CƠ SỞ DỮ LIỆU (ERD)

**Tiêu đề:** Thiết kế Cơ sở Dữ liệu — 32 bảng, PostgreSQL

**Nội dung:** *(chèn ERD hoặc trình bày theo nhóm domain)*

**Các nhóm bảng chính:**

| Nhóm | Bảng tiêu biểu |
|---|---|
| **Core / Auth** | User, Profile, Device, Session, FCMToken |
| **Thời gian & Sử dụng** | TimeLimit, UsageSession, AppUsageLog, TimeExtensionRequest |
| **Chặn nội dung** | BlockedApp, BlockedWebsite, WebCategory, BlockedCategory |
| **Vị trí & An toàn** | LocationLog, Geofence, GeofenceEvent, SOSAlert |
| **Chế độ học bài** | SchoolSchedule, SchoolDaySchedule, AllowedSchoolApp |
| **YouTube & AI** | YouTubeLog, AIAlert, BlockedVideo |
| **Báo cáo** | Warning, Notification, ReportSnapshot |

**Điểm nhấn:**
- **32 bảng** được thiết kế theo domain-driven approach.
- Ràng buộc quan trọng: `TimeLimit` có unique constraint `[profileId, dayOfWeek]` đảm bảo mỗi hồ sơ chỉ có 1 giới hạn/ngày.
- Sử dụng **Prisma ORM** để type-safe query và migration tự động.

---

## SLIDE 7b — CLASS DIAGRAM *(tùy kích thước ảnh, có thể ghép với Slide 7)*

**Tiêu đề:** Sơ đồ Lớp — Kiến trúc Domain Model

**Nội dung:**
- Chèn hình: `diagrams/Hinh-3.7.1-ClassDiagram.png`
- *(Nếu ảnh quá nhỏ khi thu nhỏ, tách thành slide riêng và zoom vào 2–3 nhóm lớp cốt lõi)*

**Điểm nhấn kỹ thuật:**
- Thể hiện mối quan hệ 1-nhiều (User → Profile → Device), nhiều-nhiều (Profile ↔ BlockedApp qua Application).
- Các Service Class (SocketService, FCMService, AIService) tách biệt khỏi Controller để đảm bảo Single Responsibility.

---

## SLIDE 8 — CÔNG NGHỆ & KIẾN TRÚC HỆ THỐNG

**Tiêu đề:** Stack Công Nghệ & Kiến Trúc

### Sơ đồ kiến trúc tổng thể:
```
[Parent App]  ←──Socket.IO──→  [Backend API]  ←──Socket.IO──→  [Child App]
(Flutter)                      (Node.js/Express)                (Flutter)
    ↑                               ↑                               ↑
    └──── FCM Push ─────────── Firebase ──────────────────── FCM Push ┘
                                    │
                              [PostgreSQL]
                              [Groq AI / Llama 4]
```

### Bảng công nghệ:

| Thành phần | Công nghệ |
|---|---|
| **Mobile App** | Flutter 3.x + Riverpod + go_router |
| **Android Native** | Kotlin — UsageStats, Accessibility, VPN, DeviceAdmin |
| **Backend** | Node.js + Express.js (kiến trúc MVC) |
| **ORM / DB** | Prisma ORM + PostgreSQL (Supabase) |
| **Real-time** | Socket.IO (room-based: `family_{userId}`) |
| **Push Notification** | Firebase Cloud Messaging (FCM) |
| **AI** | Llama 4 Scout (Groq Cloud) + OpenRouter fallback |
| **Auth** | JWT 24h + bcrypt salt=10 |
| **Deploy** | Railway (backend) + Supabase (DB) |

**Số liệu kỹ thuật:**
- Hơn **60 REST endpoints** — 32 bảng dữ liệu
- **59 unit test** + 10 integration test (Jest, ~90% coverage)
- Hơn **260 Pull Requests** đã merge trên GitHub

---

## SLIDE 9 — KẾ HOẠCH DEMO SẢN PHẨM

**Tiêu đề:** Kịch bản Demo — KidFun Live

**Demo account:** `demo@kidfun.app` / `KidFunDemo2026@HUTECH`
**Profile:** "Bé An" (ID: 30) | **Device code:** `DEMO-DEVICE-001`

### Kịch bản demo (thực hiện trực tiếp trên điện thoại):

| Bước | Hành động | Thiết bị |
|:---:|---|---|
| 1 | Đăng nhập tài khoản phụ huynh | Điện thoại A (Parent) |
| 2 | Xem hồ sơ "Bé An" + thiết bị đã liên kết | Điện thoại A |
| 3 | Đặt giới hạn thời gian ngắn (3 phút) để demo | Điện thoại A |
| 4 | Quan sát cảnh báo mềm hiện ra trên thiết bị trẻ | Điện thoại B (Child) |
| 5 | Trẻ nhấn "Xin thêm giờ" + nhập lý do | Điện thoại B |
| 6 | Phụ huynh nhận FCM push → vào app phê duyệt real-time | Điện thoại A |
| 7 | Quan sát thiết bị trẻ được mở khoá ngay lập tức | Điện thoại B |
| 8 | *(Tùy thời gian)* Demo SOS alert + xem báo cáo AI YouTube | Cả hai |

**Ghi chú:** Nếu không có 2 điện thoại, dùng 1 điện thoại + 1 emulator Android Studio.

---

## SLIDE 10 — ĐÁNH GIÁ & HƯỚNG PHÁT TRIỂN

**Tiêu đề:** Đánh Giá Sản Phẩm & Hướng Phát Triển

### Ưu điểm đã đạt được:
- **Triết lý "Soft Warning"** — độc đáo, không đối thủ nào có, khuyến khích trẻ tự quản lý.
- Giao tiếp **2 chiều thời gian thực** (Socket.IO + FCM) — phụ huynh phản hồi dưới 1 giây.
- **AI phân tích YouTube** tự động — cảnh báo nội dung không phù hợp mà không cần phụ huynh theo dõi thủ công.
- Giao diện **tiếng Việt**, miễn phí — phù hợp thị trường Việt Nam.
- Kiến trúc **sạch, có kiểm thử** (59 unit test, ~90% coverage, 260+ PRs).

### Nhược điểm / Giới hạn:
- Chỉ hỗ trợ **Android** — iOS không cung cấp API tương đương cho bên thứ ba.
- AI ở mức **metadata** (tiêu đề, tên kênh video) — chưa phân tích nội dung video thực.
- Chưa tối ưu cho **production scale** lớn (hàng triệu người dùng).

### Hướng phát triển:
- Hỗ trợ **iOS** bằng Apple `FamilyControls` / `DeviceActivityMonitor` API.
- Nâng cấp AI: phân tích **frame video / audio** thay vì chỉ metadata.
- Giám sát **Call, SMS, Zalo, Messenger** — mạng xã hội.
- Tính năng **"Nhìn lại ngày hôm nay"** cho trẻ tự đánh giá hành vi sử dụng.

---

> **Cảm ơn Thầy/Cô và Hội đồng đã lắng nghe!**
> Nhóm 8 — Khánh & Tuấn Anh — 23DTHC1 — HUTECH

---

## GHI CHÚ CHO NGƯỜI TRÌNH BÀY

### Thứ tự slide và diagram nên dùng:
| Slide | File ảnh diagram |
|---|---|
| 4 — Use Case | `diagrams/Hinh-3.2.1.1-UseCase-TongQuan.png` |
| 5 — Activity | `diagrams/Hinh-3.5.3.1-Activity-XinThemGio.png` |
| 6 — Sequence | `diagrams/Hinh-3.4.4.1-Sequence-XinThemGio.png` |
| 7b — Class Diagram | `diagrams/Hinh-3.7.1-ClassDiagram.png` |

### Thời lượng gợi ý (tổng ~12–15 phút):
- Slide 1–3: 2 phút (tổng quan + thị trường)
- Slide 4–6: 3 phút (diagram: Use Case, Activity, Sequence)
- Slide 7–7b: 2 phút (ERD + Class Diagram)
- Slide 8: 1 phút (tech stack)
- Slide 9–10: 2 phút (demo transition + đánh giá)
- Demo thực tế: 5–7 phút (nếu có)

### Câu hỏi thường gặp từ Hội đồng:
- *"Tại sao không làm iOS?"* → iOS không cung cấp UsageStatsManager/AccessibilityService cho bên thứ ba ở cấp độ ứng dụng.
- *"AI hoạt động như thế nào?"* → Gọi API Groq Cloud với model Llama 4 Scout, truyền tiêu đề + tên kênh video, nhận kết quả phân loại an toàn/không an toàn.
- *"Soft Warning là gì?"* → Hệ thống cảnh báo dần dần ở mốc 30/15/5 phút còn lại, thay vì cắt quyền đột ngột khi hết giờ.
- *"Real-time được implement như thế nào?"* → Socket.IO room `family_{userId}`, cả 2 thiết bị join cùng room sau khi đăng nhập, event được emit 2 chiều.
