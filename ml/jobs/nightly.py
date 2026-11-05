"""Tác vụ ban đêm của đồ án chuyên ngành (T7.3.1) — chạy bởi .github/workflows/thesis-nightly.yml lúc 21:05 giờ VN.

Tải dữ liệu MỘT lần qua /api/cron/thesis-data, rồi:
  1. tính mức thường ngày cho luật tầng 1 → PUT /api/cron/behavior-baselines;
  2. dự đoán M1 cho ngày mai → POST /api/cron/behavior-results (server tự tạo cảnh báo khi p ≥ 0,6).

    CRON_SECRET=... .venv/bin/python -m jobs.nightly --url https://kidfun-backend.vercel.app          # chỉ tính
    CRON_SECRET=... .venv/bin/python -m jobs.nightly --url https://kidfun-backend.vercel.app --push   # tính + gửi
"""

import argparse
import os
import sys

import pandas as pd

from features import Calendar, load_categories
from jobs.baseline import MIN_BASELINE_DAYS, build_baselines, push_baselines
from jobs.load import load_thesis_data
from jobs.predict import MIN_HISTORY_DAYS, build_predictions, push_results
from models.m1 import bundle as m1_bundle


def _print_report(name: str, report: dict, skip_reason: str) -> None:
    print(f"{name}: {report['processed']} trẻ đã tính | bỏ qua ({skip_reason}): "
          f"{len(report['skipped'])} | lỗi: {len(report['errors'])}")
    for err in report["errors"]:
        print(f"  lỗi profileId {err['profileId']}: {err['error']}", file=sys.stderr)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Tác vụ ban đêm: baseline tầng 1 + dự đoán M1.")
    ap.add_argument("--url", default=os.environ.get("THESIS_API_URL"), help="URL backend (hoặc env THESIS_API_URL)")
    ap.add_argument("--push", action="store_true", help="gửi lên backend (mặc định chỉ tính và in báo cáo)")
    args = ap.parse_args(argv)

    secret = os.environ.get("CRON_SECRET")
    if not args.url or not secret:
        print("Thiếu --url/THESIS_API_URL hoặc env CRON_SECRET", file=sys.stderr)
        return 2

    now = pd.Timestamp.now(tz="UTC")
    calendar, categories = Calendar.load(), load_categories()
    data = load_thesis_data(args.url, secret, log=print)

    baselines, b_report = build_baselines(data, now=now, calendar=calendar, categories=categories)
    _print_report("baseline", b_report, f"< {MIN_BASELINE_DAYS} ngày dữ liệu")

    version = m1_bundle.model_version()
    predictions, p_report = build_predictions(data, now=now, calendar=calendar, categories=categories,
                                              bundle=m1_bundle.load())
    _print_report(f"dự đoán M1 ({version})", p_report, f"< {MIN_HISTORY_DAYS} ngày lịch sử hoặc hôm nay chưa có dữ liệu")

    if args.push:
        print(f"đã lưu {push_baselines(args.url, secret, baselines)} baseline lên backend")
        summary = push_results(args.url, secret, predictions, version)
        print(f"đã lưu {summary['predictions']} dự đoán | cảnh báo mới: {summary['alertsCreated']} "
              f"| trùng: {summary['alertDuplicates']} | profile lạ: {summary['unknownProfiles']}")
    return 1 if b_report["errors"] or p_report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
