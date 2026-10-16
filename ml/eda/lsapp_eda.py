"""EDA bộ dữ liệu LSApp (Aliannejadi và cộng sự, ACM TOIS 2021) cho đồ án chuyên ngành.

Mục tiêu: kiểm tra LSApp dùng được tới đâu cho
  - M1 (dự đoán tổng thời gian dùng máy ngày mai): mỗi người có đủ số ngày không?
    chuỗi theo ngày có tính chu kỳ / tự tương quan không? mô hình cơ sở sai số bao nhiêu?
  - M2 (bất thường theo giờ): phân bố theo giờ trong ngày, tỷ lệ dùng lúc khuya.

Chạy:
    ml/.venv/bin/python ml/eda/lsapp_eda.py <đường-dẫn-lsapp.tsv.gz> ml/reports

Dữ liệu tải từ https://github.com/aliannejadi/LSApp (file lsapp.tsv.gz — thực chất là tar.gz
bọc lsapp.tsv). Không commit dữ liệu vào repo.
"""

import sys
import tarfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

MAX_SESSION_SECONDS = 3 * 3600  # cặp Opened/Closed dài hơn coi là lỗi ghép
MIN_DAYS_FOR_FORECAST = 14
NIGHT_HOURS = {22, 23, 0, 1, 2, 3, 4, 5}
HOUR = pd.Timedelta(hours=1)


def load(path: Path) -> pd.DataFrame:
    with tarfile.open(path) as archive:
        member = next(m for m in archive.getmembers() if m.name.endswith("lsapp.tsv"))
        df = pd.read_csv(archive.extractfile(member), sep="\t")
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    return df


def build_sessions(df: pd.DataFrame) -> pd.DataFrame:
    """Ghép Opened → Closed kế tiếp của cùng (user, app) thành một phiên dùng app."""
    events = df[df["event_type"].isin(["Opened", "Closed"])].sort_values(
        ["user_id", "app_name", "timestamp"], kind="stable"
    )
    nxt = events.groupby(["user_id", "app_name"]).shift(-1)
    is_pair = (events["event_type"] == "Opened") & (nxt["event_type"] == "Closed")
    pairs = events[is_pair].copy()
    pairs["end"] = nxt.loc[is_pair, "timestamp"]
    pairs["seconds"] = (pairs["end"] - pairs["timestamp"]).dt.total_seconds()
    valid = pairs[(pairs["seconds"] > 0) & (pairs["seconds"] <= MAX_SESSION_SECONDS)]
    return valid.rename(columns={"timestamp": "start"})[["user_id", "app_name", "start", "end", "seconds"]]


def hourly_usage(sessions: pd.DataFrame) -> pd.DataFrame:
    """Cắt từng phiên theo ranh giới giờ (cùng cách HourlyBucketer làm trên app trẻ).

    Phiên dài tối đa 3 giờ nên chạm tối đa 4 ô giờ: tính lần lượt từng ô theo vector.
    """
    pieces = []
    first_hour = sessions["start"].dt.floor("h")
    for k in range(4):
        hour_start = first_hour + k * HOUR
        piece_start = np.maximum(sessions["start"], hour_start)
        piece_end = np.minimum(sessions["end"], hour_start + HOUR)
        seconds = (piece_end - piece_start).dt.total_seconds()
        mask = seconds > 0
        pieces.append(
            pd.DataFrame(
                {
                    "user_id": sessions.loc[mask, "user_id"].values,
                    "app_name": sessions.loc[mask, "app_name"].values,
                    "hour_start": hour_start[mask].values,
                    "seconds": seconds[mask].values,
                }
            )
        )
    return pd.concat(pieces, ignore_index=True)


