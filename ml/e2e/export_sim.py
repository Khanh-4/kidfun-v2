"""Xuất dữ liệu mô phỏng 3 trẻ cho kiểm thử đầu cuối tác vụ ban đêm (T7.3.4).

Mô phỏng 21 ngày kết thúc HÔM NAY (giờ VN, đủ 24 giờ như thể tác vụ chạy cuối ngày), rồi chọn 3 trẻ phủ đủ
các nhánh của tác vụ:
  - "cao":   có giới hạn, dùng gần/vượt giới hạn nhất  → nhiều khả năng p ≥ 0,6 (server tạo cảnh báo M1);
  - "thap":  có giới hạn, dùng ít so với giới hạn       → p thấp, không cảnh báo;
  - "khong": không đặt giới hạn                         → pOverLimit = null.

    .venv/bin/python -m e2e.export_sim /tmp/sim.json
"""

import json
import sys

import pandas as pd

from features import Calendar
from jobs.baseline import vn_today
from simulator.generate import simulate

DAYS = 21
N_POOL = 40
SEED = 7


def _pick(sim: dict, today: pd.Timestamp) -> dict[str, int]:
    hourly = sim["app_usage_hourly"]
    vn_date = (hourly["hourStart"] + pd.Timedelta(hours=7)).dt.tz_localize(None).dt.normalize()
    has_today = set(hourly.loc[vn_date == today, "profileId"])
    week = hourly[vn_date > today - pd.Timedelta(days=7)]
    mean_min = week.groupby("profileId")["usageSeconds"].sum() / 60 / 7

    limit = sim["time_limits"].groupby("profileId")["dailyLimitMinutes"].mean()
    with_limit = [p for p in limit.index if p in has_today]
    ratio = (mean_min.reindex(with_limit) / limit.reindex(with_limit)).sort_values()
    no_limit = [p for p in sim["profiles"]["profileId"] if p in has_today and p not in limit.index]
    if len(ratio) < 2 or not no_limit:
        sys.exit("Mô phỏng không đủ trẻ phủ 3 nhánh — đổi SEED/N_POOL")
    return {"cao": int(ratio.index[-1]), "thap": int(ratio.index[0]), "khong": int(no_limit[0])}


def _records(df: pd.DataFrame, pid: int, cols: list[str]) -> list[dict]:
    rows = df.loc[df["profileId"] == pid, cols].copy()
    for col in rows.columns:
        if pd.api.types.is_datetime64_any_dtype(rows[col]):
            rows[col] = rows[col].map(lambda t: pd.Timestamp(t).isoformat())
    return rows.astype(object).where(rows.notna(), None).to_dict("records")


def main(out_path: str) -> None:
    today = vn_today(pd.Timestamp.now(tz="UTC"))
    start = (today - pd.Timedelta(days=DAYS - 1)).date().isoformat()
    sim = simulate(N_POOL, start, DAYS, seed=SEED, calendar=Calendar.load())
    picked = _pick(sim, today)

    children = []
    for label, pid in picked.items():
        children.append({
            "label": label,
            "simProfileId": pid,
            "hourly": _records(sim["app_usage_hourly"], pid,
                               ["packageName", "appName", "hourStart", "usageSeconds", "launchCount"]),
            "limits": _records(sim["time_limits"], pid, ["dayOfWeek", "dailyLimitMinutes", "isActive", "isGradual"]),
            "extRequests": _records(sim["time_extension_requests"], pid,
                                    ["requestMinutes", "status", "responseMinutes", "createdAt"]),
        })
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump({"today": today.date().isoformat(), "children": children}, fh, ensure_ascii=False, default=str)
    for c in children:
        print(f"{c['label']:>5}: sim #{c['simProfileId']} | {len(c['hourly'])} dòng giờ | "
              f"{len(c['limits'])} giới hạn | {len(c['extRequests'])} xin thêm giờ")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "sim.json")
