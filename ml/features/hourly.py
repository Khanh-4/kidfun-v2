"""Đặc trưng M2 — phát hiện bất thường, theo giờ và theo ngày (đặc tả 05 mục 2.1, 2.2).

Mức thường ngày của một trẻ = các ngày CÙNG LOẠI (ngày học / cuối tuần / nghỉ) trong
BASELINE_DAYS ngày trước đó, chỉ tính những ngày có dữ liệu. Trong một ngày có dữ liệu,
giờ không có dòng nào là 0 phút.
"""

import numpy as np
import pandas as pd

from .common import CATEGORIES, NIGHT_HOURS, Calendar, to_vn
from .daily import HIGH_DANGER, prepare_hourly

BASELINE_DAYS = 28
STD_FLOOR_MINUTES = 5.0
NEW_APP_KNOWN_MINUTES = 10.0
SLEEP_ACTIVE_FRACTION = 0.1  # giờ khuya mà < 10% số ngày thường có dùng máy = giờ ngủ thường lệ
MIN_DAYS_FOR_SLEEP_WINDOW = 7


def build_hourly_features(
    hourly: pd.DataFrame, *, calendar: Calendar, categories: dict[str, str]
) -> pd.DataFrame:
    """Một dòng cho mỗi giờ VN (24 giờ của mỗi ngày có dữ liệu) của mỗi trẻ."""
    h = prepare_hourly(hourly, categories)
    frames = [_profile_hours(pid, g, calendar) for pid, g in h.groupby("profileId")]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def build_day_anomaly_features(
    hourly: pd.DataFrame,
    *,
    calendar: Calendar,
    categories: dict[str, str],
    youtube: pd.DataFrame | None = None,
    ext_requests: pd.DataFrame | None = None,
) -> pd.DataFrame:
    """Một dòng cho mỗi (trẻ, ngày có dữ liệu)."""
    hours = build_hourly_features(hourly, calendar=calendar, categories=categories)
    if hours.empty:
        return pd.DataFrame()
    frames = [_profile_days(pid, g, youtube, ext_requests) for pid, g in hours.groupby("profileId")]
    return pd.concat(frames, ignore_index=True)


def _profile_hours(pid, h: pd.DataFrame, calendar: Calendar) -> pd.DataFrame:
    days = pd.DatetimeIndex(sorted(h["date"].unique()))
    day_type = calendar.day_flags(days)["day_type"].to_numpy()

    def grid(values: pd.Series) -> np.ndarray:
        g = values.groupby([h["date"], h["hour"]]).sum().unstack(fill_value=0)
        return g.reindex(index=days, columns=range(24), fill_value=0).to_numpy(dtype=float)

    minutes = grid(h["minutes"])
    by_cat = {c: grid(h["minutes"].where(h["cat"] == c, 0)) for c in CATEGORIES}

    n = len(days)
    mean, std, active_frac = (np.full((n, 24), np.nan) for _ in range(3))
    n_prior = np.zeros(n, dtype=int)
    for i, d in enumerate(days):
        prior = (days >= d - pd.Timedelta(days=BASELINE_DAYS)) & (days < d) & (day_type == day_type[i])
        n_prior[i] = prior.sum()
        if n_prior[i]:
            mean[i] = minutes[prior].mean(axis=0)
            std[i] = minutes[prior].std(axis=0)
            active_frac[i] = (minutes[prior] > 0).mean(axis=0)

    hour_of_day = np.tile(np.arange(24), (n, 1))
    is_night = np.isin(hour_of_day, NIGHT_HOURS)
    enough = (n_prior >= MIN_DAYS_FOR_SLEEP_WINDOW)[:, None]
    out = pd.DataFrame(
        {
            "profileId": pid,
            "date": np.repeat(days, 24),
            "hour": hour_of_day.ravel(),
            "day_type": np.repeat(day_type, 24),
            "hour_min": minutes.ravel(),
            **{f"hour_min_{c}": by_cat[c].ravel() for c in CATEGORIES},
            "hour_launches": grid(h["launchCount"].astype(float)).ravel(),
            "base_mean": mean.ravel(),
            "base_std": std.ravel(),
            "base_days": np.repeat(n_prior, 24),
            "hour_z": ((minutes - mean) / np.maximum(np.nan_to_num(std), STD_FLOOR_MINUTES)).ravel(),
            "is_night": is_night.ravel(),
            "in_sleep_window": (is_night & enough & (active_frac < SLEEP_ACTIVE_FRACTION)).ravel(),
            "new_app_min": _new_app_minutes(h, days).ravel(),
        }
    )
    out["slot"] = out["date"] + pd.to_timedelta(out["hour"], unit="h")
    return out


