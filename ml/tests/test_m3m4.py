import numpy as np
import pandas as pd

from models.m3m4 import habit_vectors, suggest, traits

BASE = {
    "median_school_min": 200.0,
    "mean_daily_min": 220.0,
    "school_limit": 180.0,
    "reach_limit_rate": 0.7,
    "ext_per_week": 4.0,
    "ext_mean_min": 30.0,
    "late_nights_last_week": 0,
    "game_share": 0.2,
}


def codes(stats: dict, age: str = "11-14") -> list[str]:
    return [c for c, _ in suggest(pd.Series(stats), age)]


def test_gradual_suggestion_starts_above_the_current_limit():
    ((code, text),) = suggest(pd.Series(BASE), "11-14")
    assert code == "giam_dan"
    assert "nâng giới hạn ngày đi học lên 3 giờ 30 phút" in text and "về 3 giờ trong 4 tuần" in text


def test_no_limit_suggestions_depend_on_age():
    no_limit = {**BASE, "school_limit": np.nan, "reach_limit_rate": np.nan}
    assert codes(no_limit, "3-5") == ["who"]
    assert codes(no_limit, "15-17") == ["dat_gioi_han"]
    assert codes({**no_limit, "mean_daily_min": 45.0}, "3-5") == ["dat_gioi_han"]  # đã dưới mốc WHO


def test_sleep_and_game_suggestions():
    late = {**BASE, "reach_limit_rate": 0.2, "late_nights_last_week": 4}
    assert codes(late) == ["gio_ngu"]
    assert "sau nửa đêm" in suggest(pd.Series(late), "15-17")[0][1]
    assert "sau 22h" in suggest(pd.Series(late), "6-10")[0][1]
    assert codes({**BASE, "reach_limit_rate": 0.2, "game_share": 0.6}) == ["gioi_han_game"]


def test_habit_vectors_and_traits():
    rows = []
    for pid, night in ((1, 0.0), (2, 0.0), (3, 30.0)):
        for d in pd.date_range("2026-03-02", periods=14):
            day_type = "school" if d.weekday() < 5 else "weekend"
            for h in range(24):
                used = (30.0 if h == 19 else 0.0) + (night if h == 23 else 0.0)
                rows.append(
                    {"profileId": pid, "date": d, "hour": h, "day_type": day_type, "hour_min": used,
                     "hour_min_video": used, "hour_min_game": 0.0, "hour_min_social": 0.0,
                     "hour_min_study": 0.0, "hour_min_other": 0.0}
                )
    v = habit_vectors(pd.DataFrame(rows))
    assert list(v.index) == [1, 2, 3]
    assert v.loc[3, "night_share"] > 0 and v.loc[1, "night_share"] == 0
    assert "hay dùng khuya" in traits(v, pd.Index([3]))
