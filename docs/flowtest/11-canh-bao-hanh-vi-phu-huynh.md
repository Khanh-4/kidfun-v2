# Luồng 11 — App phụ huynh: thông báo cảnh báo hành vi và nút "Đúng / Được phép" (đồ án, T7.4)

**Tính năng mới:** khi hệ thống phát hiện bé dùng máy khác thường (luật trên máy trẻ, tác vụ ML ban đêm, hoặc dự
đoán ngày mai dễ vượt giới hạn), phụ huynh nhận thông báo kèm **câu giải thích lý do**. Bấm vào thông báo mở màn
"Cảnh báo hành vi" của đúng bé đó, cảnh báo vừa nhận có nhãn **"Vừa nhận"**. Mỗi cảnh báo có 2 nút:
- **Đúng là bất thường** → ghi nhận xác nhận.
- **Được phép** → hỏi lý do (cuối tuần / ngày lễ / khác). Hệ thống dùng phản hồi này để bớt báo nhầm về sau.

Màn này cũng mở được từ danh sách hồ sơ trẻ: nút biểu tượng **biểu đồ (màu cam)** cạnh nút SOS.

Nhánh: **`develop`** (pull mới nhất). **Build lại APK app phụ huynh** (máy trẻ không cần cài lại). Thời gian: ~20 phút.

> Cảnh báo thật cần nhiều ngày dữ liệu, nên **Khánh sẽ gửi một cảnh báo thử** lên đúng hồ sơ trẻ bạn đang test.
> Nhắn Khánh: "bắt đầu test luồng 11" + **tên hồ sơ trẻ**, rồi làm theo các bước dưới khi Khánh báo đã gửi.

## Bước 1 — Màn danh sách (không cần cảnh báo)

1. Mở app phụ huynh → danh sách hồ sơ trẻ → bấm nút biểu đồ cam của một bé.
2. **Mong đợi:** mở màn "Cảnh báo hành vi · <tên bé>". Chưa có cảnh báo thì hiện "Chưa có cảnh báo nào…".
3. Kéo xuống để tải lại: không lỗi. Tắt mạng rồi mở lại màn: hiện thông báo lỗi + nút **Thử lại**.

## Bước 2 — Thông báo khi app phụ huynh ĐANG MỞ

1. Để app phụ huynh mở ở màn hình chính. Nhắn Khánh gửi cảnh báo thử số 1.
2. **Mong đợi:** hiện thông báo "Cảnh báo sử dụng của <tên bé>", nội dung là câu giải thích (vd "Hôm qua bé dùng máy …").
3. Bấm thông báo → mở màn cảnh báo của đúng bé đó, cảnh báo có viền cam và nhãn **"Vừa nhận"**.

## Bước 3 — Thông báo khi app chạy NỀN và khi đã TẮT HẲN

1. Bấm Home cho app phụ huynh chạy nền. Nhắn Khánh gửi cảnh báo thử số 2. Bấm thông báo → như Bước 2 mục 3.
2. Vuốt tắt hẳn app phụ huynh. Nhắn Khánh gửi cảnh báo thử số 3. Bấm thông báo → app mở lên, qua màn chờ rồi vào
   đúng màn cảnh báo, cảnh báo số 3 có nhãn "Vừa nhận".

## Bước 4 — Nút phản hồi

1. Ở cảnh báo số 1 bấm **Đúng là bất thường** → hai nút biến mất, hiện "Bạn xác nhận: đúng là bất thường".
2. Ở cảnh báo số 2 bấm **Được phép** → hiện bảng chọn lý do → chọn "Cuối tuần, cho phép" → hiện "Bạn đánh dấu: Cuối
   tuần, cho phép".
3. Thoát ra rồi mở lại màn: trạng thái đã phản hồi **vẫn còn** (lưu trên server).
4. Tắt mạng, bấm một nút ở cảnh báo số 3 → báo "Không gửi được phản hồi…", nút vẫn còn để bấm lại khi có mạng.

## Báo lại cho Khánh

- Bước nào không đúng mong đợi: ảnh chụp màn hình + giờ xảy ra.
- Nếu bấm thông báo mà không mở đúng màn: gửi logcat lọc `[FCM]`.

---

### Dành cho Khánh — gửi cảnh báo thử

Lấy `profileId` của bé (Supabase, bảng `Profile`), rồi mỗi lần gửi đổi `category` (khoá chống trùng gồm loại + ngày):

```bash
YESTERDAY=$(TZ=Asia/Ho_Chi_Minh date -d yesterday +%F)
curl -s -X POST https://kidfun-backend.vercel.app/api/cron/behavior-results \
  -H "Authorization: Bearer $CRON_SECRET" -H 'Content-Type: application/json' \
  -d "{\"modelVersion\":\"flowtest-11\",\"predictions\":[],\"alerts\":[{\"profileId\":<ID>,\"rule\":\"day_anomaly\",
       \"category\":\"binge_day\",\"dayType\":\"school\",\"date\":\"$YESTERDAY\",\"minutes\":300,\"usualMinutes\":100,
       \"message\":\"[Thử nghiệm] Hôm qua bé dùng máy 5 giờ, gấp 3 lần một ngày đi học bình thường.\"}]}"
```

Lần 2, 3 dùng `"category":"night_use"` rồi `"spike"`. Kết quả mong đợi: `"alertsCreated":1`. Test xong có thể xoá
các cảnh báo có câu bắt đầu bằng `[Thử nghiệm]` trong bảng `BehaviorAlert`.
