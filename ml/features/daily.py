"""Đặc trưng M1 — dự đoán tổng thời gian dùng máy ngày t+1, tính lúc {cutoff}:00 giờ VN ngày t.

Đặc tả: docs/thesis/05-dac-ta-dac-trung.md mục 1. Đầu vào là DataFrame có tên cột giống
bảng Prisma (AppUsageHourly, TimeLimit, TimeExtensionRequest, YouTubeLog, GeofenceEvent),
để cùng một hàm chạy được trên dữ liệu thật lẫn dữ liệu mô phỏng.

Chống rò rỉ: mọi đặc trưng chỉ dùng dữ liệu trước mốc cắt của ngày t. Ngày không có ô giờ nào
là THIẾU (NaN), không phải 0 phút.
"""

import numpy as np
import pandas as pd

from .common import CATEGORIES, NIGHT_HOURS, Calendar, categorize, night_key, to_vn, vn_dow

DEFAULT_CUTOFF_HOUR = 21
LATE_NIGHT_MINUTES = 15
SLEEP_WINDOW_START = 20  # cửa sổ ngủ: 20:00 ngày t−1 → 08:00 ngày t
SLEEP_WINDOW_HOURS = 12
HIGH_DANGER = 4
HOLIDAY_HORIZON_DAYS = 14  # xa hơn 14 ngày thì "sắp nghỉ" không còn ý nghĩa; để nguyên thành biến chỉ thời gian


def prepare_hourly(hourly: pd.DataFrame, categories: dict[str, str]) -> pd.DataFrame:
    local = to_vn(hourly["hourStart"])
    return hourly.assign(
        local=local,
        date=local.dt.normalize(),
        hour=local.dt.hour,
        minutes=hourly["usageSeconds"] / 60,
        cat=categorize(hourly["packageName"], categories),
    )


def build_daily_features(
    hourly: pd.DataFrame,
    *,
    calendar: Calendar,
    categories: dict[str, str],
    limits: pd.DataFrame | None = None,
    ext_requests: pd.DataFrame | None = None,
    youtube: pd.DataFrame | None = None,
    geofence: pd.DataFrame | None = None,
    cutoff_hour: int = DEFAULT_CUTOFF_HOUR,
) -> pd.DataFrame:
    """Một dòng cho mỗi (profileId, ngày t); kèm nhãn y_next / over_limit_next để huấn luyện."""
    h = prepare_hourly(hourly, categories)
    frames = [
        _profile_features(
            pid,
            g,
            calendar=calendar,
            limits=_of(limits, pid),
            ext=_of(ext_requests, pid),
            yt=_of(youtube, pid),
            geo=_of(geofence, pid),
            cutoff=cutoff_hour,
        )
        for pid, g in h.groupby("profileId")
    ]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def _of(df: pd.DataFrame | None, pid) -> pd.DataFrame | None:
    return None if df is None else df[df["profileId"] == pid]


def _profile_features(pid, h, *, calendar, limits, ext, yt, geo, cutoff) -> pd.DataFrame:
    idx = pd.date_range(h["date"].min(), h["date"].max(), freq="D")
    total = h.groupby("date")["minutes"].sum().reindex(idx)  # NaN = ngày thiếu
    until = h[h["hour"] < cutoff].groupby("date")["minutes"].sum().reindex(idx).fillna(0)
    until = until.where(total.notna())

    out = pd.DataFrame(index=idx)
    out["profileId"] = pid
    out["target_date"] = idx + pd.Timedelta(days=1)
    out = out.join(_history(total, until))
    out = out.join(_calendar(calendar, out["target_date"]))
    out = out.join(_limits(limits, out["target_date"], out["mean7"]))
    out = out.join(_app_mix(h, idx, cutoff))
    out = out.join(_night(h, idx))
    out = out.join(_sleep(h, idx))
    out = out.join(_extension(ext, idx, cutoff))
    out = out.join(_youtube(yt, idx, cutoff))
    out["outside_zone_min_7d"] = _outside_zone(geo, idx, cutoff)

    out["y_next"] = total.shift(-1)
    over = out["y_next"] > out["limit_tomorrow"]
    out["over_limit_next"] = over.where(out["has_limit"] & out["y_next"].notna())
    out["today_missing"] = total.isna()
    return out.rename_axis("date").reset_index()


