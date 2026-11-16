"""Dữ liệu cho tài khoản demo buổi bảo vệ (T9.3.2) — CHỈ nạp vào DB test cục bộ, không vào production.

Mô phỏng 28 ngày kết thúc HÔM NAY (heatmap thói quen lấy trung bình 4 tuần), rồi chọn:
  - 2 bé của phụ huynh demo (hiện trên app):
      "Minh": dùng sát giới hạn nhất; giới hạn được ĐẶT LẠI = 75% mức dùng trung bình 7 ngày gần nhất (dữ liệu demo)
              để dự đoán ngày mai vượt giới hạn (thẻ "Ngày mai" hiện số phút > giới hạn, p = 0,5 sau khi kẹp).
              LƯU Ý (16/11): bộ phân loại M1 gần như không phản ứng khi giới hạn thấp hơn hẳn mức dùng (p gốc ~0,24
              dù giới hạn chỉ bằng 1/3) nên chưa tới ngưỡng cảnh báo 0,6 — xem docs/thesis/demo-bao-ve.md;
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
TIGHT_LIMIT_CHILD = "Minh"
TIGHT_LIMIT_SHARE = 0.75  # giới hạn demo của Minh = 75% mức dùng trung bình tuần, làm tròn 5 phút
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


def _tight_limits(hourly: pd.DataFrame, pid: int, today: pd.Timestamp) -> list[dict]:
    rows = hourly[hourly["profileId"] == pid]
    vn_date = (rows["hourStart"] + pd.Timedelta(hours=7)).dt.tz_localize(None).dt.normalize()
    week = rows[(vn_date > today - pd.Timedelta(days=7)) & (vn_date <= today)]
    week_mean = week["usageSeconds"].sum() / 60 / 7
    minutes = max(15, int(round(week_mean * TIGHT_LIMIT_SHARE / 5) * 5))
    return [{"dayOfWeek": d, "dailyLimitMinutes": minutes, "isActive": True, "isGradual": False} for d in range(7)]


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
        "limits": (_tight_limits(sim["app_usage_hourly"], pid, today) if name == TIGHT_LIMIT_CHILD
                   else _records(sim["time_limits"], pid, LIMIT_COLS)),
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
