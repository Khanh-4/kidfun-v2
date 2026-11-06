# T7 — Tích hợp đầu cuối (tuần KH 7, tuần lịch 3–5)

**Mục tiêu:** mọi thứ trong `ml/` chạy thật trên hệ thống: mỗi đêm tính mức thường ngày, dự đoán ngày mai, chấm bất
thường; phụ huynh nhận thông báo, bấm đúng/sai, và xem tab "AI Insights".

**Điều kiện bắt đầu:** kết quả test T1.4 và T6.6 không có lỗi chặn.

## T7.1 Tác vụ ban đêm (Python, GitHub Actions)

- [x] T7.1.1 **Đã chốt (23/10/2026): đọc dữ liệu qua API backend**, không nối thẳng DB. Lý do: lộ `CRON_SECRET` chỉ
  gọi được vài endpoint cron, còn lộ chuỗi kết nối DB là đọc được toàn bộ dữ liệu mọi gia đình; API chỉ trả cột cần,
  bỏ tên/email (dữ liệu tối thiểu, dùng cho chương quyền riêng tư); dùng lại `middleware/cronAuth.js`; tránh bẫy RLS
  và IPv6/pooler của Supabase khi nối từ GitHub Actions.
- [x] T7.1.1a `GET /api/cron/thesis-data?days=28` (bảo vệ bằng `cronAuth`): trả `AppUsageHourly`, `TimeLimit`,
  `TimeExtensionRequest` theo `profileId`, không kèm tên/email/vị trí. Nếu gần 4,5 MB (giới hạn response Vercel) thì
  chia trang theo trẻ. Test jest: sai secret → 401, không lộ cột định danh.
  **Xong (31/10/2026):** `backend/src/controllers/thesisDataController.js`, test `tests/integration/thesisData.test.js`.
  Tham số `days` (1–90, mặc định 28), `limit` trẻ/trang (1–50, mặc định 10), `afterProfileId` (mặc định 0).
  Trả `{ since, profileIds, nextAfterProfileId, hourly, limits, extRequests }`; cột:
  `hourly` = profileId, packageName, hourStart, usageSeconds, launchCount; `limits` = profileId, dayOfWeek,
  dailyLimitMinutes, isActive, isGradual; `extRequests` = profileId, createdAt, requestMinutes, status.
  Trang vượt 4 MB → `413 PAGE_TOO_LARGE`.
- [x] T7.1.2 `ml/jobs/load.py`: gọi API ở T7.1.1a, ra cùng DataFrame mà `ml/features/` đang dùng. Test với JSON giả.
  Lặp `afterProfileId = nextAfterProfileId` tới khi `null`; gặp 413 thì giảm `limit` một nửa rồi gọi lại.
  **Xong (31/10/2026):** `load_thesis_data(url, secret)` → `ThesisData(profile_ids, hourly, limits, ext_requests)`;
  test `ml/tests/test_load.py` (7 ca, gồm đưa thẳng kết quả vào `build_daily_features`). Chạy thử:
  `CRON_SECRET=... ml/.venv/bin/python -m jobs.load --url https://kidfun-backend.vercel.app` (từ `ml/`).
- [x] T7.1.3 `ml/jobs/baseline.py`: tính JSON mức thường ngày cho từng trẻ (dùng lại `ml/tier1/rules.py`), gồm
  `categories` và `dayTypes`. Test: JSON khớp schema mà `Tier1Client.kt` đọc.
  **Xong (31/10/2026):** `build_baselines()` + `push_baselines()` (PUT theo lô 50), test `ml/tests/test_baseline_job.py`.
  Tác vụ chạy 21:05 VN → baseline phục vụ **ngày mai** (`as_of` = mai), chỉ dùng ngày đã trọn vẹn; trẻ < 7 ngày dữ
  liệu bị bỏ qua; payload > 64 KB báo lỗi. Nới ngưỡng theo phản hồi "được phép" của phụ huynh: `thesis-data` trả
  `alertFeedback` (cảnh báo TIER1 có `feedback` = `ALLOWED_*`, mọi thời điểm), `overrides_from_feedback()` áp
  `relax()` theo thứ tự thời gian, tối đa 2 lần mỗi khoá, tính lại từ đầu mỗi đêm nên không cần lưu bộ đếm.
