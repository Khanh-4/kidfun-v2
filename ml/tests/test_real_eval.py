import numpy as np
import pandas as pd

from features import Calendar, load_categories
from jobs.load import to_frames
from models import real_eval

CAL, CATS = Calendar.load(), load_categories()


def _hour(pid, day, minutes, hour=19, pkg="com.google.android.youtube"):
    ts = (pd.Timestamp(f"{day} {hour:02d}:00") - pd.Timedelta(hours=7)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return {"profileId": pid, "packageName": pkg, "hourStart": ts, "usageSeconds": int(minutes * 60), "launchCount": 1}


def _pages(n_days_by_child: dict[int, int], end="2026-11-20"):
    rows = []
    for pid, n in n_days_by_child.items():
        for k in range(n):
            day = (pd.Timestamp(end) - pd.Timedelta(days=k)).date()
            rows.append(_hour(pid, day, 30 + 10 * (pid % 7) + (k % 3) * 5))
    first = next(iter(n_days_by_child))
    limits = [{"profileId": first, "dayOfWeek": d, "dailyLimitMinutes": 45, "isActive": True, "isGradual": False}
              for d in range(7)]
    feedback = [{"profileId": first, "rule": "night", "category": "all", "dayType": "school",
                 "feedback": "ALLOWED_ONCE", "feedbackAt": "2026-11-18T15:00:00.000Z"}]
    return [{"profileIds": list(n_days_by_child), "nextAfterProfileId": None, "hourly": rows, "limits": limits,
             "extRequests": [], "alertFeedback": feedback,
             "profiles": [{"profileId": p, "ageGroup": "6-10"} for p in n_days_by_child]}]


class FakeM1:
    def predict_minutes(self, df):
        return df["mean7"].to_numpy() + 1.0  # luôn lệch 1 phút so với MA7

    def predict_over_limit(self, df):
        return np.full(len(df), 0.9)


class FakeM2:
    def flag(self, days):
        return (days["date"].dt.dayofweek == 0).to_numpy()  # mỗi thứ Hai là "bất thường"


def test_m1_compares_bundle_with_ma7_per_child_and_skips_short_history():
    data = to_frames(_pages({1: 21, 2: 21, 3: 5}))
    per_child, summary = real_eval.m1_eval(data, bundle=FakeM1(), calendar=CAL, categories=CATS)

    assert set(per_child["profileId"]) == {1, 2}  # trẻ 3 chưa đủ 7 ngày lịch sử
    assert summary["số trẻ"] == 2
    assert (per_child["số ngày"] > 0).all()
    assert summary["% ngày p ≥ 0,8"] == 100.0  # chỉ trẻ 1 có giới hạn, FakeM1 luôn 0,9


def test_m2_counts_alerts_per_child_week_only_after_14_days():
    data = to_frames(_pages({1: 28, 2: 10}))
    per_child = real_eval.m2_eval(data, bundle=FakeM2(), calendar=CAL, categories=CATS)

    assert set(per_child["profileId"]) == {1}  # trẻ 2 chưa đủ 14 ngày
    assert 0.5 <= per_child["cảnh báo/tuần"].iloc[0] <= 1.5  # ~1 thứ Hai mỗi tuần


def test_report_is_anonymous_and_lists_feedback():
    data = to_frames(_pages({98761: 21, 87652: 21}))  # mã không thể trùng ngày tháng/số liệu trong báo cáo
    text = real_eval.report(data, m1=FakeM1(), m2=FakeM2(), calendar=CAL, categories=CATS)

    assert "98761" not in text and "87652" not in text
    assert "trẻ 1" in text and "trẻ 2" in text
    assert "ALLOWED_ONCE" in text


def test_pages_snapshot_roundtrip(tmp_path):
    pages = _pages({1: 3})
    path = tmp_path / "snap.json"
    real_eval.save_pages(pages, path)
    assert real_eval.load_pages(path) == pages
