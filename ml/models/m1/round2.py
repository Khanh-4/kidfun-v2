"""M1 — bảng so sánh hoàn chỉnh (tuần 4): hồi quy (thêm LSTM), xác suất vượt giới hạn, phân tích loại bỏ nhóm
đặc trưng; trên dữ liệu mô phỏng, LSApp và StudentLife.

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m1.round2 --sim data/sim --lsapp data/lsapp.tsv.gz \
        --studentlife data/dataset_rds --out reports
"""

import argparse
from pathlib import Path

import pandas as pd

from .data import lsapp_daily_features, sim_daily_features, studentlife_daily_features
from .evaluate import metrics, report, walk_forward
from .lstm import LSTMGlobal
from .models import ALL_MODELS, XGBAbsolute, feature_columns
from .over_limit import ALL_CLASSIFIERS, proba_metrics, reliability_table, walk_forward_proba

REGRESSORS = (*ALL_MODELS, LSTMGlobal)

FEATURE_GROUPS = {  # đặc tả 05 mục 1.2
    "A. Lịch sử": (
        "y_lag1", "y_lag7", "y_same_dow_last_week", "mean7", "std7", "mean14", "today_until_cutoff",
        "today_until_cutoff_ratio", "lag1_ratio", "same_dow_ratio", "history_days", "today_missing",
    ),
    "B. Lịch": (
        "dow_sin", "dow_cos", "is_weekend", "is_holiday", "is_school_day", "is_exam_period", "is_summer",
        "days_to_next_holiday",
    ),
    "C. Giới hạn": ("limit_tomorrow", "has_limit", "limit_tomorrow_ratio", "is_gradual"),
    "D. Thương lượng": ("ext_req_7d", "ext_min_req_7d", "ext_approve_rate_7d", "ext_req_today"),
    "E. Cơ cấu app": ("share_video", "share_game", "share_social", "share_study"),
    "F. Khuya": ("night_min_last", "night_min_7d", "late_nights_7d"),
    "G. Giấc ngủ": ("last_active_hour", "sleep_gap_hours"),
    "H. Nội dung": ("yt_danger_mean_7d", "yt_danger_high_7d"),
}


def ablation_models(all_cols: list[str]):
    """XGBoost đầy đủ, bỏ từng nhóm, và chỉ giữ nhóm A (chỉ lịch sử)."""
    variants = [type("Full", (XGBAbsolute,), {"name": "đầy đủ"})]
    for group, cols in FEATURE_GROUPS.items():
        variants.append(type("Drop", (XGBAbsolute,), {"name": f"bỏ {group}", "DROP": frozenset(cols)}))
    keep_a = frozenset(c for c in all_cols if c not in FEATURE_GROUPS["A. Lịch sử"])
    variants.append(type("OnlyA", (XGBAbsolute,), {"name": "chỉ A", "DROP": keep_a}))
    return variants


def ablation_section(daily: pd.DataFrame, start: pd.Timestamp) -> str:
    variants = ablation_models(feature_columns(daily))
    preds = walk_forward(daily, variants, start, daily["target_date"].max())
    table = metrics(preds, [v.name for v in variants])[["MAE", "WAPE_%"]]
    table["ΔMAE so với đầy đủ"] = table["MAE"] - table.loc["đầy đủ", "MAE"]
    table = table.round(1).sort_values("ΔMAE so với đầy đủ", ascending=False)
    return "\n".join(["## Phân tích loại bỏ nhóm đặc trưng (XGBoost, dữ liệu mô phỏng)", "", table.to_markdown(), ""])


def over_limit_section(daily: pd.DataFrame, start: pd.Timestamp) -> str:
    preds = walk_forward_proba(daily, ALL_CLASSIFIERS, start, daily["target_date"].max())
    names = [m.name for m in ALL_CLASSIFIERS]
    table = proba_metrics(preds, names)
    best = table["Brier"].idxmin()
    base_rate = preds["over_limit_next"].astype(float).mean()
    return "\n".join(
        [
            "## Xác suất ngày mai vượt giới hạn (dữ liệu mô phỏng)",
            "",
            f"{len(preds):,} ngày có giới hạn, tỷ lệ vượt thực tế {base_rate:.1%}.",
            "",
            table.round(3).to_markdown(),
            "",
            f"Bảng tin cậy của `{best}` (xác suất dự đoán so với tỷ lệ vượt thực tế):",
            "",
            reliability_table(preds, best).round(3).to_markdown(),
            "",
        ]
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--lsapp", type=Path)
    p.add_argument("--studentlife", type=Path)
    p.add_argument("--sim-test-start", default="2026-03-02")
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    names = [m.name for m in REGRESSORS]
    start = pd.Timestamp(args.sim_test_start)

    sim = sim_daily_features(args.sim)
    sim_preds = walk_forward(sim, REGRESSORS, start, sim["target_date"].max())
    sections = [
        report("Dự đoán số phút — dữ liệu mô phỏng", sim_preds, names),
        over_limit_section(sim, start),
        ablation_section(sim, start),
    ]

    public = {
        "LSApp (người lớn)": (args.lsapp, lsapp_daily_features),
        "StudentLife (sinh viên)": (args.studentlife, studentlife_daily_features),
    }
    for title, (path, loader) in public.items():
        if path is None:
            continue
        daily = loader(path)
        half = daily["target_date"].quantile(0.5).normalize()  # nửa sau khoảng thời gian làm tập kiểm tra
        preds = walk_forward(daily, REGRESSORS, half, daily["target_date"].max())
        sections.append(report(f"Dự đoán số phút — {title}", preds, names))

    text = "# M1 — bảng so sánh hoàn chỉnh (tuần 4)\n\n" + "\n".join(sections)
    (args.out / "m1_round2.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