- [x] T7.1.4 Đóng gói mô hình M1 đã huấn luyện trên mô phỏng (file `.json` của XGBoost + isotonic) để tác vụ chỉ việc
  tải và dự đoán, không huấn luyện lại mỗi đêm.
  **Xong (05/11/2026):** `ml/models/m1/bundle.py` (`train` / `save` / `load` → `predict_minutes`, `predict_over_limit`),
  gói ở `ml/models/m1/artifacts/` (~4 MB, chỉ JSON, không pickle): `xgb_rel` + `xgb_clf_iso` theo báo cáo tuần 4,
  isotonic lưu dạng mốc (x, y) và nội suy. Huấn luyện lại: `python -m models.m1.bundle --sim data/sim` (~15 giây).
  Test `ml/tests/test_m1_bundle.py`. **Tồn đọng cho T7.3.1:** `thesis-data` chưa trả `ageGroup` → gói vẫn chạy
  (coi tuổi là thiếu) nhưng kém chính xác hơn; nên thêm `ageGroup` vào API.
- [x] T7.1.5 `.github/workflows/thesis-nightly.yml`: cron 21:05 giờ VN (14:05 UTC), cài `ml/requirements.txt`, chạy
  tác vụ, chạy được bằng tay (`workflow_dispatch`). Xong khi: một lần chạy thật thành công trên GitHub.
  **Đã viết (05/11/2026):** `.github/workflows/thesis-nightly.yml` chạy `jobs.baseline --push`; bấm tay có ô chọn
  chỉ tính không gửi. Cài `ml/requirements-job.txt` (pandas/numpy/sklearn/xgboost) thay vì `requirements.txt` đầy
  đủ — torch/prophet chỉ dùng so sánh mô hình, quá nặng cho Actions. Chạy thử trên máy (không gửi): 9 trẻ, 32 dòng
  hourly, cả 9 bị bỏ qua vì < 7 ngày dữ liệu, 0 lỗi. **Xong (05/11/2026):** chạy tay trên GitHub (không gửi) xanh
  trong 51 giây, cùng kết quả — run 41952090113.
- [x] T7.1.6 Log rõ số trẻ đã xử lý / bỏ qua (thiếu dữ liệu) / lỗi; tác vụ thất bại thì GitHub báo email.
  **Xong (05/11/2026):** `jobs.baseline` in `baseline: N trẻ đã tính | bỏ qua: … | lỗi: …` + từng lỗi theo profileId,
  trả exit 1 khi có lỗi → workflow đỏ → GitHub gửi email cho người kích hoạt/chủ repo.

## T7.2 Backend nhận kết quả

- [x] T7.2.1 `PUT /api/cron/behavior-baselines` (bảo vệ bằng `CRON_SECRET`): ghi đè `BehaviorBaseline` theo lô.
  (Đã có từ commit `b7f065b`, test ở `backend/tests/integration/behaviorAlert.test.js`; tick muộn 31/10.)
- [x] T7.2.2 **Đã chốt (23/10/2026): kết hợp hai bảng.** Mọi dự đoán ghi vào bảng mới `UsagePrediction`; chỉ khi xác
  suất vượt giới hạn ≥ 0,6 mới tạo thêm `BehaviorAlert` với `source = "M1"`. Lý do: thẻ "Ngày mai" và đánh giá MAE
  (T8.3.2) cần dự đoán của **mọi** ngày; `BehaviorAlert` chỉ nên chứa cảnh báo và thiếu cột xác suất/giới hạn; cảnh
  báo M1 đi chung đường FCM + nút đúng/sai với tầng 1 nên T7.4 không phải làm riêng. Số phút thực tế không lưu,
  tính lại từ `AppUsageHourly`.
