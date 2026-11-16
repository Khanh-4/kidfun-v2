"""Nạp dữ liệu cho M1 và dựng bảng đặc trưng ngày (ml/features) — dùng chung cho mọi mô hình."""

import re
import sys
from pathlib import Path

import numpy as np
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


def sim_daily_features(sim_dir: Path, with_geofence: bool = False) -> pd.DataFrame:
    """with_geofence chỉ dùng cho phân tích loại bỏ đặc trưng (nhóm vị trí): tác vụ ban đêm production KHÔNG nhận dữ
    liệu vùng an toàn, nên gói M1 phải học với outside_zone_min_7d = 0 như lúc chạy thật."""
    t = load_sim(sim_dir)
    geo = None
    if with_geofence:
        geo = pd.read_csv(sim_dir / "geofence_events.csv")
        geo["createdAt"] = pd.to_datetime(geo["createdAt"], utc=True)
    daily = build_daily_features(
        t["app_usage_hourly"],
        calendar=Calendar.load(),
        categories=load_categories(),
        limits=t["time_limits"],
        ext_requests=t["time_extension_requests"],
        youtube=t["youtube_logs"],
        geofence=geo,
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


LIVELAB_ROW = re.compile(r"^INSERT INTO appusage VALUES \((\d+), '([^']*)', '(.*)', (\d+), (-?\d+)\);$")
LIVELAB_TZ = "America/Chicago"  # Rice University + Houston Community College
LIVELAB_HOME = "SpringBoard"  # màn hình chính iOS, như launcher bị bỏ ở StudentLife
LIVELAB_MAX_SESSION_S = 4 * 3600  # phiên dài hơn coi là lỗi ghi log (tắt màn hình đã thoát app)


def livelab_events(path: Path) -> pd.DataFrame:
    """Đọc appusage.sql của LiveLab (dump PostgreSQL, mỗi dòng một INSERT): uid, name, time (POSIX), duration (giây).
    Bỏ SpringBoard và phiên ≤ 0 giây; chặn phiên ở 4 giờ."""
    rows = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = LIVELAB_ROW.match(line.rstrip("\n"))
            if m:
                rows.append((m.group(2), m.group(3), int(m.group(4)), int(m.group(5))))
    ev = pd.DataFrame(rows, columns=["uid", "name", "time", "duration"])
    ev = ev[(ev["name"] != LIVELAB_HOME) & (ev["duration"] > 0)]
    return ev.assign(duration=ev["duration"].clip(upper=LIVELAB_MAX_SESSION_S)).reset_index(drop=True)


def livelab_hourly(path: Path) -> pd.DataFrame:
    """LiveLab -> định dạng AppUsageHourly. Cắt phiên theo ranh giới giờ (múi Chicago lệch giờ tròn nên cắt theo giờ
    UTC cũng là theo giờ địa phương), đổi sang giờ Houston (có giờ mùa hè), rồi xử lý như LSApp: lùi 7 giờ để to_vn()
    trả lại đúng giờ địa phương gốc."""
    ev = livelab_events(path)
    start = ev["time"].to_numpy()
    end = start + ev["duration"].to_numpy()
    first_hour, last_hour = start // 3600, (end - 1) // 3600
    n = (last_hour - first_hour + 1).astype(int)
    idx = np.repeat(np.arange(len(ev)), n)
    hour = np.repeat(first_hour, n) + (np.arange(n.sum()) - np.repeat(np.cumsum(n) - n, n))
    seconds = np.minimum(end[idx], (hour + 1) * 3600) - np.maximum(start[idx], hour * 3600)
    parts = pd.DataFrame({"uid": ev["uid"].to_numpy()[idx], "name": ev["name"].to_numpy()[idx],
                          "hour": hour, "seconds": seconds,
                          "launch": (hour == first_hour[idx]).astype(int)})  # lượt mở tính ở giờ bắt đầu phiên
    hourly = parts.groupby(["uid", "name", "hour"], as_index=False)[["seconds", "launch"]].sum()
    local = (pd.to_datetime(hourly["hour"] * 3600, unit="s", utc=True)
             .dt.tz_convert(LIVELAB_TZ).dt.tz_localize(None))
    return pd.DataFrame(
        {
            "profileId": hourly["uid"],
            "packageName": hourly["name"],
            "hourStart": (local - pd.Timedelta(hours=7)).dt.tz_localize("UTC"),
            "usageSeconds": hourly["seconds"].astype(int),
            "launchCount": hourly["launch"].astype(int),
        }
    )


def livelab_daily_features(path: Path) -> pd.DataFrame:
    daily = build_daily_features(livelab_hourly(path), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")


def studentlife_daily_features(rds_dir: Path) -> pd.DataFrame:
    daily = build_daily_features(studentlife_hourly(rds_dir), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")


def lsapp_daily_features(path: Path) -> pd.DataFrame:
    daily = build_daily_features(lsapp_hourly(path), calendar=Calendar.load(), categories=load_categories())
    return daily.assign(ageGroup="adult")
