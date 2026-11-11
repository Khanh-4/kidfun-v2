# 10 — Tích hợp đầu cuối (T7)

Tài liệu bàn giao phần tích hợp của đồ án chuyên ngành: các mô hình ở `docs/thesis/06–09` chạy thật trên hệ thống
KidFun như thế nào, chạy lúc nào, chạy tay ra sao và xử lý khi lỗi. Cập nhật 11/11/2026.

## 1. Kiến trúc thật

```
 Máy trẻ (Android)                 Backend (Vercel, Express)              GitHub Actions (21:05 VN, trễ tới ~9 giờ)
 ─────────────────                 ─────────────────────────              ──────────────────────────────────────────
 HourlyUsageWorker 30'  ──POST──▶  /api/child/app-usage/hourly ─▶ AppUsageHourly
                                   /api/cron/thesis-data  ◀──GET────────  jobs.load   (dữ liệu tối thiểu, chia trang)
                                                                          ├─ jobs.baseline  mức thường ngày tầng 1
 Tier1Rules (tầng 1)  ◀──GET────   /api/child/behavior-baseline ◀─PUT───  │  → /api/cron/behavior-baselines
   └─ vượt ngưỡng ──POST──▶        /api/child/behavior-alerts             ├─ jobs.predict   M1 dự đoán ngày mai
                                   /api/cron/behavior-results  ◀─POST───  │  (+ jobs.anomaly M2 tầng 2 mức ngày)
                                     ├─ UsagePrediction                   └─ jobs.insights  M3 nhóm thói quen + M4 gợi ý
                                     └─ BehaviorAlert (M1 p ≥ 0,6, TIER2)    → /api/cron/habit-insights → HabitInsight
                                   FCM BEHAVIOR_ALERT ──▶ App phụ huynh
 App phụ huynh  ──GET──▶  /api/profiles/:id/{behavior-alerts, predictions, usage-heatmap, habit-insight}
                ──POST─▶  /api/behavior-alerts/:id/feedback  (phản hồi "được phép" → nới ngưỡng tầng 1 đêm sau)
```

- **Hai tầng (RQ4):** tầng 1 chạy ngay trên máy trẻ mỗi 30 phút (`Tier1Rules.kt`, bản tham chiếu
  `ml/tier1/rules.py`, ca kiểm thử dùng chung `ml/tier1/test_vectors.json`); tầng 2 và M1/M3/M4 chạy mỗi đêm.
- **Tác vụ ban đêm không nối thẳng DB:** chỉ gọi các endpoint `/api/cron/*` bảo vệ bằng `CRON_SECRET`. Lộ secret thì
  chỉ đọc được dữ liệu đã bỏ tên/email/vị trí (`thesisDataController.js`), không phải toàn bộ DB.
- **Không tính ML trên Vercel**, trừ heatmap (cộng dồn đơn giản trên `AppUsageHourly`, `utils/usageHeatmap.js`).

| Bảng | Ai ghi | Ai đọc |
|---|---|---|
| `AppUsageHourly` | máy trẻ | tác vụ ban đêm, heatmap |
| `BehaviorBaseline` | tác vụ (`jobs.baseline`) | máy trẻ (tầng 1) |
| `BehaviorAlert` | máy trẻ (TIER1), tác vụ (M1, TIER2) | app phụ huynh; phản hồi quay lại tác vụ |
| `UsagePrediction` | tác vụ (`jobs.predict`) | app phụ huynh — thẻ "Ngày mai" |
| `HabitInsight` | tác vụ (`jobs.insights`) | app phụ huynh — "Thói quen & gợi ý" |

## 2. Lịch chạy

- Workflow `.github/workflows/thesis-nightly.yml`, cron `5 14 * * *` = **21:05 giờ VN**, chạy trên nhánh mặc định
  (`develop`). GitHub hay chạy trễ: đo được 01:46, 03:45, 06:22 sáng VN (08–10/11).
- Vì vậy mọi job lấy **ngày tác vụ** bằng `jobs.baseline.task_day()` = giờ VN − 12 giờ: chạy trước 12:00 trưa vẫn
  tính cho ngày hôm trước. Đừng dùng "hôm nay theo đồng hồ" trong job.
- Ngưỡng dữ liệu: baseline và M1 cần ≥ 7 ngày, M2 mức ngày ≥ 14 ngày, M3/M4 ≥ 7 ngày trong 28 ngày gần nhất;
  K-Means chỉ chạy khi ≥ 6 trẻ đủ dữ liệu (ít hơn: mô tả từng trẻ so với các trẻ khác).
