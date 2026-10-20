# Đồ án chuyên ngành — Tuần 4: Bảng so sánh M1 hoàn chỉnh

> Số liệu đầy đủ: `ml/reports/m1_round2.md` (chạy lại: `ml/README.md` mục M1, khoảng 10 phút).
> Giao thức giống tuần 3 (`06-ket-qua-m1-dot1.md`): walk-forward theo tuần, chỉ chấm dòng có ≥ 7 ngày lịch sử.

## 1. Dự đoán số phút ngày mai — MAE (phút)

| Mô hình | Mô phỏng (trẻ em, 17.955) | LSApp (người lớn, 945) | StudentLife (sinh viên, 984) |
|---|---|---|---|
| XGBoost (tỷ lệ) | **33,6** | 84,5 | 146,5 |
| XGBoost (tuyệt đối) | 33,8 | 83,3 | 148,9 |
| LSTM | 36,8 | **80,2** | **142,3** |
| Prophet | 37,4 | 85,8 | 168,0 |
| Seasonal naive | 51,4 | 103,8 | 184,5 |
| MA7 | 52,3 | 81,4 | 148,0 |
| Naive | 68,6 | 103,7 | 184,9 |

(Số trong ngoặc ở tiêu đề là số dự đoán được chấm.)

- **Dữ liệu trẻ em mô phỏng:** XGBoost tốt nhất. LSTM xếp thứ hai, gần với Prophet. Cả ba đều tốt hơn rõ rệt so với
  mô hình cơ sở. Thời gian chạy cả 26 tuần: XGBoost khoảng 30 giây, LSTM 58 giây, Prophet 71 giây.
- **Dữ liệu công khai của người lớn:** LSTM nhỉnh nhất, MA7 sát ngay sau (LSApp: 80,2 so với 81,4; StudentLife: 142,3 so
  với 148,0). XGBoost chỉ ngang MA7. Tập kiểm tra dưới 1.000 dự đoán, chênh lệch nhỏ (1,5–4%) và trên StudentLife RMSE
  của MA7 còn tốt hơn LSTM, nên **không thể kết luận LSTM thật sự tốt hơn MA7**.
- **Trả lời RQ1:** mô hình phức tạp chỉ tốt hơn rõ ràng khi có tín hiệu riêng của bối cảnh (lịch học, giới hạn) và đủ
  dữ liệu. Với chuỗi ngắn, thiếu các tín hiệu đó, MA7 là mức sàn rất khó vượt. → **Khi triển khai: dùng XGBoost cho
  trẻ đã có ≥ 7 ngày dữ liệu, và luôn báo cáo kèm MA7 để đối chiếu.**

## 2. Xác suất ngày mai vượt giới hạn

12.938 ngày có giới hạn (mô phỏng), tỷ lệ vượt thực tế 33,0%.

| Mô hình | ROC-AUC | Brier | ECE |
|---|---|---|---|
| Phân phối chuẩn quanh MA7 | 0,656 | 0,265 | 0,227 |
| XGBoost phân loại | **0,732** | **0,191** | 0,033 |
| XGBoost + hiệu chỉnh isotonic | 0,727 | **0,191** | **0,007** |

Bảng tin cậy của mô hình đã hiệu chỉnh:

| Khoảng xác suất dự đoán | Số ngày | Xác suất dự đoán trung bình | Tỷ lệ vượt thực tế |
|---|---|---|---|
| 0–0,2 | 3.598 | 0,11 | 0,11 |
| 0,2–0,4 | 4.332 | 0,31 | 0,30 |
| 0,4–0,6 | 4.341 | 0,49 | 0,49 |
| 0,6–0,8 | 640 | 0,65 | 0,63 |
| 0,8–1 | 27 | 0,91 | 0,70 |

- Hiệu chỉnh isotonic giảm ECE từ 0,033 xuống 0,007: **"70%" thì thực tế xảy ra khoảng 70%**. Đây là điều kiện để
  câu cảnh báo "khả năng vượt giới hạn X%" (đặc tả 05 mục 3) đáng tin với phụ huynh. Riêng khoảng > 0,8 chỉ có 27 ngày
  nên còn lệch.
- ROC-AUC chỉ khoảng 0,73. Lý do: trong bộ sinh mô phỏng, trẻ có vượt giới hạn hay không phụ thuộc phần lớn vào việc
  phụ huynh **duyệt hay từ chối** xin thêm giờ, và việc này ngẫu nhiên, không dự đoán trước được. Trên dữ liệu thật,
  mức này phụ thuộc vào thói quen duyệt của từng gia đình.
- Ngưỡng gửi cảnh báo đề xuất: **p ≥ 0,6**, chiếm khoảng 5% số ngày, tỷ lệ đúng khoảng 64%. Sẽ điều chỉnh lại bằng vòng
  phản hồi của phụ huynh ở tuần 6.

## 3. Phân tích loại bỏ nhóm đặc trưng (XGBoost, mô phỏng; MAE đầy đủ = 33,8)

| Biến thể | MAE | Tăng so với đầy đủ |
|---|---|---|
| Chỉ nhóm A (lịch sử) | 38,0 | +4,2 |
| Bỏ B. Lịch | 36,4 | +2,5 |
| Bỏ A. Lịch sử | 36,2 | +2,4 |
| Bỏ C. Giới hạn | 34,6 | +0,8 |
| Bỏ G, E, F, D, H | 33,9–34,1 | ≤ +0,3 |

- Các nhóm ngoài lịch sử giúp giảm 11% MAE (38,0 → 33,8). **Lịch VN (B) đóng góp nhiều nhất, sau đó là giới hạn
  (C)**: đây chính là các tín hiệu mà dữ liệu công khai không có.
- Các nhóm D (xin thêm giờ), F (khuya), H (nội dung YouTube) gần như không giúp dự đoán **tổng số phút**. Một phần do
  bộ sinh mô phỏng không cho các nhóm này ảnh hưởng tới tổng ngày hôm sau. Vai trò chính của chúng là ở M2 (bất thường)
  và câu giải thích. Cần kiểm tra lại trên dữ liệu thật.

## 4. Hạn chế

- Dữ liệu mô phỏng được sinh theo đúng các quy luật mà bộ đặc trưng mô tả, nên kết quả trên mô phỏng có thể lạc quan.
  Dữ liệu công khai đều của người lớn.
- Chưa kiểm định ý nghĩa thống kê của chênh lệch giữa các mô hình (dự kiến làm kiểm định Diebold–Mariano ở tuần 8
  cùng dữ liệu thật).
- LSTM chưa dò siêu tham số (14 ngày, 32 nút ẩn, 12 epoch).

## 5. Việc tuần 5

M2 tầng 2: Isolation Forest, DBSCAN, Autoencoder trên đặc trưng theo giờ/ngày (đã có nhãn bất thường cài sẵn trong
`anomalies.csv`); bộ sinh câu giải thích (mẫu câu + SHAP).