def _history(total: pd.Series, until: pd.Series) -> pd.DataFrame:
    past = total.shift(1)
    mean7 = past.rolling(7, min_periods=3).mean()
    mean14 = past.rolling(14, min_periods=3).mean()
    same_dow = pd.concat([total.shift(k) for k in (6, 13, 20, 27)], axis=1).mean(axis=1)
    return pd.DataFrame(
        {
            "y_lag1": past,
            "y_lag7": total.shift(7),
            "y_same_dow_last_week": total.shift(6),  # cùng thứ với ngày t+1 (seasonal naive)
            "mean7": mean7,
            "std7": past.rolling(7, min_periods=3).std(),
            "mean14": mean14,
            "today_until_cutoff": until,
            "today_until_cutoff_ratio": until / until.shift(1).rolling(7, min_periods=3).mean(),
            "lag1_ratio": past / mean7,
            "same_dow_ratio": same_dow / mean14,
            "history_days": past.notna().cumsum(),
        }
    )


def _calendar(calendar: Calendar, target_dates: pd.Series) -> pd.DataFrame:
    flags = calendar.day_flags(target_dates)
    angle = 2 * np.pi * flags["dow"].to_numpy() / 7
    cols = ["is_weekend", "is_holiday", "is_school_day", "is_exam_period", "is_summer", "days_to_next_holiday"]
    out = pd.DataFrame({c: flags[c].to_numpy() for c in cols}, index=target_dates.index)
    out["days_to_next_holiday"] = out["days_to_next_holiday"].clip(upper=HOLIDAY_HORIZON_DAYS)
    return out.assign(dow_sin=np.sin(angle), dow_cos=np.cos(angle))


def _limits(limits, target_dates: pd.Series, mean7: pd.Series) -> pd.DataFrame:
    """TimeLimit chỉ lưu trạng thái hiện tại (không có lịch sử) -> áp cho mọi ngày."""
    by_dow, gradual = {}, {}
    if limits is not None:
        active = limits[limits["isActive"]]
        by_dow = dict(zip(active["dayOfWeek"], active["dailyLimitMinutes"]))
        gradual = dict(zip(active["dayOfWeek"], active["isGradual"]))
    dow = pd.Series(vn_dow(target_dates), index=target_dates.index)
    limit = dow.map(by_dow).astype(float)
    return pd.DataFrame(
        {
            "limit_tomorrow": limit,
            "has_limit": limit.notna(),
            "limit_tomorrow_ratio": limit / mean7,
            "is_gradual": dow.map(lambda d: bool(gradual.get(d, False))),
        }
    )


def _split_by_cutoff(values: pd.Series, local: pd.Series, idx, cutoff) -> tuple[pd.Series, pd.Series]:
    """Tổng theo ngày: cả ngày, và phần trước mốc cắt."""
    date = local.dt.normalize()
    full = values.groupby(date).sum().reindex(idx, fill_value=0)
    cut = values[local.dt.hour < cutoff].groupby(date[local.dt.hour < cutoff]).sum().reindex(idx, fill_value=0)
    return full, cut


def _win7(full: pd.Series, cut: pd.Series) -> pd.Series:
    """Cửa sổ 7 ngày tính tới mốc cắt: 6 ngày đầy đủ trước t + phần trước mốc cắt của ngày t."""
    return full.shift(1).rolling(6, min_periods=1).sum().fillna(0) + cut


def _app_mix(h, idx, cutoff) -> pd.DataFrame:
    wins = {
        cat: _win7(*_split_by_cutoff(h["minutes"].where(h["cat"] == cat, 0), h["local"], idx, cutoff))
        for cat in CATEGORIES
    }
    total = sum(wins.values()).replace(0, np.nan)
    return pd.DataFrame({f"share_{c}": wins[c] / total for c in CATEGORIES if c != "other"})


def _night(h, idx) -> pd.DataFrame:
    night = h[h["hour"].isin(NIGHT_HOURS)]
    per_night = night.groupby(night_key(night["local"]))["minutes"].sum().reindex(idx, fill_value=0)
    last = per_night.shift(1)  # đêm t−1 → sáng t, đã kết thúc trước mốc cắt
    late = (last > LATE_NIGHT_MINUTES).astype(float).where(last.notna())
    return pd.DataFrame(
        {
            "night_min_last": last,
            "night_min_7d": last.rolling(7, min_periods=1).sum(),
            "late_nights_7d": late.rolling(7, min_periods=1).sum(),
        }
    )


