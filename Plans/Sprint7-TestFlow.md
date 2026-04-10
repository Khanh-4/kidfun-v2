# KidFun V3 — Sprint 7: Test Flow
> GPS Tracking, Geofencing & SOS
> **Server:** https://kidfun-backend-production.up.railway.app
> **Ngày test:** ___________  |  **Người test:** ___________

---

## Yêu cầu trước khi test

| # | Yêu cầu | ✅ |
|---|---------|---|
| 1 | Có **2 thiết bị Android thật** (hoặc 1 thiết bị + 1 máy tính chạy Parent Web) | ⬜ |
| 2 | Thiết bị Child đã **link device** (có `deviceCode`) | ⬜ |
| 3 | Tài khoản Parent đã đăng nhập, có profile con | ⬜ |
| 4 | Thiết bị đã **bật GPS** (Location Services) | ⬜ |
| 5 | App Child đã được **cấp quyền Location (Foreground + Background)** | ⬜ |
| 6 | App Child đã được **cấp quyền Microphone** | ⬜ |
| 7 | App Parent đã bật **notification** | ⬜ |
| 8 | Cả 2 app đang kết nối internet | ⬜ |

---

## Module 1: GPS Tracking

### TC-01: Child gửi vị trí lần đầu (Foreground)

**Mục đích:** Kiểm tra Child sync vị trí lên server khi app đang mở.

**Điều kiện:** Child đã link device, app đang foreground.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Mở app Child | App hiển thị màn hình chính |
| 2 | Chờ 30 giây | Log hiện `✅ [LOCATION SYNC] Sent to server` |
| 3 | Mở app Parent → vào màn hình Map của profile con | Thấy **marker vị trí** xuất hiện trên bản đồ |
| 4 | Gọi API: `GET /api/profiles/:id/location/current` | Trả về `latitude`, `longitude`, `createdAt` hợp lệ |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-02: Child gửi vị trí định kỳ 30 giây (Foreground)

**Mục đích:** Kiểm tra interval 30s khi foreground.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Giữ app Child ở foreground | App hiển thị bình thường |
| 2 | Chờ 3 phút, quan sát log | Thấy ít nhất **6 lần** log `[LOCATION SYNC]` (mỗi ~30s) |
| 3 | Parent mở Map | Marker cập nhật vị trí mới sau mỗi ~30s |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-03: Child chuyển sang Background — đổi interval 5 phút

**Mục đích:** Kiểm tra tự động giảm tần suất khi app chạy ngầm.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | App Child đang foreground (interval 30s) | Vị trí cập nhật đều |
| 2 | Nhấn Home (minimize app) | App chạy background |
| 3 | Chờ 2 phút | **Không** thấy update vị trí trong khoảng này |
| 4 | Chờ đủ 5 phút từ lúc minimize | Thấy 1 lần update vị trí mới trên server |
| 5 | Mở lại app Child (foreground) | Log hiện `🔄 [LOCATION] Foreground: true`, quay lại 30s |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-04: Parent xem vị trí real-time qua Socket.IO

**Mục đích:** Kiểm tra luồng Socket.IO `locationUpdated`.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent mở màn hình Map (đang kết nối socket) | Bản đồ hiển thị, marker có hoặc không |
| 2 | Child gửi vị trí mới (di chuyển hoặc chờ 30s) | **Marker tự động dịch chuyển** trên bản đồ của Parent mà không cần reload |
| 3 | Parent nhấn nút "Lấy vị trí hiện tại" (FAB) | Marker được center vào vị trí mới nhất, map zoom vào level 15 |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-05: Xem lịch sử vị trí theo ngày

**Mục đích:** Kiểm tra màn hình Location History + vẽ polyline.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi API: `GET /api/profiles/:id/location/history?date=YYYY-MM-DD` | Trả về mảng `history` có ít nhất 1 bản ghi |
| 2 | Parent mở màn hình Lịch sử vị trí | Hiển thị DatePicker, map, danh sách events |
| 3 | Chọn ngày hôm nay | Map vẽ **polyline** nối các điểm vị trí theo thứ tự thời gian |
| 4 | Chọn ngày chưa có data | Thông báo "Không có dữ liệu" hoặc list rỗng |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

## Module 2: Geofence

### TC-06: Tạo Geofence mới trên bản đồ