- Mỗi lần chạy ghi đè theo (trẻ, ngày) — chạy lại trong ngày an toàn, cảnh báo không gửi trùng.

## 3. Chạy tay

**Trên GitHub:** Actions → `thesis-nightly` → *Run workflow*. Bỏ chọn ô `push` để chỉ tính và in báo cáo.

**Trên máy:**

```bash
cd ml
CRON_SECRET=... .venv/bin/python -m jobs.nightly --url https://kidfun-backend.vercel.app          # chỉ tính
CRON_SECRET=... .venv/bin/python -m jobs.nightly --url https://kidfun-backend.vercel.app --push   # tính + ghi
```

Báo cáo in ra một dòng cho mỗi bước (baseline, M1, M2, M3/M4) kèm số trẻ đã tính / bỏ qua / lỗi.

**Kiểm thử đầu cuối không đụng production** (chạy sau mỗi lần sửa job hoặc API kết quả):

```bash
bash ml/e2e/run_local.sh
```

**Gửi kết quả thử cho người test:** lệnh `curl` ở cuối `docs/flowtest/11-canh-bao-hanh-vi-phu-huynh.md` (cảnh báo)
và `docs/flowtest/13-ai-insights.md` (dự đoán, nhóm thói quen). Câu thử bắt đầu bằng `[Thử nghiệm]` để dễ xoá.

## 4. Cấu hình

| Ở đâu | Tên | Ghi chú |
|---|---|---|
| GitHub → Settings → Secrets | `CRON_SECRET` | trùng biến `CRON_SECRET` của project Vercel backend |
| GitHub → Settings → Variables | `THESIS_API_URL` (tuỳ chọn) | mặc định `https://kidfun-backend.vercel.app` |
| `ml/requirements-job.txt` | pandas, numpy, scikit-learn, xgboost | job **không** cài matplotlib/torch — module dùng trong job không được import chúng ở đầu file |
| `ml/models/m1/`, `ml/models/m2/` | gói mô hình đã huấn luyện | đổi gói thì đổi `model_version()` để dòng ghi trong DB truy được nguồn |

## 5. Xử lý lỗi

| Hiện tượng | Nguyên nhân thường gặp | Làm gì |
|---|---|---|
| GitHub gửi email "thesis-nightly failed" | job trả mã ≠ 0 (lỗi tính cho ít nhất một trẻ, hoặc API trả lỗi) | mở log run, tìm dòng `lỗi profileId …` hoặc `… trả 4xx/5xx` |
| `thesis-data trả 401` / `… trả 401` | `CRON_SECRET` ở GitHub khác Vercel | đặt lại secret cho khớp |
| `413 PAGE_TOO_LARGE` | một trang dữ liệu > 4 MB | giảm `DEFAULT_LIMIT` trong `ml/jobs/load.py` (10 trẻ/trang; `jobs.nightly` dùng giá trị này, `jobs.load` có cờ `--limit` để thử) |
| Báo cáo "0 trẻ đã tính", bỏ qua toàn bộ | chưa trẻ nào đủ 7 ngày, hoặc job tính nhầm ngày | xem số dòng hourly ở dòng `trang sau profileId …`; kiểm `task_day()` nếu job chạy sau 12:00 trưa |
| `ModuleNotFoundError` trên GitHub nhưng chạy máy được | module job import gói chỉ có trong `requirements.txt` | chuyển import vào trong hàm (xem `models/m3m4.py`) |
| App phụ huynh không có thẻ "Ngày mai" | chưa đủ dữ liệu (app hiện "cần thêm N ngày") hoặc job chưa chạy đêm qua | xem run gần nhất; kiểm bảng `UsagePrediction` theo `profileId` |
| Phụ huynh nhận cảnh báo M1 quá nhiều | ngưỡng `M1_ALERT_THRESHOLD = 0,6` (`behaviorResultsController.js`) | chỉnh ngưỡng; xác suất M1 còn thô (03-rui-ro-va-ton-dong.md) |

## 6. Giới hạn đã biết

Xem `ke-hoach/03-rui-ro-va-ton-dong.md`. Chính: gói M1 chưa dùng `ageGroup` dù API đã trả; xác suất vượt giới hạn
dạng bậc thang; production còn ít trẻ đủ dữ liệu nên K-Means chưa chạy thật; trẻ không dùng máy cả ngày thì không có
dự đoán ngày mai.
