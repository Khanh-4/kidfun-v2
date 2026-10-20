"""Bộ sinh dữ liệu mô phỏng hành vi dùng máy của trẻ (đồ án chuyên ngành, tuần 2).

Xuất đúng tên cột các bảng Prisma (AppUsageHourly, TimeLimit, TimeExtensionRequest, YouTubeLog)
để ml/features chạy y hệt trên dữ liệu thật. Mốc thời gian ghi theo UTC như Postgres.

Hiệu chỉnh mức nền (phút/ngày học) theo các nguồn đã trích trong PDF mô tả đề tài:
  3–5 tuổi ~82 phút (Q&Me 2023, VN), 11–14 ~284 phút (tweens) và 15–17 ~442 phút (teens)
  theo Common Sense Census 2019 (Mỹ — hạn chế đã nêu); 6–10 tuổi nội suy. Cuối tuần/ngày nghỉ tăng
  rõ rệt (Tuổi Trẻ 2014: tỷ lệ trẻ dùng 3–4h/ngày ~1% ngày thường -> 7–9% cuối tuần).
"""

from dataclasses import dataclass

import numpy as np
import pandas as pd

from features.common import VN_OFFSET, Calendar

AGE_GROUPS = {  # nhóm tuổi: (phút nền ngày học, tỷ trọng video, game, social, study, other, giờ ngủ)
    "3-5": (82, (0.75, 0.15, 0.00, 0.05, 0.05), 20),
    "6-10": (150, (0.50, 0.30, 0.05, 0.10, 0.05), 21),
    "11-14": (284, (0.35, 0.30, 0.20, 0.10, 0.05), 22),
    "15-17": (442, (0.30, 0.20, 0.35, 0.10, 0.05), 23),
}
APPS = {  # nhóm -> các app (packageName, appName) có trong ml/config/app_categories.csv
    "video": [("com.google.android.youtube", "YouTube"), ("com.ss.android.ugc.trill", "TikTok")],
    "game": [("com.garena.game.kgvn", "Liên Quân Mobile"), ("com.roblox.client", "Roblox"),
             ("com.mojang.minecraftpe", "Minecraft")],
    "social": [("com.zing.zalo", "Zalo"), ("com.facebook.orca", "Messenger"), ("com.facebook.katana", "Facebook")],
    "study": [("com.duolingo", "Duolingo"), ("com.google.android.apps.classroom", "Google Classroom")],
    "other": [("com.android.chrome", "Chrome")],
}
CATEGORIES = tuple(APPS)
YOUTUBE = "com.google.android.youtube"
UNKNOWN_APPS = [("com.sim.unknown.game1", "Game lạ 1"), ("com.sim.unknown.chat2", "App chat lạ 2")]
DAY_MULTIPLIER = {"school": 1.0, "weekend": 1.45, "off": 1.6}
EXAM_MULTIPLIER = 0.8
AR_PHI, AR_SIGMA = 0.5, 0.25  # nhiễu theo ngày có tự tương quan
MISSING_DAY_PROB = 0.02
HAS_LIMIT_PROB = 0.7
ASK_MORE_PROB = 0.6
WARMUP_DAYS = 28  # không cài bất thường trong 28 ngày đầu (để có mức thường ngày)
ANOMALY_RATE = 1 / 20  # trung bình 1 bất thường / 20 ngày / trẻ
ANOMALY_KINDS = ("night_use", "spike", "new_app", "binge_day", "danger_content")
DANGER_LEVEL_P = (0.7, 0.2, 0.08, 0.015, 0.005)  # dangerLevel 1..5 của video bình thường


@dataclass(frozen=True)
class Child:
    profile_id: int
    age_group: str
    base_minutes: float
    weekend_mult: float
    prefs: np.ndarray
    bedtime: int
    limit_weekday: int | None
    limit_weekend: int | None
    approve_prob: float
    apps: dict


def make_children(n: int, rng: np.random.Generator) -> list[Child]:
    children = []
    for i in range(n):
        group = str(rng.choice(list(AGE_GROUPS)))
        base, prefs, bedtime = AGE_GROUPS[group]
        base_minutes = base * rng.lognormal(0, 0.35)
        limit = max(30, int(round(base_minutes * rng.uniform(0.8, 1.2) / 15) * 15))
        has_limit = rng.random() < HAS_LIMIT_PROB
        children.append(
            Child(
                profile_id=i + 1,
                age_group=group,
                base_minutes=base_minutes,
                weekend_mult=rng.uniform(1.2, 1.7),
                prefs=rng.dirichlet(np.array(prefs) * 20 + 0.1),
                bedtime=bedtime,
                limit_weekday=limit if has_limit else None,
                limit_weekend=int(limit * 1.5) if has_limit else None,
                approve_prob=rng.uniform(0.3, 0.8),
                apps={c: APPS[c][rng.integers(len(APPS[c]))] for c in CATEGORIES},
            )
        )
    return children


