"""Tải dữ liệu thật từ backend cho tác vụ ban đêm (T7.1.2).

Gọi GET /api/cron/thesis-data (T7.1.1a) theo từng trang trẻ, ghép thành đúng các DataFrame
mà ml/features/ đang dùng với dữ liệu mô phỏng: hourly, limits, ext_requests.

    CRON_SECRET=... .venv/bin/python -m jobs.load --url https://kidfun-backend.vercel.app
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Callable
from urllib.parse import urlencode

import pandas as pd

DEFAULT_DAYS = 28
DEFAULT_LIMIT = 10
TIMEOUT_S = 60

HOURLY_COLS = {"profileId": "int64", "packageName": "object", "hourStart": "datetime",
               "usageSeconds": "int64", "launchCount": "int64"}
LIMIT_COLS = {"profileId": "int64", "dayOfWeek": "int64", "dailyLimitMinutes": "int64",
              "isActive": "bool", "isGradual": "bool"}
EXT_COLS = {"profileId": "int64", "createdAt": "datetime", "requestMinutes": "int64", "status": "object"}

# (url, headers) -> (HTTP status, body JSON). Truyền vào được để test không cần mạng.
GetJson = Callable[[str, dict], tuple[int, dict]]


class ApiError(RuntimeError):
    pass


@dataclass(frozen=True)
class ThesisData:
    profile_ids: list[int]
    hourly: pd.DataFrame
    limits: pd.DataFrame
    ext_requests: pd.DataFrame


def http_get_json(url: str, headers: dict) -> tuple[int, dict]:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as err:
        try:
            body = json.loads(err.read())
        except ValueError:
            body = {}
        return err.code, body


def fetch_pages(base_url: str, secret: str, *, days: int = DEFAULT_DAYS, limit: int = DEFAULT_LIMIT,
                get_json: GetJson = http_get_json, log: Callable[[str], None] = lambda _: None) -> list[dict]:
    """Mọi trang `data` của API; gặp 413 (trang quá to) thì giảm limit một nửa rồi gọi lại trang đó."""
    headers = {"Authorization": f"Bearer {secret}"}
    pages, after = [], 0
    while True:
        url = f"{base_url.rstrip('/')}/api/cron/thesis-data?{urlencode({'days': days, 'limit': limit, 'afterProfileId': after})}"
        status, body = get_json(url, headers)
        if status == 413 and limit > 1:
            limit //= 2
            log(f"trang sau profileId {after} quá to → giảm limit còn {limit}")
            continue
        if status != 200:
            raise ApiError(f"thesis-data trả {status}: {body.get('message') or body.get('code') or body}")
        data = body["data"]
        pages.append(data)
        log(f"trang sau profileId {after}: {len(data['profileIds'])} trẻ, {len(data['hourly'])} dòng hourly")
        if data["nextAfterProfileId"] is None:
            return pages
        after = data["nextAfterProfileId"]


def _frame(rows: list[dict], cols: dict[str, str]) -> pd.DataFrame:
    df = pd.DataFrame(rows, columns=list(cols))
    for col, kind in cols.items():
        df[col] = pd.to_datetime(df[col], utc=True) if kind == "datetime" else df[col].astype(kind)
    return df


def to_frames(pages: list[dict]) -> ThesisData:
    def rows(key):
        return [r for p in pages for r in p[key]]

    return ThesisData(
        profile_ids=[pid for p in pages for pid in p["profileIds"]],
        hourly=_frame(rows("hourly"), HOURLY_COLS),
        limits=_frame(rows("limits"), LIMIT_COLS),
        ext_requests=_frame(rows("extRequests"), EXT_COLS),
    )


def load_thesis_data(base_url: str, secret: str, **kw) -> ThesisData:
    return to_frames(fetch_pages(base_url, secret, **kw))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Tải dữ liệu thật cho tác vụ ban đêm (kiểm tra nhanh).")
    ap.add_argument("--url", default=os.environ.get("THESIS_API_URL"), help="URL backend (hoặc env THESIS_API_URL)")
    ap.add_argument("--days", type=int, default=DEFAULT_DAYS)
    ap.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    args = ap.parse_args(argv)

    secret = os.environ.get("CRON_SECRET")
    if not args.url or not secret:
        print("Thiếu --url/THESIS_API_URL hoặc env CRON_SECRET", file=sys.stderr)
        return 2

    data = load_thesis_data(args.url, secret, days=args.days, limit=args.limit, log=print)
    print(f"{len(data.profile_ids)} trẻ | {len(data.hourly)} dòng hourly | "
          f"{len(data.limits)} limits | {len(data.ext_requests)} yêu cầu thêm giờ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
