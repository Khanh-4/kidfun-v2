# 2. Lộ trình 9 tuần

## Kế hoạch gốc và tiến độ thực tế

Kế hoạch gốc nằm ở mục 6.2 của `thesis-topic01.pdf`. Phần việc của tuần 1–6 đã code xong trong tuần lịch 1–2,
nên đi trước kế hoạch khoảng 4 tuần. T7 (tuần KH 7) xong ở tuần lịch 5 và T8.4 làm sớm, nên tới 12/11 vẫn
**đi trước khoảng 2 tuần**. Số tuần dư dùng cho T8 (cần thời gian tích luỹ dữ liệu thật) và các
việc mở rộng ở [04-huong-phat-trien.md](04-huong-phat-trien.md).

| Tuần KH | Việc theo kế hoạch gốc | Thực tế | PR |
|---|---|---|---|
| 1 | Thiết kế hai tầng, EDA, đặc tả đặc trưng, bộ thu thập theo giờ, đo pin mốc | Xong, trừ số đo pin | #300–#306 |
| 2 | Đưa bộ thu thập vào dùng, bộ sinh mô phỏng, pipeline đặc trưng | Xong | #308 |
| 3 | M1: mô hình cơ sở, XGBoost, Prophet | Xong | #309 |
| 4 | M1: LSTM, xác suất vượt giới hạn, hiệu chỉnh | Xong | #310 |
| 5 | M2 tầng 2 + câu giải thích | Xong | #311 |
| 6 | M2 tầng 1, vòng phản hồi, M3/M4 gọn | Xong (chờ test máy thật) | #312–#316 |
| 7 | Tích hợp đầu cuối, tab AI Insights | **Xong** T7.1–T7.6 (05–11/11); flowtest 11, 12 đạt, 13 đạt nhưng cần APK mới để test lại phần sửa #359/#360 → [T7](tasks/T7-tich-hop.md) | #324–#327, #336–#360 |
| 8 | Kiểm thử máy thật, pin, đánh giá cuối | Đang làm: T8.4 kiểm định thống kê xong (trên mô phỏng + dữ liệu công khai), T8.1.1 kịch bản đo = flowtest 14; còn T8.1–T8.3, T8.5 chờ máy thật / dữ liệu thật → [T8](tasks/T8-kiem-thu-danh-gia.md) | #361, #362 |
| 9 | Báo cáo, slide, demo | Chưa làm → [T9](tasks/T9-bao-cao-demo.md) | |

## Lịch các tuần còn lại (đề xuất)

| Tuần lịch | Ngày | Việc chính | Mốc bàn giao |
|---|---|---|---|
| 3 | 26/10 – 01/11 | Xử lý kết quả test tuần 1–6; T7.1 tác vụ ban đêm, T7.2 API kết quả | Baseline thật được tính mỗi đêm |
| 4 | 02/11 – 08/11 | T7.3 M1 + M2 tầng 2 chạy theo lịch; T7.4 app phụ huynh (thông báo, nút đúng/sai) | Hệ thống chạy đầu cuối |
| 5 | 09/11 – 15/11 | T7.5 tab AI Insights; flowtest mới; bắt đầu tích luỹ dữ liệu và phản hồi thật | **Đã đạt** (T7 xong 11/11); làm thêm T8.4 + flowtest 14 |
| 6 | 16/11 – 22/11 | T8.1 đo độ trễ tầng 1, T8.2 đo pin trước/sau theo [flowtest 14](../../flowtest/14-do-tre-canh-bao-va-pin.md) | Số liệu RQ4 |
| 7 | 23/11 – 29/11 | T8.3, T8.5 đánh giá trên dữ liệu thật (chạy lại kiểm định T8.4 trên đó), khảo sát câu giải thích | Kết quả đánh giá cuối |
| 8 | 30/11 – 06/12 | T9.1 viết báo cáo, T9.2 slide | Bản nháp báo cáo gửi GVHD |
| 9 | 07/12 – 13/12 | T9.3 demo, sửa theo góp ý, dự phòng | Báo cáo, slide, demo hoàn chỉnh |

Lịch này phụ thuộc người test (T8 cần máy thật). Nếu test trễ thì kéo phần mở rộng ở `04` lên làm trước.

## Nhật ký tuần

Mỗi tuần thêm một dòng (cũng là nội dung cho phiếu theo dõi).

| Tuần lịch | Ngày | Tóm tắt |
|---|---|---|
| 1 | 12/10 – 18/10 | Chốt đề tài, cập nhật theo 4 góp ý GVHD, bộ thu thập theo giờ (đã triển khai), EDA LSApp + StudentLife, đặc tả đặc trưng |
| 2 | 19/10 – 25/10 | Đặc trưng M1/M2, bộ mô phỏng, M1 hoàn chỉnh, M2 hai tầng, phản hồi, M3/M4, API backend, flowtest; tạo thư mục kế hoạch này |
| 3 | 26/10 – 01/11 | Sửa lỗi đồng hồ đếm ngược, kết thúc phiên, cron báo cáo ngày (#321–#323); T7.1.1a API `thesis-data`, T7.1.2 `load.py`, T7.1.3 `baseline.py` + nới ngưỡng theo phản hồi (#324–#327); xoay `CRON_SECRET`; DB prod chưa có dữ liệu dùng app → flowtest 06 (#328) |
| 4 | 02/11 – 08/11 | Rà soát quyền app trẻ (#330), nhật ký YouTube theo ngày VN (#331); flowtest 07–10 (#332, #341); sửa lỗi test 03/11: FCM máy trẻ, cờ khoá cũ, mốc 06:00 (#333); push FCM nền văng lỗi làm chặn app/web không chạy (#334); backend chuyển syd1 cùng region DB (#335); T7.1.4 đóng gói M1 (#336); T7.1.5–T7.1.6 workflow `thesis-nightly` 21:05 (#337–#338); T7.2 bảng `UsagePrediction` + `behavior-results` + `predictions` (#339); T7.3.1 tác vụ dự đoán M1 (#340); prod bắt đầu có dữ liệu theo giờ (9 trẻ); phiếu tuần 4 (#342); T7.3.4 kiểm thử đầu cuối trên DB test (#343); T7.3.2 M2 tầng 2 DBSCAN ban đêm (#344); T7.4 màn cảnh báo hành vi + nút Đúng/Được phép (#345) |
| 5 | 09/11 – 15/11 | (tới 12/11) Sửa lỗi test 10/11: push FCM nền → isolate chính (#346), lịch học / giới hạn app qua FCM (#347), chế độ đi học (#348), xin thêm giờ (#349), mở lại phiên khi gỡ khoá (#350), heartbeat hạn mức 0 phút (#351); tác vụ ban đêm tính đúng ngày khi cron trễ (#352); T7.5 màn AI Insights (#353), M3/M4 + bảng HabitInsight (#354), bàn giao T7.6 (#356), M1 dùng nhóm tuổi (#357) → **T7 xong**; flowtest 11, 12, 13 đạt, sửa lệch thẻ dự đoán (#359, #360); T8.4 kiểm định thống kê (#361); flowtest 14 đo độ trễ + pin (#362) |
