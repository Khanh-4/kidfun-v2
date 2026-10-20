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


def studentlife_hourly(rds_dir: Path) -> pd.DataFrame:
    """StudentLife -> định dạng AppUsageHourly: mỗi ảnh chụp 'đang dùng' (20 phút một lần) tính 20 phút cho app
    trên cùng. Ngày có < 50% số ảnh chụp bị bỏ (thành ngày thiếu). Giờ America/New_York, xử lý như LSApp."""
    sys.path.insert(0, str(ML_DIR / "eda"))
    import studentlife_eda as sl  # noqa: E402

    snap = sl.snapshots(*sl.load(rds_dir))
    local = snap["local"].dt.tz_localize(None)
    snap = snap.assign(date=local.dt.normalize(), hour_start=local.dt.floor("h"))
    coverage = snap.groupby(["uid", "date"])["active"].transform("size")
    used = snap[snap["active"] & (coverage >= sl.MIN_COVERAGE * sl.SNAPSHOTS_PER_DAY)]
    hourly = used.groupby(["uid", "package", "hour_start"]).size().rename("snaps").reset_index()
    # Có người được chụp dày hơn 20 phút/lần -> chặn mỗi giờ tối đa 60 phút, co theo tỷ lệ giữa các app
    per_hour = hourly.groupby(["uid", "hour_start"])["snaps"].transform("sum") * sl.SNAPSHOT_MINUTES
    minutes = hourly["snaps"] * sl.SNAPSHOT_MINUTES * (60 / per_hour).clip(upper=1)
    return pd.DataFrame(
        {
            "profileId": hourly["uid"],
            "packageName": hourly["package"],
            "hourStart": (hourly["hour_start"] - pd.Timedelta(hours=7)).dt.tz_localize("UTC"),
            "usageSeconds": (minutes * 60).round().astype(int),
            "launchCount": hourly["snaps"],
        }
    )


def studentlife_daily_features(rds_dir: Path) -> pd.DataFrame:
    daily = build_daily_features(studentlife_hourly(rds_dir), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")


def lsapp_daily_features(path: Path) -> pd.DataFrame:
    daily = build_daily_features(lsapp_hourly(path), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")
