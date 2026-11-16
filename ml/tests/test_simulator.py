import pandas as pd
import pytest

from features import Calendar, build_day_anomaly_features, build_daily_features, load_categories
from features.common import to_vn
from simulator import simulate

CAL = Calendar.load()


@pytest.fixture(scope="module")
def sim():
    return simulate(12, "2025-09-01", 90, seed=7, calendar=CAL)


def daily_totals(u: pd.DataFrame) -> pd.DataFrame:
    day = to_vn(u["hourStart"]).dt.normalize().rename("date")
    return (u["usageSeconds"] / 60).groupby([u["profileId"], day]).sum().rename("total").reset_index()


def test_columns_match_prisma_tables(sim):
    assert {"profileId", "deviceId", "packageName", "appName", "hourStart", "usageSeconds", "launchCount"} <= set(
        sim["app_usage_hourly"].columns
    )
    assert {"profileId", "dayOfWeek", "dailyLimitMinutes", "isActive", "isGradual"} <= set(sim["time_limits"].columns)
    assert {"profileId", "requestMinutes", "status", "createdAt"} <= set(sim["time_extension_requests"].columns)
    assert {"profileId", "watchedAt", "dangerLevel"} <= set(sim["youtube_logs"].columns)
    assert str(sim["app_usage_hourly"]["hourStart"].dt.tz) == "UTC"


def test_same_seed_same_data():
    a = simulate(3, "2025-09-01", 40, seed=1, calendar=CAL)["app_usage_hourly"]
    b = simulate(3, "2025-09-01", 40, seed=1, calendar=CAL)["app_usage_hourly"]
    pd.testing.assert_frame_equal(a, b)


def test_no_hour_over_60_minutes(sim):
    per_hour = sim["app_usage_hourly"].groupby(["profileId", "hourStart"])["usageSeconds"].sum()
    assert per_hour.max() <= 3600


def test_daily_usage_respects_limit_plus_approved_extension(sim):
    total = daily_totals(sim["app_usage_hourly"])
    total["dow"] = (total["date"].dt.weekday + 1) % 7
    merged = total.merge(sim["time_limits"], left_on=["profileId", "dow"], right_on=["profileId", "dayOfWeek"])
    ext = sim["time_extension_requests"]
    granted = (
        ext.assign(date=to_vn(ext["createdAt"]).dt.normalize())
        .groupby(["profileId", "date"])["responseMinutes"]
        .sum()
        .rename("granted")
    )
    merged = merged.join(granted, on=["profileId", "date"]).fillna({"granted": 0})
    assert len(merged) > 0
    assert (merged["total"] <= merged["dailyLimitMinutes"] + merged["granted"] + 1).all()


def test_anomalies_labelled_after_warmup_and_present_in_data(sim):
    a = sim["anomalies"]
    assert len(a) > 0
    assert (pd.to_datetime(a["date"]) >= pd.Timestamp("2025-09-29")).all()
    night = a[a["kind"] == "night_use"].iloc[0]
    hours = [int(h) for h in night["hours"].split()]
    u = sim["app_usage_hourly"]
    local = to_vn(u["hourStart"])
    hit = u[
        (u["profileId"] == night["profileId"])
        & (local.dt.normalize() == pd.Timestamp(night["date"]))
        & local.dt.hour.isin(hours)
    ]
    assert hit["usageSeconds"].sum() > 0


def test_weekends_use_more_than_school_days(sim):
    total = daily_totals(sim["app_usage_hourly"])
    day_type = CAL.day_flags(total["date"])["day_type"].to_numpy()
    by_type = total.groupby(day_type)["total"].mean()
    assert by_type["weekend"] > by_type["school"]


def test_feature_pipeline_runs_on_simulated_data(sim):
    cats = load_categories()
    daily = build_daily_features(
        sim["app_usage_hourly"],
        calendar=CAL,
        categories=cats,
        limits=sim["time_limits"],
        ext_requests=sim["time_extension_requests"],
        youtube=sim["youtube_logs"],
    )
    assert daily["profileId"].nunique() == 12
    assert daily["y_next"].notna().mean() > 0.9
    assert daily["over_limit_next"].notna().any()
    days = build_day_anomaly_features(
        sim["app_usage_hourly"], calendar=CAL, categories=cats, youtube=sim["youtube_logs"]
    )
    assert days["day_ratio"].notna().mean() > 0.5


def test_geofence_events_do_not_change_other_tables():
    with_geo = simulate(8, "2025-11-03", 21, seed=5)
    without = simulate(8, "2025-11-03", 21, seed=5, geofence=False)
    for name in ("app_usage_hourly", "time_limits", "time_extension_requests", "youtube_logs", "anomalies"):
        pd.testing.assert_frame_equal(with_geo[name], without[name])
    assert without["geofence_events"].empty


def test_geofence_events_alternate_and_outings_fall_in_idle_hours():
    s = simulate(12, "2025-11-03", 42, seed=5)
    geo = s["geofence_events"]
    assert list(geo.columns) == ["geofenceId", "profileId", "type", "latitude", "longitude", "createdAt"]
    assert not geo.empty and set(geo["type"]) == {"EXIT", "ENTER"}
    for _, g in geo.sort_values("createdAt").groupby("profileId"):
        kinds = g["type"].tolist()
        assert all(a != b for a, b in zip(kinds, kinds[1:]))  # EXIT/ENTER xen kẽ
    # Lượt đi chơi (ra khỏi vùng NHÀ buổi chiều tối) chỉ nằm trong giờ trẻ dùng máy ≤ 10 phút
    usage = s["app_usage_hourly"].assign(h=lambda d: d["hourStart"].dt.floor("h"))
    minutes = (usage.groupby(["profileId", "h"])["usageSeconds"].sum() / 60).to_dict()
    home = geo["geofenceId"] % 2 == 0  # vùng Nhà = 2·id, Trường = 2·id + 1
    outings = geo[home & (geo["type"] == "EXIT") & ((geo["createdAt"] + pd.Timedelta(hours=7)).dt.hour >= 14)]
    assert not outings.empty
    assert all(minutes.get((p, t.floor("h")), 0) <= 10 for p, t in zip(outings["profileId"], outings["createdAt"]))


def test_binge_day_marked_unobservable_when_the_limit_blocks_it():
    s = simulate(60, "2025-09-01", 150, seed=3, geofence=False)  # đủ ngày binge ở trẻ KHÔNG giới hạn (≈ 13)
    an = s["anomalies"]
    assert an["observable"].dtype == bool
    assert an.loc[an["kind"] != "binge_day", "observable"].all()
    limited_ids = set(s["time_limits"]["profileId"])
    binge = an[an["kind"] == "binge_day"].assign(limited=lambda d: d["profileId"].isin(limited_ids))
    rate = binge.groupby("limited")["observable"].mean()
    assert rate[False] > 0.5  # không giới hạn: phần lớn lộ rõ (trừ trẻ vốn đã dùng gần kín 60 phút/giờ)
    assert rate[True] < rate[False]  # có giới hạn: nhiều ngày bị chặn, trông như ngày bình thường
