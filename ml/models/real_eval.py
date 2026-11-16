"""T8.3 — đánh giá M1 / M2 trên DỮ LIỆU THẬT (chỉ đọc, qua GET /api/cron/thesis-data như tác vụ ban đêm).

Truy vấn production MỘT lần rồi lưu snapshot, các lần sau đọc từ file (hỏi Khanh trước khi truy vấn production):

    CRON_SECRET=... .venv/bin/python -m models.real_eval --url https://kidfun-backend.vercel.app --days 90 \
        --save-pages data/real/snapshot.json --out reports
    .venv/bin/python -m models.real_eval --pages data/real/snapshot.json --out reports

- M1 (T8.3.2): gói production dự đoán từng ngày thật có ≥ 7 ngày lịch sử, so MAE với MA7 theo từng trẻ; xác suất
  "dùng hết giờ" chấm Brier/ROC-AUC (khi có đủ hai lớp) và tỷ lệ ngày p ≥ 0,8 (= ngưỡng cảnh báo của server).
- M2 mức ngày (T8.3.3): gói DBSCAN chấm mọi ngày có ≥ 14 ngày dữ liệu trước đó → cảnh báo/trẻ/tuần.
- Phản hồi (T8.3.4): API hiện chỉ trả phản hồi "được phép" (ALLOWED_*) của tầng 1 — đủ cho phần nới ngưỡng, chưa đủ
  để tính tỷ lệ phụ huynh xác nhận đúng (cần thêm phản hồi CONFIRMED vào thesis-data).
Báo cáo chỉ dùng số thứ tự "trẻ k", không in profileId. Snapshot chứa dữ liệu thật: để trong ml/data/ (không commit).
"""

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
from sklearn.metrics import brier_score_loss, roc_auc_score

from features import Calendar, build_day_anomaly_features, build_daily_features, load_categories
from jobs.load import ThesisData, fetch_pages, to_frames

M1_MIN_HISTORY = 7  # = jobs.predict.MIN_HISTORY_DAYS
M2_MIN_HISTORY = 14  # = jobs.anomaly.MIN_HISTORY_DAYS
ALERT = 0.8  # = M1_ALERT_THRESHOLD ở backend
MIN_CHILDREN_FOR_TEST = 6  # ít hơn thì Wilcoxon vô nghĩa — chỉ mô tả


def save_pages(pages: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(pages, ensure_ascii=False), encoding="utf-8")


