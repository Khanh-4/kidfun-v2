"""Dự đoán M1 cho ngày mai và gửi lên backend (T7.3.1).

Tác vụ chạy 21:05 giờ VN: bảng đặc trưng ngày dựng từ dữ liệu thật (cùng build_daily_features với lúc huấn
luyện), lấy dòng của HÔM NAY (target_date = ngày mai), cho gói M1 đã đóng gói (T7.1.4) dự đoán.
Server tự tạo cảnh báo khi pOverLimit ≥ 0,6 và dựng câu tiếng Việt — tác vụ chỉ gửi số liệu.
"""

from typing import Callable

import numpy as np
import pandas as pd

from features import Calendar, build_daily_features
from features.common import VN_OFFSET, to_vn
from jobs.baseline import task_day
from jobs.load import ApiError, ThesisData, http_json
from models.m1.bundle import BundleError

MIN_HISTORY_DAYS = 7  # = evaluate.MIN_HISTORY_DAYS: ít hơn thì lúc đánh giá cũng không chấm
IDLE_GRACE_DAYS = 1  # ngày cuối có dữ liệu = hôm qua → hôm nay coi là 0 phút (xem pad_idle_today)
IDLE_PACKAGE = "kidfun.idle_day"  # gói giả cho dòng 0 giây; không có trong app_categories → nhóm "other"
RESULTS_BATCH = 500  # = MAX_PREDICTIONS ở backend/src/controllers/behaviorResultsController.js
SUMMARY_KEYS = ("predictions", "alertsCreated", "alertDuplicates", "unknownProfiles")

PostJson = Callable[[str, dict, dict], tuple[int, dict]]


def http_post_json(url: str, headers: dict, body: dict) -> tuple[int, dict]:
    return http_json(url, headers, method="POST", body=body)


def pad_idle_today(hourly: pd.DataFrame, today: pd.Timestamp) -> pd.DataFrame:
    """Máy trẻ chỉ gửi những giờ có dùng, nên ngày không dùng máy không có dòng nào → bảng đặc trưng dừng ở
    ngày cuối có dữ liệu và trẻ bị bỏ qua. Nếu HÔM QUA trẻ còn dữ liệu thì coi hôm nay là 0 phút (thêm một dòng
    0 giây lúc 12:00 VN). Trống từ hai ngày liền trở lên thì vẫn bỏ qua: nhiều khả năng máy tắt / gỡ app."""
    if hourly.empty:
        return hourly
    last_day = to_vn(hourly["hourStart"]).dt.normalize().groupby(hourly["profileId"]).max()
    idle = last_day.index[last_day == today - pd.Timedelta(days=IDLE_GRACE_DAYS)]
    if idle.empty:
        return hourly
    noon_utc = (today + pd.Timedelta(hours=12) - VN_OFFSET).tz_localize("UTC")
    pad = pd.DataFrame({
        "profileId": idle.astype("int64"),
        "packageName": IDLE_PACKAGE,
        "hourStart": noon_utc,
        "usageSeconds": 0,
        "launchCount": 0,
    })
    return pd.concat([hourly, pad.astype(hourly.dtypes[pad.columns].to_dict())], ignore_index=True)


def build_predictions(data: ThesisData, *, now: pd.Timestamp, calendar: Calendar, categories: dict[str, str],
                      bundle) -> tuple[list[dict], dict]:
    """Trả (danh sách dự đoán để POST, báo cáo processed/skipped/errors)."""
    report = {"processed": 0, "skipped": [], "errors": []}
    today = task_day(now)
    hourly = pad_idle_today(data.hourly, today)
    daily = build_daily_features(hourly, calendar=calendar, categories=categories,
                                 limits=data.limits, ext_requests=data.ext_requests)
    rows = daily[(daily["date"] == today) & (daily["history_days"] >= MIN_HISTORY_DAYS)] if not daily.empty else daily
    if not rows.empty:
        rows = rows[(rows["mean7"] > 0) | rows["y_lag1"].notna()]

    ready = set(rows["profileId"]) if not rows.empty else set()
    report["skipped"] = [pid for pid in data.profile_ids if pid not in ready]
    if rows.empty:
        return [], report

    # Nhóm tuổi từ thesis-data (tính từ ngày sinh). Trẻ chưa có ngày sinh → để trống, gói M1 coi tuổi là thiếu
    # như trước 11/11 — lúc huấn luyện mô hình có dùng tuổi, thiếu thì kém chính xác hơn (T7.1.4).
    ages = data.profiles.set_index("profileId")["ageGroup"]
    rows = rows.assign(ageGroup=rows["profileId"].map(ages))

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
