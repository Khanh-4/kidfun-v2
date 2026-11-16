"""M1 — bảng so sánh hoàn chỉnh (tuần 4): hồi quy (thêm LSTM), xác suất vượt giới hạn, phân tích loại bỏ nhóm
đặc trưng; trên dữ liệu mô phỏng, LSApp, StudentLife và LiveLab (thêm 16/11).

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m1.round2 --sim data/sim --lsapp data/lsapp.tsv.gz \
        --studentlife data/dataset_rds --livelab data/livelab/appusage.sql --out reports
"""

import argparse
from pathlib import Path

import pandas as pd

from .data import livelab_daily_features, lsapp_daily_features, sim_daily_features, studentlife_daily_features
from .evaluate import metrics, report, walk_forward
from .lstm import LSTMGlobal
from .models import ALL_MODELS, XGBAbsolute, feature_columns
from .consistency import PlattClipped
from .over_limit import ALL_CLASSIFIERS, M1_LABEL, proba_metrics, reliability_table, walk_forward_proba

REGRESSORS = (*ALL_MODELS, LSTMGlobal)
PROBA_MODELS = (*ALL_CLASSIFIERS, PlattClipped)
PRODUCTION_PROBA = PlattClipped.name  # = M1Bundle.predict_over_limit (Platt + kẹp theo số phút, từ 16/11)

FEATURE_GROUPS = {  # đặc tả 05 mục 1.2
    "A. Lịch sử": (
        "y_lag1", "y_lag7", "y_same_dow_last_week", "mean7", "std7", "mean14", "today_until_cutoff",
        "today_until_cutoff_ratio", "lag1_ratio", "same_dow_ratio", "today_missing",
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
    "I. Vị trí": ("outside_zone_min_7d",),  # từ 16/11: bộ mô phỏng sinh GeofenceEvent
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
    preds = walk_forward_proba(daily, PROBA_MODELS, start, daily["target_date"].max())
    names = [m.name for m in PROBA_MODELS]
    table = proba_metrics(preds, names)
    base_rate = preds[M1_LABEL].astype(float).mean()
    return "\n".join(
        [
            "## Xác suất ngày mai dùng hết giờ — dùng ≥ giới hạn − 5 phút (dữ liệu mô phỏng)",
            "",
            f"{len(preds):,} ngày có giới hạn, tỷ lệ dùng hết giờ thực tế {base_rate:.1%}.",
            "",
            table.round(3).to_markdown(),
            "",
            f"Bảng tin cậy của `{PRODUCTION_PROBA}` — mô hình gói M1 đang dùng (xác suất dự đoán so với tỷ lệ "
            "dùng hết giờ thực tế):",
            "",
            reliability_table(preds, PRODUCTION_PROBA).round(3).to_markdown(),
            "",
        ]
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--lsapp", type=Path)
    p.add_argument("--studentlife", type=Path)
    p.add_argument("--livelab", type=Path, help="appusage.sql (giải nén từ traces/apps.tar.gz)")
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
        ablation_section(sim_daily_features(args.sim, with_geofence=True), start),
    ]

    public = {
        "LSApp (người lớn)": (args.lsapp, lsapp_daily_features),
        "StudentLife (sinh viên)": (args.studentlife, studentlife_daily_features),
        "LiveLab (sinh viên, iPhone)": (args.livelab, livelab_daily_features),
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
