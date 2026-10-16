# Đồ án chuyên ngành — Tuần 1: Đặc tả bộ đặc trưng (features) cho M1 và M2

> Dựa trên: bảng `AppUsageHourly` (`01-thiet-ke-thu-thap-theo-gio.md`), các bảng sẵn có của KidFun
> (`backend/prisma/schema.prisma`), và kết quả EDA (`02-eda-lsapp.md`, `03-eda-studentlife.md`).
> Phần cài đặt (module `ml/features/`) làm ở tuần 2.

## 0. Quy ước chung

| Quy ước | Nội dung |
|---|---|
| Múi giờ | Mọi đặc trưng tính theo **giờ VN (UTC+7)**: `giờ_VN = hourStart + 7h`. Không dùng giờ máy chủ. |
| Ngày | Ngày lịch VN 00:00–23:59. `dayOfWeek`: **0 = Chủ nhật** … 6 = thứ Bảy (trùng quy ước `TimeLimit` và `vnDayRange()`). |
| Đơn vị | Phút (làm tròn 0,1). |
| Nguồn thời gian dùng | `AppUsageHourly.usageSeconds` (đã loại launcher và chính app KidFun lúc thu thập). |
| Khung khuya | 22:00–06:00 giờ VN, trừ khi phụ huynh đã đặt khung riêng (lấy từ cài đặt tầng 1 khi có). |
| Chuẩn hoá | Mô hình **chung cho mọi trẻ** (EDA: mỗi người ít ngày) → đặc trưng lịch sử dùng **giá trị tương đối** so với mức thường ngày của chính trẻ, kèm giá trị tuyệt đối. |

## 1. M1 — Dự đoán tổng thời gian ngày mai

### 1.1. Thời điểm chạy và chống rò rỉ thông tin
- Tác vụ chạy lúc **21:00 giờ VN ngày t** (để kịp cảnh báo "tối hôm trước").
- Mục tiêu: `y(t+1)` = tổng `usageSeconds`/60 của ngày VN `t+1`.
- Nhãn phân loại: `vượt(t+1) = y(t+1) > L(t+1)`, với `L(t+1)` = `TimeLimit.dailyLimitMinutes` của `dayOfWeek(t+1)` (nếu `isActive`). Không có giới hạn → không có nhãn, chỉ dự đoán số phút.
- **Mọi đặc trưng chỉ dùng dữ liệu có `giờ_VN < 21:00` của ngày t** (các ô giờ ≤ 20:00). Khi tạo tập huấn luyện từ dữ liệu quá khứ cũng cắt đúng mốc này — nếu không, mô hình được "nhìn thấy" 3 giờ cuối ngày t mà lúc chạy thật không có.

### 1.2. Danh sách đặc trưng

| Nhóm | Đặc trưng | Định nghĩa | Nguồn |
|---|---|---|---|
| A. Lịch sử | `y_lag1`, `y_lag7` | Tổng phút ngày t−1, t−7 (ngày đầy đủ) | AppUsageHourly |
| | `mean7`, `std7`, `mean14` | Trung bình / độ lệch chuẩn 7 và 14 ngày đầy đủ gần nhất | AppUsageHourly |
| | `today_until21` | Phút từ 00:00 đến 21:00 ngày t | AppUsageHourly |
| | `today_until21_ratio` | `today_until21` / trung bình cùng mốc 21:00 của 7 ngày trước | AppUsageHourly |
| | `lag1_ratio`, `same_dow_ratio` | `y_lag1/mean7`; trung bình các ngày cùng thứ (4 tuần) / `mean14` | AppUsageHourly |
| | `history_days` | Số ngày đã có dữ liệu (để mô hình biết độ tin cậy) | AppUsageHourly |
| B. Lịch | `dow_sin`, `dow_cos` | Thứ của ngày t+1 dạng tuần hoàn | lịch |
| | `is_weekend`, `is_holiday` | Ngày t+1 là cuối tuần / ngày lễ VN (Tết, 30/4, 1/5, 2/9…) | lịch + file cấu hình |
| | `is_school_day`, `is_exam_period`, `is_summer` | Theo lịch năm học VN (file cấu hình `ml/config/vn_school_calendar.csv`); nếu trẻ có `SchoolSchedule.isEnabled` thì ưu tiên lịch đó | lịch, SchoolSchedule |
| | `days_to_next_holiday` | Số ngày tới kỳ nghỉ gần nhất (hành vi đổi trước kỳ nghỉ) | lịch |
| C. Giới hạn | `limit_tomorrow` | `L(t+1)`; không có thì để trống + cờ `has_limit` | TimeLimit |
| | `limit_tomorrow_ratio` | `L(t+1)/mean7` (giới hạn chặt hay lỏng so với thói quen) | TimeLimit |
| | `is_gradual` | Đang áp dụng giảm dần | TimeLimit |
| D. Thương lượng | `ext_req_7d`, `ext_min_req_7d` | Số lần / số phút xin thêm trong 7 ngày | TimeExtensionRequest |
| | `ext_approve_rate_7d` | Tỷ lệ được duyệt (`APPROVED`) trong 7 ngày | TimeExtensionRequest |
| | `ext_req_today` | Số lần xin thêm trong ngày t (trước 21:00) | TimeExtensionRequest |
| E. Cơ cấu app | `share_video`, `share_game`, `share_social`, `share_study` | Tỷ trọng phút theo nhóm app trong 7 ngày | AppUsageHourly + `ml/config/app_categories.csv` (packageName → nhóm; không có → `other`) |
| F. Khuya | `night_min_last`, `night_min_7d`, `late_nights_7d` | Phút khung khuya đêm qua; tổng 7 ngày; số đêm có > 15 phút khuya | AppUsageHourly |
| G. Giấc ngủ (xấp xỉ) | `last_active_hour`, `sleep_gap_hours` | Giờ cuối có sử dụng trước 06:00; khoảng trống không dùng dài nhất trong đêm (độ phân giải 1 giờ) | AppUsageHourly |
| H. Nội dung | `yt_danger_mean_7d`, `yt_danger_high_7d` | Trung bình `dangerLevel`; số video `dangerLevel ≥ 4` trong 7 ngày | YouTubeLog |
| I. Vị trí | `outside_zone_min_7d` | Phút ở ngoài vùng an toàn (ghép `EXIT` → `ENTER` kế tiếp) | GeofenceEvent |

