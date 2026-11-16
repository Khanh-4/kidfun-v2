# M1 — số phút và xác suất vượt giới hạn có khớp nhau không

Dữ liệu mô phỏng, walk-forward từ 2026-03-02: 12,938 ngày có giới hạn, tỷ lệ vượt thực tế 33.0%.

**Ngày mâu thuẫn trước khi kẹp** (số phút dự đoán vượt giới hạn mà p < 0,5, hoặc ngược lại): `xgb_clf_iso` 27.1%, `xgb_clf_platt` 29.2%.

| model              |   ROC-AUC |   Brier |   ECE |   số mức p khác nhau |
|:-------------------|----------:|--------:|------:|---------------------:|
| xgb_clf_iso        |     0.725 |   0.191 | 0.006 |                  601 |
| xgb_clf_iso_clip   |     0.727 |   0.193 | 0.037 |                  568 |
| xgb_clf_platt      |     0.726 |   0.191 | 0.014 |                 5768 |
| xgb_clf_platt_clip |     0.726 |   0.192 | 0.04  |                 4984 |
| reg_resid          |     0.718 |   0.205 | 0.084 |                 6474 |

- Kẹp: hết mâu thuẫn, Brier gần như giữ nguyên, ECE tăng nhẹ.
- Platt thay isotonic: Brier như nhau, xác suất liên tục thay vì ~26 mức. **Gói M1 dùng `xgb_clf_platt_clip` từ 16/11.**
- `reg_resid`: nhất quán và mịn nhưng hiệu chỉnh kém hơn — một phân phối sai số chung cho mọi trẻ không
  bắt được việc độ dao động khác nhau giữa các trẻ (bỏ dời trung vị cũng không khá hơn: ECE ~0,10).