- [x] T7.2.2a Migration thêm bảng `UsagePrediction` (`profileId`, `date`, `predictedMinutes`, `pOverLimit`,
  `limitMinutes`, `message`, `modelVersion`, `createdAt`; unique `(profileId, date)`; bật RLS như các bảng khác).
  Viết tay, `IF NOT EXISTS`. **Có migration → hỏi trước khi push.**
  **Xong (05/11/2026):** migration `20261105000001_add_usage_prediction` + model `UsagePrediction` (`date` kiểu
  `DATE` = ngày được dự đoán theo giờ VN). Chạy 2 lần trên DB test không lỗi, RLS bật, `migrate diff` DB ↔ schema
  rỗng, jest 130/130.
- [x] T7.2.3 `POST /api/cron/behavior-results`: nhận dự đoán M1 (upsert `UsagePrediction`) + cảnh báo M1/M2 tầng 2
  (`BehaviorAlert`, `source = M1 | TIER2`), chống trùng theo khoá unique, gửi FCM cho cảnh báo mới (ngưỡng 0,6 ở
  `docs/thesis/07`).
  **Xong (05/11/2026):** `behaviorResultsController.saveResults`. Body `{ modelVersion, predictions[], alerts? }`;
  ngưỡng `M1_ALERT_THRESHOLD = 0.6` đặt ở server — tác vụ chỉ gửi dự đoán, server tự tạo cảnh báo M1
  (`rule = over_limit`, `slotStart` = 00:00 giờ VN của ngày dự đoán, câu tiếng Việt dựng ở server). `alerts` = tầng 2,
  cùng dạng ô giờ với tầng 1. Test `backend/tests/integration/behaviorResults.test.js` (11 ca, gồm 401/400/ghi đè/
  chống trùng/FCM một lần) — phần lớn T7.2.5 cho endpoint này.
