import pandas as pd

from features import Calendar, load_categories
from jobs.insights import MIN_CLUSTER_CHILDREN, build_insights, push_insights
from jobs.load import to_frames

CAL = Calendar.load()
CATS = load_categories()
NOW = pd.Timestamp("2026-10-20 14:05", tz="UTC")  # 21:05 VN ngày 20/10


def hour_row(pid, vn_local, minutes, pkg="com.google.android.youtube"):
    ts = (pd.Timestamp(vn_local) - pd.Timedelta(hours=7)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return {"profileId": pid, "packageName": pkg, "hourStart": ts, "usageSeconds": int(minutes * 60), "launchCount": 1}


def days_of(pid, n, hour=19, minutes=40, pkg="com.google.android.youtube", last="2026-10-20"):
    end = pd.Timestamp(last)
    return [hour_row(pid, f"{(end - pd.Timedelta(days=k)).date()} {hour:02d}:00", minutes, pkg) for k in range(n)]


def data_for(pids, rows, limits=(), ages=None):
    profiles = [{"profileId": p, "ageGroup": (ages or {}).get(p)} for p in pids]
    return to_frames([{"profileIds": pids, "nextAfterProfileId": None, "profiles": profiles, "hourly": rows,
                       "limits": list(limits), "extRequests": [], "alertFeedback": []}])


def run(data):
    return build_insights(data, now=NOW, calendar=CAL, categories=CATS)


def test_bo_qua_tre_chua_du_7_ngay():
    insights, report = run(data_for([1, 2], days_of(1, 14) + days_of(2, 3)))

    assert [i["profileId"] for i in insights] == [1]
    assert report["skipped"] == [2]


def test_mot_tre_thi_chua_so_sanh_duoc_nhung_van_co_goi_y():
    [i], _ = run(data_for([1], days_of(1, 14, minutes=90)))

    assert i["date"] == "2026-10-20"
    assert i["habitSummary"] is None and i["clusterId"] is None
    assert [s["code"] for s in i["suggestions"]] == ["dat_gioi_han"]  # chưa có giới hạn


def test_it_tre_thi_mo_ta_tung_tre_so_voi_cac_tre_khac_khong_phan_nhom():
    rows = days_of(1, 14, hour=23, minutes=60) + days_of(2, 14, hour=19, minutes=30) + days_of(3, 14, hour=19, minutes=20)
    insights, _ = run(data_for([1, 2, 3], rows))
    by = {i["profileId"]: i for i in insights}

    assert "hay dùng khuya" in by[1]["habitSummary"]
    assert all(i["clusterId"] is None for i in insights)


def test_du_tre_thi_phan_nhom_k_means():
    n = MIN_CLUSTER_CHILDREN + 2
    rows = []
    for pid in range(1, n + 1):
        night = pid % 2 == 0
        rows += days_of(pid, 14, hour=23 if night else 18, minutes=30 + 10 * pid,
                        pkg="com.roblox.client" if night else "com.google.android.youtube")
    insights, report = run(data_for(list(range(1, n + 1)), rows))

    assert report["processed"] == n and report["clusters"] >= 2
    assert all(i["clusterId"] is not None and i["clusterCount"] == report["clusters"] for i in insights)
    assert all(i["habitSummary"] for i in insights)


def test_goi_y_gio_ngu_theo_nhom_tuoi():
    rows = days_of(1, 14, hour=22, minutes=30)  # 22h: muộn với trẻ 6–10, chưa muộn với trẻ lớn
    young, _ = run(data_for([1], rows, ages={1: "6-10"}))
    older, _ = run(data_for([1], rows, ages={1: "15-17"}))

    assert "gio_ngu" in [s["code"] for s in young[0]["suggestions"]]
    assert "gio_ngu" not in [s["code"] for s in older[0]["suggestions"]]


def test_push_theo_lo_va_cong_don():
    calls = []

    def fake_put(url, headers, body):
        calls.append(body)
        return 200, {"data": {"saved": len(body["insights"]), "unknownProfiles": 0}}

    items = [{"profileId": p, "date": "2026-10-20", "suggestions": []} for p in range(1, 4)]
    summary = push_insights("https://x", "s", items, "m3m4@test", put_json=fake_put, batch=2)

    assert [len(c["insights"]) for c in calls] == [2, 1]
    assert summary == {"saved": 3, "unknownProfiles": 0}
