from dataclasses import dataclass

import numpy as np
import pandas as pd
import pytest

from features import Calendar, load_categories
from jobs import anomaly
from jobs.load import ThesisData
from simulator import simulate

NOW = pd.Timestamp("2026-03-20 14:05", tz="UTC")  # 21:05 giờ VN ngày 20/03 → chấm ngày 19/03


@dataclass
class FakeBundle:
    """Đánh dấu mọi dòng (flag_all) hoặc không dòng nào."""

    flag_all: bool

    def flag(self, days):
        return np.full(len(days), self.flag_all)


def _data(days: int) -> ThesisData:
    start = (pd.Timestamp("2026-03-19") - pd.Timedelta(days=days - 1)).date().isoformat()
    s = simulate(3, start, days, seed=3)
    empty_fb = pd.DataFrame(columns=["profileId", "rule", "category", "dayType", "feedback", "feedbackAt"])
    hourly = s["app_usage_hourly"][["profileId", "packageName", "hourStart", "usageSeconds", "launchCount"]]
    ext = s["time_extension_requests"][["profileId", "createdAt", "requestMinutes", "status"]]
    return ThesisData(sorted(s["profiles"]["profileId"]), hourly, s["time_limits"], ext, empty_fb)


def _build(data, bundle):
    return anomaly.build_day_alerts(data, now=NOW, calendar=Calendar.load(), categories=load_categories(),
                                    bundle=bundle)


def test_flagged_yesterday_becomes_day_alert_with_yesterday_wording():
    data = _data(30)
    alerts, report = _build(data, FakeBundle(True))

    assert alerts, "trẻ đủ 14 ngày, mọi dòng bị đánh dấu → phải có cảnh báo"
    assert report["flagged"] == len(alerts) == report["processed"]
    for a in alerts:
        assert a["rule"] == "day_anomaly"
        assert a["date"] == "2026-03-19"
        assert a["category"] in {"danger_content", "new_app", "night_use", "binge_day", "spike"}
        assert a["dayType"] in {"school", "weekend", "off"}
        assert a["minutes"] >= 0
        assert a["message"].startswith("Hôm qua")
        assert "Hôm nay" not in a["message"]


def test_not_flagged_sends_nothing_but_counts_processed():
    alerts, report = _build(_data(30), FakeBundle(False))

    assert alerts == []
    assert report["processed"] > 0 and report["flagged"] == 0


def test_children_with_less_than_14_days_are_skipped():
    data = _data(10)
    alerts, report = _build(data, FakeBundle(True))

    assert alerts == []
    assert sorted(report["skipped"]) == data.profile_ids


def test_push_alerts_batches_with_empty_predictions():
    calls = []

    def post_json(url, headers, body):
        calls.append((url, body))
        return 200, {"data": {"alertsCreated": len(body["alerts"]), "alertDuplicates": 0, "alertsRejected": 0}}

    alerts = [{"profileId": i, "rule": "day_anomaly"} for i in range(anomaly.ALERTS_BATCH + 5)]
    summary = anomaly.push_alerts("http://x/", "s", alerts, "dbscan_day@d", post_json=post_json)

    assert len(calls) == 2
    assert calls[0][0] == "http://x/api/cron/behavior-results"
    assert calls[0][1]["predictions"] == [] and calls[0][1]["modelVersion"] == "dbscan_day@d"
    assert summary["alertsCreated"] == len(alerts)


def test_push_alerts_raises_on_http_error():
    with pytest.raises(anomaly.ApiError):
        anomaly.push_alerts("http://x", "s", [{"profileId": 1}], "v", post_json=lambda *_: (400, {"message": "bad"}))