- [x] T7.2.4 `GET /api/profiles/:id/predictions?days=14` cho app phụ huynh, có kiểm tra quyền sở hữu (như PR #314).
  **Xong (05/11/2026):** `behaviorResultsController.listPredictions`. Trả từ (hôm nay giờ VN − days + 1) trở đi,
  gồm cả ngày mai, mới nhất trước; `days` mặc định 14, kẹp 1..60; hồ sơ không thuộc phụ huynh → 404 như `listAlerts`.
  Chưa trả số phút thực tế — T8.3 tính từ `AppUsageHourly` khi cần.
- [x] T7.2.5 Test jest cho từng endpoint: sai secret → 401, sai chủ → 403/404, dữ liệu hợp lệ → ghi đúng.
  **Xong (05/11/2026):** `backend/tests/integration/behaviorResults.test.js` 15 ca cho `behavior-results` (401, 400 ×5,
  ghi đè, ngưỡng 0,6, chống trùng + FCM một lần, profile lạ, TIER2) và `predictions` (401, người lạ 404, cửa sổ ngày,
  kẹp `days`). `behavior-baselines` đã có test từ trước. jest 145/145.

## T7.3 M1 và M2 tầng 2 chạy theo lịch

- [x] T7.3.1 Nối T7.1 và T7.2: tác vụ gửi baseline + dự đoán + cảnh báo lên server trong một lần chạy.
  **Xong (05/11/2026):** `ml/jobs/nightly.py` tải `thesis-data` một lần → baseline (PUT `behavior-baselines`) + dự đoán
  M1 (`ml/jobs/predict.py`, POST `behavior-results`); workflow `thesis-nightly` chuyển sang `jobs.nightly`. Dự đoán lấy
  dòng HÔM NAY của `build_daily_features` (target = ngày mai); chỉ gửi `pOverLimit`/`limitMinutes` khi ngày mai có giới
  hạn; cảnh báo do server tạo (p ≥ 0,6). `modelVersion` = `xgb_rel+xgb_clf_iso@<ngày huấn luyện>` từ `meta.json`.
  Test `ml/tests/test_predict_job.py` (7 ca, gồm 1 ca chạy gói M1 thật trên dữ liệu dạng production). Chạy thử với
  production (không gửi): 9 trẻ, cả 9 bị bỏ qua vì chưa đủ 7 ngày, 0 lỗi.
- [ ] T7.3.2 Chấm M2 tầng 2 (DBSCAN mức ngày) cho ngày hôm qua; chỉ gửi khi trẻ có ≥ 14 ngày dữ liệu.
- [x] T7.3.3 Trẻ chưa đủ 7 ngày dữ liệu: bỏ qua M1, chỉ gửi baseline (tầng 1 vẫn chạy luật khuya 0h–6h).
  **Xong (05/11/2026):** `predict.MIN_HISTORY_DAYS = 7` bỏ qua M1. Lưu ý: baseline cũng cần ≥ 7 ngày (T7.1.3) nên trẻ
  mới không nhận gì từ tác vụ; máy trẻ vẫn chạy luật khuya 0h–6h không cần baseline.
- [x] T7.3.4 Kiểm thử đầu cuối trên DB test local (`.env.test`, schema `kidfun_test`) với dữ liệu mô phỏng 3 trẻ.
  **Xong (07/11/2026):** `bash ml/e2e/run_local.sh` — `ml/e2e/export_sim.py` mô phỏng 21 ngày kết thúc hôm nay, chọn 3
  trẻ phủ 3 nhánh (có giới hạn dùng nhiều / có giới hạn dùng ít / không giới hạn) → `backend/scripts/thesis-e2e.js seed`
  vào DB test → bật backend local (env `.env.test` nạp trước `.env`) → `jobs.nightly --push` **2 lần** → `verify` →
  dọn. Kết quả: 3 baseline, 3 dự đoán cho ngày mai, `limitMinutes` đúng giới hạn ngày mai, trẻ không giới hạn có
  `pOverLimit = null`, chạy lại vẫn 1 dự đoán/trẻ (ghi đè), không cảnh báo trùng. Lần chạy này không trẻ nào p ≥ 0,6
  nên nhánh tạo cảnh báo M1 chỉ được kiểm bằng `backend/tests/integration/behaviorResults.test.js`.
  Ghi nhận: isotonic là hàm bậc thang nên p rất thô (hai trẻ khác nhau cùng ra 0,362) → xem lại ở T8.3.

## T7.4 App phụ huynh: thông báo và nút đúng/sai

- [ ] T7.4.1 Xử lý thông báo FCM loại `BEHAVIOR_ALERT`: hiện câu giải thích, bấm vào mở đúng cảnh báo.
- [ ] T7.4.2 Hai nút trên thông báo / màn chi tiết: "Đúng là bất thường" và "Được phép" (cuối tuần, ngày lễ, khác) →
  `POST /api/behavior-alerts/:id/feedback`.
- [ ] T7.4.3 Danh sách cảnh báo của từng trẻ (`GET /api/profiles/:id/behavior-alerts`), có trạng thái đã phản hồi.
- [ ] T7.4.4 Widget test cho màn danh sách và nút phản hồi (notifier giả).

## T7.5 Tab "AI Insights" trong app phụ huynh

- [ ] T7.5.1 Thẻ "Ngày mai": phút dự đoán, xác suất vượt giới hạn, câu giải thích (M1).
- [ ] T7.5.2 Heatmap theo giờ × thứ trong tuần 4 tuần gần nhất (M3).
- [ ] T7.5.3 Nhóm thói quen của trẻ (K-Means, M3) và 1–3 gợi ý có dẫn nguồn (M4).
- [ ] T7.5.4 Trạng thái rỗng khi chưa đủ dữ liệu ("cần thêm N ngày").
- [ ] T7.5.5 Nếu M3/M4 cần API riêng: thêm vào tác vụ ban đêm (T7.1) thay vì tính trên Vercel.

## T7.6 Bàn giao

- [ ] T7.6.1 Viết `docs/thesis/10-tich-hop.md`: kiến trúc thật, lịch chạy, cách chạy tay, xử lý lỗi.
- [ ] T7.6.2 Flowtest mới `docs/flowtest/05-ai-insights.md` (nhận thông báo, bấm đúng/sai, xem tab).
- [ ] T7.6.3 Cập nhật `ml/README.md` (lệnh chạy tác vụ) và bảng trạng thái ở [README](../README.md).
