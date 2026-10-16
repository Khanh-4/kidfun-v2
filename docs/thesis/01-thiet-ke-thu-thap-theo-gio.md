# Đồ án chuyên ngành — Tuần 1: Thiết kế bộ thu thập dữ liệu theo giờ

> Phạm vi tài liệu: phần **thu thập dữ liệu theo giờ và theo ứng dụng** trên app trẻ + bảng/API nhận dữ liệu.
> Đây là việc phải chạy sớm nhất để kịp tích luỹ dữ liệu thật (xem kế hoạch 9 tuần trong `thesis-topic01.pdf`, mục 6.2).
> Tầng 1 (cảnh báo tức thì), bảng cảnh báo và bảng phản hồi của phụ huynh sẽ thiết kế ở tuần 5–6.

## 1. Hiện trạng

| Thành phần | Hiện tại | Hạn chế cho đồ án |
|---|---|---|
| `UsageStatsHelper.getTodayUsage()` (Kotlin) | `queryUsageStats(INTERVAL_DAILY)` → tổng giây foreground **theo ngày** của từng app (lọc > 1 phút) | Không biết trẻ dùng app **lúc mấy giờ** → không phát hiện được "dùng máy lúc 2–3 giờ sáng", không có heatmap giờ × thứ |
| Vòng đồng bộ (`child_dashboard_screen.dart`) | `Timer.periodic` 5 phút trong UI Flutter → `POST /api/child/app-usage` | Chỉ chạy khi Flutter engine còn sống; thức máy + bật mạng mỗi 5 phút |
| Bảng `AppUsageLog` | 1 dòng / (profile, device, package, **ngày**), ghi đè giá trị tích luỹ | Không có chiều giờ |
| Xác thực `/api/child/*` | Không có JWT, máy trẻ gửi `deviceCode` trong body | Native Kotlin cũng gửi được, chỉ cần đọc `device_code` |

## 2. Quyết định thiết kế

### 2.1. Nguồn dữ liệu: `UsageStatsManager.queryEvents`
- Đọc chuỗi sự kiện `ACTIVITY_RESUMED` (1) / `ACTIVITY_PAUSED` (2) — trên Android cũ là `MOVE_TO_FOREGROUND` / `MOVE_TO_BACKGROUND`, cùng mã số.
- Ghép thành các **khoảng foreground** `[start, end)` cho từng package. Khoảng nào chưa đóng (app đang mở) thì cắt ở thời điểm hiện tại.
- Ngắt khoảng khi gặp `SCREEN_NON_INTERACTIVE` (16, API 28+) hoặc `DEVICE_SHUTDOWN` (26) để không đếm thời gian màn hình tắt.
- **Cắt khoảng theo ranh giới giờ UTC** rồi cộng dồn → `(giờ, package) → số giây, số lần mở`. VN là UTC+7, không đổi giờ mùa hè, nên ranh giới giờ UTC trùng đúng ranh giới giờ VN; không cần xử lý múi giờ trên máy.
- Mở lại cùng app trong vòng 2 giây (chuyển màn hình nội bộ app) không tính là lần mở mới.
- Bỏ qua chính app KidFun và launcher (màn hình chính) — không phải hành vi "dùng app".

### 2.2. Cách tính lại: luôn tính lại trọn vẹn, gửi giá trị tuyệt đối (idempotent)
- Mỗi lần chạy: tính lại **toàn bộ các giờ từ 00:00 hôm qua đến hiện tại** từ sự kiện gốc (Android giữ sự kiện vài ngày).
- Gửi **giá trị tuyệt đối** của mỗi ô (giờ, package); server **upsert ghi đè**. Gửi trùng, gửi lại sau mất mạng, hay worker chạy 2 lần đều cho kết quả đúng — không cần watermark phức tạp.
- Để tiết kiệm mạng: chỉ gửi những ô **thay đổi** so với lần gửi thành công trước (lưu dấu các ô đã gửi trong SharedPreferences, xoá ô cũ hơn 2 ngày).
- Mất mạng nhiều ngày: phần hôm qua vẫn được bù khi có mạng lại; quá 2 ngày thì mất phần giờ (vẫn còn số liệu theo ngày ở `AppUsageLog`). Chấp nhận được với mục tiêu nghiên cứu, sẽ ghi vào hạn chế.