### 1.3. Trẻ mới, ít lịch sử
- `history_days < 7`: **không gửi cảnh báo** M1; vẫn tính dự đoán (mô hình chung + `history_days`) để hiển thị ở tab AI Insights kèm nhãn "đang học thói quen của bé".
- Ngày thiếu dữ liệu (máy tắt, mất quyền) là **thiếu**, không phải 0 phút (bài học EDA LSApp): nhận biết bằng ngày không có ô giờ nào **và** máy không gửi heartbeat; loại khỏi cửa sổ lịch sử thay vì lấp 0.

## 2. M2 — Phát hiện bất thường

### 2.1. Đặc trưng theo giờ (đơn vị chấm điểm: một giờ của một trẻ)

| Đặc trưng | Định nghĩa |
|---|---|
| `hour_min` | Phút dùng trong giờ đó (mọi app) |
| `hour_min_by_cat` | Phút theo nhóm app (video, game, social, study, other) |
| `hour_launches` | Tổng `launchCount` |
| `hour_z` | (`hour_min` − trung bình) / độ lệch chuẩn của **cùng giờ, cùng loại ngày** (ngày học / cuối tuần / nghỉ) trong 28 ngày, của chính trẻ; độ lệch chuẩn chặn dưới 5 phút để tránh chia cho số rất nhỏ |
| `is_night`, `in_sleep_window` | Giờ thuộc khung khuya; giờ nằm trong khoảng ngủ thường lệ của trẻ (từ đặc trưng G, EDA StudentLife) |
| `new_app_min` | Phút của app chưa từng dùng > 10 phút trong 28 ngày trước |

### 2.2. Đặc trưng theo ngày

`day_min`, `day_ratio` (= `day_min / mean28` cùng loại ngày), `night_min`, `max_hour_min`, `n_active_hours`,
độ lệch cơ cấu app so với 28 ngày (khoảng cách L1 giữa hai vector tỷ trọng nhóm app), `new_app_min`,
`yt_danger_high`, `ext_req`.

### 2.3. Tầng 1 trên máy trẻ — chỉ dùng mức thường ngày tính sẵn
Server tính hằng đêm và gửi xuống máy (JSON nhỏ, vài KB; ví dụ với số liệu giả):
```json
{ "profileId": 12, "validUntil": "2026-10-18T00:00:00+07:00",
  "nightWindow": ["22:00", "06:00"],
  "baseline": [ { "dayType": "school", "hour": 22, "cat": "game", "mean": 3.5, "std": 6.0 } ],
  "rules": { "nightMinMinutes": 10, "spikeRatio": 3.0, "spikeMinMinutes": 20 } }
```
Luật tầng 1 (kiểm tra mỗi khi có ô giờ mới):
- **Khuya:** trong khung khuya, `hour_min ≥ nightMinMinutes` → cảnh báo ngay.
- **Tăng đột biến:** `hour_min_by_cat ≥ spikeRatio × mean` **và** ≥ `spikeMinMinutes` (chặn trường hợp mức thường ngày gần 0).
- Ngưỡng nới theo phản hồi "được phép" của phụ huynh (mục 4).