def hour_weights(day_type: str, bedtime: int) -> np.ndarray:
    w = np.zeros(24)
    if day_type == "school":
        w[6] = 0.3
        w[11:13] = 0.4  # nghỉ trưa
        w[16 : bedtime + 1] = 1.0
        w[19:21] *= 1.5
    else:
        w[8 : bedtime + 1] = 1.0
        w[14:17] *= 1.3
        w[19:22] *= 1.4
    return w / w.sum()


def simulate(n_children: int, start: str, days: int, seed: int = 42, calendar: Calendar | None = None) -> dict:
    """Trả về dict DataFrame: profiles, app_usage_hourly, time_limits, time_extension_requests,
    youtube_logs, anomalies (nhãn bất thường đã cài)."""
    rng = np.random.default_rng(seed)
    calendar = calendar or Calendar.load()
    dates = pd.date_range(start, periods=days, freq="D")
    flags = calendar.day_flags(dates)
    children = make_children(n_children, rng)

    usage, ext, yt, anomalies = [], [], [], []
    for child in children:
        noise = 0.0
        for i, day in enumerate(dates):
            noise = AR_PHI * noise + rng.normal(0, AR_SIGMA)
            if rng.random() < MISSING_DAY_PROB:
                continue  # máy tắt / mất quyền: không có dòng nào
            f = flags.loc[day]
            kind = str(rng.choice(ANOMALY_KINDS)) if i >= WARMUP_DAYS and rng.random() < ANOMALY_RATE else None
            hours, marked = _plan_day(child, f, noise, kind, rng)
            hours, requests = _apply_limit(child, f, day, hours, rng)
            danger_hour = int(rng.integers(16, 22)) if kind == "danger_content" else None
            ext += requests
            usage += _to_rows(child, day, hours)
            yt += _youtube(child, day, hours, danger_hour, rng)
            if kind:
                marked = [danger_hour] if danger_hour is not None else marked
                anomalies.append((child.profile_id, day.date().isoformat(), kind, " ".join(map(str, sorted(marked)))))

    return {
        "profiles": pd.DataFrame(
            [{"profileId": c.profile_id, "deviceId": c.profile_id, "ageGroup": c.age_group} for c in children]
        ),
        "app_usage_hourly": pd.DataFrame(usage),
        "time_limits": _limits(children),
        "time_extension_requests": pd.DataFrame(
            ext, columns=["profileId", "deviceId", "requestMinutes", "status", "responseMinutes", "createdAt"]
        ),
        "youtube_logs": pd.DataFrame(
            yt, columns=["profileId", "deviceId", "videoTitle", "watchedAt", "durationSeconds", "dangerLevel"]
        ),
        "anomalies": pd.DataFrame(anomalies, columns=["profileId", "date", "kind", "hours"]),
    }


def _plan_day(child: Child, f, noise: float, kind, rng) -> tuple[dict, list]:
    """Phút theo (giờ, nhóm, app) mà trẻ MUỐN dùng trong ngày (trước khi áp giới hạn) + các giờ bị cài bất thường."""
    day_type = f["day_type"]
    mult = 1.0 if day_type == "school" else DAY_MULTIPLIER[day_type] * child.weekend_mult / DAY_MULTIPLIER["weekend"]
    mult *= EXAM_MULTIPLIER if f["is_exam_period"] else 1.0
    mult *= 2.5 if kind == "binge_day" else 1.0
    per_hour = np.minimum(child.base_minutes * mult * np.exp(noise) * hour_weights(day_type, child.bedtime), 60)

    hours = {}
    for hour in np.nonzero(per_hour)[0]:
        split = rng.dirichlet(child.prefs * 30 + 0.05) * per_hour[hour]
        for cat, minutes in zip(CATEGORIES, split):
            if minutes >= 1:
                hours[(int(hour), cat, child.apps[cat])] = minutes
    marked = sorted({h for h, _c, _a in hours}) if kind == "binge_day" else _inject(hours, child, kind, rng)
    return _cap_hours(hours), marked


def _cap_hours(hours: dict) -> dict:
    """Một giờ không thể dùng quá 60 phút: co tỷ lệ các app trong giờ bị vượt."""
    per_hour: dict[int, float] = {}
    for (hour, _c, _a), minutes in hours.items():
        per_hour[hour] = per_hour.get(hour, 0.0) + minutes
    return {key: m * min(1.0, 60 / per_hour[key[0]]) for key, m in hours.items()}