### 2.3. Lịch chạy: WorkManager native (Kotlin), 30 phút/lần
- `PeriodicWorkRequest` 30 phút, điều kiện **có mạng**; WorkManager tự gộp với các tác vụ khác, tự chạy lại sau khi khởi động máy, không phụ thuộc UI Flutter.
- Viết **bằng Kotlin** (không dùng plugin Dart `workmanager`): không phải khởi động thêm một Flutter engine nền mỗi lần chạy → nhẹ pin hơn — đúng góp ý GVHD số 3.
- Worker đọc `deviceCode` từ SharedPreferences của Flutter (`FlutterSharedPreferences`, khoá `flutter.device_code`); chưa liên kết thì bỏ qua.
- Đăng ký (enqueue `KEEP`) khi app trẻ khởi động và khi liên kết thành công; huỷ khi gỡ liên kết.
- **Giữ nguyên vòng 5 phút cũ** trong tuần 1: tính năng giới hạn theo app đang dựa vào `AppUsageLog`. Việc giãn/bỏ vòng 5 phút để đo pin (RQ4) làm ở tuần 6 cùng tầng 1.

### 2.4. Bảng mới `AppUsageHourly`

```prisma
model AppUsageHourly {
  id           Int      @id @default(autoincrement())
  profileId    Int
  deviceId     Int
  packageName  String
  appName      String?
  hourStart    DateTime // thời điểm bắt đầu giờ (UTC instant), vd 2026-10-16T19:00:00Z = 02:00 sáng 17/10 giờ VN
  usageSeconds Int      // 0..3600
  launchCount  Int      @default(0) // số khoảng foreground bắt đầu trong giờ này
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  profile Profile @relation(fields: [profileId], references: [id], onDelete: Cascade)
  device  Device  @relation(fields: [deviceId], references: [id], onDelete: Cascade)

  @@unique([deviceId, packageName, hourStart])
  @@index([profileId, hourStart])
}
```

- Lưu `hourStart` dạng **thời điểm UTC tuyệt đối** — tránh bẫy lệch 7 giờ đã gặp (xem `vnDayRange()`); đổi sang giờ VN khi phân tích.
- Không ràng buộc với `AppUsageLog` (hai nguồn độc lập; sau này có thể đối chiếu tổng theo ngày để kiểm tra chất lượng dữ liệu).
- Ước lượng dung lượng: ~10 app × 16 giờ thức/ngày ≈ 160 dòng/máy/ngày → vài nghìn dòng/tháng, nhỏ với Postgres.
- Cần bật RLS cho bảng mới (bài học bẫy RLS subquery trên Supabase): bảng chỉ backend dùng → bật RLS, không policy cho anon; kiểm tra không có policy bảng khác subquery vào nó.

### 2.5. API mới `POST /api/child/app-usage/hourly`

```json
{
  "deviceCode": "ABC123",
  "buckets": [
    { "packageName": "com.google.android.youtube", "appName": "YouTube",
      "hourStart": "2026-10-16T19:00:00.000Z", "usageSeconds": 1840, "launchCount": 3 }
  ]
}
```

- Kiểm tra đầu vào: `buckets` 1..500 phần tử; `hourStart` phải tròn giờ, không ở tương lai, không cũ hơn 7 ngày; `usageSeconds` 0..3600; `launchCount` 0..1000; `packageName` ≤ 255 ký tự.
- Tìm device theo `deviceCode` (giống `syncAppUsage`); không thấy → 404 `DEVICE_NOT_LINKED` (worker sẽ ngừng gửi).
- Upsert theo `(deviceId, packageName, hourStart)` trong **một transaction**; trả `{ upserted: n }`.
- Không gửi thông báo, không đụng logic giới hạn — thuần thu thập.

## 3. Kiểm thử

| Mức | Nội dung |
|---|---|
| Unit (Kotlin, JVM) | Hàm thuần `HourlyBucketer`: ghép sự kiện → khoảng → cắt theo giờ. Ca: khoảng vắt qua 2 giờ, qua nửa đêm, app đang mở (chưa PAUSED), màn hình tắt giữa chừng, sự kiện PAUSED không có RESUMED trước đó |
| Backend (Jest, DB `kidfun_test`) | Upsert ghi đè đúng; gửi trùng không nhân đôi; từ chối `hourStart` lệch giờ / tương lai / quá cũ; deviceCode sai → 404 |
| Trên máy thật (bạn cùng nhóm, Android Studio) | Dùng YouTube 10 phút lúc 21:50–22:00 → có 2 dòng ở giờ 21 và 22; tắt mạng 1 tiếng rồi bật lại → dữ liệu bù đủ; gỡ liên kết → worker ngừng |

## 4. Việc tiếp theo trong tuần 1 (sau khi bộ thu thập chạy)

1. EDA dữ liệu công khai (LSApp trước — có dấu thời gian từng phiên, gần nhất với dữ liệu của mình).
2. Đo mức pin hiện tại làm mốc (`dumpsys batterystats`, 24 giờ) — cần bạn cùng nhóm chạy trên máy thật.
3. Đặc tả bộ đặc trưng (mục 2.2 trong PDF) theo đúng cột của `AppUsageHourly`.
