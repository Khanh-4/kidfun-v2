import numpy as np
import pandas as pd
import pytest

from features import Calendar, build_day_anomaly_features, build_hourly_features, load_categories

CAL = Calendar.load()
CATS = load_categories()
GAME = "com.garena.game.kgvn"
YT = "com.google.android.youtube"
# 10 ngày học: thứ Hai–thứ Sáu của 2 tuần 5–9/10 và 12–16/10/2026
SCHOOL_DAYS = [d for d in pd.date_range("2026-10-05", "2026-10-16") if d.weekday() < 5]
TEST_DAY = pd.Timestamp("2026-10-19")  # thứ Hai


def utc(local) -> pd.Timestamp:
    return pd.Timestamp(local).tz_localize("UTC") - pd.Timedelta(hours=7)


def rows(entries) -> pd.DataFrame:
    """entries: (giờ VN, phút, packageName)."""
    return pd.DataFrame(
        [
            {"profileId": 1, "packageName": pkg, "hourStart": utc(ts), "usageSeconds": int(m * 60), "launchCount": 2}
            for ts, m, pkg in entries
        ]
    )


def usual_days(extra=()):
    base = [(d + pd.Timedelta(hours=20), 10, GAME) for d in SCHOOL_DAYS]
    base += [(d + pd.Timedelta(hours=10), 30, YT) for d in SCHOOL_DAYS]
    return rows(base + list(extra))


def at(day, hour):
    return day + pd.Timedelta(hours=hour)


def hour_row(df, day, hour):
    return df[(df["date"] == day) & (df["hour"] == hour)].iloc[0]


def build_hours(h):
    return build_hourly_features(h, calendar=CAL, categories=CATS)


def test_hour_z_against_same_day_type_baseline_with_std_floor():
    df = build_hours(usual_days([(at(TEST_DAY, 20), 60, GAME)]))
    r = hour_row(df, TEST_DAY, 20)
    assert r["base_mean"] == 10 and r["base_days"] == 10
    assert r["hour_z"] == pytest.approx((60 - 10) / 5)  # độ lệch chuẩn 0 -> chặn dưới 5 phút
    assert r["hour_min_game"] == 60


def test_weekend_is_not_part_of_school_baseline():
    saturday = pd.Timestamp("2026-10-10")
    df = build_hours(usual_days([(at(saturday, 20), 120, GAME), (at(TEST_DAY, 20), 10, GAME)]))
    assert hour_row(df, TEST_DAY, 20)["base_mean"] == 10
    assert hour_row(df, saturday, 20)["day_type"] == "weekend"


def test_night_use_inside_usual_sleep_window():
    df = build_hours(usual_days([(at(TEST_DAY, 2), 25, GAME)]))
    r = hour_row(df, TEST_DAY, 2)
    assert bool(r["is_night"]) and bool(r["in_sleep_window"])
    assert not bool(hour_row(df, TEST_DAY, 10)["in_sleep_window"])


def test_new_app_minutes():
    df = build_hours(usual_days([(at(TEST_DAY, 15), 20, "com.roblox.client")]))
    assert hour_row(df, TEST_DAY, 15)["new_app_min"] == 20
    assert hour_row(df, TEST_DAY, 10)["new_app_min"] == 0  # YouTube đã quen
    assert np.isnan(hour_row(df, SCHOOL_DAYS[0], 10)["new_app_min"])  # chưa có lịch sử


def test_day_level_features():
    extra = [(at(TEST_DAY, 20), 80, GAME), (at(TEST_DAY, 23), 15, GAME)]
    yt = pd.DataFrame({"profileId": [1, 1], "watchedAt": [utc(at(TEST_DAY, 9))] * 2, "dangerLevel": [5, 2]})
    df = build_day_anomaly_features(usual_days(extra), calendar=CAL, categories=CATS, youtube=yt).set_index("date")
    r = df.loc[TEST_DAY]
    assert r["day_min"] == 95
    assert r["day_ratio"] == pytest.approx(95 / 40)
    assert r["night_min"] == 15
    assert r["max_hour_min"] == 80 and r["n_active_hours"] == 2
    assert r["mix_l1"] == pytest.approx(2 * (1 - 10 / 40))  # chỉ game; thường 25% game / 75% video
    assert r["yt_danger_high"] == 1