def _inject(hours: dict, child: Child, kind, rng) -> list:
    if kind == "night_use":
        marked = [int(h) for h in rng.choice([0, 1, 2, 3], size=int(rng.integers(1, 3)), replace=False)]
        for hour in marked:
            hours[(hour, "game", child.apps["game"])] = rng.uniform(20, 55)
        return marked
    if kind == "spike":
        cat = str(rng.choice(["game", "video", "social"]))
        for hour in (19, 20, 21):
            key = (hour, cat, child.apps[cat])
            hours[key] = min(60.0, max(hours.get(key, 0.0), 5.0) * rng.uniform(3, 5) + 15)
        return [19, 20, 21]
    if kind == "new_app":
        hour = int(rng.integers(15, 21))
        hours[(hour, "other", UNKNOWN_APPS[rng.integers(len(UNKNOWN_APPS))])] = rng.uniform(30, 60)
        return [hour]
    return []


def _apply_limit(child: Child, f, day, hours: dict, rng) -> tuple[dict, list]:
    """Chạm giới hạn -> xin thêm 15/30 phút (60%), phụ huynh duyệt hoặc từ chối; sau đó máy bị chặn.
    Giới hạn chọn theo thứ trong tuần, khớp bảng TimeLimit."""
    limit = child.limit_weekend if f["is_weekend"] else child.limit_weekday
    if limit is None:
        return hours, []
    used, cap, asked, requests, kept = 0.0, float(limit), False, [], {}
    for key in sorted(hours):
        hour, minutes = key[0], hours[key]
        if used + minutes > cap and not asked and rng.random() < ASK_MORE_PROB:
            asked = True
            want = int(rng.choice([15, 30]))
            approved = rng.random() < child.approve_prob
            created = _utc(day, hour) + pd.Timedelta(minutes=int(rng.integers(0, 60)))
            requests.append(
                (child.profile_id, child.profile_id, want, "APPROVED" if approved else "REJECTED",
                 want if approved else None, created)
            )
            cap += want if approved else 0
        allowed = max(0.0, min(minutes, cap - used))
        if allowed >= 1:
            kept[key] = allowed
        used += allowed
    return kept, requests


def _to_rows(child: Child, day, hours: dict) -> list:
    rows = {}
    for (hour, _cat, (pkg, name)), minutes in hours.items():
        prev = rows.get((hour, pkg), {"usageSeconds": 0, "launchCount": 0})
        rows[(hour, pkg)] = {
            "profileId": child.profile_id,
            "deviceId": child.profile_id,
            "packageName": pkg,
            "appName": name,
            "hourStart": _utc(day, hour),
            "usageSeconds": prev["usageSeconds"] + int(minutes * 60),
            "launchCount": prev["launchCount"] + 1 + int(minutes // 10),
        }
    return list(rows.values())


def _youtube(child: Child, day, hours: dict, danger_hour, rng) -> list:
    logs = []
    for (hour, _cat, (pkg, _name)), minutes in hours.items():
        if pkg != YOUTUBE:
            continue
        for _ in range(max(1, int(minutes // 8))):
            level = int(rng.choice([1, 2, 3, 4, 5], p=DANGER_LEVEL_P))
            watched = _utc(day, hour) + pd.Timedelta(minutes=int(rng.integers(0, 60)))
            logs.append((child.profile_id, child.profile_id, "Video mô phỏng", watched, 480, level))
    if danger_hour is not None:
        logs += [
            (child.profile_id, child.profile_id, "Video mô phỏng (nguy hiểm)",
             _utc(day, danger_hour) + pd.Timedelta(minutes=10 * k), 480, int(rng.integers(4, 6)))
            for k in range(3)
        ]
    return logs


def _limits(children: list[Child]) -> pd.DataFrame:
    rows = [
        {
            "profileId": c.profile_id,
            "dayOfWeek": dow,
            "dailyLimitMinutes": c.limit_weekend if dow in (0, 6) else c.limit_weekday,
            "isActive": True,
            "isGradual": False,
        }
        for c in children
        if c.limit_weekday is not None
        for dow in range(7)
    ]
    return pd.DataFrame(rows, columns=["profileId", "dayOfWeek", "dailyLimitMinutes", "isActive", "isGradual"])


def _utc(day, hour: int) -> pd.Timestamp:
    return (day + pd.Timedelta(hours=hour) - VN_OFFSET).tz_localize("UTC")
