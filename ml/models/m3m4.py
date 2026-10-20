"""M3 (gọn) — nhóm thói quen bằng K-Means + heatmap; M4 (gọn) — hệ luật gợi ý cho phụ huynh.

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m3m4 --sim data/sim --out reports
"""

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.cluster import KMeans  # noqa: E402
from sklearn.metrics import adjusted_rand_score, silhouette_score  # noqa: E402
from sklearn.preprocessing import StandardScaler  # noqa: E402

from features import Calendar, build_hourly_features, load_categories  # noqa: E402
from features.common import CATEGORIES, NIGHT_HOURS  # noqa: E402

from .explain import minutes  # noqa: E402
from .m1.data import load_sim  # noqa: E402

HABIT_END = pd.Timestamp("2026-06-01")  # dùng năm học (trước hè) để mô tả thói quen
K_RANGE = range(3, 7)
SUGGEST_AS_OF = pd.Timestamp("2026-05-15")
WINDOW_DAYS = 28
LATE_MINUTES = 10
LATE_HOURS = {"3-5": NIGHT_HOURS, "6-10": NIGHT_HOURS}  # trẻ lớn (11+) quen ngủ muộn hơn: chỉ tính sau nửa đêm
LATE_HOURS_OLDER = (0, 1, 2, 3, 4, 5)
TRAITS = {  # đặc điểm dùng để mô tả nhóm: tên cột -> (cụm từ khi cao, cụm từ khi thấp)
    "log_daily_min": ("dùng nhiều", "dùng ít"),
    "night_share": ("hay dùng khuya", "hầu như không dùng khuya"),
    "weekend_ratio": ("cuối tuần tăng mạnh", "cuối tuần gần như ngày thường"),
    "share_video": ("nghiêng về video", "ít video"),
    "share_game": ("nghiêng về game", "ít game"),
    "share_social": ("nghiêng về mạng xã hội", "ít mạng xã hội"),
}
WHO_MAX_MINUTES_YOUNG = 60  # WHO 2019: trẻ 2–4 tuổi không quá 1 giờ/ngày (áp gần đúng cho nhóm 3–5)


# ----------------------------------------------------------------------------------------------- M3
def habit_vectors(hours: pd.DataFrame) -> pd.DataFrame:
    """Một dòng / trẻ: phân bố 24 giờ ngày học và ngày không học (tỷ lệ), cơ cấu nhóm app, mức dùng."""
    rows = {}
    for pid, g in hours.groupby("profileId"):
        vec = {}
        for kind, part in (("school", g[g["day_type"] == "school"]), ("weekend", g[g["day_type"] != "school"])):
            by_hour = part.groupby("hour")["hour_min"].mean().reindex(range(24), fill_value=0)
            vec.update({f"{kind}_h{h:02d}": v for h, v in (by_hour / max(by_hour.sum(), 1e-9)).items()})
            vec[f"{kind}_daily_min"] = part.groupby("date")["hour_min"].sum().mean()
        cats = g[[f"hour_min_{c}" for c in CATEGORIES]].sum()
        vec.update({f"share_{c}": v for c, v in zip(CATEGORIES, cats / max(cats.sum(), 1e-9))})
        vec["night_share"] = g.loc[g["hour"].isin(NIGHT_HOURS), "hour_min"].sum() / max(g["hour_min"].sum(), 1e-9)
        vec["weekend_ratio"] = vec["weekend_daily_min"] / max(vec["school_daily_min"], 1e-9)
        rows[pid] = vec
    out = pd.DataFrame.from_dict(rows, orient="index")
    out["log_daily_min"] = np.log1p(out[["school_daily_min", "weekend_daily_min"]].mean(axis=1))
    return out.drop(columns=["school_daily_min", "weekend_daily_min"])


def cluster(vectors: pd.DataFrame) -> tuple[np.ndarray, int, dict]:
    z = StandardScaler().fit_transform(vectors)
    scores = {k: silhouette_score(z, KMeans(k, n_init=10, random_state=0).fit_predict(z)) for k in K_RANGE}
    best = max(scores, key=scores.get)
    return KMeans(best, n_init=10, random_state=0).fit_predict(z), best, scores


def traits(vectors: pd.DataFrame, members: pd.Index, k: int = 2) -> str:
    """Mô tả nhóm bằng k đặc điểm lệch nhiều nhất so với toàn bộ trẻ (theo độ lệch chuẩn)."""
    cols = list(TRAITS)
    z = (vectors.loc[members, cols].mean() - vectors[cols].mean()) / vectors[cols].std()
    top = z.abs().sort_values(ascending=False).index[:k]
    return ", ".join(TRAITS[c][0] if z[c] > 0 else TRAITS[c][1] for c in top)


