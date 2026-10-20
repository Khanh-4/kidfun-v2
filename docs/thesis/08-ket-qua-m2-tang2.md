# Đồ án chuyên ngành — Tuần 5: M2 tầng 2 (phát hiện bất thường) + câu giải thích

> Số liệu đầy đủ: `ml/reports/m2_round1.md`. Chạy lại: `cd ml && .venv/bin/python -m models.m2.evaluate --sim data/sim --out reports`
> (khoảng 3 phút).

## 1. Thiết lập

- **Dữ liệu:** dữ liệu mô phỏng 100 trẻ × 365 ngày, có sẵn 5 loại bất thường cài vào kèm nhãn: dùng khuya, tăng đột
  biến buổi tối, app lạ, cả ngày dùng gấp nhiều lần, video nguy hiểm.
- **Làm sạch nhãn:** bất thường được cài *trước* khi áp giới hạn thời gian, nên một số giờ bị cài lại bị máy chặn
  (0 phút). Những nhãn này bị bỏ: 1.873 → 1.527 nhãn giờ; 1.680 → 1.618 nhãn ngày.
- **Chia tập:** các mô hình học không giám sát (không dùng nhãn) trên dữ liệu trước 01/03/2026, chấm điểm từ ngày đó.
  Ngưỡng cảnh báo = phân vị của điểm trên tập huấn luyện, ứng với ngân sách cảnh báo **1% số giờ có dùng máy** (mức
  giờ) và **5% số ngày** (mức ngày). Nhãn không được dùng để chọn ngưỡng.
- **Hai mức chấm điểm:**
  - **mức giờ** cho các bất thường dùng khuya, tăng đột biến, app lạ: 174.369 giờ kiểm tra, 676 giờ bất thường;
  - **mức ngày** cho cả 5 loại: 17.854 ngày kiểm tra, 845 ngày bất thường.

## 2. Kết quả

### Mức giờ

| Bộ phát hiện | PR-AUC | Precision | Recall | F1 | Recall: khuya | Recall: đột biến | Recall: app lạ |
|---|---|---|---|---|---|---|---|
| z-score (so với cùng giờ, cùng loại ngày) | **0,61** | **0,33** | 0,66 | **0,44** | 0,96 | 0,45 | 0,65 |
| Isolation Forest | 0,59 | 0,08 | **0,74** | 0,15 | **1,00** | 0,47 | 0,95 |
| Luật tầng 1 | 0,54 | 0,19 | 0,66 | 0,29 | 0,99 | 0,35 | 0,81 |
| Autoencoder | 0,36 | 0,12 | 0,61 | 0,20 | 0,42 | **0,60** | **0,98** |

### Mức ngày

| Bộ phát hiện | PR-AUC | Precision | Recall | F1 | Cả ngày | Nội dung | App lạ | Khuya | Đột biến |
|---|---|---|---|---|---|---|---|---|---|
| DBSCAN | **0,70** | **0,51** | **0,76** | **0,61** | 0,27 | 0,89 | 0,97 | 0,95 | 0,76 |
| Isolation Forest | 0,60 | **0,51** | 0,61 | 0,56 | 0,18 | 0,91 | 0,89 | 0,65 | 0,44 |
| Autoencoder | 0,51 | 0,42 | 0,50 | 0,46 | 0,26 | 0,34 | 0,86 | 0,63 | 0,51 |
| Luật tầng 1 | 0,18 | 0,23 | 0,20 | 0,21 | 0,15 | 0,24 | 0,35 | 0,17 | 0,12 |
| z-score (tỷ lệ so với ngày thường) | 0,13 | 0,16 | 0,15 | 0,15 | 0,23 | 0,04 | 0,10 | 0,17 | 0,20 |

## 3. Nhận xét

1. **Kiến trúc hai tầng được ủng hộ bởi số liệu:**
   - **Tầng 1 (luật trên máy trẻ)** bắt được 99% các giờ dùng khuya, với chi phí tính toán gần bằng 0. Nó đủ để gửi
     cảnh báo tức thì, không cần chờ lô ban đêm (đúng góp ý 1 của GVHD).
   - **Tầng 2 (server)** cần các mô hình nhìn nhiều tín hiệu cùng lúc. Ở mức ngày, DBSCAN và Isolation Forest vượt xa
     luật và z-score (PR-AUC 0,70 / 0,60 so với 0,18 / 0,13), vì bất thường ngày là sự kết hợp của nhiều đặc trưng:
     app lạ, nội dung, khung giờ.
2. **Ở mức giờ, z-score đơn giản lại tốt nhất:** PR-AUC 0,61, F1 0,44, và chỉ cảnh báo 0,8% số giờ. Isolation Forest có
   recall cao hơn nhưng cảnh báo tới 3,5% số giờ thay vì 1%. Lý do: tập kiểm tra rơi vào mùa hè, trẻ dùng nhiều hơn so
   với giai đoạn huấn luyện, nên ngưỡng cố định bị vượt nhiều hơn (dữ liệu trôi theo mùa). Autoencoder chậm nhất (59
   giây) mà kém nhất.
