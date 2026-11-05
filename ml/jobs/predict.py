"""Dự đoán M1 cho ngày mai và gửi lên backend (T7.3.1).

Tác vụ chạy 21:05 giờ VN: bảng đặc trưng ngày dựng từ dữ liệu thật (cùng build_daily_features với lúc huấn
luyện), lấy dòng của HÔM NAY (target_date = ngày mai), cho gói M1 đã đóng gói (T7.1.4) dự đoán.
Server tự tạo cảnh báo khi pOverLimit ≥ 0,6 và dựng câu tiếng Việt — tác vụ chỉ gửi số liệu.
"""

from typing import Callable

import numpy as np
import pandas as pd

from features import Calendar, build_daily_features
from jobs.baseline import vn_today
from jobs.load import ApiError, ThesisData, http_json
from models.m1.bundle import BundleError

MIN_HISTORY_DAYS = 7  # = evaluate.MIN_HISTORY_DAYS: ít hơn thì lúc đánh giá cũng không chấm
RESULTS_BATCH = 500  # = MAX_PREDICTIONS ở backend/src/controllers/behaviorResultsController.js
SUMMARY_KEYS = ("predictions", "alertsCreated", "alertDuplicates", "unknownProfiles")

PostJson = Callable[[str, dict, dict], tuple[int, dict]]


def http_post_json(url: str, headers: dict, body: dict) -> tuple[int, dict]:
    return http_json(url, headers, method="POST", body=body)


def build_predictions(data: ThesisData, *, now: pd.Timestamp, calendar: Calendar, categories: dict[str, str],
                      bundle) -> tuple[list[dict], dict]:
    """Trả (danh sách dự đoán để POST, báo cáo processed/skipped/errors)."""
    report = {"processed": 0, "skipped": [], "errors": []}
    today = vn_today(now)
    daily = build_daily_features(data.hourly, calendar=calendar, categories=categories,
                                 limits=data.limits, ext_requests=data.ext_requests)
    rows = daily[(daily["date"] == today) & (daily["history_days"] >= MIN_HISTORY_DAYS)] if not daily.empty else daily
    if not rows.empty:
        rows = rows[(rows["mean7"] > 0) | rows["y_lag1"].notna()]

    ready = set(rows["profileId"]) if not rows.empty else set()
    report["skipped"] = [pid for pid in data.profile_ids if pid not in ready]
    if rows.empty:
        return [], report

    try:
        minutes = bundle.predict_minutes(rows)
        p_over = bundle.predict_over_limit(rows)
    except BundleError as err:
        report["errors"] = [{"profileId": int(pid), "error": str(err)} for pid in rows["profileId"]]
        return [], report

    target = (today + pd.Timedelta(days=1)).date().isoformat()
    predictions = []
    for row, mins, p in zip(rows.itertuples(), minutes, p_over):
        has_limit = bool(row.has_limit)
        predictions.append({
            "profileId": int(row.profileId),
            "date": target,
            "predictedMinutes": round(float(mins), 1),
            "pOverLimit": round(float(p), 4) if has_limit and np.isfinite(p) else None,
            "limitMinutes": int(row.limit_tomorrow) if has_limit else None,
        })
    report["processed"] = len(predictions)
    return predictions, report


def push_results(base_url: str, secret: str, predictions: list[dict], model_version: str, *,
                 post_json: PostJson = http_post_json) -> dict:
    """POST /api/cron/behavior-results theo lô; trả tóm tắt cộng dồn từ backend."""
    url = f"{base_url.rstrip('/')}/api/cron/behavior-results"
    headers = {"Authorization": f"Bearer {secret}"}
    summary = dict.fromkeys(SUMMARY_KEYS, 0)
    for i in range(0, len(predictions), RESULTS_BATCH):
        body = {"modelVersion": model_version, "predictions": predictions[i:i + RESULTS_BATCH]}
        status, resp = post_json(url, headers, body)
        if status != 200:
            raise ApiError(f"behavior-results trả {status}: {resp.get('message') or resp.get('code') or resp}")
        for key in SUMMARY_KEYS:
            summary[key] += resp["data"].get(key, 0)
    return summary