def describe(vectors: pd.DataFrame, labels: np.ndarray, daily_min: pd.Series, ages: pd.Series) -> pd.DataFrame:
    rows = []
    for c in sorted(set(labels)):
        v = vectors[labels == c]
        rows.append(
            {
                "nhóm": c,
                "số trẻ": len(v),
                "mô tả": traits(vectors, v.index),
                "phút/ngày": round(daily_min[v.index].mean()),
                "tỷ lệ khuya": round(v["night_share"].mean(), 3),
                "ngày nghỉ / ngày học": round(v["weekend_ratio"].mean(), 2),
                "nhóm tuổi phổ biến": ages[v.index].mode().iloc[0],
            }
        )
    return pd.DataFrame(rows).set_index("nhóm")


def plot_heatmaps(hours: pd.DataFrame, labels: pd.Series, path: Path) -> None:
    clusters = sorted(labels.unique())
    fig, axes = plt.subplots(1, len(clusters), figsize=(4 * len(clusters), 3), squeeze=False)
    for ax, c in zip(axes[0], clusters):
        part = hours[hours["profileId"].isin(labels[labels == c].index)]
        heat = part.groupby([part["date"].dt.dayofweek, part["hour"]])["hour_min"].mean().unstack(fill_value=0)
        ax.imshow(heat.to_numpy(), aspect="auto", cmap="viridis")
        ax.set_title(f"Nhóm {c}")
        ax.set_yticks(range(7), ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
        ax.set_xticks(range(0, 24, 6))
        ax.set_xlabel("giờ")
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


# ----------------------------------------------------------------------------------------------- M4
def round15(m: float) -> int:
    return int(max(15, round(m / 15) * 15))


def child_stats(
    hours: pd.DataFrame, limits: pd.DataFrame, ext: pd.DataFrame, ages: pd.Series, as_of: pd.Timestamp
) -> pd.DataFrame:
    """Thống kê 28 ngày trước as_of cho từng trẻ — đầu vào của hệ luật gợi ý."""
    start = as_of - pd.Timedelta(days=WINDOW_DAYS)
    window = hours[(hours["date"] >= start) & (hours["date"] < as_of)]
    daily = window.groupby(["profileId", "date", "day_type"])["hour_min"].sum().reset_index()
    daily["dow"] = (daily["date"].dt.dayofweek + 1) % 7
    daily = daily.merge(
        limits[["profileId", "dayOfWeek", "dailyLimitMinutes"]],
        left_on=["profileId", "dow"],
        right_on=["profileId", "dayOfWeek"],
        how="left",
    )
    daily["reached"] = (daily["hour_min"] >= daily["dailyLimitMinutes"] - 1).where(daily["dailyLimitMinutes"].notna())
    ext_date = (pd.to_datetime(ext["createdAt"], utc=True).dt.tz_localize(None) + pd.Timedelta(hours=7)).dt.normalize()
    ext_window = ext[(ext_date >= start) & (ext_date < as_of)]
    late_hours = window["profileId"].map(lambda p: LATE_HOURS.get(ages.get(p), LATE_HOURS_OLDER))
    is_late = [h in hs for h, hs in zip(window["hour"], late_hours)]
    late = window[np.array(is_late, dtype=bool) & (window["hour_min"] >= LATE_MINUTES).to_numpy()]
    late_last_week = late[late["date"] >= as_of - pd.Timedelta(days=7)]
    cats = window.groupby("profileId")[[f"hour_min_{c}" for c in CATEGORIES]].sum()
    school = daily[daily["day_type"] == "school"].groupby("profileId")
    stats = pd.DataFrame(
        {
            "median_school_min": school["hour_min"].median(),
            "mean_daily_min": daily.groupby("profileId")["hour_min"].mean(),
            "school_limit": school["dailyLimitMinutes"].first(),
            "reach_limit_rate": school["reached"].mean(),
            "ext_per_week": ext_window.groupby("profileId").size() / (WINDOW_DAYS / 7),
            "ext_mean_min": ext_window.groupby("profileId")["requestMinutes"].mean(),
            "late_nights_last_week": late_last_week.groupby("profileId")["date"].nunique(),
            "game_share": cats["hour_min_game"] / cats.sum(axis=1).replace(0, np.nan),
        }
    )
    return stats.fillna({"ext_per_week": 0, "late_nights_last_week": 0})


def suggest(s: pd.Series, age_group: str) -> list[tuple[str, str]]:
    """Gợi ý (mã luật, câu) cho một trẻ."""
    out = []
    has_limit = pd.notna(s["school_limit"])
    if has_limit and s["reach_limit_rate"] >= 0.5 and s["ext_per_week"] >= 2:
        out.append((
            "giam_dan",
            f"Bé chạm giới hạn {minutes(s['school_limit'])} ở {s['reach_limit_rate']:.0%} ngày đi học và xin thêm giờ "
            f"khoảng {s['ext_per_week']:.0f} lần/tuần. Có thể nâng giới hạn ngày đi học lên "
            f"{minutes(round15(s['school_limit'] + s['ext_mean_min']))} rồi bật chế độ giảm dần về "
            f"{minutes(s['school_limit'])} trong 4 tuần, để bé ít phải xin thêm hơn.",
        ))
    if not has_limit and age_group == "3-5" and s["mean_daily_min"] > WHO_MAX_MINUTES_YOUNG:
        out.append((
            "who",
            f"Bé đang dùng khoảng {minutes(s['mean_daily_min'])}/ngày. WHO khuyến nghị trẻ 2–4 tuổi dùng màn hình "
            f"không quá 1 giờ/ngày — có thể đặt giới hạn 1 giờ và giảm dần.",
        ))
    elif not has_limit:
        out.append((
            "dat_gioi_han",
            f"Bé chưa có giới hạn thời gian. Có thể bắt đầu bằng mức hiện tại "
            f"({minutes(round15(s['median_school_min']))} ngày đi học) rồi giảm dần 10% mỗi tuần.",
        ))
    if s["late_nights_last_week"] >= 3:
        after = "22h" if age_group in LATE_HOURS else "nửa đêm"
        out.append((
            "gio_ngu",
            f"Tuần qua bé dùng máy sau {after} ở {int(s['late_nights_last_week'])} đêm. "
            f"Có thể đặt khung giờ ngủ (khoá máy từ 21:30) cho các ngày đi học.",
        ))
    if s["game_share"] >= 0.5:
        out.append((
            "gioi_han_game",
            f"Game chiếm {s['game_share']:.0%} thời gian dùng máy. Có thể đặt giới hạn riêng cho game "
            f"(ví dụ {minutes(round15(s['median_school_min'] * 0.4))}/ngày đi học).",
        ))
    return out


# ----------------------------------------------------------------------------------------------- CLI
def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    t = load_sim(args.sim)
    hours = build_hourly_features(t["app_usage_hourly"], calendar=Calendar.load(), categories=load_categories())
    ages = t["profiles"].set_index("profileId")["ageGroup"]

    school_year = hours[hours["date"] < HABIT_END]
    vectors = habit_vectors(school_year)
    labels, k, scores = cluster(vectors)
    daily_min = school_year.groupby(["profileId", "date"])["hour_min"].sum().groupby("profileId").mean()
    plot_heatmaps(school_year, pd.Series(labels, index=vectors.index), args.out / "m3_heatmaps.png")
    ari = adjusted_rand_score(ages[vectors.index], labels)

    stats = child_stats(hours, t["time_limits"], t["time_extension_requests"], ages, SUGGEST_AS_OF)
    sug = pd.DataFrame(
        [(pid, code, text) for pid, s in stats.iterrows() for code, text in suggest(s, ages[pid])],
        columns=["profileId", "luật", "câu"],
    )

    scores_text = ", ".join(f"k={kk}: {v:.2f}" for kk, v in scores.items())
    lines = [
        "# M3 (nhóm thói quen) + M4 (gợi ý cho phụ huynh) — tuần 6",
        "",
        f"## M3 — K-Means trên {len(vectors)} trẻ (năm học, trước {HABIT_END:%d/%m/%Y})",
        "",
        f"Chọn k = {k} theo silhouette ({scores_text}). Độ khớp với nhóm tuổi (ARI) = {ari:.2f}.",
        "",
        describe(vectors, labels, daily_min, ages).to_markdown(),
        "",
        "![Heatmap thứ × giờ theo nhóm](m3_heatmaps.png)",
        "",
        f"## M4 — gợi ý ngày {SUGGEST_AS_OF:%d/%m/%Y} (cửa sổ {WINDOW_DAYS} ngày)",
        "",
        f"{sug['profileId'].nunique()}/{len(stats)} trẻ có ít nhất một gợi ý.",
        "",
        sug["luật"].value_counts().rename("số trẻ").to_markdown(),
        "",
        "Ví dụ:",
        "",
        *[f"- `{r['luật']}`: {r['câu']}" for _, r in sug.groupby("luật").head(1).iterrows()],
        "",
    ]
    text = "\n".join(lines)
    (args.out / "m3_m4.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
