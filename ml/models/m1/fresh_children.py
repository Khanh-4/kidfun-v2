"""M1 trên TRẺ MỚI (lịch sử ngắn, bắt đầu ở thời điểm khác) — gần với triển khai thật hơn walk-forward (16/11).

Walk-forward chấm trẻ có lịch sử dài (mọi trẻ của bộ mô phỏng bắt đầu 01/09/2025). Ở đây huấn luyện gói M1 trên toàn
bộ data/sim rồi chấm 3 nhóm 60 trẻ mới mô phỏng riêng, mỗi nhóm 75 ngày bắt đầu ở một mùa khác; so có/bỏ đặc trưng
history_days (trùng với mùa trong data/sim). Kết quả: bỏ history_days giảm ECE ở cả 3 nhóm, AUC/MAE gần như không đổi
→ gói M1 bỏ nó từ 16/11. Tần suất p ≥ 0,8 phụ thuộc mạnh vào mùa (trẻ bắt đầu tháng 10 ít dùng hết giờ hơn).

    .venv/bin/python -m models.m1.fresh_children --sim data/sim --out reports     # ~2 phút
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import brier_score_loss, roc_auc_score

from features import Calendar, build_daily_features, load_categories
from simulator.generate import simulate

from . import bundle
from . import models as m1_models
from .data import sim_daily_features
from .over_limit import M1_LABEL, expected_calibration_error, limited

COHORTS = (("2026-01-12", 21), ("2026-04-06", 22), ("2026-10-05", 23))
COHORT_SIZE, COHORT_DAYS = 60, 75
ALERT = 0.8  # = M1_ALERT_THRESHOLD ở backend


def _train(daily: pd.DataFrame, with_history_days: bool) -> bundle.M1Bundle:
    saved = set(m1_models.NON_FEATURES)
    if with_history_days:
        m1_models.NON_FEATURES.discard("history_days")
    try:
        return bundle.train(daily)
    finally:
        m1_models.NON_FEATURES.clear()
        m1_models.NON_FEATURES.update(saved)


def _cohort(start: str, seed: int, cal: Calendar, cats: dict) -> pd.DataFrame:
    sim = simulate(COHORT_SIZE, start, COHORT_DAYS, seed=seed, calendar=cal)
    d = build_daily_features(sim["app_usage_hourly"], calendar=cal, categories=cats, limits=sim["time_limits"],
                             ext_requests=sim["time_extension_requests"], youtube=sim["youtube_logs"])
    d = d.merge(sim["profiles"][["profileId", "ageGroup"]], on="profileId")
    return d[limited(d) & (d["history_days"] >= 7) & d["y_next"].notna()]


def _score(m1: bundle.M1Bundle, rows: pd.DataFrame) -> dict:
    p, y = m1.predict_over_limit(rows), rows[M1_LABEL].astype(int).to_numpy()
    alert = p >= ALERT
    return {
        "ROC-AUC": roc_auc_score(y, p), "Brier": brier_score_loss(y, p), "ECE": expected_calibration_error(y, p),
        "% ngày p ≥ 0,8": alert.mean() * 100, "precision @0,8": y[alert].mean() if alert.any() else np.nan,
        "% dùng hết giờ thật": y.mean() * 100, "MAE phút": float(np.nanmean(np.abs(m1.predict_minutes(rows) - rows["y_next"]))),
    }


def report(sim_dir: Path) -> str:
    cal, cats = Calendar.load(), load_categories()
    train = sim_daily_features(sim_dir)
    variants = {"có history_days": _train(train, True), "bỏ history_days (gói M1)": _train(train, False)}
    rows = []
    for start, seed in COHORTS:
        cohort = _cohort(start, seed, cal, cats)
        rows += [{"trẻ mới từ": start, "biến thể": name, "số ngày": len(cohort), **_score(m1, cohort)}
                 for name, m1 in variants.items()]
    table = pd.DataFrame(rows).round(3).to_markdown(index=False)
    return "\n".join([
        "# M1 trên trẻ mới (lịch sử ngắn) — có/bỏ đặc trưng history_days",
        "",
        f"Gói M1 huấn luyện trên toàn bộ data/sim; chấm {len(COHORTS)} nhóm × {COHORT_SIZE} trẻ mới, mỗi nhóm "
        f"{COHORT_DAYS} ngày, chỉ ngày có giới hạn và ≥ 7 ngày lịch sử. Nhãn: dùng hết giờ (≥ giới hạn − 5 phút).",
        "",
        table,
        "",
    ])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    text = report(args.sim)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "m1_fresh_children.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