**Mục đích:** Kiểm tra flow tạo vùng an toàn bằng tap.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent mở màn hình Map | Bản đồ hiển thị |
| 2 | Nhấn icon `+` (Thêm Vùng an toàn) | Hiện SnackBar hướng dẫn "Chạm lên bản đồ..." |
| 3 | Tap vào một điểm trên bản đồ | Xuất hiện **marker** tại điểm đã chọn + **vòng tròn xanh** (polygon) |
| 4 | Kéo Slider bán kính (100m → 500m → 2000m) | Vòng tròn thay đổi kích thước theo thời gian thực |
| 5 | Nhấn "Tiếp tục" | Hiện dialog nhập tên |
| 6 | Nhập tên "Trường học" → nhấn "Lưu" | Dialog đóng, vùng an toàn xuất hiện trên bản đồ với màu xanh |
| 7 | Gọi API: `GET /api/profiles/:id/geofences` | Trả về geofence mới trong danh sách |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-07: Validation tạo Geofence

**Mục đích:** Kiểm tra các trường hợp lỗi input.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi API tạo geofence với `radius: 30` (< 50) | Server trả về **400** "Radius must be between 50 and 5000 meters" |
| 2 | Gọi API tạo geofence với `radius: 9999` (> 5000) | Server trả về **400** |
| 3 | Gọi API thiếu field `name` | Server trả về **400** "Missing required fields" |
| 4 | Nhấn "Tiếp tục" mà chưa chọn điểm trên map | Dialog **không hiện** / nút bị disable |
| 5 | Nhấn "Lưu" khi tên rỗng | Dialog không đóng, vùng không được tạo |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-08: Xóa Geofence

**Mục đích:** Kiểm tra xóa vùng an toàn bằng tap trên polygon.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Đã có ít nhất 1 geofence trên bản đồ | Polygon hiển thị |
| 2 | **Không** ở chế độ thêm mới | Icon `+` không active |
| 3 | Tap vào vùng polygon trên bản đồ | Hiện **AlertDialog** "Xóa Vùng an toàn?" với tên vùng |
| 4 | Nhấn "Hủy" | Dialog đóng, vùng vẫn còn |
| 5 | Tap vào polygon lần nữa → nhấn "Xóa" | Polygon **biến mất** khỏi bản đồ |
| 6 | Gọi API: `GET /api/profiles/:id/geofences` | Geofence đã xóa **không còn** trong danh sách |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-09: Sự kiện ENTER Geofence

**Mục đích:** Kiểm tra detection khi Child đi vào vùng.

**Chuẩn bị:** Tạo geofence "Nhà" tại tọa độ `10.762622, 106.660172`, radius 200m. Child hiện đang ở **ngoài** vùng.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent mở app, đang nghe socket | App sẵn sàng |
| 2 | Gọi API POST location với tọa độ **trong** vùng (cách tâm < 200m) | API trả về 201 |
| 3 | Parent nhận Socket.IO event `geofenceEvent` | Hiện dialog/thông báo "**vào** Nhà" |
| 4 | Gọi API: `GET /api/profiles/:id/geofences/events?date=...` | Có event `type: "ENTER"` cho geofence "Nhà" |
| 5 | Parent kiểm tra notification (nếu app background) | Nhận push notification "con đã vào Nhà an toàn" |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-10: Sự kiện EXIT Geofence

**Mục đích:** Kiểm tra detection khi Child rời vùng.

**Chuẩn bị:** Tiếp theo TC-09, Child đang **trong** vùng.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi API POST location với tọa độ **ngoài** vùng (cách tâm > 200m) | API trả về 201 |
| 2 | Parent nhận Socket.IO event `geofenceEvent` | Hiện dialog/thông báo "**rời** Nhà" |
| 3 | Gọi API geofence events | Có event `type: "EXIT"` mới nhất |
| 4 | Parent kiểm tra push notification | Nhận notification "con vừa rời khỏi Nhà" |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-11: Geofence không active không trigger event

**Mục đích:** Toggle isActive = false → không detect ENTER/EXIT.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi API: `PUT /api/geofences/:id` với `{ "isActive": false }` | Trả về geofence đã cập nhật |
| 2 | Gọi API POST location vào trong vùng đó | API thành công nhưng **không có** geofence event |
| 3 | Gọi API geofence events | **Không có** event mới được tạo |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-12: Xem lịch sử Geofence Events

**Mục đích:** Kiểm tra màn hình timeline ENTER/EXIT.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Đã có ít nhất 2 events (ENTER + EXIT) từ TC-09, TC-10 | Có data |
| 2 | Parent mở màn hình Geofence Events | Hiện danh sách timeline |
| 3 | Kiểm tra màu sắc | ENTER = **màu xanh**, EXIT = **màu cam** |
| 4 | Chọn DatePicker → ngày hôm nay | Lọc đúng events trong ngày |
| 5 | Chọn ngày hôm qua (không có data) | Hiện "Không có sự kiện" |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

## Module 3: SOS