def forecast_baselines(daily: pd.DataFrame) -> dict:
    """MAE (phút) của 3 mô hình cơ sở trong kế hoạch, walk-forward, trên người đủ ngày.

    Ngày không có sự kiện nào là THIẾU dữ liệu (app ghi log có thể không chạy), không phải
    0 phút — nên không lấp 0; lượt dự đoán nào thiếu đầu vào hoặc giá trị thật thì bỏ qua.
    """
    errors = {"naive": [], "seasonal_naive_7": [], "ma7": []}
    acf1, acf7 = [], []
    for _, series in daily.groupby("user_id"):
        if len(series) < MIN_DAYS_FOR_FORECAST:
            continue
        s = series.set_index("date")["minutes"].asfreq("D")
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
        "n_users": len(acf1),
        "acf_lag1_median": float(np.nanmedian(acf1)),
        "acf_lag7_median": float(np.nanmedian(acf7)) if acf7 else float("nan"),
    }


def save_figures(hour_share: pd.Series, active_days: pd.Series, hourly: pd.DataFrame, out_dir: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 3.2))
    ax.bar(hour_share.index, hour_share.values * 100, color="#1f3a6e")
    ax.set_xlabel("Giờ trong ngày (giờ ghi trong dữ liệu)")
    ax.set_ylabel("% tổng thời gian dùng")
    ax.set_xticks(range(0, 24, 2))
    fig.tight_layout()
    fig.savefig(out_dir / "lsapp_hour_profile.png", dpi=150)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 3.2))
    ax.hist(active_days, bins=range(0, int(active_days.max()) + 2, 2), color="#1b7a55")
    ax.axvline(MIN_DAYS_FOR_FORECAST, color="#a8620a", linestyle="--", label=f"{MIN_DAYS_FOR_FORECAST} ngày")
    ax.set_xlabel("Số ngày có dữ liệu của mỗi người")
    ax.set_ylabel("Số người")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_dir / "lsapp_active_days.png", dpi=150)
    plt.close(fig)

    heat = hourly.pivot_table(index="weekday", columns="hour", values="seconds", aggfunc="sum").fillna(0)
    fig, ax = plt.subplots(figsize=(8, 3))
    image = ax.imshow(heat / heat.values.sum() * 100, aspect="auto", cmap="Blues")
    ax.set_yticks(range(7), ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
    ax.set_xticks(range(0, 24, 2))
    ax.set_xlabel("Giờ trong ngày")
    fig.colorbar(image, ax=ax, label="% tổng thời gian")
    fig.tight_layout()
    fig.savefig(out_dir / "lsapp_heatmap_weekday_hour.png", dpi=150)
    plt.close(fig)


def main(data_path: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    df = load(data_path)

    active_days = df.assign(date=df["timestamp"].dt.date).groupby("user_id")["date"].nunique()
    span_days = df.groupby("user_id")["timestamp"].agg(lambda t: (t.max() - t.min()).days)

    sessions = build_sessions(df)
    hourly = hourly_usage(sessions)
    hourly["hour"] = hourly["hour_start"].dt.hour
    hourly["weekday"] = hourly["hour_start"].dt.dayofweek

    by_hour = hourly.groupby("hour")["seconds"].sum()
    hour_share = by_hour / by_hour.sum()
    night_share = float(hour_share[hour_share.index.isin(NIGHT_HOURS)].sum())

    daily = (
        hourly.assign(date=hourly["hour_start"].dt.normalize())
        .groupby(["user_id", "date"])["seconds"].sum()
        .div(60).rename("minutes").reset_index()
    )
    is_weekend = daily["date"].dt.dayofweek >= 5
    weekday_mean = float(daily.loc[~is_weekend, "minutes"].mean())
    weekend_mean = float(daily.loc[is_weekend, "minutes"].mean())
    baselines = forecast_baselines(daily)

    top_apps = sessions.groupby("app_name")["seconds"].sum().div(3600).sort_values(ascending=False).head(10)
    save_figures(hour_share, active_days, hourly, out_dir)

    eligible = int((active_days >= MIN_DAYS_FOR_FORECAST).sum())
    event_counts = ", ".join(f"{k}: {v:,}" for k, v in df["event_type"].value_counts().items())
    lines = [
        "# EDA bộ dữ liệu LSApp",
        "",
        "> Sinh tự động bởi `ml/eda/lsapp_eda.py`. Nguồn: https://github.com/aliannejadi/LSApp",
        "",
        "## 1. Quy mô",
        "",
        "| Chỉ số | Giá trị |",
        "|---|---|",
        f"| Số dòng sự kiện | {len(df):,} |",
        f"| Loại sự kiện | {event_counts} |",
        f"| Số người | {df['user_id'].nunique()} |",
        f"| Số app | {df['app_name'].nunique()} |",
        f"| Khoảng thời gian toàn bộ | {df['timestamp'].min():%Y-%m-%d} → {df['timestamp'].max():%Y-%m-%d} |",
        f"| Số ngày có dữ liệu / người (trung vị; trung bình; max) | {active_days.median():.0f}; {active_days.mean():.1f}; {active_days.max()} |",
        f"| Từ sự kiện đầu đến cuối / người (trung vị; trung bình) | {span_days.median():.0f}; {span_days.mean():.1f} ngày |",
        f"| Người có ≥ {MIN_DAYS_FOR_FORECAST} ngày dữ liệu | {eligible} |",
        f"| Người có ≥ 28 ngày dữ liệu | {int((active_days >= 28).sum())} |",
        f"| Phiên dùng app ghép được (Opened→Closed, ≤ 3 giờ) | {len(sessions):,} |",
        f"| Độ dài phiên (trung vị; trung bình) | {sessions['seconds'].median():.0f} s; {sessions['seconds'].mean():.0f} s |",
        "",
        "![Số ngày có dữ liệu](lsapp_active_days.png)",
        "",
        "## 2. Phân bố theo giờ",
        "",
        f"- Tỷ lệ thời gian dùng trong khung khuya 22:00–06:00: **{night_share * 100:.1f}%**.",
        f"- Giờ dùng nhiều nhất: {int(hour_share.idxmax())}h ({hour_share.max() * 100:.1f}%); "
        f"ít nhất: {int(hour_share.idxmin())}h ({hour_share.min() * 100:.2f}%).",
        "",
        "![Phân bố theo giờ](lsapp_hour_profile.png)",
        "",
        "![Heatmap thứ × giờ](lsapp_heatmap_weekday_hour.png)",
        "",
        "## 3. Tổng thời gian theo ngày",
        "",
        f"- Trung bình ngày thường: {weekday_mean:.0f} phút; cuối tuần: {weekend_mean:.0f} phút "
        f"(chênh {(weekend_mean / weekday_mean - 1) * 100:+.0f}%).",
        f"- Tự tương quan chuỗi theo ngày ({baselines['n_users']} người ≥ {MIN_DAYS_FOR_FORECAST} ngày, trung vị): "
        f"trễ 1 ngày = {baselines['acf_lag1_median']:.2f}, trễ 7 ngày = {baselines['acf_lag7_median']:.2f}.",
        "",
        "### Mô hình cơ sở (walk-forward, MAE theo phút)",
        "",
        "| Mô hình | MAE (phút) |",
        "|---|---|",
        *[f"| {name} | {mae:.1f} |" for name, mae in baselines["mae"].items()],
        "",
        f"Số lượt dự đoán: {baselines['n_predictions']:,} (từ ngày thứ 8 của mỗi người đủ điều kiện).",
        "",
        "## 4. Top 10 app theo tổng giờ dùng",
        "",
        "| App | Giờ |",
        "|---|---|",
        *[f"| {app} | {hours:,.0f} |" for app, hours in top_apps.items()],
        "",
    ]
    (out_dir / "lsapp_eda.md").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Cách dùng: lsapp_eda.py <lsapp.tsv.gz> <thư-mục-kết-quả>")
    main(Path(sys.argv[1]), Path(sys.argv[2]))