def _new_app_minutes(h: pd.DataFrame, days: pd.DatetimeIndex) -> np.ndarray:
    """Phút theo giờ của app chưa từng dùng quá 10 phút trong 28 ngày trước; NaN nếu chưa có lịch sử."""
    per_app_day = h.groupby(["date", "packageName"])["minutes"].sum().unstack(fill_value=0).reindex(days, fill_value=0)
    out = np.full((len(days), 24), np.nan)
    for i, d in enumerate(days):
        prior = (days >= d - pd.Timedelta(days=BASELINE_DAYS)) & (days < d)
        if not prior.any():
            continue
        known = per_app_day.columns[per_app_day[prior].sum(axis=0) > NEW_APP_KNOWN_MINUTES]
        today = h[(h["date"] == d) & ~h["packageName"].isin(known)]
        out[i] = today.groupby("hour")["minutes"].sum().reindex(range(24), fill_value=0).to_numpy()
    return out


def _profile_days(pid, hours: pd.DataFrame, youtube, ext) -> pd.DataFrame:
    by_day = hours.groupby("date")
    days = pd.DatetimeIndex(sorted(hours["date"].unique()))
    day_min = by_day["hour_min"].sum().reindex(days)
    day_type = by_day["day_type"].first().reindex(days).to_numpy()
    cat_min = by_day[[f"hour_min_{c}" for c in CATEGORIES]].sum().reindex(days).to_numpy()

    ratio, mix_l1 = np.full(len(days), np.nan), np.full(len(days), np.nan)
    for i, d in enumerate(days):
        window = (days >= d - pd.Timedelta(days=BASELINE_DAYS)) & (days < d)
        same = window & (day_type == day_type[i])
        if same.any() and day_min[same].mean() > 0:
            ratio[i] = day_min.iloc[i] / day_min[same].mean()
        if window.any() and cat_min[window].sum() > 0 and cat_min[i].sum() > 0:
            today_mix = cat_min[i] / cat_min[i].sum()
            usual_mix = cat_min[window].sum(axis=0) / cat_min[window].sum()
            mix_l1[i] = np.abs(today_mix - usual_mix).sum()

    # Khung khuya trong CHÍNH ngày d (0–5h sáng và 22–23h), khớp với nhãn/giờ của ngày đó
    night_min = hours[hours["is_night"]].groupby("date")["hour_min"].sum().reindex(days, fill_value=0)
    high_danger = lambda df: df["dangerLevel"] >= HIGH_DANGER  # noqa: E731
    return pd.DataFrame(
        {
            "profileId": pid,
            "date": days,
            "day_type": day_type,
            "day_min": day_min.to_numpy(),
            "day_ratio": ratio,
            "night_min": night_min.to_numpy(),
            "max_hour_min": by_day["hour_min"].max().reindex(days).to_numpy(),
            "n_active_hours": by_day["hour_min"].apply(lambda s: (s > 0).sum()).reindex(days).to_numpy(),
            "mix_l1": mix_l1,
            "new_app_min": by_day["new_app_min"].sum(min_count=1).reindex(days).to_numpy(),
            "yt_danger_high": _count_per_day(youtube, pid, "watchedAt", days, high_danger),
            "ext_req": _count_per_day(ext, pid, "createdAt", days),
        }
    )


def _count_per_day(df, pid, ts_col, days, where=None) -> np.ndarray:
    if df is None or df.empty:
        return np.zeros(len(days))
    rows = df[df["profileId"] == pid]
    if where is not None:
        rows = rows[where(rows).fillna(False).astype(bool)]
    date = to_vn(rows[ts_col]).dt.normalize()
    return date.value_counts().reindex(days, fill_value=0).to_numpy(dtype=float)
