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
