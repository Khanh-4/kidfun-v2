"""M2 tầng 1 — luật nhẹ chạy trên máy trẻ (đặc tả 05 mục 2.3), bản Python tham chiếu.

Bản Kotlin trên app trẻ phải cho cùng kết quả với `check_hour()` (test vector ở ml/tests/test_tier1.py).
Server tính hằng đêm `build_baseline()` -> JSON vài KB gửi xuống máy:
  { profileId, validUntil, nightWindow, baseline: [{dayType, hour, cat, mean, std}], rules,
    categories: {packageName: nhóm}, dayTypes: {"YYYY-MM-DD": school|weekend|off} }
`categories` (từ ml/config/app_categories.csv) để máy trẻ phân nhóm app theo cùng một nguồn; `dayTypes` vì máy trẻ
không biết lịch lễ / nghỉ học VN (thiếu ngày nào thì máy tự suy: thứ Bảy, Chủ nhật = weekend, còn lại = school).
Luật (kiểm tra mỗi ô giờ):
  - khuya: giờ thuộc khung khuya, tổng phút >= nightMinMinutes, VÀ trẻ thường không dùng máy giờ đó
    (tổng mức thường ngày cùng giờ, cùng loại ngày <= nightUsualMaxMinutes) — khung 22h cố định báo nhầm hàng loạt
    với trẻ lớn quen ngủ lúc 23h (thực nghiệm tuần 6);
  - tăng đột biến: phút của MỘT nhóm app >= spikeRatio × mức thường ngày của nhóm đó (cùng giờ, cùng loại ngày)
    và >= spikeMinMinutes (chặn trường hợp mức thường ngày gần 0).
Phụ huynh bấm "được phép" -> nới ngưỡng của đúng loại ngày (+ nhóm app), tối đa MAX_RELAX lần (đặc tả 05 mục 4).
"""

from copy import deepcopy

import pandas as pd

from features.common import CATEGORIES, NIGHT_HOURS, Calendar

DEFAULT_RULES = {"nightMinMinutes": 10, "nightUsualMaxMinutes": 3.0, "spikeRatio": 3.0, "spikeMinMinutes": 20}
NIGHT_WINDOW = ["22:00", "06:00"]
BASELINE_DAYS = 28
MIN_MEAN_IN_JSON = 0.5  # bỏ ô có mức thường ngày ~0 cho JSON nhỏ (ô thiếu = 0)
SPIKE_RELAX, NIGHT_RELAX, MAX_RELAX = 1.25, 1.5, 2


def build_baseline(
    hours: pd.DataFrame,
    profile_id,
    as_of: pd.Timestamp,
    overrides: dict | None = None,
    calendar: Calendar | None = None,
    categories: dict[str, str] | None = None,
) -> dict:
    """hours: bảng của build_hourly_features() cho MỘT trẻ. Mức thường ngày = 28 ngày trước as_of."""
    window = hours[(hours["date"] >= as_of - pd.Timedelta(days=BASELINE_DAYS)) & (hours["date"] < as_of)]
    entries = []
    for (day_type, hour), g in window.groupby(["day_type", "hour"]):
        for cat in CATEGORIES:
            values = g[f"hour_min_{cat}"]
            if values.mean() >= MIN_MEAN_IN_JSON:
                entries.append(
                    {
                        "dayType": day_type,
                        "hour": int(hour),
                        "cat": cat,
                        "mean": round(float(values.mean()), 1),
                        "std": round(float(values.std(ddof=0)), 1),
                    }
                )
    days = pd.date_range(as_of - pd.Timedelta(days=1), as_of + pd.Timedelta(days=1))
    day_types = {} if calendar is None else dict(zip(days.strftime("%Y-%m-%d"), calendar.day_flags(days)["day_type"]))
    return {
        "profileId": int(profile_id),
        "validUntil": (as_of + pd.Timedelta(days=1)).strftime("%Y-%m-%dT00:00:00+07:00"),
        "nightWindow": NIGHT_WINDOW,
        "baseline": entries,
        "rules": {**DEFAULT_RULES, **(overrides or {})},
        "categories": dict(categories or {}),
        "dayTypes": day_types,
    }


def night_min(rules: dict, day_type: str) -> float:
    return rules.get("nightMinByDayType", {}).get(day_type, rules["nightMinMinutes"])


def spike_ratio(rules: dict, day_type: str, cat: str) -> float:
    return rules.get("spikeRatioByKey", {}).get(f"{day_type}:{cat}", rules["spikeRatio"])


def check_hour(minutes_by_cat: dict, hour: int, day_type: str, baseline: dict) -> list[tuple[str, str]]:
    """Trả về danh sách (luật, nhóm app) bị vi phạm trong một ô giờ."""
    rules = baseline["rules"]
    alerts = []
    means = {(e["dayType"], e["hour"], e["cat"]): e["mean"] for e in baseline["baseline"]}
    total = sum(minutes_by_cat.values())
    usual_total = sum(m for (d, h, _), m in means.items() if d == day_type and h == hour)
    if hour in NIGHT_HOURS and total >= night_min(rules, day_type) and usual_total <= rules["nightUsualMaxMinutes"]:
        alerts.append(("night", max(minutes_by_cat, key=minutes_by_cat.get)))
    for cat, used in minutes_by_cat.items():
        usual = means.get((day_type, hour, cat), 0.0)
        if used >= spike_ratio(rules, day_type, cat) * usual and used >= rules["spikeMinMinutes"]:
            alerts.append(("spike", cat))
    return alerts


def relax(rules: dict, counts: dict, rule: str, day_type: str, cat: str) -> tuple[dict, dict]:
    """Phụ huynh bấm 'được phép' cho một cảnh báo -> trả về (rules mới, bộ đếm mới); không sửa đầu vào."""
    key = f"{day_type}:night" if rule == "night" else f"{day_type}:{cat}"
    if counts.get(key, 0) >= MAX_RELAX:
        return rules, counts
    new = deepcopy(rules)
    if rule == "night":
        new.setdefault("nightMinByDayType", {})[day_type] = night_min(rules, day_type) * NIGHT_RELAX
    else:
        new.setdefault("spikeRatioByKey", {})[key] = spike_ratio(rules, day_type, cat) * SPIKE_RELAX
    return new, {**counts, key: counts.get(key, 0) + 1}
