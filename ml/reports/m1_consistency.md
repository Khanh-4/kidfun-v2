# M1 — số phút và xác suất dùng hết giờ có khớp nhau không

Dữ liệu mô phỏng, walk-forward từ 2026-03-02: 12,938 ngày có giới hạn, tỷ lệ dùng hết giờ thực tế 62.8%.

**Ngày mâu thuẫn trước khi kẹp** (số phút dự đoán ≥ giới hạn − 5 mà p < 0,5, hoặc ngược lại): `xgb_clf_iso` 12.6%, `xgb_clf_platt` 12.4%.

| model              |   ROC-AUC |   Brier |   ECE |   số mức p khác nhau |
|:-------------------|----------:|--------:|------:|---------------------:|
| xgb_clf_iso        |     0.853 |   0.149 | 0.014 |                  714 |
| xgb_clf_iso_clip   |     0.853 |   0.149 | 0.018 |                  697 |
| xgb_clf_platt      |     0.855 |   0.149 | 0.017 |                 6553 |
| xgb_clf_platt_clip |     0.855 |   0.149 | 0.015 |                 5867 |
| reg_resid          |     0.836 |   0.177 | 0.144 |                 6563 |

- Kẹp: hết mâu thuẫn, Brier gần như giữ nguyên, ECE tăng nhẹ.
- Platt thay isotonic: Brier như nhau, xác suất liên tục thay vì ~26 mức. **Gói M1 dùng `xgb_clf_platt_clip` từ 16/11.**
- `reg_resid`: nhất quán và mịn nhưng hiệu chỉnh kém hơn — một phân phối sai số chung cho mọi trẻ không
  bắt được việc độ dao động khác nhau giữa các trẻ.
