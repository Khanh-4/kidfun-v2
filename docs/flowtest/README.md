# Flowtest — kịch bản test KidFun cho người test

Mỗi file là **một luồng test**: làm theo từng bước, so với **Kết quả mong đợi**, đánh dấu `[x]` đạt hoặc ghi lỗi.
Người code (Khanh) không có máy để test, nên kết quả của bạn là căn cứ duy nhất để biết tính năng chạy đúng
trên điện thoại thật.

## Thứ tự làm

| # | File | Nội dung | Thời gian | Ai làm |
|---|---|---|---|---|
| 0 | [00-chuan-bi.md](00-chuan-bi.md) | Lấy code, đặt file cấu hình, chạy app, xem log | 30–60 phút (một lần) | Người test |
| 1 | [01-thu-thap-theo-gio.md](01-thu-thap-theo-gio.md) | Bộ thu thập thời gian dùng app theo giờ (PR #303) | ~2 giờ (chủ yếu là chờ) | Người test + Khanh kiểm tra DB |
| 2 | [02-canh-bao-tang1.md](02-canh-bao-tang1.md) | Cảnh báo dùng máy bất thường ngay trên máy trẻ (PR #313, #315) | 1 đêm + 30 phút | Người test |
| 3 | [03-hoi-quy-app-phu-huynh.md](03-hoi-quy-app-phu-huynh.md) | App phụ huynh vẫn chạy đúng sau sửa lỗi phân quyền (PR #314) | ~45 phút | Người test |
| 4 | [04-do-pin.md](04-do-pin.md) | Đo pin 2 lần: bản cũ (mốc) và bản mới | 2 × 24 giờ | Người test |
| 5 | [05-dong-ho-dem-nguoc.md](05-dong-ho-dem-nguoc.md) | Đồng hồ đếm ngược app trẻ: đổi hạn mức, tắt màn hình, ra khỏi app, qua 00:00 | ~1 giờ (bước 4 lúc 23:55–00:15) | Người test |
| 6 | [06-chan-doan-du-lieu-dung-app.md](06-chan-doan-du-lieu-dung-app.md) | **Làm trước luồng 1 & 2** — chẩn đoán vì sao server không nhận dữ liệu dùng app (máy ảo được) | ~20 phút, báo Khanh trong 1 giờ | Người test |

Luồng 2 và 4 cần nhiều thời gian, nên bắt đầu sớm. Luồng 4 dùng bản **release** và **không** chạy song song với
luồng 1–3 trên cùng máy (cài bản khác lên giữa chừng sẽ làm sai số đo pin).

## Cách gửi kết quả

Với mỗi file đã làm, gửi lại cho Khanh:

1. File `.md` đã đánh dấu `[x]` / `[ ]` (hoặc chụp màn hình phần checklist).
2. Phần **Ghi chép** ở cuối file đã điền.
3. Khi có bước **không đạt**: dùng mẫu báo lỗi dưới đây.

### Mẫu báo lỗi

```
Luồng / bước: (vd 02 – bước 3)
Mã commit đang test: (lệnh: git rev-parse --short HEAD)
Máy / Android: (vd Samsung A52, Android 14)
Đã làm gì: …
Mong đợi: …
Thực tế: …
Giờ xảy ra: (giờ:phút, để Khanh đối chiếu log server)
Log: dán đoạn Logcat liên quan (xem 00-chuan-bi.md mục 5)
Ảnh/quay màn hình: (nếu có)
```

## Quy ước trong các file

- **Máy trẻ** = điện thoại cài app ở chế độ con; **máy phụ huynh** = máy đăng nhập tài khoản phụ huynh
  (có thể là emulator trong Android Studio).
- Giờ luôn là **giờ Việt Nam**.
- Ô `Khanh kiểm tra` = bước người test không tự xem được (cần xem database); chỉ cần báo giờ đã làm để Khanh tra.
