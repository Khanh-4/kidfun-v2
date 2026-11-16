import pandas as pd

from e2e.export_demo import BACKGROUND, DEMO_CHILDREN, build_demo


def test_demo_has_two_named_children_and_enough_background_for_kmeans():
    demo = build_demo(pd.Timestamp("2026-11-16"))
    kids = demo["children"]
    shown = [c for c in kids if c["demo"]]

    assert [c["name"] for c in shown] == [name for name, _ in DEMO_CHILDREN]
    assert len(kids) == len(DEMO_CHILDREN) + BACKGROUND
    assert len(kids) >= 6  # M3 K-Means chỉ chạy khi ≥ 6 trẻ đủ 7 ngày
    assert len({c["simProfileId"] for c in kids}) == len(kids)


def test_every_child_has_28_days_ending_today_and_an_age():
    demo = build_demo(pd.Timestamp("2026-11-16"))
    for c in demo["children"]:
        vn = pd.to_datetime([h["hourStart"] for h in c["hourly"]], utc=True).tz_localize(None) + pd.Timedelta(hours=7)
        days = vn.normalize()
        assert days.max() == pd.Timestamp("2026-11-16")
        assert days.nunique() >= 21
        assert c["dateOfBirth"] < "2023-01-01"


def test_night_anomaly_only_on_the_designated_child():
    demo = build_demo(pd.Timestamp("2026-11-16"))
    flagged = [c["name"] for c in demo["children"] if c["dayAnomalyInjected"]]

    assert flagged == ["An"]