def load_pages(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def m1_eval(data: ThesisData, *, bundle, calendar: Calendar, categories: dict) -> tuple[pd.DataFrame, dict]:
    daily = build_daily_features(data.hourly, calendar=calendar, categories=categories,
                                 limits=data.limits, ext_requests=data.ext_requests)
    empty = pd.DataFrame(columns=["profileId", "số ngày", "MAE gói M1", "MAE MA7"])
    if daily.empty:
        return empty, {"số trẻ": 0}
    ages = data.profiles.set_index("profileId")["ageGroup"] if not data.profiles.empty else pd.Series(dtype=object)
    rows = daily[daily["y_next"].notna() & (daily["history_days"] >= M1_MIN_HISTORY)]
    rows = rows.assign(ageGroup=rows["profileId"].map(ages))
    if rows.empty:
        return empty, {"số trẻ": 0}
    pred = np.asarray(bundle.predict_minutes(rows), dtype=float)
    ma7 = rows["mean7"].fillna(rows["y_lag1"]).to_numpy(dtype=float)
    err = rows.assign(e_m1=np.abs(pred - rows["y_next"]), e_ma7=np.abs(ma7 - rows["y_next"]))
    per_child = (err.groupby("profileId")
                 .agg(**{"số ngày": ("y_next", "size"), "MAE gói M1": ("e_m1", "mean"), "MAE MA7": ("e_ma7", "mean")})
                 .reset_index())
    summary = {
        "số trẻ": len(per_child), "số ngày": int(per_child["số ngày"].sum()),
        "MAE gói M1": float(err["e_m1"].mean()), "MAE MA7": float(err["e_ma7"].mean()),
        "trẻ gói M1 thắng": int((per_child["MAE gói M1"] < per_child["MAE MA7"]).sum()),
    }
    if len(per_child) >= MIN_CHILDREN_FOR_TEST:
        summary["Wilcoxon p"] = float(wilcoxon(per_child["MAE gói M1"], per_child["MAE MA7"]).pvalue)
    limited = rows[rows["has_limit"].astype(bool) & rows["hit_limit_next"].notna()]
    if not limited.empty:
        p = np.asarray(bundle.predict_over_limit(limited), dtype=float)
        y = limited["hit_limit_next"].astype(int).to_numpy()
        summary.update({"ngày có giới hạn": len(limited), "% dùng hết giờ thật": float(y.mean() * 100),
                        "% ngày p ≥ 0,8": float((p >= ALERT).mean() * 100), "Brier": float(brier_score_loss(y, p))})
        if len(set(y)) == 2:
            summary["ROC-AUC"] = float(roc_auc_score(y, p))
    return per_child, summary


def m2_eval(data: ThesisData, *, bundle, calendar: Calendar, categories: dict) -> pd.DataFrame:
    days = build_day_anomaly_features(data.hourly, calendar=calendar, categories=categories,
                                      ext_requests=data.ext_requests)
    cols = ["profileId", "số ngày chấm", "số cảnh báo", "cảnh báo/tuần"]
    if days.empty:
        return pd.DataFrame(columns=cols)
    days = days.sort_values(["profileId", "date"]).reset_index(drop=True)
    seen_before = days.groupby("profileId").cumcount()  # số ngày có dữ liệu TRƯỚC ngày đang chấm
    scored = days[seen_before >= M2_MIN_HISTORY].reset_index(drop=True)
    if scored.empty:
        return pd.DataFrame(columns=cols)
    scored = scored.assign(flag=np.asarray(bundle.flag(scored), dtype=bool))
    out = scored.groupby("profileId").agg(**{"số ngày chấm": ("flag", "size"), "số cảnh báo": ("flag", "sum")})
    out["cảnh báo/tuần"] = out["số cảnh báo"] / (out["số ngày chấm"] / 7)
    return out.reset_index()[cols]


def _anonymize(df: pd.DataFrame, names: dict) -> pd.DataFrame:
    return df.assign(profileId=df["profileId"].map(names)).rename(columns={"profileId": "trẻ"})


def report(data: ThesisData, *, m1, m2, calendar: Calendar, categories: dict) -> str:
    names = {pid: f"trẻ {i + 1}" for i, pid in enumerate(sorted(data.profile_ids))}
    per_child, summary = m1_eval(data, bundle=m1, calendar=calendar, categories=categories)
    m2_table = m2_eval(data, bundle=m2, calendar=calendar, categories=categories)
    fb = data.alert_feedback
    fb_table = (fb.groupby(["rule", "feedback"]).size().rename("số phản hồi").reset_index()
                if not fb.empty else pd.DataFrame(columns=["rule", "feedback", "số phản hồi"]))
    days_span = ""
    if not data.hourly.empty:
        local = pd.to_datetime(data.hourly["hourStart"], utc=True) + pd.Timedelta(hours=7)
        days_span = f"{local.min().date()} → {local.max().date()}"
    fmt = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in summary.items()}
    return "\n".join([
        "# T8.3 — M1 / M2 trên dữ liệu thật",
        "",
        f"{len(data.profile_ids)} trẻ, dữ liệu {days_span}. Số thứ tự trẻ thay cho mã hồ sơ.",
        "",
        "## M1 — dự đoán số phút ngày mai (gói production) so với MA7",
        "",
        "Tóm tắt: " + ", ".join(f"{k} = {v}" for k, v in fmt.items()),
        "",
        _anonymize(per_child, names).round(1).to_markdown(index=False) if not per_child.empty else "_Chưa trẻ nào đủ 7 ngày._",
        "",
        "## M2 mức ngày (DBSCAN) — cảnh báo trên mỗi trẻ mỗi tuần",
        "",
        _anonymize(m2_table, names).round(2).to_markdown(index=False) if not m2_table.empty else "_Chưa trẻ nào đủ 14 ngày._",
        "",
        "## Phản hồi tầng 1 (API hiện chỉ trả \"được phép\")",
        "",
        fb_table.to_markdown(index=False) if not fb_table.empty else "_Chưa có phản hồi._",
        "",
    ])


def main(argv=None) -> int:
    from models.m1 import bundle as m1_bundle
    from models.m2 import day_bundle

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--url", help="backend production/test; cần CRON_SECRET")
    src.add_argument("--pages", type=Path, help="snapshot đã lưu")
    p.add_argument("--days", type=int, default=90)
    p.add_argument("--save-pages", type=Path)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args(argv)
    if args.url:
        secret = os.environ.get("CRON_SECRET")
        if not secret:
            print("Thiếu CRON_SECRET", file=sys.stderr)
            return 2
        pages = fetch_pages(args.url, secret, days=args.days)
        if args.save_pages:
            save_pages(pages, args.save_pages)
    else:
        pages = load_pages(args.pages)
    text = report(to_frames(pages), m1=m1_bundle.load(), m2=day_bundle.load(),
                  calendar=Calendar.load(), categories=load_categories())
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "t83_real_data.md").write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
