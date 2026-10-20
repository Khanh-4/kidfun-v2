# Đồ án chuyên ngành — Tuần 3: Kết quả thực nghiệm M1 (đợt 1)

> Số liệu đầy đủ: `ml/reports/m1_round1.md`. Cách chạy lại: `ml/README.md` mục M1.

## 1. Thiết lập

- **Bài toán:** lúc 21:00 giờ VN ngày t, dự đoán tổng phút dùng máy của ngày t+1 (`y_next`).
- **Đánh giá walk-forward theo tuần:** với mỗi tuần kiểm tra, huấn luyện trên mọi ngày *trước* tuần đó rồi dự đoán
  các ngày trong tuần. Chỉ chấm các dòng có ít nhất 7 ngày lịch sử (đặc tả 05 mục 1.3).
- **Dữ liệu:**
  - mô phỏng: 100 trẻ, 01/09/2025 – 31/08/2026 (seed 42); kiểm tra 26 tuần từ 02/03/2026, gồm 17.955 dự đoán;
  - LSApp: kiểm tra nửa sau khoảng thời gian, 93 người lớn, 945 dự đoán.
- **Mô hình:**

| Mô hình | Mô tả |
|---|---|
| naive | ngày mai = ngày đầy đủ gần nhất (t−1) |
| seasonal_naive | ngày mai = cùng thứ tuần trước |
| ma7 | trung bình 7 ngày đầy đủ gần nhất |
| xgb_abs | XGBoost, **một mô hình chung cho mọi trẻ**, dự đoán số phút |
| xgb_rel | XGBoost chung, dự đoán tỷ lệ `y_next / mean7` rồi nhân lại (đặc trưng tương đối) |
| prophet | mỗi trẻ một mô hình: xu hướng + chu kỳ tuần + biến lịch VN; dự đoán nhiều bước (1–7 ngày), không dùng dữ liệu trong ngày |

## 2. Kết quả chính

| Mô hình | Mô phỏng: MAE (phút) | Mô phỏng: WAPE | LSApp: MAE (phút) | LSApp: WAPE |
|---|---|---|---|---|
| xgb_rel | **33,6** | **13,4%** | 84,5 | 45,0% |
| xgb_abs | 33,8 | 13,4% | 83,3 | 45,7% |
| prophet | 37,4 | 14,9% | 85,8 | 46,3% |
| seasonal_naive | 51,4 | 20,4% | 103,8 | 54,5% |
| ma7 | 52,3 | 20,8% | **81,4** | **43,3%** |
| naive | 68,6 | 26,8% | 103,7 | 51,0% |

## 3. Nhận xét

1. **Trên dữ liệu mô phỏng (trẻ em, có lịch VN và giới hạn), XGBoost tốt nhất.** MAE thấp hơn mô hình cơ sở tốt nhất
   (seasonal naive) khoảng 35%. Mức giảm sai số giữ nguyên ở mọi nhóm tuổi và mọi loại ngày. Cuối tuần là loại ngày
   khó nhất: MAE 45 phút, so với 30 phút ở ngày học.
2. **Hai biến thể XGBoost ngang nhau.** Dự đoán tỷ lệ so với MA7 không tốt hơn dự đoán số phút trực tiếp, vì đặc
   trưng tương đối đã có sẵn trong đầu vào. Giữ cả hai biến thể để kiểm tra lại trên dữ liệu thật.
3. **Prophet đứng thứ 3 dù chịu thiệt thòi:** nó dự đoán xa tới 7 ngày và không dùng phần dữ liệu đã có trong ngày t.
   Điểm yếu thực tế là tốn thời gian: phải huấn luyện mỗi trẻ một mô hình, chậm hơn khoảng 2,3 lần so với XGBoost.
4. **Trên LSApp, MA7 tốt nhất. Mô hình phức tạp không giúp được gì** (kém hơn MA7 2–5%). Điều này khớp với EDA tuần 1:
   người lớn không có chu kỳ tuần, mỗi người ít ngày, và không có tín hiệu giới hạn hay lịch học. Đây là câu trả lời
   một phần cho RQ1: **khi chuỗi ngắn và thiếu tín hiệu đặc thù, mô hình cơ sở đơn giản đủ tốt**.
   Lợi thế của XGBoost đến từ các nhóm đặc trưng riêng của hệ thống quản lý thời gian dùng máy.

## 4. Hạn chế của đợt 1

- Dữ liệu mô phỏng được sinh theo đúng các quy luật mà bộ đặc trưng mô tả (lịch, giới hạn, xin thêm giờ),
  nên kết quả trên mô phỏng có thể **lạc quan**. Cần đối chiếu với dữ liệu thật KidFun khi đã tích luỹ đủ.
- Chưa chứng minh được nhóm đặc trưng nào tạo ra lợi thế → làm phân tích loại bỏ (ablation) theo nhóm A–I ở tuần 4.
- LSApp không rõ múi giờ (đang coi là giờ địa phương); tập kiểm tra LSApp nhỏ (945 dự đoán).
- `TimeLimit` không lưu lịch sử thay đổi, nên đặc trưng giới hạn dùng trạng thái hiện tại cho mọi ngày.

## 5. Việc tuần 4

LSTM; xác suất vượt giới hạn (`over_limit_next`) và hiệu chỉnh xác suất (ROC-AUC, Brier);
ablation theo nhóm đặc trưng; chạy thêm trên StudentLife; tổng hợp bảng so sánh M1 hoàn chỉnh.
