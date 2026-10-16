"""EDA bộ dữ liệu StudentLife (Wang và cộng sự, UbiComp 2014) cho đồ án chuyên ngành.

Bổ sung cho EDA LSApp ở hai điểm LSApp thiếu: mỗi người có NHIỀU tuần dữ liệu và dấu thời gian
là Unix epoch + địa điểm biết trước (Dartmouth, giờ America/New_York) → kiểm tra được chu kỳ
tuần và phân bố theo giờ địa phương.

Giới hạn của dữ liệu (đã kiểm tra, xem docs/thesis/03-eda-studentlife.md):
  - other/app_usage: ẢNH CHỤP danh sách task đang chạy mỗi 20 phút, không phải sự kiện mở/đóng
    → không đo được số phút dùng app. Dùng "chỉ số hoạt động" = số ảnh chụp có app thật ở trên
    cùng, ngoài khoảng khoá máy dài.
  - sensing/phonelock: chỉ ghi lần khoá máy ≥ 60 phút → dùng làm tín hiệu ngủ/nghỉ.

Chạy (dữ liệu: Zenodo record 3529253, bản RDS CC-BY-4.0 của dataset gốc):
    ml/.venv/bin/python ml/eda/studentlife_eda.py <thư-mục-dataset_rds> ml/reports
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import pyreadr  # noqa: E402

TZ = "America/New_York"
SNAPSHOT_MINUTES = 20
SNAPSHOTS_PER_DAY = 24 * 60 // SNAPSHOT_MINUTES
MIN_COVERAGE = 0.5  # ngày hợp lệ: có ≥ 50% số ảnh chụp
NIGHT_HOURS = {22, 23, 0, 1, 2, 3, 4, 5}
# Ảnh chụp mà app trên cùng là một trong các package này thì không tính là "đang dùng app"
NON_USAGE_PACKAGES = (
    "com.google.android.apps.paco",  # app thu thập dữ liệu của nghiên cứu
    "launcher",
    "home",
    "com.android.systemui",
    "com.android.deskclock",
    "com.google.android.deskclock",
    "keyguard",
    "lockscreen",
    "screenlock",  # app màn hình khoá bên thứ ba, vd com.jiubang.goscreenlock
)


def load(rds_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    apps = pyreadr.read_r(rds_dir / "other" / "app_usage.Rds")[None]
    locks = pyreadr.read_r(rds_dir / "sensing" / "phonelock.Rds")[None]
    apps["uid"] = apps["uid"].astype(str)
    locks["uid"] = locks["uid"].astype(str)
    return apps, locks


def snapshots(apps: pd.DataFrame, locks: pd.DataFrame) -> pd.DataFrame:
    """Mỗi ảnh chụp một dòng: app trên cùng, giờ địa phương, có đang trong khoảng khoá dài không."""
    top = apps.groupby(["uid", "timestamp"], sort=False).head(1)
    snap = top[["uid", "timestamp", "RUNNING_TASKS_topActivity_mPackage"]].rename(
        columns={"RUNNING_TASKS_topActivity_mPackage": "package"}
    )
    snap["package"] = snap["package"].fillna("")
    snap["local"] = pd.to_datetime(snap["timestamp"], unit="s", utc=True).dt.tz_convert(TZ)

    snap["locked"] = False
    for uid, user_locks in locks.groupby("uid"):
        idx = snap.index[snap["uid"] == uid]
        ts = snap.loc[idx, "timestamp"].to_numpy()
        order = np.argsort(user_locks["start_timestamp"].to_numpy())
        starts = user_locks["start_timestamp"].to_numpy()[order]
        ends = user_locks["end_timestamp"].to_numpy()[order]
        pos = np.searchsorted(starts, ts, side="right") - 1
        inside = (pos >= 0) & (ts < ends[np.clip(pos, 0, None)])
        snap.loc[idx, "locked"] = inside

    pattern = "|".join(NON_USAGE_PACKAGES)
    snap["active"] = ~snap["locked"] & (snap["package"] != "") & ~snap["package"].str.contains(pattern)
    return snap


def daily_activity(snap: pd.DataFrame) -> pd.DataFrame:
    snap = snap.assign(date=snap["local"].dt.tz_localize(None).dt.normalize())
    daily = snap.groupby(["uid", "date"]).agg(n=("active", "size"), active=("active", "sum")).reset_index()
    daily = daily[daily["n"] >= MIN_COVERAGE * SNAPSHOTS_PER_DAY].copy()
    # Quy về "phút hoạt động ước lượng" trên ngày đủ 72 ảnh chụp, để so sánh được giữa các ngày
    daily["active_minutes"] = daily["active"] / daily["n"] * SNAPSHOTS_PER_DAY * SNAPSHOT_MINUTES
    daily["weekend"] = daily["date"].dt.dayofweek >= 5
    return daily


def bedtimes(locks: pd.DataFrame) -> pd.DataFrame:
    """Giờ bắt đầu lần khoá máy dài nhất của mỗi đêm (đêm tính từ 18h hôm trước tới 18h)."""
    df = locks.copy()
    df["start"] = pd.to_datetime(df["start_timestamp"], unit="s", utc=True).dt.tz_convert(TZ).dt.tz_localize(None)
    df["minutes"] = (df["end_timestamp"] - df["start_timestamp"]) / 60
    df["night"] = (df["start"] - pd.Timedelta(hours=18)).dt.normalize()
    longest = df.loc[df.groupby(["uid", "night"], observed=True)["minutes"].idxmax()]
    longest = longest[longest["minutes"] >= 180].copy()  # lần khoá ≥ 3 giờ mới coi là ngủ
    # Giờ đi ngủ tính theo "giờ sau 18h" để 23h và 1h sáng nằm liền nhau
    longest["bed_hour"] = ((longest["start"] - longest["night"]).dt.total_seconds() / 3600) - 18
    # Đêm của thứ Sáu và thứ Bảy (ngày hôm sau là cuối tuần)
    longest["before_weekend"] = longest["night"].dt.dayofweek.isin([4, 5])
    return longest


def forecast_baselines(daily: pd.DataFrame) -> dict:
    errors = {"naive": [], "seasonal_naive_7": [], "ma7": []}
    acf1, acf7 = [], []
    for _, series in daily.groupby("uid"):
        s = series.set_index("date")["active_minutes"].asfreq("D")
        acf1.append(s.autocorr(1))
        acf7.append(s.autocorr(7))
        for t in range(7, len(s)):
            actual, window = s.iloc[t], s.iloc[t - 7 : t]
            if np.isnan(actual) or window.isna().any():
                continue
            errors["naive"].append(abs(actual - s.iloc[t - 1]))
            errors["seasonal_naive_7"].append(abs(actual - s.iloc[t - 7]))
            errors["ma7"].append(abs(actual - window.mean()))
    return {
        "mae": {k: float(np.mean(v)) for k, v in errors.items()},
        "n_predictions": len(errors["naive"]),
        "acf_lag1_median": float(np.nanmedian(acf1)),
        "acf_lag7_median": float(np.nanmedian(acf7)),
    }


def save_figures(snap: pd.DataFrame, beds: pd.DataFrame, out_dir: Path) -> pd.Series:
    active = snap[snap["active"]]
    hour_share = active["local"].dt.hour.value_counts(normalize=True).sort_index()

    fig, ax = plt.subplots(figsize=(8, 3.2))
    ax.bar(hour_share.index, hour_share.values * 100, color="#1f3a6e")
    ax.set_xlabel("Giờ địa phương (America/New_York)")
    ax.set_ylabel("% ảnh chụp có hoạt động")
    ax.set_xticks(range(0, 24, 2))
    fig.tight_layout()
    fig.savefig(out_dir / "studentlife_hour_profile.png", dpi=150)
    plt.close(fig)

    heat = pd.crosstab(active["local"].dt.dayofweek, active["local"].dt.hour, normalize="all") * 100
    fig, ax = plt.subplots(figsize=(8, 3))
    image = ax.imshow(heat, aspect="auto", cmap="Blues")
    ax.set_yticks(range(7), ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
    ax.set_xticks(range(0, 24, 2))
    ax.set_xlabel("Giờ địa phương")
    fig.colorbar(image, ax=ax, label="% ảnh chụp có hoạt động")
    fig.tight_layout()
    fig.savefig(out_dir / "studentlife_heatmap_weekday_hour.png", dpi=150)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 3.2))
    bins = np.arange(0, 14.5, 0.5) + 18
    ax.hist(beds.loc[~beds["before_weekend"], "bed_hour"] + 18, bins=bins, alpha=0.7,
            label="Đêm trước ngày thường", color="#1f3a6e", density=True)
    ax.hist(beds.loc[beds["before_weekend"], "bed_hour"] + 18, bins=bins, alpha=0.6,
            label="Đêm thứ Sáu, thứ Bảy", color="#a8620a", density=True)
    ticks = range(18, 33, 2)
    ax.set_xticks(list(ticks), [f"{h % 24}h" for h in ticks])
    ax.set_xlabel("Giờ bắt đầu lần khoá máy dài nhất trong đêm (giờ đi ngủ ước lượng)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_dir / "studentlife_bedtime.png", dpi=150)
    plt.close(fig)
    return hour_share


def fmt_hour(h: float) -> str:
    total = int(round((h + 18) * 60)) % (24 * 60)
    return f"{total // 60:02d}:{total % 60:02d}"


def main(rds_dir: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    apps, locks = load(rds_dir)
    snap = snapshots(apps, locks)
    daily = daily_activity(snap)
    beds = bedtimes(locks)
    baselines = forecast_baselines(daily)
    hour_share = save_figures(snap, beds, out_dir)

    days_per_user = daily.groupby("uid")["date"].nunique()
    weekday_mean = daily.loc[~daily["weekend"], "active_minutes"].mean()
    weekend_mean = daily.loc[daily["weekend"], "active_minutes"].mean()
    night_share = hour_share[hour_share.index.isin(NIGHT_HOURS)].sum()
    bed_weekday = beds.loc[~beds["before_weekend"], "bed_hour"].median()
    bed_weekend = beds.loc[beds["before_weekend"], "bed_hour"].median()
    top_packages = snap.loc[snap["active"], "package"].value_counts(normalize=True).head(10)
    excluded = 1 - snap["active"].mean()

    lines = [
        "# EDA bộ dữ liệu StudentLife",
        "",
        "> Sinh tự động bởi `ml/eda/studentlife_eda.py`. Nguồn: Zenodo record 3529253 (bản RDS của",
        "> https://studentlife.cs.dartmouth.edu). Giờ địa phương: America/New_York.",
        "",
        "## 1. Quy mô",
        "",
        "| Chỉ số | Giá trị |",
        "|---|---|",
        f"| Số sinh viên | {snap['uid'].nunique()} |",
        f"| Ảnh chụp danh sách app (mỗi {SNAPSHOT_MINUTES} phút) | {len(snap):,} |",
        f"| Khoảng thời gian | {snap['local'].min():%Y-%m-%d} → {snap['local'].max():%Y-%m-%d} |",
        f"| Ngày hợp lệ / người (≥ {MIN_COVERAGE:.0%} ảnh chụp; trung vị; min; max) | "
        f"{days_per_user.median():.0f}; {days_per_user.min()}; {days_per_user.max()} |",
        f"| Ảnh chụp bị loại (khoá máy dài, app nghiên cứu, launcher, hệ thống) | {excluded:.1%} |",
        f"| Lần khoá máy ≥ 60 phút | {len(locks):,} |",
        "",
        "## 2. Phân bố theo giờ địa phương",
        "",
        f"- Tỷ lệ ảnh chụp có hoạt động trong 22:00–06:00: **{night_share:.1%}**.",
        f"- Giờ hoạt động nhiều nhất: {int(hour_share.idxmax())}h; ít nhất: {int(hour_share.idxmin())}h.",
        "",
        "![Phân bố theo giờ](studentlife_hour_profile.png)",
        "",
        "![Heatmap thứ × giờ](studentlife_heatmap_weekday_hour.png)",
        "",
        "## 3. Chu kỳ tuần",
        "",
        f"- Chỉ số hoạt động trung bình (phút ước lượng/ngày): ngày thường {weekday_mean:.0f}, "
        f"cuối tuần {weekend_mean:.0f} (chênh {(weekend_mean / weekday_mean - 1):+.0%}).",
        f"- Giờ đi ngủ ước lượng (trung vị): đêm trước ngày thường {fmt_hour(bed_weekday)}, "
        f"đêm thứ Sáu/thứ Bảy {fmt_hour(bed_weekend)} ({len(beds):,} đêm).",
        f"- Tự tương quan chuỗi theo ngày (trung vị): trễ 1 ngày = {baselines['acf_lag1_median']:.2f}, "
        f"trễ 7 ngày = {baselines['acf_lag7_median']:.2f}.",
        "",
        "![Giờ đi ngủ ước lượng](studentlife_bedtime.png)",
        "",
        "### Mô hình cơ sở trên chỉ số hoạt động (walk-forward, MAE theo phút ước lượng)",
        "",
        "| Mô hình | MAE |",
        "|---|---|",
        *[f"| {name} | {mae:.1f} |" for name, mae in baselines["mae"].items()],
        "",
        f"Số lượt dự đoán: {baselines['n_predictions']:,}.",
        "",
        "## 4. Top 10 app trên cùng (trong các ảnh chụp có hoạt động)",
        "",
        "| Package | Tỷ lệ |",
        "|---|---|",
        *[f"| {pkg} | {share:.1%} |" for pkg, share in top_packages.items()],
        "",
    ]
    (out_dir / "studentlife_eda.md").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Cách dùng: studentlife_eda.py <thư-mục-dataset_rds> <thư-mục-kết-quả>")
    main(Path(sys.argv[1]), Path(sys.argv[2]))
