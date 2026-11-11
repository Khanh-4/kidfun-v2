"""Nhóm thói quen (M3) + gợi ý cho phụ huynh (M4) trong tác vụ ban đêm — đồ án chuyên ngành, T7.5.3.

Dùng lại models/m3m4.py (bản chạy trên dữ liệu mô phỏng ở tuần 6) cho dữ liệu thật 28 ngày gần nhất:
  - M3: vector thói quen mỗi trẻ → K-Means khi đủ trẻ; ít trẻ thì chỉ mô tả từng trẻ so với các trẻ khác;
  - M4: hệ luật gợi ý (giảm dần, WHO, đặt giới hạn, giờ ngủ, game) theo nhóm tuổi.
Kết quả → PUT /api/cron/habit-insights, app phụ huynh hiện ở màn AI Insights.
"""

from typing import Callable

import pandas as pd

from features import Calendar, build_hourly_features
from jobs.baseline import http_put_json, task_day
from jobs.load import ApiError, ThesisData
from models.m3m4 import WINDOW_DAYS, child_stats, cluster, habit_vectors, suggest, traits

MODEL_VERSION = "m3m4-kmeans+rules@2026-11-11"
MIN_HABIT_DAYS = 7  # = MIN_HISTORY_DAYS của M1: dưới một tuần chưa nói được "thói quen"
MIN_CLUSTER_CHILDREN = 6  # K-Means (k = 3..6) cần đủ trẻ; ít hơn thì không phân nhóm
DEFAULT_AGE = "11-14"  # trẻ chưa có ngày sinh: luật WHO (3–5 tuổi) không áp, giờ ngủ tính sau nửa đêm
PUT_BATCH = 500  # = MAX_INSIGHTS ở backend

PutJson = Callable[[str, dict, dict], tuple[int, dict]]


def _ages(data: ThesisData) -> pd.Series:
    known = data.profiles.dropna(subset=["ageGroup"]).set_index("profileId")["ageGroup"]
    return pd.Series({pid: known.get(pid, DEFAULT_AGE) for pid in data.profile_ids}, dtype=object)


def _habits(vectors: pd.DataFrame) -> tuple[dict, dict, int | None]:
    """(pid → câu mô tả, pid → nhóm, số nhóm). Một trẻ thì chưa có gì để so sánh."""
    if len(vectors) < 2:
        return {}, {}, None
    if len(vectors) < MIN_CLUSTER_CHILDREN:
        return {pid: traits(vectors, pd.Index([pid])) for pid in vectors.index}, {}, None
    labels, k, _ = cluster(vectors)
    groups = pd.Series(labels, index=vectors.index)
    summary = {c: traits(vectors, groups.index[groups == c]) for c in set(labels)}
    return ({pid: summary[c] for pid, c in groups.items()}, {pid: int(c) for pid, c in groups.items()}, k)


def build_insights(data: ThesisData, *, now: pd.Timestamp, calendar: Calendar,
                   categories: dict[str, str]) -> tuple[list[dict], dict]:
    """Trả (danh sách để PUT, báo cáo processed/skipped/clusters)."""
    today = task_day(now)
    report = {"processed": 0, "skipped": list(data.profile_ids), "clusters": None}
    hours = build_hourly_features(data.hourly, calendar=calendar, categories=categories)
    if hours.empty:
        return [], report

    window = hours[(hours["date"] > today - pd.Timedelta(days=WINDOW_DAYS)) & (hours["date"] <= today)]
    days = window.groupby("profileId")["date"].nunique()
    ready = sorted(int(p) for p in days[days >= MIN_HABIT_DAYS].index)
    report["skipped"] = [pid for pid in data.profile_ids if pid not in ready]
    if not ready:
        return [], report

    window = window[window["profileId"].isin(ready)]
    summary, groups, k = _habits(habit_vectors(window))
    ages = _ages(data)
    stats = child_stats(window, data.limits, data.ext_requests, ages, today + pd.Timedelta(days=1))
    # Tuần toàn ngày nghỉ thì không có trung vị ngày đi học → lấy mức trung bình để câu gợi ý vẫn có số.
    stats["median_school_min"] = stats["median_school_min"].fillna(stats["mean_daily_min"])

    insights = []
    for pid in ready:
        insights.append({
            "profileId": pid,
            "date": today.date().isoformat(),
            "habitSummary": summary.get(pid),
            "clusterId": groups.get(pid),
            "clusterCount": k,
            "suggestions": [{"code": c, "text": t} for c, t in suggest(stats.loc[pid], ages[pid])],
        })
    report.update(processed=len(insights), clusters=k)
    return insights, report


def push_insights(base_url: str, secret: str, insights: list[dict], model_version: str = MODEL_VERSION, *,
                  put_json: PutJson = http_put_json, batch: int = PUT_BATCH) -> dict:
    """PUT /api/cron/habit-insights theo lô; trả tóm tắt cộng dồn."""
    url = f"{base_url.rstrip('/')}/api/cron/habit-insights"
    headers = {"Authorization": f"Bearer {secret}"}
    summary = {"saved": 0, "unknownProfiles": 0}
    for i in range(0, len(insights), batch):
        status, resp = put_json(url, headers, {"modelVersion": model_version, "insights": insights[i:i + batch]})
        if status != 200:
            raise ApiError(f"habit-insights trả {status}: {resp.get('message') or resp.get('code') or resp}")
        for key in summary:
            summary[key] += resp["data"].get(key, 0)
    return summary
