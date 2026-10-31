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
- [ ] T7.1.4 Đóng gói mô hình M1 đã huấn luyện trên mô phỏng (file `.json` của XGBoost + isotonic) để tác vụ chỉ việc
  tải và dự đoán, không huấn luyện lại mỗi đêm.
- [ ] T7.1.5 `.github/workflows/thesis-nightly.yml`: cron 21:05 giờ VN (14:05 UTC), cài `ml/requirements.txt`, chạy
  tác vụ, chạy được bằng tay (`workflow_dispatch`). Xong khi: một lần chạy thật thành công trên GitHub.
- [ ] T7.1.6 Log rõ số trẻ đã xử lý / bỏ qua (thiếu dữ liệu) / lỗi; tác vụ thất bại thì GitHub báo email.

## T7.2 Backend nhận kết quả

- [x] T7.2.1 `PUT /api/cron/behavior-baselines` (bảo vệ bằng `CRON_SECRET`): ghi đè `BehaviorBaseline` theo lô.
  (Đã có từ commit `b7f065b`, test ở `backend/tests/integration/behaviorAlert.test.js`; tick muộn 31/10.)
- [x] T7.2.2 **Đã chốt (23/10/2026): kết hợp hai bảng.** Mọi dự đoán ghi vào bảng mới `UsagePrediction`; chỉ khi xác
  suất vượt giới hạn ≥ 0,6 mới tạo thêm `BehaviorAlert` với `source = "M1"`. Lý do: thẻ "Ngày mai" và đánh giá MAE
  (T8.3.2) cần dự đoán của **mọi** ngày; `BehaviorAlert` chỉ nên chứa cảnh báo và thiếu cột xác suất/giới hạn; cảnh
  báo M1 đi chung đường FCM + nút đúng/sai với tầng 1 nên T7.4 không phải làm riêng. Số phút thực tế không lưu,
  tính lại từ `AppUsageHourly`.
- [ ] T7.2.2a Migration thêm bảng `UsagePrediction` (`profileId`, `date`, `predictedMinutes`, `pOverLimit`,
  `limitMinutes`, `message`, `modelVersion`, `createdAt`; unique `(profileId, date)`; bật RLS như các bảng khác).
  Viết tay, `IF NOT EXISTS`. **Có migration → hỏi trước khi push.**
- [ ] T7.2.3 `POST /api/cron/behavior-results`: nhận dự đoán M1 (upsert `UsagePrediction`) + cảnh báo M1/M2 tầng 2
  (`BehaviorAlert`, `source = M1 | TIER2`), chống trùng theo khoá unique, gửi FCM cho cảnh báo mới (ngưỡng 0,6 ở
  `docs/thesis/07`).
- [ ] T7.2.4 `GET /api/profiles/:id/predictions?days=14` cho app phụ huynh, có kiểm tra quyền sở hữu (như PR #314).
- [ ] T7.2.5 Test jest cho từng endpoint: sai secret → 401, sai chủ → 403/404, dữ liệu hợp lệ → ghi đúng.

## T7.3 M1 và M2 tầng 2 chạy theo lịch

- [ ] T7.3.1 Nối T7.1 và T7.2: tác vụ gửi baseline + dự đoán + cảnh báo lên server trong một lần chạy.
- [ ] T7.3.2 Chấm M2 tầng 2 (DBSCAN mức ngày) cho ngày hôm qua; chỉ gửi khi trẻ có ≥ 14 ngày dữ liệu.
- [ ] T7.3.3 Trẻ chưa đủ 7 ngày dữ liệu: bỏ qua M1, chỉ gửi baseline (tầng 1 vẫn chạy luật khuya 0h–6h).
- [ ] T7.3.4 Kiểm thử đầu cuối trên DB test local (`.env.test`, schema `kidfun_test`) với dữ liệu mô phỏng 3 trẻ.

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
