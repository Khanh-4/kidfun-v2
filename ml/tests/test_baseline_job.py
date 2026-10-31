import json

import pandas as pd
import pytest

from features import Calendar, load_categories
from jobs.baseline import MAX_PAYLOAD_BYTES, PUT_BATCH, build_baselines, push_baselines
from jobs.load import ApiError, to_frames

CAL = Calendar.load()
CATS = load_categories()
NOW = pd.Timestamp("2026-10-20 14:05", tz="UTC")  # 21:05 giờ VN ngày 20/10, giờ chạy tác vụ


def hour_row(pid, vn_local, minutes, pkg="com.google.android.youtube"):
    ts = (pd.Timestamp(vn_local) - pd.Timedelta(hours=7)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return {"profileId": pid, "packageName": pkg, "hourStart": ts, "usageSeconds": int(minutes * 60), "launchCount": 1}


def data_for(pids, rows):
    return to_frames([{"profileIds": pids, "nextAfterProfileId": None, "hourly": rows, "limits": [], "extRequests": []}])


def days_of_usage(pid, n, last="2026-10-19", minutes=40):
    """n ngày liền nhau tới `last`, mỗi ngày 19:00 VN xem YouTube `minutes` phút."""
    end = pd.Timestamp(last)
    return [hour_row(pid, f"{(end - pd.Timedelta(days=k)).date()} 19:00", minutes) for k in range(n)]


def test_tinh_baseline_cho_ngay_mai_khop_schema_tier1_kotlin():
    data = data_for([1], days_of_usage(1, 14))

    baselines, report = build_baselines(data, now=NOW, calendar=CAL, categories=CATS)

    assert report == {"processed": 1, "skipped": [], "errors": []}
    [b] = baselines
    p = b["payload"]
    assert b["profileId"] == 1 and p["profileId"] == 1
    # tác vụ chạy 21:05 ngày 20/10 → baseline phục vụ ngày 21/10, hết hạn đầu ngày 22/10
    assert b["validUntil"] == p["validUntil"] == "2026-10-22T00:00:00+07:00"
    # Những gì Tier1Rules.kt đọc: baseline[] (dayType, hour, cat, mean), rules số, categories, dayTypes
    assert p["nightWindow"] == ["22:00", "06:00"]
    for e in p["baseline"]:
        assert isinstance(e["dayType"], str) and isinstance(e["hour"], int)
        assert isinstance(e["cat"], str) and isinstance(e["mean"], float)
    for key in ("nightMinMinutes", "nightUsualMaxMinutes", "spikeRatio", "spikeMinMinutes"):
        assert isinstance(p["rules"][key], (int, float))
    assert p["categories"]["com.google.android.youtube"] == "video"
    assert set(p["dayTypes"]) == {"2026-10-20", "2026-10-21", "2026-10-22"}
    assert set(p["dayTypes"].values()) <= {"school", "weekend", "off"}
    json.dumps(b)  # gửi được qua HTTP


def test_mean_tinh_tren_ngay_tron_ven_bo_phan_hom_nay_dang_do():
    rows = days_of_usage(1, 14) + [hour_row(1, "2026-10-20 19:00", 200)]  # hôm nay dùng bất thường
    [b], _ = build_baselines(data_for([1], rows), now=NOW, calendar=CAL, categories=CATS)

    means = {e["mean"] for e in b["payload"]["baseline"] if e["hour"] == 19 and e["cat"] == "video"}
    assert means and max(means) == 40.0


def test_bo_qua_tre_it_hon_7_ngay_du_lieu_va_tre_khong_co_du_lieu():
    data = data_for([1, 2, 3], days_of_usage(1, 14) + days_of_usage(2, 3))

    baselines, report = build_baselines(data, now=NOW, calendar=CAL, categories=CATS)

    assert [b["profileId"] for b in baselines] == [1]
    assert report["processed"] == 1
    assert sorted(report["skipped"]) == [2, 3]


def test_payload_qua_64kb_thi_bao_loi_khong_gui(monkeypatch):
    monkeypatch.setattr("jobs.baseline.MAX_PAYLOAD_BYTES", 100)

    baselines, report = build_baselines(data_for([1], days_of_usage(1, 14)), now=NOW, calendar=CAL, categories=CATS)

    assert baselines == []
    assert report["errors"] and report["errors"][0]["profileId"] == 1
    assert MAX_PAYLOAD_BYTES == 64 * 1024  # khớp MAX_BASELINE_BYTES ở backend


class FakePut:
    def __init__(self, status=200):
        self.status, self.calls = status, []

    def __call__(self, url, headers, body):
        assert headers["Authorization"] == "Bearer s3cret"
        self.calls.append((url, body))
        n = len(body["baselines"])
        return self.status, {"success": True, "data": {"saved": n, "unknownProfiles": 0}}


def test_push_chia_lo_50_tre_moi_lan():
    baselines = [{"profileId": i, "payload": {}, "validUntil": "2026-10-22T00:00:00+07:00"} for i in range(1, 121)]
    put = FakePut()

    saved = push_baselines("https://api.test/", "s3cret", baselines, put_json=put)

    assert PUT_BATCH == 50
    assert [len(b["baselines"]) for _, b in put.calls] == [50, 50, 20]
    assert put.calls[0][0] == "https://api.test/api/cron/behavior-baselines"
    assert saved == 120


def test_push_loi_thi_bao_ApiError():
    with pytest.raises(ApiError, match="401"):
        push_baselines("https://api.test", "s3cret", [{"profileId": 1, "payload": {}, "validUntil": "x"}],
                       put_json=FakePut(status=401))


def test_push_danh_sach_rong_thi_khong_goi_api():
    put = FakePut()
    assert push_baselines("https://api.test", "s3cret", [], put_json=put) == 0
    assert put.calls == []
