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
