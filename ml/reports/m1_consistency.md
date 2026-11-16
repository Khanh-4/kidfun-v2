# M1 — số phút và xác suất vượt giới hạn có khớp nhau không

Dữ liệu mô phỏng, walk-forward từ 2026-03-02: 12,938 ngày có giới hạn, tỷ lệ vượt thực tế 33.0%.

**Mâu thuẫn ở `xgb_clf_iso`: 3,509/12,938 ngày = 27.1%** (số phút dự đoán vượt giới hạn mà p < 0,5, hoặc ngược lại).

| model            |   ROC-AUC |   Brier |   ECE |   số mức p khác nhau |
|:-----------------|----------:|--------:|------:|---------------------:|
| xgb_clf_iso      |     0.725 |   0.191 | 0.006 |                  601 |
| xgb_clf_iso_clip |     0.727 |   0.193 | 0.037 |                  568 |
| reg_resid        |     0.718 |   0.205 | 0.084 |                 6474 |

- `xgb_clf_iso_clip` (gói M1 dùng từ 16/11): hết mâu thuẫn, Brier gần như giữ nguyên, ECE tăng nhẹ.
- `reg_resid`: nhất quán và mịn nhưng hiệu chỉnh kém hơn — một phân phối sai số chung cho mọi trẻ không
  bắt được việc độ dao động khác nhau giữa các trẻ (bỏ dời trung vị cũng không khá hơn: ECE ~0,10).
