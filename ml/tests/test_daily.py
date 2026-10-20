import numpy as np
import pandas as pd
import pytest

from features import Calendar, build_daily_features, load_categories
from features.common import to_vn

CAL = Calendar.load()
CATS = load_categories()


def utc(local: str) -> pd.Timestamp:
    """Giờ VN -> mốc UTC như cột DateTime trong Postgres."""
    return pd.Timestamp(local, tz="UTC") - pd.Timedelta(hours=7)


def hourly(*rows) -> pd.DataFrame:
    """rows: (giờ VN, phút[, packageName])."""
    return pd.DataFrame(
        [
            {
                "profileId": 1,
                "packageName": r[2] if len(r) > 2 else "com.google.android.youtube",
                "hourStart": utc(r[0]),
                "usageSeconds": int(r[1] * 60),
                "launchCount": 1,
            }
            for r in rows
        ]
    )


def build(h, **kw) -> pd.DataFrame:
    return build_daily_features(h, calendar=CAL, categories=CATS, **kw).set_index("date")


def test_usage_after_cutoff_only_reaches_target_not_features():
    df = build(hourly(("2026-10-05 10:00", 30), ("2026-10-05 21:00", 40), ("2026-10-06 09:00", 60)))
    t = df.loc["2026-10-05"]
    assert t["today_until_cutoff"] == 30
    assert t["y_next"] == 60
    assert df.loc["2026-10-06", "y_lag1"] == 70  # ngày t−1 tính đủ cả ngày


def test_utc_17h_is_midnight_of_next_vn_day():
    local = to_vn(pd.Series([pd.Timestamp("2026-10-05 17:00", tz="UTC")]))
    assert local.iloc[0] == pd.Timestamp("2026-10-06 00:00")


def test_missing_day_is_nan_not_zero():
    df = build(hourly(("2026-10-01 10:00", 30), ("2026-10-03 10:00", 50)))
    assert bool(df.loc["2026-10-02", "today_missing"])
    assert np.isnan(df.loc["2026-10-03", "y_lag1"])
    assert df.loc["2026-10-03", "history_days"] == 1


def test_calendar_flags_use_target_day():
    df = build(hourly(("2026-02-16 10:00", 10), ("2026-10-10 10:00", 10)))
    assert bool(df.loc["2026-02-16", "is_holiday"])  # ngày mai 17/2/2026 = mùng 1 Tết
    assert not bool(df.loc["2026-10-06", "is_holiday"])
    assert bool(df.loc["2026-10-06", "is_school_day"])  # 7/10/2026 là thứ Tư
    sunday = df.loc["2026-10-10"]  # ngày mai 11/10/2026 là Chủ nhật -> dow 0
    assert sunday["dow_sin"] == pytest.approx(0) and sunday["dow_cos"] == pytest.approx(1)


def test_extension_requests_respect_cutoff():
    ext = pd.DataFrame(
        {
            "profileId": [1, 1],
            "requestMinutes": [15, 30],
            "status": ["APPROVED", "REJECTED"],
            "createdAt": [utc("2026-10-05 20:30"), utc("2026-10-05 21:30")],
        }
    )
    df = build(hourly(("2026-10-05 10:00", 30), ("2026-10-06 10:00", 30)), ext_requests=ext)
    assert df.loc["2026-10-05", "ext_req_today"] == 1
    assert df.loc["2026-10-05", "ext_min_req_7d"] == 15
    assert df.loc["2026-10-06", "ext_req_7d"] == 2
    assert df.loc["2026-10-06", "ext_approve_rate_7d"] == 0.5


def test_late_night_belongs_to_previous_evening():
    df = build(hourly(("2026-10-04 23:00", 30), ("2026-10-05 01:00", 10), ("2026-10-05 10:00", 20)))
    t = df.loc["2026-10-05"]
    assert t["night_min_last"] == 40
    assert t["late_nights_7d"] == 1
    assert t["last_active_hour"] == 25  # 01:00 sáng


def test_limit_for_tomorrow_and_over_limit_label():
    limits = pd.DataFrame(
        {"profileId": [1], "dayOfWeek": [0], "dailyLimitMinutes": [60], "isActive": [True], "isGradual": [False]}
    )
    df = build(hourly(("2026-10-10 10:00", 30), ("2026-10-11 10:00", 90)), limits=limits)
    sat = df.loc["2026-10-10"]  # ngày mai Chủ nhật
    assert sat["limit_tomorrow"] == 60 and bool(sat["over_limit_next"])
    assert not bool(df.loc["2026-10-11", "has_limit"])


def test_outside_zone_minutes():
    geo = pd.DataFrame(
        {
            "profileId": [1, 1],
            "type": ["EXIT", "ENTER"],
            "createdAt": [utc("2026-10-05 08:00"), utc("2026-10-05 10:00")],
        }
    )
    df = build(hourly(("2026-10-05 10:00", 30)), geofence=geo)
    assert df.loc["2026-10-05", "outside_zone_min_7d"] == 120


def test_app_share_uses_categories():
    df = build(
        hourly(("2026-10-05 09:00", 30, "com.garena.game.kgvn"), ("2026-10-05 10:00", 10, "com.duolingo"))
    )
    t = df.loc["2026-10-05"]
    assert t["share_game"] == 0.75 and t["share_study"] == 0.25
