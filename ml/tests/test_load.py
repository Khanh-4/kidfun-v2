import pandas as pd
import pytest

from features import Calendar, build_daily_features, load_categories
from jobs.load import ApiError, fetch_pages, load_thesis_data, to_frames


def page(pids, nxt, hourly=(), limits=(), ext=()):
    return {
        "success": True,
        "data": {
            "since": "2026-10-03T00:00:00.000Z",
            "profileIds": list(pids),
            "nextAfterProfileId": nxt,
            "hourly": list(hourly),
            "limits": list(limits),
            "extRequests": list(ext),
        },
    }


def hour_row(pid, ts, minutes, pkg="com.google.android.youtube"):
    return {"profileId": pid, "packageName": pkg, "hourStart": ts, "usageSeconds": minutes * 60, "launchCount": 2}


class FakeApi:
    """Trả lần lượt các (status, body) đã xếp sẵn; ghi lại URL đã gọi."""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.urls = []

    def __call__(self, url, headers):
        assert headers["Authorization"] == "Bearer s3cret"
        self.urls.append(url)
        return self.responses.pop(0)


def test_lap_qua_cac_trang_theo_nextAfterProfileId():
    api = FakeApi((200, page([1, 2], 2)), (200, page([3], None)))

    pages = fetch_pages("https://api.test", "s3cret", days=14, limit=2, get_json=api)

    assert len(pages) == 2
    assert "days=14" in api.urls[0] and "limit=2" in api.urls[0] and "afterProfileId=0" in api.urls[0]
    assert "afterProfileId=2" in api.urls[1]


def test_gap_413_thi_giam_limit_mot_nua_va_goi_lai_cung_trang():
    api = FakeApi((413, {"code": "PAGE_TOO_LARGE"}), (200, page([1, 2], None)))

    fetch_pages("https://api.test", "s3cret", limit=8, get_json=api)

    assert "limit=8" in api.urls[0]
    assert "limit=4" in api.urls[1] and "afterProfileId=0" in api.urls[1]


def test_413_khi_limit_da_la_1_thi_bao_loi():
    api = FakeApi((413, {"code": "PAGE_TOO_LARGE"}))

    with pytest.raises(ApiError, match="413"):
        fetch_pages("https://api.test", "s3cret", limit=1, get_json=api)


def test_sai_secret_bao_loi_ro_rang():
    api = FakeApi((401, {"success": False, "message": "Unauthorized"}))

    with pytest.raises(ApiError, match="401.*Unauthorized"):
        fetch_pages("https://api.test", "s3cret", get_json=api)


def test_to_frames_dung_kieu_cot_ml_features_can():
    pages = [
        page(
            [1],
            None,
            hourly=[hour_row(1, "2026-10-05T03:00:00.000Z", 30)],
            limits=[{"profileId": 1, "dayOfWeek": 1, "dailyLimitMinutes": 90, "isActive": True, "isGradual": False}],
            ext=[{"profileId": 1, "createdAt": "2026-10-05T12:00:00.000Z", "requestMinutes": 15, "status": "APPROVED"}],
        )["data"]
    ]

    data = to_frames(pages)

    assert data.profile_ids == [1]
    assert list(data.hourly.columns) == ["profileId", "packageName", "hourStart", "usageSeconds", "launchCount"]
    assert data.hourly["hourStart"].iloc[0] == pd.Timestamp("2026-10-05 03:00", tz="UTC")
    assert data.ext_requests["createdAt"].dt.tz is not None
    assert data.limits["isActive"].dtype == bool


def test_to_frames_doc_alertFeedback_va_chiu_duoc_backend_cu_chua_tra():
    fb = {"profileId": 1, "rule": "spike", "category": "game", "dayType": "weekend",
          "feedback": "ALLOWED_WEEKEND", "feedbackAt": "2026-10-05T12:00:00.000Z"}
    with_fb = {**page([1], None)["data"], "alertFeedback": [fb]}

    data = to_frames([with_fb])
    assert data.alert_feedback.iloc[0]["rule"] == "spike"
    assert data.alert_feedback["feedbackAt"].dt.tz is not None

    old_backend = page([1], None)["data"]  # chưa có khoá alertFeedback
    assert to_frames([old_backend]).alert_feedback.empty


def test_khong_co_du_lieu_van_tra_frame_rong_du_cot():
    data = to_frames([page([], None)["data"]])

    assert data.hourly.empty and "hourStart" in data.hourly.columns
    assert data.limits.empty and "dailyLimitMinutes" in data.limits.columns
    assert data.ext_requests.empty and "requestMinutes" in data.ext_requests.columns


def test_ket_qua_dua_thang_vao_build_daily_features():
    rows = [hour_row(1, f"2026-10-{d:02d}T03:00:00.000Z", 20 + d) for d in range(1, 12)]
    api = FakeApi((200, page([1], None, hourly=rows,
                             limits=[{"profileId": 1, "dayOfWeek": d, "dailyLimitMinutes": 60,
                                      "isActive": True, "isGradual": False} for d in range(7)])))

    data = load_thesis_data("https://api.test", "s3cret", get_json=api)
    df = build_daily_features(data.hourly, calendar=Calendar.load(), categories=load_categories(),
                              limits=data.limits, ext_requests=data.ext_requests)

    assert len(df) == 11
    assert (df["profileId"] == 1).all()
    assert df["limit_tomorrow"].eq(60).all()
