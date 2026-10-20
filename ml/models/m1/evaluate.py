"""Đánh giá walk-forward cho M1 (đợt 1).

Giao thức: chia thời gian thành các tuần kiểm tra liên tiếp. Với mỗi tuần, huấn luyện trên mọi dòng có
target_date TRƯỚC tuần đó, dự đoán các ngày trong tuần. Chỉ chấm các dòng có y_next và history_days >= 7
(trẻ mới < 7 ngày không được cảnh báo — đặc tả 05 mục 1.3).

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m1.evaluate --sim data/sim --lsapp data/lsapp.tsv.gz --out reports
"""

import argparse
import time
from pathlib import Path

import numpy as np
import pandas as pd

from .data import lsapp_daily_features, sim_daily_features
from .models import ALL_MODELS

MIN_HISTORY_DAYS = 7
FOLD_DAYS = 7


def evaluable(daily: pd.DataFrame) -> pd.Series:
    return daily["y_next"].notna() & (daily["history_days"] >= MIN_HISTORY_DAYS)


def walk_forward(daily: pd.DataFrame, models, test_start: pd.Timestamp, test_end: pd.Timestamp) -> pd.DataFrame:
    """Trả về bảng dự đoán: một dòng / dòng kiểm tra, một cột / mô hình."""
    mask = evaluable(daily)
    preds, timing = [], {m.name: 0.0 for m in models}
    for fold_start in pd.date_range(test_start, test_end, freq=f"{FOLD_DAYS}D"):
        fold_end = fold_start + pd.Timedelta(days=FOLD_DAYS)
        train = daily[daily["y_next"].notna() & (daily["target_date"] < fold_start)]
        test = daily[mask & (daily["target_date"] >= fold_start) & (daily["target_date"] < fold_end)]
        if test.empty or train.empty:
            continue
        fold = test[["profileId", "ageGroup", "target_date", "y_next", "is_school_day", "is_weekend"]].copy()
        for model_cls in models:
            t0 = time.time()
            fold[model_cls.name] = model_cls().fit(train).predict(test)
            timing[model_cls.name] += time.time() - t0
        preds.append(fold)
    out = pd.concat(preds, ignore_index=True)
    out.attrs["seconds"] = timing
    return out


def metrics(preds: pd.DataFrame, names: list[str]) -> pd.DataFrame:
    rows = []
    for name in names:
        err = preds[name] - preds["y_next"]
        rows.append(
            {
                "model": name,
                "MAE": err.abs().mean(),
                "RMSE": np.sqrt((err**2).mean()),
                "WAPE_%": 100 * err.abs().sum() / preds["y_next"].sum(),
            }
        )
    return pd.DataFrame(rows).set_index("model")


def mae_by(preds: pd.DataFrame, names: list[str], key) -> pd.DataFrame:
    return pd.DataFrame({n: (preds[n] - preds["y_next"]).abs().groupby(key).mean() for n in names}).T


def day_type(preds: pd.DataFrame) -> pd.Series:
    school = preds["is_school_day"].astype(bool)
    weekend = preds["is_weekend"].astype(bool)
    other = "ngày nghỉ" if school.any() else "ngày thường"  # dữ liệu ngoài lịch VN (vd LSApp) không có ngày học
    kind = np.where(school, "ngày học", np.where(weekend, "cuối tuần", other))
    return pd.Series(kind, index=preds.index, name="loại ngày")


def report(title: str, preds: pd.DataFrame, names: list[str]) -> str:
    seconds = pd.Series(preds.attrs.get("seconds", {}), name="giây")
    overall = metrics(preds, names).join(seconds).round(1)
    lines = [
        f"## {title}",
        "",
        f"{len(preds):,} dự đoán, {preds['profileId'].nunique()} người, "
        f"{preds['target_date'].min():%d/%m/%Y} – {preds['target_date'].max():%d/%m/%Y}.",
        "",
        overall.sort_values("MAE").to_markdown(),
        "",
    ]
    if preds["ageGroup"].nunique() > 1:
        lines += ["MAE theo nhóm tuổi:", "", mae_by(preds, names, preds["ageGroup"]).round(1).to_markdown(), ""]
    lines += ["MAE theo loại ngày cần dự đoán:", "", mae_by(preds, names, day_type(preds)).round(1).to_markdown(), ""]
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--lsapp", type=Path)
    p.add_argument("--sim-test-start", default="2026-03-02")
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    names = [m.name for m in ALL_MODELS]

    daily = sim_daily_features(args.sim)
    preds = walk_forward(daily, ALL_MODELS, pd.Timestamp(args.sim_test_start), daily["target_date"].max())
    sections = [report("Dữ liệu mô phỏng", preds, names)]

    if args.lsapp:
        daily = lsapp_daily_features(args.lsapp)
        start = daily["target_date"].quantile(0.5).normalize()  # nửa sau khoảng thời gian làm tập kiểm tra
        preds = walk_forward(daily, ALL_MODELS, start, daily["target_date"].max())
        sections.append(report("LSApp (người lớn)", preds, names))

    text = "# M1 — kết quả thực nghiệm đợt 1\n\n" + "\n".join(sections)
    (args.out / "m1_round1.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
