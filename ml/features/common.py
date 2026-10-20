"""Phần dùng chung cho đặc trưng M1/M2: giờ VN, lịch năm học VN, nhóm app.

Quy ước theo docs/thesis/05-dac-ta-dac-trung.md mục 0:
- mọi đặc trưng tính theo giờ VN (UTC+7), không dùng giờ máy chủ;
- dayOfWeek: 0 = Chủ nhật … 6 = thứ Bảy (trùng TimeLimit và vnDayRange() ở backend).
"""

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"
VN_OFFSET = pd.Timedelta(hours=7)
NIGHT_HOURS = (22, 23, 0, 1, 2, 3, 4, 5)  # khung khuya 22:00–06:00
CATEGORIES = ("video", "game", "social", "study", "other")
OFF_KINDS = ("holiday", "school_break", "summer")


def to_vn(ts: pd.Series) -> pd.Series:
    """Mốc UTC (có hoặc không gắn múi giờ) -> giờ VN dạng naive."""
    ts = pd.to_datetime(ts, utc=True)
    return ts.dt.tz_localize(None) + VN_OFFSET


def vn_dow(dates) -> np.ndarray:
    """0 = Chủ nhật … 6 = thứ Bảy."""
    return (pd.DatetimeIndex(dates).weekday.to_numpy() + 1) % 7


def night_key(local: pd.Series) -> pd.Series:
    """Đêm mà một giờ VN thuộc về: 22–23h ngày d và 0–5h ngày d+1 đều là đêm d."""
    return (local - pd.Timedelta(hours=6)).dt.normalize()


def load_categories(path: Path = CONFIG_DIR / "app_categories.csv") -> dict[str, str]:
    df = pd.read_csv(path)
    unknown = set(df["category"]) - set(CATEGORIES)
    if unknown:
        raise ValueError(f"Nhóm app không hợp lệ trong {path}: {sorted(unknown)}")
    return dict(zip(df["packageName"], df["category"]))


def categorize(packages: pd.Series, mapping: dict[str, str]) -> pd.Series:
    return packages.map(mapping).fillna("other")


@dataclass(frozen=True)
class Calendar:
    """Lịch năm học + ngày lễ VN (ml/config/vn_school_calendar.csv)."""

    periods: pd.DataFrame

    @classmethod
    def load(cls, path: Path = CONFIG_DIR / "vn_school_calendar.csv") -> "Calendar":
        df = pd.read_csv(path, parse_dates=["start", "end"])
        if (df["end"] < df["start"]).any():
            raise ValueError(f"Có khoảng end < start trong {path}")
        return cls(df)

    def _in(self, dates: pd.DatetimeIndex, kinds) -> np.ndarray:
        rows = self.periods[self.periods["kind"].isin(kinds)]
        hit = np.zeros(len(dates), dtype=bool)
        for start, end in zip(rows["start"], rows["end"]):
            hit |= (dates >= start) & (dates <= end)
        return hit

    def day_flags(self, dates) -> pd.DataFrame:
        """Cờ lịch cho từng ngày; index = ngày."""
        dates = pd.DatetimeIndex(dates).normalize()
        dow = vn_dow(dates)
        is_weekend = np.isin(dow, (0, 6))
        is_off = self._in(dates, OFF_KINDS)
        is_school_day = self._in(dates, ("school_year",)) & ~is_weekend & ~is_off
        day_type = np.where(is_school_day, "school", np.where(is_off, "off", "weekend"))
        return pd.DataFrame(
            {
                "dow": dow,
                "is_weekend": is_weekend,
                "is_holiday": self._in(dates, ("holiday",)),
                "is_school_day": is_school_day,
                "is_exam_period": self._in(dates, ("exam",)),
                "is_summer": self._in(dates, ("summer",)),
                "day_type": day_type,
                "days_to_next_holiday": self._days_to_next_off(dates),
            },
            index=dates,
        )

    def _days_to_next_off(self, dates: pd.DatetimeIndex) -> np.ndarray:
        """Số ngày tới ngày nghỉ (lễ / nghỉ Tết / hè) gần nhất; 0 nếu đang nghỉ; NaN nếu ngoài lịch."""
        rows = self.periods[self.periods["kind"].isin(OFF_KINDS)]
        out = np.full(len(dates), np.nan)
        for i, d in enumerate(dates):
            if ((rows["start"] <= d) & (rows["end"] >= d)).any():
                out[i] = 0
                continue
            ahead = rows.loc[rows["start"] > d, "start"]
            if len(ahead):
                out[i] = (ahead.min() - d).days
        return out
