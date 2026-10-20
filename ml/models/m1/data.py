"""Nạp dữ liệu cho M1 và dựng bảng đặc trưng ngày (ml/features) — dùng chung cho mọi mô hình."""

import sys
from pathlib import Path

import pandas as pd

from features import Calendar, build_daily_features, load_categories

ML_DIR = Path(__file__).resolve().parents[2]
SIM_TABLES = ("profiles", "app_usage_hourly", "time_limits", "time_extension_requests", "youtube_logs")
TIME_COLUMNS = {"app_usage_hourly": "hourStart", "time_extension_requests": "createdAt", "youtube_logs": "watchedAt"}


def load_sim(sim_dir: Path) -> dict[str, pd.DataFrame]:
    tables = {name: pd.read_csv(sim_dir / f"{name}.csv") for name in SIM_TABLES}
    for name, col in TIME_COLUMNS.items():
        tables[name][col] = pd.to_datetime(tables[name][col], utc=True)
    return tables


def sim_daily_features(sim_dir: Path) -> pd.DataFrame:
    t = load_sim(sim_dir)
    daily = build_daily_features(
        t["app_usage_hourly"],
        calendar=Calendar.load(),
        categories=load_categories(),
        limits=t["time_limits"],
        ext_requests=t["time_extension_requests"],
        youtube=t["youtube_logs"],
    )
    return daily.merge(t["profiles"][["profileId", "ageGroup"]], on="profileId")


def lsapp_hourly(path: Path) -> pd.DataFrame:
    """LSApp -> định dạng AppUsageHourly. Dấu thời gian LSApp không rõ múi giờ (EDA tuần 1) nên coi là
    giờ địa phương: lùi 7 giờ để to_vn() trả lại đúng giờ gốc. packageName = tên app (không có package)."""
    sys.path.insert(0, str(ML_DIR / "eda"))
    import lsapp_eda  # noqa: E402  (tái dùng cách ghép phiên + cắt theo giờ của EDA)

    hourly = lsapp_eda.hourly_usage(lsapp_eda.build_sessions(lsapp_eda.load(path)))
    hourly = hourly.groupby(["user_id", "app_name", "hour_start"], as_index=False)["seconds"].sum()
    return pd.DataFrame(
        {
            "profileId": hourly["user_id"],
            "packageName": hourly["app_name"],
            "hourStart": (hourly["hour_start"] - pd.Timedelta(hours=7)).dt.tz_localize("UTC"),
            "usageSeconds": hourly["seconds"].round().astype(int),
            "launchCount": 1,
        }
    )


def lsapp_daily_features(path: Path) -> pd.DataFrame:
    daily = build_daily_features(lsapp_hourly(path), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")
