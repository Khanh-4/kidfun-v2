# 2. Lộ trình 9 tuần

## Kế hoạch gốc và tiến độ thực tế

Kế hoạch gốc nằm ở mục 6.2 của `thesis-topic01.pdf`. Phần việc của tuần 1–6 đã code xong trong tuần lịch 1–2,
nên hiện **đi trước kế hoạch khoảng 4 tuần**. Số tuần dư dùng cho T8 (cần thời gian tích luỹ dữ liệu thật) và các
việc mở rộng ở [04-huong-phat-trien.md](04-huong-phat-trien.md).

| Tuần KH | Việc theo kế hoạch gốc | Thực tế | PR |
|---|---|---|---|
| 1 | Thiết kế hai tầng, EDA, đặc tả đặc trưng, bộ thu thập theo giờ, đo pin mốc | Xong, trừ số đo pin | #300–#306 |
| 2 | Đưa bộ thu thập vào dùng, bộ sinh mô phỏng, pipeline đặc trưng | Xong | #308 |
| 3 | M1: mô hình cơ sở, XGBoost, Prophet | Xong | #309 |
| 4 | M1: LSTM, xác suất vượt giới hạn, hiệu chỉnh | Xong | #310 |
| 5 | M2 tầng 2 + câu giải thích | Xong | #311 |
| 6 | M2 tầng 1, vòng phản hồi, M3/M4 gọn | Xong (chờ test máy thật) | #312–#316 |
| 7 | Tích hợp đầu cuối, tab AI Insights | Chưa làm → [T7](tasks/T7-tich-hop.md) | |
| 8 | Kiểm thử máy thật, pin, đánh giá cuối | Chưa làm → [T8](tasks/T8-kiem-thu-danh-gia.md) | |
| 9 | Báo cáo, slide, demo | Chưa làm → [T9](tasks/T9-bao-cao-demo.md) | |

## Lịch các tuần còn lại (đề xuất)

| Tuần lịch | Ngày | Việc chính | Mốc bàn giao |
|---|---|---|---|
| 3 | 26/10 – 01/11 | Xử lý kết quả test tuần 1–6; T7.1 tác vụ ban đêm, T7.2 API kết quả | Baseline thật được tính mỗi đêm |
| 4 | 02/11 – 08/11 | T7.3 M1 + M2 tầng 2 chạy theo lịch; T7.4 app phụ huynh (thông báo, nút đúng/sai) | Hệ thống chạy đầu cuối |
| 5 | 09/11 – 15/11 | T7.5 tab AI Insights; flowtest mới; bắt đầu tích luỹ dữ liệu và phản hồi thật | App phụ huynh đủ tính năng |
| 6 | 16/11 – 22/11 | T8.1 đo độ trễ tầng 1, T8.2 đo pin trước/sau | Số liệu RQ4 |
| 7 | 23/11 – 29/11 | T8.3–T8.5 đánh giá trên dữ liệu thật, kiểm định thống kê, khảo sát câu giải thích | Kết quả đánh giá cuối |
| 8 | 30/11 – 06/12 | T9.1 viết báo cáo, T9.2 slide | Bản nháp báo cáo gửi GVHD |
| 9 | 07/12 – 13/12 | T9.3 demo, sửa theo góp ý, dự phòng | Báo cáo, slide, demo hoàn chỉnh |

Lịch này phụ thuộc người test (T8 cần máy thật). Nếu test trễ thì kéo phần mở rộng ở `04` lên làm trước.

## Nhật ký tuần

Mỗi tuần thêm một dòng (cũng là nội dung cho phiếu theo dõi).

| Tuần lịch | Ngày | Tóm tắt |
|---|---|---|
| 1 | 12/10 – 18/10 | Chốt đề tài, cập nhật theo 4 góp ý GVHD, bộ thu thập theo giờ (đã triển khai), EDA LSApp + StudentLife, đặc tả đặc trưng |
| 2 | 19/10 – 25/10 | Đặc trưng M1/M2, bộ mô phỏng, M1 hoàn chỉnh, M2 hai tầng, phản hồi, M3/M4, API backend, flowtest; tạo thư mục kế hoạch này |