## 3. Câu giải thích cho phụ huynh

Chọn **1–2 đặc trưng lệch nhiều nhất** (theo `hour_z` / tỷ lệ so với mức thường ngày, hoặc giá trị SHAP lớn nhất với XGBoost), điền vào mẫu:

| Kiểu | Mẫu câu | Điều kiện |
|---|---|---|
| Khuya | "Bé dùng {app/nhóm} lúc {giờ} trong {n} phút — giờ này bé thường đã ngủ." | `is_night` hoặc `in_sleep_window` |
| Tăng đột biến | "Bé chơi {nhóm} {khung giờ} tăng gấp {k} lần so với bình thường ({x} phút, thường khoảng {m} phút)." | `ratio ≥ 2` |
| App mới | "Bé dùng một ứng dụng mới: {appName}, {n} phút hôm nay." | `new_app_min > 0` |
| Dự báo vượt | "Ngày mai ({thứ}) bé có khả năng dùng quá giới hạn {L} phút (xác suất {p}%). Lý do chính: {đặc trưng top SHAP}." | M1, `p ≥ ngưỡng` |

Quy tắc: làm tròn số dễ đọc ("gấp 3 lần", không "gấp 2,87 lần"); không nêu điểm số, z-score hay tên đặc trưng kỹ thuật; dùng `appName`, không dùng `packageName`.

## 4. Phản hồi của phụ huynh → điều chỉnh

| Phản hồi | Tác động ngắn hạn (ngay) | Tác động dài hạn |
|---|---|---|
| "Đúng là bất thường" | Giữ ngưỡng | Nhãn dương cho tập đánh giá / huấn luyện lại |
| "Do cuối tuần cho phép" / "Ngày lễ" / "Được phép" | Nới ngưỡng của đúng **loại ngày + nhóm app** đó (vd `spikeRatio` × 1,25), tối đa 2 lần nới | Nhãn âm; loại khỏi tập bất thường |

## 5. Đặc trưng nào có ở nguồn dữ liệu nào

| Nhóm | LSApp | StudentLife | Bộ sinh mô phỏng | KidFun thật |
|---|---|---|---|---|
| A. Lịch sử | ✓ (mỗi người ít ngày) | ✓ (chỉ số hoạt động, không phải phút thật) | ✓ | ✓ |
| B. Lịch | một phần (múi giờ không rõ) | ✓ (lịch Mỹ) | ✓ (lịch VN) | ✓ |
| C. Giới hạn | ✗ | ✗ | ✓ | ✓ |
| D. Thương lượng | ✗ | ✗ | ✓ | ✓ |
| E. Cơ cấu app | ✓ | ✓ | ✓ | ✓ |
| F. Khuya | ✗ (múi giờ không rõ) | ✓ | ✓ | ✓ |
| G. Giấc ngủ | ✗ | ✓ (khoá máy dài) | ✓ | ✓ (xấp xỉ theo giờ) |
| H. Nội dung | ✗ | ✗ | ✓ | ✓ |
| I. Vị trí | ✗ | ✗ | tuỳ chọn | ✓ |

Hệ quả cho phân tích loại bỏ (ablation, mục 4.2 PDF): các nhóm C, D, H, I — **tín hiệu đặc thù của hệ thống quản lý thời gian dùng thiết bị** — chỉ đo được trên dữ liệu mô phỏng và dữ liệu thật KidFun. Bộ sinh mô phỏng phải sinh đủ các nhóm này, có quan hệ nhân quả hợp lý (vd gần chạm giới hạn → xin thêm giờ).

## 6. Việc tuần 2
1. `ml/config/app_categories.csv` (top app phổ biến ở VN → nhóm) và `ml/config/vn_school_calendar.csv` (năm học 2025–2026, 2026–2027, ngày lễ).
2. `ml/features/`: hàm thuần `build_daily_features(hourly, limits, ext_requests, youtube, geofence, cutoff_hour=21)` và `build_hourly_features(...)`, có unit test cho mốc cắt 21:00 và đổi múi giờ.
3. Bộ sinh dữ liệu mô phỏng xuất đúng định dạng bảng `AppUsageHourly` + các bảng liên quan, để cùng một hàm đặc trưng chạy được trên cả dữ liệu mô phỏng và dữ liệu thật.
