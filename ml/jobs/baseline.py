"""Tính mức thường ngày cho luật tầng 1 trên máy trẻ (T7.1.3) và gửi lên backend.

Tác vụ chạy 21:05 giờ VN nên baseline phục vụ NGÀY MAI: mức thường ngày lấy từ các ngày đã trọn vẹn
(bỏ phần hôm nay còn dở), JSON đúng schema `Tier1Rules.kt` đọc (xem ml/tier1/rules.py).

    CRON_SECRET=... .venv/bin/python -m jobs.baseline --url https://kidfun-backend.vercel.app          # chỉ tính
    CRON_SECRET=... .venv/bin/python -m jobs.baseline --url https://kidfun-backend.vercel.app --push   # tính + gửi
"""

import argparse
import json
import os
import sys
from typing import Callable

import pandas as pd

from features import Calendar, build_hourly_features, load_categories
from features.common import VN_OFFSET
from jobs.load import ApiError, ThesisData, http_json, load_thesis_data
from tier1.rules import DEFAULT_RULES, build_baseline, relax

MIN_BASELINE_DAYS = 7  # ít ngày hơn thì mức thường ngày chưa đáng tin → bỏ qua trẻ đó
MAX_PAYLOAD_BYTES = 64 * 1024  # = MAX_BASELINE_BYTES ở backend/src/controllers/behaviorAlertController.js
PUT_BATCH = 50  # = MAX_BASELINES ở backend

# (url, headers, body) -> (HTTP status, body JSON). Truyền vào được để test không cần mạng.
PutJson = Callable[[str, dict, dict], tuple[int, dict]]


def http_put_json(url: str, headers: dict, body: dict) -> tuple[int, dict]:
    return http_json(url, headers, method="PUT", body=body)


def vn_today(now: pd.Timestamp) -> pd.Timestamp:
    """Ngày hôm nay theo giờ VN, dạng naive 00:00 — cùng kiểu cột `date` của build_hourly_features."""
    return (now.tz_convert("UTC").tz_localize(None) + VN_OFFSET).normalize()


TIER1_RULES = ("night", "spike")
OVERRIDE_KEYS = ("nightMinByDayType", "spikeRatioByKey")


def overrides_from_feedback(feedback: pd.DataFrame) -> dict:
    """Áp relax() lần lượt theo thời gian cho mọi lần phụ huynh bấm "được phép" của MỘT trẻ.

    Tính lại từ đầu mỗi đêm (relax tối đa MAX_RELAX lần mỗi khoá) nên không cần lưu bộ đếm ở đâu cả.
    Trả về chỉ phần ngưỡng riêng theo loại ngày / nhóm app, để build_baseline gộp với DEFAULT_RULES.
    """
    rules, counts = dict(DEFAULT_RULES), {}
    usable = feedback[feedback["rule"].isin(TIER1_RULES) & feedback["dayType"].notna()]
    for row in usable.sort_values("feedbackAt").itertuples():
        rules, counts = relax(rules, counts, row.rule, row.dayType, row.category)
    return {k: rules[k] for k in OVERRIDE_KEYS if k in rules}


def build_baselines(data: ThesisData, *, now: pd.Timestamp, calendar: Calendar,
                    categories: dict[str, str]) -> tuple[list[dict], dict]:
    """Trả (danh sách {profileId, payload, validUntil} để PUT, báo cáo processed/skipped/errors)."""
    today = vn_today(now)
    as_of = today + pd.Timedelta(days=1)
    hours = build_hourly_features(data.hourly, calendar=calendar, categories=categories)
    if not hours.empty:
        hours = hours[hours["date"] < today]

    baselines, report = [], {"processed": 0, "skipped": [], "errors": []}
    for pid in data.profile_ids:
        mine = hours[hours["profileId"] == pid] if not hours.empty else hours
        if mine.empty or mine["date"].nunique() < MIN_BASELINE_DAYS:
            report["skipped"].append(pid)
            continue
        overrides = overrides_from_feedback(data.alert_feedback[data.alert_feedback["profileId"] == pid])
        payload = build_baseline(mine, pid, as_of, overrides=overrides, calendar=calendar, categories=categories)
        size = len(json.dumps(payload))
        if size > MAX_PAYLOAD_BYTES:
            report["errors"].append({"profileId": pid, "error": f"payload {size} byte > {MAX_PAYLOAD_BYTES}"})
            continue
        baselines.append({"profileId": int(pid), "payload": payload, "validUntil": payload["validUntil"]})
        report["processed"] += 1
    return baselines, report


def push_baselines(base_url: str, secret: str, baselines: list[dict], *,
                   put_json: PutJson = http_put_json) -> int:
    """PUT /api/cron/behavior-baselines theo lô; trả tổng số baseline backend đã lưu."""
    url = f"{base_url.rstrip('/')}/api/cron/behavior-baselines"
    headers = {"Authorization": f"Bearer {secret}"}
    saved = 0
    for i in range(0, len(baselines), PUT_BATCH):
        status, body = put_json(url, headers, {"baselines": baselines[i:i + PUT_BATCH]})
        if status != 200:
            raise ApiError(f"behavior-baselines trả {status}: {body.get('message') or body.get('code') or body}")
        saved += body["data"]["saved"]
    return saved


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Tính (và gửi) mức thường ngày cho luật tầng 1.")
    ap.add_argument("--url", default=os.environ.get("THESIS_API_URL"), help="URL backend (hoặc env THESIS_API_URL)")
    ap.add_argument("--push", action="store_true", help="gửi lên backend (mặc định chỉ tính và in báo cáo)")
    args = ap.parse_args(argv)

    secret = os.environ.get("CRON_SECRET")
    if not args.url or not secret:
        print("Thiếu --url/THESIS_API_URL hoặc env CRON_SECRET", file=sys.stderr)
        return 2

    data = load_thesis_data(args.url, secret, log=print)
    baselines, report = build_baselines(data, now=pd.Timestamp.now(tz="UTC"),
                                        calendar=Calendar.load(), categories=load_categories())
    print(f"baseline: {report['processed']} trẻ đã tính | bỏ qua (< {MIN_BASELINE_DAYS} ngày dữ liệu): "
          f"{len(report['skipped'])} | lỗi: {len(report['errors'])}")
    for err in report["errors"]:
        print(f"  lỗi profileId {err['profileId']}: {err['error']}", file=sys.stderr)
    if args.push:
        print(f"đã lưu {push_baselines(args.url, secret, baselines)} baseline lên backend")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
