# ml/ — phần học máy của đồ án chuyên ngành (Đề tài 01)

Module Python độc lập, không chạy trong backend. Tài liệu thiết kế/diễn giải ở `docs/thesis/`.

## Cài đặt

```bash
python3 -m venv ml/.venv
ml/.venv/bin/pip install -r ml/requirements.txt
```

## EDA LSApp

```bash
mkdir -p ml/data
curl -L -o ml/data/lsapp.tsv.gz https://raw.githubusercontent.com/aliannejadi/LSApp/main/lsapp.tsv.gz
ml/.venv/bin/python ml/eda/lsapp_eda.py ml/data/lsapp.tsv.gz ml/reports
```

Kết quả: `ml/reports/lsapp_eda.md` + hình PNG. Dữ liệu (`ml/data/`) không commit.

## EDA StudentLife

Trang gốc (studentlife.cs.dartmouth.edu) không truy cập được ngày 16/10/2026 → dùng bản RDS
(CC-BY-4.0) trên Zenodo, record 3529253, md5 `353ae79f157097a57bff1c004634ba1b`.

```bash
curl -L -o ml/data/dataset_rds.zip https://zenodo.org/api/records/3529253/files/dataset_rds.zip/content
cd ml/data && unzip dataset_rds.zip 'dataset_rds/other/app_usage.Rds' 'dataset_rds/sensing/phonelock.Rds' && cd ../..
ml/.venv/bin/python ml/eda/studentlife_eda.py ml/data/dataset_rds ml/reports
```

## Đặc trưng (`features/`) — đặc tả: `docs/thesis/05-dac-ta-dac-trung.md`

- `build_daily_features()` — M1, một dòng / (trẻ, ngày t), tính lúc 21:00 giờ VN, kèm nhãn `y_next`, `over_limit_next`.
- `build_hourly_features()`, `build_day_anomaly_features()` — M2, theo giờ và theo ngày.
- Đầu vào: DataFrame cùng tên cột với bảng Prisma (`AppUsageHourly`, `TimeLimit`, `TimeExtensionRequest`,
  `YouTubeLog`, `GeofenceEvent`), mốc thời gian UTC. Cấu hình: `config/app_categories.csv`,
  `config/vn_school_calendar.csv` (nhiều ngày là ước lượng — xem cột `note`).

## Bộ sinh dữ liệu mô phỏng (`simulator/`)

```bash
cd ml
.venv/bin/python -m simulator --children 100 --start 2025-09-01 --days 365 --out data/sim   # ~20 giây
```

Xuất `data/sim/*.csv` (cùng cột bảng Prisma) + `anomalies.csv` (nhãn: `night_use`, `spike`, `new_app`,
`binge_day`, `danger_content`; cột `hours` = các giờ VN bị cài). Kết quả kiểm tra (seed 42, trẻ không đặt giới hạn,
phút/ngày học): 3–5 tuổi 88 (mục tiêu 82), 11–14 tuổi 316 (284), 15–17 tuổi 431 (442); cuối tuần/ngày nghỉ ≈ 1,5×.
Trên đặc trưng M2: `hour_z` trung vị của giờ bị cài bất thường là 5,0 so với 0,0 ở giờ bình thường.

## M1 — dự đoán tổng thời gian ngày mai (`models/m1/`)

```bash
cd ml
.venv/bin/python -m models.m1.evaluate --sim data/sim --lsapp data/lsapp.tsv.gz --out reports
```

Walk-forward theo tuần (huấn luyện trên mọi ngày trước tuần kiểm tra), chỉ chấm dòng có >= 7 ngày lịch sử.
Mô hình: naive, seasonal naive, MA7, XGBoost (tuyệt đối / tỷ lệ so với MA7), Prophet mỗi trẻ một mô hình.
Kết quả: `reports/m1_round1.md`.

Bảng so sánh hoàn chỉnh (tuần 4: thêm LSTM, xác suất vượt giới hạn + hiệu chỉnh isotonic, ablation nhóm đặc trưng,
StudentLife), khoảng 10 phút:

```bash
.venv/bin/python -m models.m1.round2 --sim data/sim --lsapp data/lsapp.tsv.gz --studentlife data/dataset_rds --out reports
```

Kết quả: `reports/m1_round2.md`. PyTorch cài bản CPU: `pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cpu`.

## M2 tầng 2 — phát hiện bất thường (`models/m2/`) + câu giải thích (`models/explain.py`)

```bash
.venv/bin/python -m models.m2.evaluate --sim data/sim --out reports   # ~3 phút
```

Luật tầng 1, z-score, Isolation Forest, Autoencoder (mức giờ và ngày), DBSCAN (mức ngày); học trước 01/03/2026,
kiểm tra sau; đo cả tỷ lệ câu giải thích nói đúng loại bất thường. Kết quả: `reports/m2_round1.md`.

## Test

```bash
cd ml && .venv/bin/python -m pytest -q
```
