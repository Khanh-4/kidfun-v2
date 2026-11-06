"""Chấm M2 tầng 2 mức ngày (DBSCAN) cho NGÀY HÔM QUA và gửi cảnh báo lên backend (T7.3.2).

Tác vụ chạy 21:05 giờ VN; hôm nay chưa hết ngày nên chấm hôm qua (đủ 24 giờ). Chỉ trẻ có ≥ 14 ngày dữ liệu:
ít hơn thì mức thường ngày (day_ratio) chưa đại diện cho thói quen của trẻ.
Câu giải thích do explain_day dựng (cùng câu lúc đánh giá ở docs/thesis/08), đổi "Hôm nay" → "Hôm qua".
"""

import numpy as np
import pandas as pd

from features import Calendar, build_day_anomaly_features
from jobs.baseline import vn_today
from jobs.load import ApiError, ThesisData
from jobs.predict import PostJson, http_post_json
from models.explain import explain_day

MIN_HISTORY_DAYS = 14
ALERTS_BATCH = 500  # = MAX_PREDICTIONS (giới hạn số cảnh báo ngày/lần) ở behaviorResultsController.js
RULE = "day_anomaly"
SUMMARY_KEYS = ("alertsCreated", "alertDuplicates", "alertsRejected")

__all__ = ["ApiError", "build_day_alerts", "push_alerts"]


def _usual(row) -> float | None:
    ratio = row.get("day_ratio")
    if ratio is None or not np.isfinite(ratio) or ratio <= 0:
        return None
    return round(float(row["day_min"] / ratio), 1)


def _alert(row, date_iso: str) -> dict:
    kind, message = explain_day(row)
    return {
        "profileId": int(row["profileId"]),
        "rule": RULE,
        "category": kind,
        "dayType": row["day_type"],
        "date": date_iso,
        "minutes": round(float(row["day_min"]), 1),
        "usualMinutes": _usual(row),
        "message": message.replace("Hôm nay", "Hôm qua", 1),
    }


def build_day_alerts(data: ThesisData, *, now: pd.Timestamp, calendar: Calendar, categories: dict[str, str],
                     bundle) -> tuple[list[dict], dict]:
    """Trả (cảnh báo để POST, báo cáo processed/flagged/skipped)."""
    report = {"processed": 0, "flagged": 0, "skipped": list(data.profile_ids)}
    yesterday = vn_today(now) - pd.Timedelta(days=1)
    days = build_day_anomaly_features(data.hourly, calendar=calendar, categories=categories,
                                      ext_requests=data.ext_requests)
    if days.empty:
        return [], report

    upto = days[days["date"] <= yesterday]
    history = upto.groupby("profileId")["date"].nunique()
    ready = set(history[history >= MIN_HISTORY_DAYS].index)
    rows = upto[(upto["date"] == yesterday) & upto["profileId"].isin(ready)].reset_index(drop=True)
    scored = set(rows["profileId"])
    report["skipped"] = [pid for pid in data.profile_ids if pid not in scored]
    report["processed"] = len(rows)
    if rows.empty:
        return [], report

    flagged = rows[np.asarray(bundle.flag(rows), dtype=bool)]
    date_iso = yesterday.date().isoformat()
    alerts = [_alert(row, date_iso) for _, row in flagged.iterrows()]
    report["flagged"] = len(alerts)
    return alerts, report


def push_alerts(base_url: str, secret: str, alerts: list[dict], model_version: str, *,
                post_json: PostJson = http_post_json) -> dict:
    """POST /api/cron/behavior-results (predictions rỗng) theo lô; trả tóm tắt cộng dồn."""
    url = f"{base_url.rstrip('/')}/api/cron/behavior-results"
    headers = {"Authorization": f"Bearer {secret}"}
    summary = dict.fromkeys(SUMMARY_KEYS, 0)
    for i in range(0, len(alerts), ALERTS_BATCH):
        body = {"modelVersion": model_version, "predictions": [], "alerts": alerts[i:i + ALERTS_BATCH]}
        status, resp = post_json(url, headers, body)
        if status != 200:
            raise ApiError(f"behavior-results (cảnh báo ngày) trả {status}: "
                           f"{resp.get('message') or resp.get('code') or resp}")
        for key in SUMMARY_KEYS:
            summary[key] += resp["data"].get(key, 0)
    return summary