### TC-13: Child bấm SOS (flow cơ bản)

**Mục đích:** Kiểm tra toàn bộ flow SOS từ Child đến Parent.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Child mở app, thấy nút SOS màu đỏ | Nút SOS hiển thị rõ ràng, dễ thấy |
| 2 | Child nhấn nút SOS | Hiện **AlertDialog** xác nhận "🆘 Gửi SOS?" |
| 3 | Nhấn "Hủy" | Dialog đóng, **không** gửi SOS |
| 4 | Nhấn nút SOS lần nữa → nhấn "GỬI SOS" | Hiện SnackBar "✅ Đã gửi SOS cho phụ huynh" |
| 5 | Parent nhận Socket.IO event `sosAlert` | Hiện **SOS Dialog** không thể dismiss (barrierDismissible = false) |
| 6 | Kiểm tra thời gian từ bước 4 đến bước 5 | **< 2 giây** |
| 7 | Gọi API: `GET /api/profiles/:id/sos` | Có SOS mới nhất với `status: "ACTIVE"` |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-14: SOS Dialog hiển thị đúng thông tin

**Mục đích:** Kiểm tra nội dung dialog phía Parent.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent đang thấy SOS Dialog | Dialog có nền đỏ nhạt |
| 2 | Kiểm tra icon | Icon `⚠️` màu đỏ, size lớn |
| 3 | Kiểm tra tên con | Hiển thị đúng tên profile con |
| 4 | Kiểm tra thời gian | Hiển thị timestamp đúng định dạng |
| 5 | Kiểm tra vị trí | Tọa độ lat/lng hiển thị hoặc có nút "Xem vị trí" |
| 6 | Kiểm tra các nút | Có đủ: "Xem vị trí", "Gọi con", "Đã nhận được" |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-15: SOS có ghi âm 15 giây

**Mục đích:** Kiểm tra upload audio sau khi SOS.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Child bấm SOS (đã cấp quyền microphone) | SOS fast alert gửi ngay (< 2s) |
| 2 | Chờ 15–20 giây | App ghi âm âm thanh xung quanh trong 15s |
| 3 | Kiểm tra SOS Dialog của Parent | Nút **"Nghe ghi âm"** xuất hiện (có `audioUrl`) |
| 4 | Parent nhấn "Nghe ghi âm" | Âm thanh phát được, nghe rõ |
| 5 | Gọi API GET SOS | `audioUrl` khác null, trỏ đến file `.m4a` hợp lệ |
| 6 | Truy cập URL audio trực tiếp | File download được, duration ~15 giây |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-16: SOS không có ghi âm (không có quyền mic)

**Mục đích:** Kiểm tra fallback khi thiếu quyền microphone.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Thu hồi quyền Microphone của app Child | Settings → App → Permissions |
| 2 | Child bấm SOS → xác nhận | SOS vẫn gửi thành công (fast alert) |
| 3 | Parent nhận SOS Dialog | Dialog hiển thị nhưng **không có** nút "Nghe ghi âm" |
| 4 | Kiểm tra API | `audioUrl: null` trong response |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-17: Parent nhấn "Xem vị trí" từ SOS Dialog

**Mục đích:** Kiểm tra điều hướng từ SOS sang map.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent đang thấy SOS Dialog | Dialog hiển thị |
| 2 | Nhấn "Xem vị trí" | Dialog đóng, navigate sang **màn hình Map** |
| 3 | Kiểm tra map | Bản đồ **center** vào tọa độ của SOS, zoom level >= 15 |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-18: Parent nhấn "Gọi con"

**Mục đích:** Kiểm tra chức năng gọi điện từ SOS Dialog.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent đang thấy SOS Dialog | Dialog hiển thị |
| 2 | Nhấn "Gọi con" | Mở ứng dụng **Dialer** của điện thoại với số đã điền sẵn |
| 3 | Kiểm tra số điện thoại | Đúng số điện thoại liên kết với profile con |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-19: Parent Acknowledge SOS

**Mục đích:** Kiểm tra thay đổi trạng thái SOS.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent đang thấy SOS Dialog với status ACTIVE | Nút "Đã nhận được" hiển thị |
| 2 | Nhấn "Đã nhận được" | Dialog đóng |
| 3 | Gọi API: `GET /api/profiles/:id/sos` | SOS có `status: "ACKNOWLEDGED"`, `acknowledgedAt` không null |
| 4 | Gọi API: `PUT /api/sos/:id/resolve` | Trả về `status: "RESOLVED"`, `resolvedAt` không null |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-20: Xem lịch sử SOS

