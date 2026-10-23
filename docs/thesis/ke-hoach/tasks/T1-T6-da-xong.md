# T1–T6 — Các task đã code xong

Ghi lại để tra cứu. Chi tiết ở tài liệu và PR được dẫn. Những subtask **chưa tick** là phần còn treo của task đó.

## T1 — Thu thập dữ liệu theo giờ (tuần KH 1–2)

- [x] T1.1 Bảng `AppUsageHourly` + `POST /api/child/app-usage/hourly` (PR #303, đã lên production).
- [x] T1.2 App trẻ: `HourlyBucketer.kt`, `HourlyUsageWorker.kt` (WorkManager 30 phút, gửi theo lô).
- [x] T1.3 Thiết kế: `docs/thesis/01-thiet-ke-thu-thap-theo-gio.md`.
- [ ] T1.4 Test máy thật theo `docs/flowtest/01-thu-thap-theo-gio.md` (chờ: người test).
- [ ] T1.5 Số đo pin mốc 24h theo `docs/flowtest/04-do-pin.md` (chờ: người test).

## T2 — EDA dữ liệu công khai và đặc tả (tuần KH 1)

- [x] T2.1 EDA LSApp (PR #304) → `docs/thesis/02-eda-lsapp.md`.
- [x] T2.2 EDA StudentLife (PR #305) → `docs/thesis/03-eda-studentlife.md`.
- [x] T2.3 Hướng dẫn đo pin + đặc tả đặc trưng (PR #306) → `docs/thesis/04`, `05`.

## T3 — Đặc trưng và bộ mô phỏng (tuần KH 2)

- [x] T3.1 `ml/config/` (nhóm app, lịch học VN), `ml/features/` daily (M1) + hourly (M2) (PR #308).
- [x] T3.2 `ml/simulator/`: 100 trẻ × 365 ngày, 5 loại bất thường có nhãn.
- [ ] T3.3 Sinh `GeofenceEvent` trong mô phỏng → chuyển sang mở rộng A3.

## T4 — M1 dự đoán (tuần KH 3–4)

- [x] T4.1 Mô hình cơ sở, XGBoost, Prophet, walk-forward (PR #309) → `docs/thesis/06`.
- [x] T4.2 LSTM, xác suất vượt giới hạn + isotonic, ablation, StudentLife (PR #310) → `docs/thesis/07`.
- [ ] T4.3 Kiểm định thống kê giữa các mô hình → chuyển sang T8.4.

## T5 — M2 tầng 2 và câu giải thích (tuần KH 5)

- [x] T5.1 Isolation Forest, DBSCAN, Autoencoder, z-score; mức giờ + mức ngày (PR #311).
- [x] T5.2 `ml/models/explain.py`: câu tiếng Việt + SHAP (`pred_contribs`) → `docs/thesis/08`.

## T6 — M2 tầng 1, phản hồi, M3/M4 (tuần KH 6)

- [x] T6.1 Bản tham chiếu luật tầng 1 `ml/tier1/rules.py` + `test_vectors.json` (PR #312).
- [x] T6.2 Thực nghiệm "phụ huynh mô phỏng" (RQ5) + M3/M4 gọn → `docs/thesis/09`.
- [x] T6.3 Backend: `BehaviorAlert`, `BehaviorBaseline`, 5 API, FCM (PR #313); sửa IDOR (PR #314).
- [x] T6.4 App trẻ: `Tier1Rules.kt`, `Tier1Client.kt` chạy sau `HourlyUsageWorker` (PR #315).
- [x] T6.5 Kịch bản test cho người test `docs/flowtest/` (PR #316).
- [ ] T6.6 Test máy thật theo `docs/flowtest/02-canh-bao-tang1.md` và `03-hoi-quy-app-phu-huynh.md` (chờ: người test).
