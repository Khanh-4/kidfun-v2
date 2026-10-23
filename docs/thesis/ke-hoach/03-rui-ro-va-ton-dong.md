# 3. Rủi ro, tồn đọng, câu hỏi chưa chốt

## Đang chờ

| Việc | Chờ ai | Ảnh hưởng tới |
|---|---|---|
| Kết quả chạy `docs/flowtest/00–03` trên máy thật | Người test | Mọi task sau; lỗi thì sửa trước khi làm T7 |
| Số đo pin mốc 24h (build commit `5b0a0b0`) và bản mới | Người test | RQ4 (T8.2) |
| `CRON_SECRET` để thử luật tăng đột biến trên máy thật | Khánh | Flowtest 02 |
| Hình thức báo cáo cuối (có phải viết dạng bài báo không) | GVHD | T9 |

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
| Tác vụ ban đêm cần đọc DB production từ GitHub Actions | Trung bình | Chọn ở T7.1.1: đọc qua API có `CRON_SECRET` hay chuỗi kết nối chỉ đọc | Chưa chốt |

## Tồn đọng kỹ thuật (đã biết, chưa làm)

- Chưa kiểm định thống kê chênh lệch giữa các mô hình M1 (Wilcoxon / Diebold–Mariano) → T8.4.
- LSTM chưa dò siêu tham số (14 ngày, 32 nút ẩn, 12 epoch).
- Bộ mô phỏng chưa sinh `GeofenceEvent`, nên nhóm đặc trưng vị trí chưa đánh giá được.
- Lịch học VN trong `ml/config/vn_school_calendar.csv` có nhiều ngày ước lượng (xem cột `note`).
- Bất thường `binge_day` có recall < 0,3 vì giới hạn chặn bớt (`docs/thesis/08`).
- Chưa dùng bộ dữ liệu Tsinghua App Usage dù đã nêu trong PDF.
- Câu giải thích chưa được phụ huynh thật chấm điểm dễ hiểu (thang 1–5) → T8.5.