3. **Khó nhất là "tăng đột biến" và "cả ngày dùng gấp nhiều lần":**
   - Tăng đột biến buổi tối có recall ≤ 0,6, vì buổi tối vốn là lúc trẻ dùng nhiều, nên khác biệt khó nổi lên.
   - "Cả ngày dùng gấp nhiều lần" có recall dưới 0,3 ở mọi mô hình. Lý do: 70% trẻ mô phỏng có giới hạn thời gian, nên
     ngày định dùng gấp 2,5 lần bị **chính giới hạn chặn lại** và trông như một ngày chạm giới hạn bình thường. Đây là
     kết quả hợp lý: giới hạn đã xử lý loại bất thường này rồi.
4. **Đề xuất triển khai:**
   - mức giờ dùng luật tầng 1 (trên máy trẻ) + z-score (server);
   - mức ngày dùng DBSCAN, Isolation Forest làm phương án dự phòng (nhanh hơn 4 lần).
   - Ngưỡng sẽ hiệu chỉnh theo phản hồi của phụ huynh ở tuần 6.

## 4. Câu giải thích

Với mỗi cảnh báo **đúng**, kiểm tra câu giải thích có nói đúng loại bất thường đã cài không:

| Loại | Mức giờ (z-score) | Mức ngày (DBSCAN) |
|---|---|---|
| Dùng khuya | 99% | 88% |
| App lạ | 86% | 77% |
| Tăng đột biến | 84% | 52% |
| Nội dung nguy hiểm | — | 100% |
| Cả ngày dùng nhiều | — | 30% |

Ví dụ câu sinh ra:

- "Bé chơi game lúc 3h trong 38 phút — giờ này bé thường đã ngủ."
- "Hôm nay bé xem 3 video có thể không phù hợp với lứa tuổi."
- "Hôm nay bé dùng máy 1 giờ 20 phút, gấp 2 lần một ngày đi học bình thường (khoảng 37 phút)."
- (M1, lý do lấy từ SHAP của XGBoost) "Ngày mai (thứ Sáu) bé có khả năng dùng quá giới hạn 1 giờ (khoảng 80%). Lý do
  chính: giới hạn ngày mai thấp so với thói quen của bé."

Ghi chú:

- **Lỗi đã sửa trong tuần:** ban đầu số phút khuya của ngày d được tính theo "đêm d" (22h ngày d → 6h ngày d+1), nên giờ
  dùng lúc 1–3h sáng bị tính sang hôm trước. Câu giải thích "dùng khuya" ở mức ngày vì thế chỉ đúng 14%. Sau khi sửa
  thành khung khuya *trong chính ngày d*, tỷ lệ đúng lên 88%, và recall "khuya" của DBSCAN tăng từ 0,82 lên 0,95.
- Câu sai loại nhiều nhất là ở "tăng đột biến": câu thường nói "app mới", vì nhóm app bị đẩy lên là app trẻ hiếm khi
  dùng trước đó. Về nội dung câu vẫn đúng, chỉ khác cách gọi loại.
- **Lỗi đã sửa ở M1:** đặc trưng `days_to_next_holiday` đóng vai trò biến chỉ thời gian và chiếm vị trí "lý do chính"
  một cách sai lệch. Nay đã chặn ở 14 ngày (xem `07-ket-qua-m1-hoan-chinh.md` mục 4). Cũng nhờ kiểm tra câu giải thích
  mà phát hiện ra lỗi này.

## 5. Hạn chế

- Bất thường cài sẵn do bộ sinh tạo ra, nên rõ ràng hơn bất thường thật. Recall trên dữ liệu thật sẽ thấp hơn.
- Ngưỡng cố định bị lệch khi hành vi đổi theo mùa (hè). Cần cập nhật mức thường ngày liên tục (đã có cửa sổ 28 ngày) và
  hiệu chỉnh ngưỡng theo phản hồi.
- Chưa dùng thư viện `shap` riêng: M1 dùng SHAP tính sẵn của XGBoost (`pred_contribs`), M2 dùng độ lệch so với mức
  thường ngày, vì các bộ phát hiện không giám sát không có SHAP chuẩn.

## 6. Việc tuần 6

- M2 tầng 1 trên máy trẻ (Kotlin): luật khuya / đột biến + JSON mức thường ngày do server gửi xuống, API nhận cảnh báo
  tức thì.
- Vòng phản hồi: bảng phản hồi, điều chỉnh ngưỡng, thực nghiệm "phụ huynh mô phỏng".
- M3, M4 ở mức gọn.
