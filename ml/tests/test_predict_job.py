import numpy as np
import pandas as pd
import pytest

from features import Calendar, load_categories
from jobs.load import ApiError, to_frames
from jobs.predict import RESULTS_BATCH, build_predictions, push_results
from models.m1 import bundle as m1_bundle

CAL = Calendar.load()
CATS = load_categories()
NOW = pd.Timestamp("2026-10-20 14:05", tz="UTC")  # 21:05 giờ VN ngày 20/10 → dự đoán cho 21/10


def hour_row(pid, vn_local, minutes, pkg="com.google.android.youtube"):
    ts = (pd.Timestamp(vn_local) - pd.Timedelta(hours=7)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return {"profileId": pid, "packageName": pkg, "hourStart": ts, "usageSeconds": int(minutes * 60), "launchCount": 1}


def days_of_usage(pid, n, last="2026-10-20", minutes=40):
    end = pd.Timestamp(last)
    return [hour_row(pid, f"{(end - pd.Timedelta(days=k)).date()} 19:00", minutes) for k in range(n)]


def limit_rows(pid, minutes=120):
    return [{"profileId": pid, "dayOfWeek": d, "dailyLimitMinutes": minutes, "isActive": True, "isGradual": False}
            for d in range(7)]


def data_for(pids, rows, limits=()):
    return to_frames([{"profileIds": pids, "nextAfterProfileId": None, "hourly": rows, "limits": list(limits),
                       "extRequests": [], "alertFeedback": []}])


class FakeBundle:
    """Dự đoán cố định để test phần ghép dữ liệu, không phụ thuộc mô hình."""

    def predict_minutes(self, df):
        return np.full(len(df), 95.0)

    def predict_over_limit(self, df):
        return np.full(len(df), 0.42)


def run(data, bundle=None):
    return build_predictions(data, now=NOW, calendar=CAL, categories=CATS, bundle=bundle or FakeBundle())


def test_du_doan_cho_ngay_mai_kem_xac_suat_khi_co_gioi_han():
    preds, report = run(data_for([1], days_of_usage(1, 14), limit_rows(1, 120)))

    assert report == {"processed": 1, "skipped": [], "errors": []}
    assert preds == [{"profileId": 1, "date": "2026-10-21", "predictedMinutes": 95.0,
                      "pOverLimit": 0.42, "limitMinutes": 120}]


def test_khong_co_gioi_han_thi_khong_gui_xac_suat():
    [p], _ = run(data_for([1], days_of_usage(1, 14)))

    assert p["pOverLimit"] is None and p["limitMinutes"] is None


def test_bo_qua_tre_chua_du_7_ngay_lich_su_hoac_khong_co_du_lieu_hom_nay():
    rows = days_of_usage(1, 5) + days_of_usage(2, 14, last="2026-10-18") + days_of_usage(3, 14)
    preds, report = run(data_for([1, 2, 3, 4], rows))

    assert [p["profileId"] for p in preds] == [3]
    assert sorted(report["skipped"]) == [1, 2, 4]


def test_goi_m1_that_chay_duoc_tren_du_lieu_dang_production():
    rows = days_of_usage(1, 21) + [hour_row(1, "2026-10-20 08:00", 30, pkg="com.whatsapp")]
    [p], report = run(data_for([1], rows, limit_rows(1, 60)), bundle=m1_bundle.load())

    assert report["errors"] == []
    assert 0 <= p["predictedMinutes"] < 24 * 60
    assert 0 <= p["pOverLimit"] <= 1


def test_gui_ket_qua_theo_lo_va_cong_don_tom_tat():
    calls = []

    def fake_post(url, headers, body):
        calls.append((url, headers, body))
        n = len(body["predictions"])
        return 200, {"data": {"predictions": n, "alertsCreated": 1, "alertDuplicates": 0, "unknownProfiles": 0}}

    preds = [{"profileId": i, "date": "2026-10-21", "predictedMinutes": 1.0} for i in range(RESULTS_BATCH + 3)]
    summary = push_results("https://x.test/", "s3cret", preds, "v1", post_json=fake_post)

    assert [len(c[2]["predictions"]) for c in calls] == [RESULTS_BATCH, 3]
    assert calls[0][0] == "https://x.test/api/cron/behavior-results"
    assert calls[0][1] == {"Authorization": "Bearer s3cret"}
    assert all(c[2]["modelVersion"] == "v1" for c in calls)
    assert summary == {"predictions": RESULTS_BATCH + 3, "alertsCreated": 2, "alertDuplicates": 0, "unknownProfiles": 0}


def test_backend_tra_loi_thi_bao_loi_ro_rang():
    def fake_post(url, headers, body):
        return 400, {"message": "predictions must be an array"}

    with pytest.raises(ApiError, match="400"):
        push_results("https://x.test", "s", [{"profileId": 1}], "v1", post_json=fake_post)


def test_khong_co_du_doan_thi_khong_goi_backend():
    def fake_post(url, headers, body):
        raise AssertionError("không được gọi")

    assert push_results("https://x.test", "s", [], "v1", post_json=fake_post)["predictions"] == 0


def test_github_chay_tre_luc_4h_sang_van_du_doan_cho_dung_ngay_mai():
    late = pd.Timestamp("2026-10-20 21:00", tz="UTC")  # 04:00 VN ngày 21/10
    preds, report = build_predictions(data_for([1], days_of_usage(1, 14), limit_rows(1, 120)),
                                      now=late, calendar=CAL, categories=CATS, bundle=FakeBundle())

    assert report["skipped"] == []
    assert [p["date"] for p in preds] == ["2026-10-21"]
