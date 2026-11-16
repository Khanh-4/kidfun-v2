"""Dữ liệu cho tài khoản demo buổi bảo vệ (T9.3.2) — CHỈ nạp vào DB test cục bộ, không vào production.

Mô phỏng 28 ngày kết thúc HÔM NAY (heatmap thói quen lấy trung bình 4 tuần), rồi chọn:
  - 2 bé của phụ huynh demo (hiện trên app):
      "Minh": có giới hạn, chạm giới hạn thường xuyên nhất → thẻ "Ngày mai" có khả năng dùng hết giờ cao (thử 16/11:
              p = 0,74 với nhãn của #372; cảnh báo M1 cần p ≥ 0,8 nên không chắc có trong ngày demo);
      "An":   có giới hạn, mức dùng trung bình; HÔM QUA cài một đêm bất thường (dùng 0h–4h + chiều tối dài)
              → M2 mức ngày đánh dấu, có cảnh báo kèm giải thích để bấm "Đúng là bất thường" / "Được phép".
  - 6 bé "nền" ở một tài khoản khác: M3 K-Means chỉ chia nhóm khi ≥ 6 trẻ đủ 7 ngày, nên cần thêm trẻ để thẻ
    "So với các bé khác · Nhóm x/3" hiện ra.
Mỗi bé có ngày sinh (giữa nhóm tuổi của bộ mô phỏng) để gói M1 và luật gợi ý M4 dùng tuổi.

    .venv/bin/python -m e2e.export_demo /tmp/demo.json
"""

import json
import sys

import pandas as pd

from e2e.export_sim import _inject_anomaly, _records
from features import Calendar
from simulator.generate import simulate

DAYS = 28
N_POOL = 40
SEED = 11
BACKGROUND = 6
DEMO_CHILDREN = (("Minh", "cao"), ("An", "vua"))
ANOMALY_CHILD = "An"
AGE_YEARS = {"3-5": 4, "6-10": 8, "11-14": 12, "15-17": 16}
HOURLY_COLS = ["packageName", "appName", "hourStart", "usageSeconds", "launchCount"]
LIMIT_COLS = ["dayOfWeek", "dailyLimitMinutes", "isActive", "isGradual"]
EXT_COLS = ["requestMinutes", "status", "responseMinutes", "createdAt"]


def _pick(sim: dict, today: pd.Timestamp) -> tuple[dict[str, int], list[int]]:
    hourly = sim["app_usage_hourly"]
    vn_date = (hourly["hourStart"] + pd.Timedelta(hours=7)).dt.tz_localize(None).dt.normalize()
    has_today = set(hourly.loc[vn_date == today, "profileId"])
    week = hourly[vn_date > today - pd.Timedelta(days=7)]
    mean_min = week.groupby("profileId")["usageSeconds"].sum() / 60 / 7
    limit = sim["time_limits"].groupby("profileId")["dailyLimitMinutes"].mean()
    with_limit = [p for p in limit.index if p in has_today]
    if len(with_limit) < 3:
        sys.exit("Mô phỏng không đủ trẻ có giới hạn — đổi SEED/N_POOL")
    ratio = (mean_min.reindex(with_limit) / limit.reindex(with_limit)).sort_values()
    picked = {"cao": int(ratio.index[-1]), "vua": int(ratio.index[len(ratio) // 2])}
    background = [int(p) for p in sim["profiles"]["profileId"] if p in has_today and p not in picked.values()]
    if len(background) < BACKGROUND:
        sys.exit("Mô phỏng không đủ trẻ nền — đổi SEED/N_POOL")
    return picked, background[:BACKGROUND]


def _birth_date(age_group: str, today: pd.Timestamp) -> str:
    years = AGE_YEARS.get(age_group, 8)
    return (today - pd.DateOffset(years=years) - pd.Timedelta(days=100)).date().isoformat()


def _child(sim: dict, pid: int, name: str, demo: bool, today: pd.Timestamp) -> dict:
    hourly = _records(sim["app_usage_hourly"], pid, HOURLY_COLS)
    anomaly = name == ANOMALY_CHILD
    age_group = sim["profiles"].set_index("profileId")["ageGroup"].get(pid, "6-10")
    return {
        "name": name,
        "demo": demo,
        "simProfileId": pid,
        "ageGroup": age_group,
        "dateOfBirth": _birth_date(age_group, today),
        "dayAnomalyInjected": anomaly,
        "hourly": _inject_anomaly(hourly, today) if anomaly else hourly,
        "limits": _records(sim["time_limits"], pid, LIMIT_COLS),
        "extRequests": _records(sim["time_extension_requests"], pid, EXT_COLS),
    }


def build_demo(today: pd.Timestamp) -> dict:
    start = (today - pd.Timedelta(days=DAYS - 1)).date().isoformat()
    sim = simulate(N_POOL, start, DAYS, seed=SEED, calendar=Calendar.load())
    picked, background = _pick(sim, today)
    children = [_child(sim, picked[role], name, True, today) for name, role in DEMO_CHILDREN]
    children += [_child(sim, pid, f"Bé nền {i + 1}", False, today) for i, pid in enumerate(background)]
    return {"today": today.date().isoformat(), "children": children}


def main(out_path: str) -> None:
    from jobs.baseline import task_day

    demo = build_demo(task_day(pd.Timestamp.now(tz="UTC")))
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(demo, fh, ensure_ascii=False, default=str)
    for c in demo["children"]:
        print(f"{c['name']:>9}: sim #{c['simProfileId']} | {c['ageGroup']:>5} | {len(c['hourly'])} dòng giờ | "
              f"{len(c['limits'])} giới hạn{' | đêm bất thường hôm qua' if c['dayAnomalyInjected'] else ''}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "demo.json")
