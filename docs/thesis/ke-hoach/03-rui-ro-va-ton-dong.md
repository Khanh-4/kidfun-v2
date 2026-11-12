# 3. Rủi ro, tồn đọng, câu hỏi chưa chốt

## Đang chờ

| Việc | Chờ ai | Ảnh hưởng tới |
|---|---|---|
| Kết quả flowtest 02 (cảnh báo tầng 1 trên máy thật). Flowtest 01 coi như đạt vì prod đã có dữ liệu theo giờ; 03 đã test lại sau #319 | Người test | Flowtest 14 phần A cần tầng 1 chạy đúng |
| ~~Kết quả flowtest 06: DB production 0 dòng `AppUsageHourly`~~ — 05/11 đã có 9 trẻ / 32 dòng | — | Đã có dữ liệu; chờ đủ 7 ngày |
| Test lại flowtest 10 sau #346 (chặn app/web khi chạy nền), tốc độ API sau khi chuyển syd1 | Người test | Ổn định app trước T8 |
| Máy trẻ chạy liên tục 7–14 ngày có Usage Access (flowtest 10 Bước 6) | Người test | Baseline/dự đoán thật (≥ 7 ngày), M2 tầng 2 (≥ 14 ngày), T8 |
| Số đo pin 24h bản mốc `5b0a0b0` và bản mới ([flowtest 14](../../flowtest/14-do-tre-canh-bao-va-pin.md) phần B) | Người test | RQ4 (T8.2) |
| Nạp mức thường ngày giả trước mỗi buổi A2 của flowtest 14 (luật tăng đột biến) | Khánh | T8.1 |
| Flowtest 14 phần A: độ trễ tầng 1, ≥ 2 máy, 3 đêm + 3 buổi chiều mỗi máy | Người test | RQ4 (T8.1) |
| Build APK phụ huynh mới (#359, #360) → test lại flowtest 13 bước 4.2/4.3/5.1/5.1b | Khánh build, người test | Đóng T7 trên máy thật |
| Flowtest 05 bước 5 (hạn mức 0 phút không làm nhảy đồng hồ, #351) | Người test | Đồng hồ đếm ngược |
| Chọn bản mốc đo pin: giữ `5b0a0b0` (rủi ro Socket.IO, xem bảng Rủi ro) hay làm bản mốc sạch hơn | Khánh | T8.2 |
| Hình thức báo cáo cuối (có phải viết dạng bài báo không), lịch nộp nháp và lịch bảo vệ | GVHD | T9 |

## Rủi ro

| Rủi ro | Mức | Hướng xử lý | Trạng thái |
|---|---|---|---|
| Dữ liệu thật về trẻ em quá ít | Cao | Huấn luyện, so sánh trên mô phỏng + công khai; dữ liệu thật để demo và kiểm tra cuối; ghi rõ trong báo cáo | Đã tính trong thiết kế |
| Kết quả trên mô phỏng lạc quan (bộ sinh theo đúng quy luật của đặc trưng) | Trung bình | Kiểm chứng thêm trên LSApp, StudentLife; nêu thành hạn chế | Đã ghi ở `docs/thesis/07`, `08` |
| Hãng Android kill app chạy nền, chặn quyền thống kê | Trung bình | Gửi theo đợt; test ≥ 2 dòng máy; hướng dẫn tắt tối ưu pin | Chờ test máy thật |
| Tầng 1 báo nhầm lúc nửa đêm làm phiền phụ huynh | Trung bình | Luật khuya cá nhân hoá (báo nhầm 92% → 42%), nới ngưỡng theo phản hồi | Đã giảm; cần số liệu thật |
| Phản hồi thật của phụ huynh quá ít | Cao | Đánh giá RQ5 chủ yếu bằng "phụ huynh mô phỏng"; phản hồi thật dùng minh hoạ | Đã có kết quả mô phỏng |
| Migration lên nhầm DB production | Cao | Lệnh Prisma ghi đè cả `DATABASE_URL` lẫn `DIRECT_URL`; hỏi trước khi push nhánh có migration | Quy tắc đã áp dụng |
| Quyền riêng tư của trẻ | Trung bình | Chỉ dùng dữ liệu có đồng ý; ẩn danh khi phân tích; dữ liệu không rời hệ thống | Cần nhắc lại trong báo cáo |
| Tác vụ ban đêm cần đọc DB production từ GitHub Actions | Trung bình | Đọc qua API có `CRON_SECRET`, chỉ trả cột cần, không nối thẳng DB | Đã chốt 23/10 (T7.1.1) |
| Bản mốc đo pin `5b0a0b0` còn Socket.IO mà server đã bỏ (#333): app cũ kết nối lại liên tục → pin bản mốc tốn hơn thực tế, lợi cho bản mới | Trung bình | Đếm số lần kết nối lại trong bugreport/netstats của lần A; ghi thành hạn chế, hoặc làm bản mốc sạch hơn | Mới (12/11), chờ chốt |
| GitHub chạy cron `thesis-nightly` trễ 6–15 giờ | Trung bình | Job tự tính ngày tác vụ (`task_day`, mốc 12:00 VN); M1 cắt dữ liệu ở 21:00 theo thiết kế | Đã xử lý (#352, #354) |
| Mức thường ngày giả thiếu `categories` → máy trẻ coi mọi app là "other", luật game không bao giờ báo | Thấp | Script trong flowtest 14 tự nạp từ `ml/config/app_categories.csv`; game test phải có trong csv | Đã ghi vào flowtest 14 |

## Tồn đọng kỹ thuật (đã biết, chưa làm)

- ~~Chưa kiểm định thống kê~~ — xong 12/11 (T8.4, #361) trên mô phỏng + LSApp + StudentLife. Còn chạy lại trên dữ
  liệu thật ở T8.3. Kết quả đáng chú ý: StudentLife LSTM hơn MA7 chỉ sát ngưỡng (p Holm 0,048); mức giờ M2 chưa phân
  biệt được z-score và Isolation Forest.
- LSTM chưa dò siêu tham số (14 ngày, 32 nút ẩn, 12 epoch).
- Bộ mô phỏng chưa sinh `GeofenceEvent`, nên nhóm đặc trưng vị trí chưa đánh giá được.
- Lịch học VN trong `ml/config/vn_school_calendar.csv` có nhiều ngày ước lượng (xem cột `note`).
- Bất thường `binge_day` có recall < 0,3 vì giới hạn chặn bớt (`docs/thesis/08`).
- Chưa dùng bộ dữ liệu Tsinghua App Usage dù đã nêu trong PDF.
- Câu giải thích chưa được phụ huynh thật chấm điểm dễ hiểu (thang 1–5) → T8.5.
- ~~Gói M1 chưa dùng tuổi~~ — đã nối 11/11: `jobs/predict.py` ghép `profiles[].ageGroup` từ `thesis-data`. Trẻ **chưa
  nhập ngày sinh** vẫn bị coi là thiếu tuổi (kém chính xác hơn) → nhắc phụ huynh nhập ngày sinh trước T8.3.
- K-Means (M3) chỉ chạy khi ≥ 6 trẻ đủ 7 ngày dữ liệu; production hiện ít trẻ nên app chỉ thấy mô tả "so với các
  bé khác", chưa có số nhóm.
- Trẻ không dùng máy cả ngày hôm nay (không có dòng nào) thì tác vụ không dự đoán ngày mai (`predict.py` cần dòng
  của hôm nay). Chấp nhận được lúc này; xem lại nếu dữ liệu thật hay thiếu ngày.
- Xác suất vượt giới hạn của M1 rất thô vì hiệu chỉnh isotonic là hàm bậc thang (~25 bậc): trong kiểm thử đầu cuối
  (T7.3.4) hai trẻ dùng máy khác hẳn nhau cùng ra p = 0,362. Xem xét Platt scaling hoặc isotonic trên tập hiệu chỉnh
  lớn hơn khi đánh giá ở T8.3.
- M1 hai mô hình có lúc mâu thuẫn: trong E2E 07/11 trẻ "thap" được dự đoán 76 phút > giới hạn 67 nhưng p vượt = 0,000
  (bộ phân loại và bộ hồi quy học riêng). App phụ huynh (T7.4/T7.5) nên hiện cả hai cho nhất quán hoặc ghi chú; xem
  lại ở T8.3.
- Test `backend/tests/integration/todayLimitReboot.test.js` fail nếu chạy trong 06:00–06:40 giờ VN (log tạo lúc
  now − 40 phút rơi sang ngày hạn mức trước, mốc 06:00 từ PR #333). Không phải lỗi sản phẩm; sửa test cho cố định giờ.
