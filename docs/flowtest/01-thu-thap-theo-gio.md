# 01 — Bộ thu thập thời gian dùng app theo giờ (PR #303)

**Tính năng:** cứ khoảng 30 phút, app trẻ tính số phút dùng từng app trong từng giờ rồi gửi lên server (bảng
`AppUsageHourly`). Đây là dữ liệu đầu vào cho các mô hình học máy của đồ án.

**Cần:** đã làm xong [00-chuan-bi.md](00-chuan-bi.md), máy trẻ đã liên kết, bản **debug** chạy từ Android Studio.
Máy trẻ phải mở app KidFun ít nhất một lần sau khi cài, để app lên lịch thu thập.

## Bước 1 — Dữ liệu vắt qua mốc giờ

1. Khoảng **hh:50** (vd 21:50), trên máy trẻ mở **YouTube**, xem liên tục khoảng **10 phút**, qua mốc giờ (tới ~22:00).
2. Đóng YouTube, ghi lại giờ bắt đầu và giờ kết thúc.
3. Chờ tối đa **40 phút** (worker chạy 30 phút/lần, Android có thể lùi lịch vài phút).

**Kết quả mong đợi**
- [ ] Logcat (tag `HourlyUsageWorker`) **không** có dòng chứa `thất bại` hoặc `từ chối`.
- [ ] `Khanh kiểm tra`: bảng `AppUsageHourly` có dòng YouTube ở **cả hai giờ** (vd 21:00 và 22:00), tổng khoảng
      10 phút. → Báo Khanh giờ bắt đầu/kết thúc.

## Bước 2 — Mất mạng rồi gửi bù

1. Bật **Chế độ máy bay** (tắt cả Wi-Fi lẫn 4G) trên máy trẻ.
2. Trong lúc mất mạng: dùng 2 app khác nhau (vd một game và Chrome), mỗi app khoảng 10 phút. Ghi lại giờ.
3. Để máy mất mạng khoảng **1 giờ**, rồi tắt Chế độ máy bay.
4. Chờ tối đa **40 phút**.

**Kết quả mong đợi**
- [ ] Trong lúc mất mạng: Logcat có thể có `Gửi dữ liệu theo giờ thất bại, thử lại sau` (bình thường).
- [ ] Sau khi có mạng lại: không còn dòng lỗi; app không crash.
- [ ] `Khanh kiểm tra`: dữ liệu của 2 app trong lúc mất mạng có đủ trên server (gửi bù).

## Bước 3 — Gỡ liên kết thì ngừng gửi

1. Trên máy phụ huynh: gỡ liên kết máy trẻ (xoá thiết bị). Ghi lại giờ.
2. Dùng máy trẻ thêm khoảng 10 phút, chờ 40 phút.

**Kết quả mong đợi**
- [ ] Logcat có dòng `Thiết bị không còn liên kết, huỷ lịch thu thập theo giờ` (có thể xuất hiện ở lần chạy kế tiếp).
- [ ] Sau đó không còn log `HourlyUsageWorker` định kỳ nữa.
- [ ] `Khanh kiểm tra`: không có dữ liệu mới sau giờ gỡ liên kết.

Liên kết lại máy trẻ (theo 00-chuan-bi.md mục 4) trước khi làm luồng 02.

## Ghi chép

| Mục | Giá trị |
|---|---|
| Mã commit | |
| Bước 1: giờ bắt đầu – kết thúc xem YouTube | |
| Bước 2: giờ bật / tắt Chế độ máy bay; app đã dùng | |
| Bước 3: giờ gỡ liên kết | |
| Ghi chú khác | |
