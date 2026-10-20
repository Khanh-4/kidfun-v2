"""Dữ liệu cho M2: đặc trưng theo giờ/ngày (ml/features) + nhãn bất thường cài sẵn của bộ sinh mô phỏng.

Làm sạch nhãn: bất thường được cài TRƯỚC khi áp giới hạn thời gian, nên có giờ bị cài nhưng máy đã bị chặn
(0 phút) -> không còn gì để phát hiện. Ở mức giờ chỉ giữ nhãn dương khi giờ đó còn dùng máy; ở mức ngày bỏ nhãn của
những ngày mà mọi giờ bị cài đều 0 phút. Số nhãn bị bỏ được báo cáo.
"""

from pathlib import Path

import numpy as np
import pandas as pd

from features import Calendar, build_day_anomaly_features, build_hourly_features, load_categories

from ..m1.data import load_sim

HOUR_KINDS = ("night_use", "spike", "new_app")
DAY_ONLY_KINDS = ("binge_day", "danger_content")
DAY_FEATURES = (
    "day_min", "day_ratio", "night_min", "max_hour_min", "n_active_hours", "mix_l1", "new_app_min",
    "yt_danger_high", "ext_req",
)


def load_labels(sim_dir: Path) -> pd.DataFrame:
    labels = pd.read_csv(sim_dir / "anomalies.csv", dtype={"hours": str})
    labels["date"] = pd.to_datetime(labels["date"])
    return labels


def hour_labels(labels: pd.DataFrame) -> pd.DataFrame:
    rows = [
        (r.profileId, r.date, int(h), r.kind)
        for r in labels[labels["kind"].isin(HOUR_KINDS)].itertuples()
        for h in str(r.hours).split()
    ]
    return pd.DataFrame(rows, columns=["profileId", "date", "hour", "kind"])


def attach_labels(hours: pd.DataFrame, days: pd.DataFrame, labels: pd.DataFrame):
    """Gắn nhãn đã làm sạch vào bảng giờ / ngày. Trả về (hours, days, thống kê)."""
    hl = hour_labels(labels)
    hours = hours.merge(hl, on=["profileId", "date", "hour"], how="left")
    hours["label"] = hours["kind"].notna() & (hours["hour_min"] > 0)
    # Ngày bất thường cả ngày (binge/danger) mơ hồ ở mức giờ -> loại khỏi đánh giá theo giờ
    day_only = labels[labels["kind"].isin(DAY_ONLY_KINDS)][["profileId", "date"]].assign(day_only=True)
    hours = hours.merge(day_only, on=["profileId", "date"], how="left")
    hours = hours[hours["day_only"].isna()].drop(columns="day_only")

    survived = hours[hours["label"]].groupby(["profileId", "date"]).size().rename("n").reset_index()
    labels = labels.merge(survived, on=["profileId", "date"], how="left")
    keep = labels["kind"].isin(DAY_ONLY_KINDS) | labels["n"].notna()
    days = days.merge(labels[keep][["profileId", "date", "kind"]], on=["profileId", "date"], how="left")
    days["label"] = days["kind"].notna()

    stats = {
        "nhãn giờ cài vào": len(hl),
        "nhãn giờ còn dùng máy (giữ)": int(hours["label"].sum()),
        "nhãn ngày cài vào": len(labels),
        "nhãn ngày giữ": int(keep.sum()),
    }
    return hours, days, stats


def sim_m2_frames(sim_dir: Path):
    t = load_sim(sim_dir)
    cal, cats = Calendar.load(), load_categories()
    hours = build_hourly_features(t["app_usage_hourly"], calendar=cal, categories=cats)
    days = build_day_anomaly_features(
        t["app_usage_hourly"],
        calendar=cal,
        categories=cats,
        youtube=t["youtube_logs"],
        ext_requests=t["time_extension_requests"],
    )
    return attach_labels(hours, days, load_labels(sim_dir))


def hour_matrix(hours: pd.DataFrame) -> pd.DataFrame:
    angle = 2 * np.pi * hours["hour"] / 24
    cats = [c for c in hours.columns if c.startswith("hour_min_")]
    x = hours[["hour_min", "hour_launches", *cats]].astype(float)
    base = hours["base_mean"].fillna(0)
    return x.assign(
        base_mean=base,
        hour_z=hours["hour_z"].fillna(0),
        ratio=hours["hour_min"] / base.clip(lower=5),
        new_app_min=hours["new_app_min"].fillna(0),
        is_night=hours["is_night"].astype(float),
        in_sleep_window=hours["in_sleep_window"].astype(float),
        hour_sin=np.sin(angle),
        hour_cos=np.cos(angle),
        **{f"day_{t}": (hours["day_type"] == t).astype(float) for t in ("school", "weekend", "off")},
    )


def day_matrix(days: pd.DataFrame) -> pd.DataFrame:
    x = days[list(DAY_FEATURES)].astype(float)
    return x.assign(
        day_ratio=x["day_ratio"].fillna(1.0),
        mix_l1=x["mix_l1"].fillna(0),
        new_app_min=x["new_app_min"].fillna(0),
    )