def _sleep(h, idx) -> pd.DataFrame:
    """Xấp xỉ giấc ngủ theo độ phân giải 1 giờ, cửa sổ 20:00 ngày t−1 → 08:00 ngày t."""
    grid = h.pivot_table(index="date", columns="hour", values="minutes", aggfunc="sum")
    grid = grid.reindex(index=idx, columns=range(24))
    present = grid.notna().any(axis=1).to_numpy()
    vals = grid.fillna(0).to_numpy()
    prev = np.vstack([np.zeros((1, 24)), vals[:-1]])
    morning = SLEEP_WINDOW_HOURS - (24 - SLEEP_WINDOW_START)
    active = np.hstack([prev[:, SLEEP_WINDOW_START:], vals[:, :morning]]) > 0

    last_pos = np.where(active.any(axis=1), SLEEP_WINDOW_HOURS - 1 - np.argmax(active[:, ::-1], axis=1), np.nan)
    gaps = np.array([_longest_run(~row) for row in active], dtype=float)
    known = present & np.concatenate([[False], present[:-1]])  # cần đủ dữ liệu cả 2 ngày
    return pd.DataFrame(
        {
            "last_active_hour": np.where(known, SLEEP_WINDOW_START + last_pos, np.nan),  # 20..31 (31 = 07:00)
            "sleep_gap_hours": np.where(known, gaps, np.nan),
        },
        index=idx,
    )


def _longest_run(mask: np.ndarray) -> int:
    best = run = 0
    for flag in mask:
        run = run + 1 if flag else 0
        best = max(best, run)
    return best


def _extension(ext, idx, cutoff) -> pd.DataFrame:
    if ext is None or ext.empty:
        zero = pd.Series(0.0, index=idx)
        return pd.DataFrame(
            {"ext_req_7d": zero, "ext_min_req_7d": zero, "ext_approve_rate_7d": np.nan, "ext_req_today": zero}
        )
    local = to_vn(ext["createdAt"])
    n_full, n_cut = _split_by_cutoff(pd.Series(1.0, index=ext.index), local, idx, cutoff)
    m_full, m_cut = _split_by_cutoff(ext["requestMinutes"].astype(float), local, idx, cutoff)
    a_full, a_cut = _split_by_cutoff((ext["status"] == "APPROVED").astype(float), local, idx, cutoff)
    n7 = _win7(n_full, n_cut)
    return pd.DataFrame(
        {
            "ext_req_7d": n7,
            "ext_min_req_7d": _win7(m_full, m_cut),
            "ext_approve_rate_7d": _win7(a_full, a_cut) / n7.replace(0, np.nan),
            "ext_req_today": n_cut,
        }
    )


def _youtube(yt, idx, cutoff) -> pd.DataFrame:
    if yt is None or yt.empty:
        return pd.DataFrame({"yt_danger_mean_7d": np.nan, "yt_danger_high_7d": 0.0}, index=idx)
    local = to_vn(yt["watchedAt"])
    level = yt["dangerLevel"].astype(float)
    s_full, s_cut = _split_by_cutoff(level.fillna(0), local, idx, cutoff)
    c_full, c_cut = _split_by_cutoff(level.notna().astype(float), local, idx, cutoff)
    hi_full, hi_cut = _split_by_cutoff((level >= HIGH_DANGER).astype(float), local, idx, cutoff)
    return pd.DataFrame(
        {
            "yt_danger_mean_7d": _win7(s_full, s_cut) / _win7(c_full, c_cut).replace(0, np.nan),
            "yt_danger_high_7d": _win7(hi_full, hi_cut),
        }
    )


def _outside_zone(geo, idx, cutoff) -> pd.Series:
    """Phút ngoài vùng an toàn trong cửa sổ 7 ngày: ghép EXIT với ENTER kế tiếp."""
    if geo is None or geo.empty:
        return pd.Series(0.0, index=idx)
    events = geo.assign(local=to_vn(geo["createdAt"])).sort_values("local")
    intervals, start = [], None
    for kind, ts in zip(events["type"], events["local"]):
        if kind == "EXIT" and start is None:
            start = ts
        elif kind == "ENTER" and start is not None:
            intervals.append((start, ts))
            start = None
    if start is not None:
        intervals.append((start, pd.Timestamp.max))

    values = []
    for day in idx:
        lo, hi = day - pd.Timedelta(days=6), day + pd.Timedelta(hours=cutoff)
        overlap = sum(max(pd.Timedelta(0), min(e, hi) - max(s, lo)).total_seconds() for s, e in intervals)
        values.append(overlap / 60)
    return pd.Series(values, index=idx)