**Mục đích:** Kiểm tra màn hình SOS History.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Đã có ít nhất 2 SOS từ các TC trước | Có data |
| 2 | Parent mở màn hình SOS History | Danh sách sắp xếp **mới nhất trước** |
| 3 | Kiểm tra badge status | ACTIVE = đỏ, ACKNOWLEDGED = vàng, RESOLVED = xanh |
| 4 | Tap vào 1 SOS | Xem chi tiết: vị trí trên map, audio player, timestamp |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-21: Push Notification SOS khi Parent chạy ngầm

**Mục đích:** Kiểm tra độ ưu tiên cao của push notification.

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Parent **minimize app** (background) | App chạy ngầm |
| 2 | Child bấm SOS | Push notification xuất hiện ngay lập tức |
| 3 | Kiểm tra notification | Title "🆘 SOS KHẨN CẤP từ [Tên con]", kèm sound |
| 4 | Tap vào notification | Mở app Parent, hiện SOS Dialog |
| 5 | Tắt hẳn app Parent (killed) | Notification vẫn nhận được (Firebase FCM) |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

## Module 4: API Validation & Error Cases

### TC-22: Authentication Guards

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi `GET /api/profiles/:id/location/current` **không có** Authorization header | Trả về **401** Unauthorized |
| 2 | Gọi `POST /api/profiles/:id/geofences` không có token | Trả về **401** |
| 3 | Gọi `POST /api/child/location` không cần auth (child endpoint) | Trả về **201** nếu deviceCode hợp lệ |
| 4 | Gọi `POST /api/child/sos` không cần auth | Trả về **201** nếu deviceCode hợp lệ |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-23: Device Not Linked

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Gọi `POST /api/child/location` với `deviceCode: "INVALID_CODE"` | Trả về **404** "Device not linked" |
| 2 | Gọi `POST /api/child/sos` với deviceCode không tồn tại | Trả về **404** "Device not linked" |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

### TC-24: Audio Upload Validation

| Bước | Hành động | Kết quả mong đợi |
|------|-----------|------------------|
| 1 | Upload file ảnh `.jpg` vào `POST /api/child/sos` field `audio` | Trả về **400** "Invalid audio format" |
| 2 | Upload file âm thanh > 5MB | Trả về **400** (multer limit error) |
| 3 | Upload file `.m4a` hợp lệ | Trả về **201**, `audioUrl` hợp lệ |

**Pass/Fail:** ⬜ Pass  ⬜ Fail

**Ghi chú:** ___________

---

## Tóm tắt Kết quả

| Module | Tổng TC | Pass | Fail | Ghi chú |
|--------|---------|------|------|---------|
| GPS Tracking | 5 | | | |
| Geofence | 7 | | | |
| SOS | 9 | | | |
| API Validation | 3 | | | |
| **Tổng** | **24** | | | |

---

## Lỗi tìm thấy

| # | TC | Mô tả lỗi | Mức độ | Người fix | Status |
|---|----|-----------|--------|-----------|--------|
| 1 | TC-01 | Marker vị trí không hiển thị trên bản đồ (do thiếu asset icon) | 🟠 High | Antigravity | RESOLVED |
| 2 | N/A | Lỗi đếm ngược thời gian bị kẹt mức 0 khi parent cập nhật time limit (lỗi delta logic) | 🔴 Critical | Antigravity | RESOLVED |
| 3 | TC-06 | UI Dialog "Lưu vùng an toàn": nút "Hủy" (TextButton) nhỏ hơn nút "Lưu" (ElevatedButton) — UX không đồng nhất | 🟡 Medium | Antigravity | RESOLVED |
| 4 | TC-08 | UI Dialog "Xóa vùng an toàn": Row Expanded bị OverflowBar co nhỏ nên 2 nút không bằng nhau | 🟡 Medium | Antigravity | RESOLVED |
| 5 | TC-12 | Màn hình Lịch sử di chuyển không tự cập nhật Geofence Event khi có ENTER/EXIT real-time — phải chọn lại ngày mới hiện | 🟠 High | Antigravity | RESOLVED |

> **Mức độ:** 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low

---

## Ghi chú thêm

- **Lưu ý thiết bị Xiaomi/Oppo/Vivo:** Phải vào Settings → Battery → App "KidFun" → **No restrictions** để background location hoạt động.
- **Emulator:** Không test được GPS thật. Dùng **thiết bị vật lý** cho TC-02, TC-03.
- **Geofence state cache:** In-memory, restart server → mất trạng thái. Lần POST location đầu tiên sau restart sẽ không trigger event (expected behavior).
- **SOS Audio delay:** Bình thường audio upload xong sau 15–20s. Nút "Nghe ghi âm" có thể không có ngay, cần F5 hoặc chờ.
