"""Thực nghiệm vòng phản hồi (RQ5): phụ huynh bấm "đúng là bất thường" / "được phép" có giảm báo nhầm không?

Mô phỏng tầng 1 (ml/tier1/rules.py) theo từng tuần trên giai đoạn kiểm tra:
  - mức thường ngày tính lại mỗi tuần từ 28 ngày trước đó (như server tính hằng đêm);
  - "phụ huynh mô phỏng" trả lời RESPOND_PROB số cảnh báo: đúng nhãn -> "đúng là bất thường", sai -> "được phép";
    với xác suất `noise` bấm nhầm;
  - "được phép" -> nới ngưỡng của loại ngày (+ nhóm app) đó, áp dụng từ tuần sau.
So sánh với không có phản hồi: tỷ lệ báo nhầm, số cảnh báo / trẻ / tuần, recall bất thường cài sẵn.

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m2.feedback --sim data/sim --out reports
"""

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

from features.common import CATEGORIES, NIGHT_HOURS  # noqa: E402
from tier1.rules import BASELINE_DAYS, DEFAULT_RULES, build_baseline, night_min, relax, spike_ratio  # noqa: E402

from .data import sim_m2_frames  # noqa: E402

SPLIT = pd.Timestamp("2026-03-02")  # thứ Hai
RESPOND_PROB = 0.7
FIXED_WINDOW = {**DEFAULT_RULES, "nightUsualMaxMinutes": float("inf")}  # luật khuya ban đầu: khung 22h cố định
POLICIES = {  # tên: (luật xuất phát, nhiễu phản hồi; None = không phản hồi)
    "khung khuya cố định": (FIXED_WINDOW, None),
    "khung khuya cố định + phản hồi (nhiễu 10%)": (FIXED_WINDOW, 0.1),
    "khuya cá nhân hoá": (DEFAULT_RULES, None),
    "khuya cá nhân hoá + phản hồi (nhiễu 0%)": (DEFAULT_RULES, 0.0),
    "khuya cá nhân hoá + phản hồi (nhiễu 10%)": (DEFAULT_RULES, 0.1),
    "khuya cá nhân hoá + phản hồi (nhiễu 20%)": (DEFAULT_RULES, 0.2),
}
CAT_COLS = [f"hour_min_{c}" for c in CATEGORIES]


def weekly_means(hours: pd.DataFrame, week_start: pd.Timestamp) -> pd.DataFrame:
    window = hours[(hours["date"] >= week_start - pd.Timedelta(days=BASELINE_DAYS)) & (hours["date"] < week_start)]
    return window.groupby(["profileId", "day_type", "hour"])[CAT_COLS].mean()


def detect(week: pd.DataFrame, means: pd.DataFrame, rules: dict, base: dict = DEFAULT_RULES) -> pd.DataFrame:
    """Gắn cờ tầng 1 cho các giờ có dùng máy trong tuần. rules: {profileId: rules}; trẻ chưa có -> base."""
    usual = means.reindex(pd.MultiIndex.from_frame(week[["profileId", "day_type", "hour"]])).fillna(0).to_numpy()
    used = week[CAT_COLS].to_numpy()
    pid_rules = [rules.get(p, base) for p in week["profileId"]]
    ratio = np.array([[spike_ratio(r, d, c) for c in CATEGORIES] for r, d in zip(pid_rules, week["day_type"])])
    spike = (used >= ratio * usual) & (used >= DEFAULT_RULES["spikeMinMinutes"])
    night_threshold = np.array([night_min(r, d) for r, d in zip(pid_rules, week["day_type"])])
    usual_max = np.array([r["nightUsualMaxMinutes"] for r in pid_rules])
    night = (
        week["hour"].isin(NIGHT_HOURS).to_numpy()
        & (week["hour_min"].to_numpy() >= night_threshold)
        & (usual.sum(axis=1) <= usual_max)
    )
    # Luật chính của cảnh báo (để phụ huynh phản hồi): khuya, nếu không thì nhóm app vượt nhiều nhất
    excess = np.where(spike, used / np.maximum(usual, 1e-9), 0)
    out = week.assign(
        alert=night | spike.any(axis=1),
        rule=np.where(night, "night", "spike"),
        cat=np.array(CATEGORIES)[excess.argmax(axis=1)],
    )
    return out[out["alert"]]


def run_policy(
    hours: pd.DataFrame, noise: float | None, base: dict = DEFAULT_RULES, seed: int = 0, split: pd.Timestamp = SPLIT
) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    rules, counts = {}, {}
    active = hours[hours["hour_min"] > 0]
    rows = []
    for week_start in pd.date_range(split, hours["date"].max(), freq="7D"):
        week = active[(active["date"] >= week_start) & (active["date"] < week_start + pd.Timedelta(days=7))]
        if week.empty:
            continue
        alerts = detect(week, weekly_means(hours, week_start), rules, base)
        rows.append(
            {
                "tuần": week_start,
                "cảnh báo": len(alerts),
                "báo đúng": int(alerts["label"].sum()),
                "bất thường": int(week["label"].sum()),
                "số trẻ": week["profileId"].nunique(),
            }
        )
        if noise is None:
            continue
        for a in alerts.itertuples():
            if rng.random() >= RESPOND_PROB:
                continue
            says_anomaly = a.label != (rng.random() < noise)
            if not says_anomaly:
                current = rules.get(a.profileId, base)
                rules[a.profileId], counts[a.profileId] = relax(
                    current, counts.get(a.profileId, {}), a.rule, a.day_type, a.cat
                )
    weekly = pd.DataFrame(rows)
    weekly["tỷ lệ báo nhầm"] = 1 - weekly["báo đúng"] / weekly["cảnh báo"].replace(0, np.nan)
    weekly["cảnh báo / trẻ / tuần"] = weekly["cảnh báo"] / weekly["số trẻ"]
    return weekly


def summarize(weekly: dict[str, pd.DataFrame]) -> pd.DataFrame:
    rows = []
    for name, w in weekly.items():
        first, last = w.head(4), w.tail(4)
        rows.append(
            {
                "chính sách": name,
                "báo nhầm 4 tuần đầu": 1 - first["báo đúng"].sum() / first["cảnh báo"].sum(),
                "báo nhầm 4 tuần cuối": 1 - last["báo đúng"].sum() / last["cảnh báo"].sum(),
                "cảnh báo/trẻ/tuần (4 tuần cuối)": last["cảnh báo"].sum() / last["số trẻ"].sum(),
                "recall cả giai đoạn": w["báo đúng"].sum() / w["bất thường"].sum(),
            }
        )
    return pd.DataFrame(rows).set_index("chính sách")


def plot(weekly: dict[str, pd.DataFrame], path: Path) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(11, 3.8))
    for name, w in weekly.items():
        axes[0].plot(w["tuần"], w["tỷ lệ báo nhầm"], label=name)
        axes[1].plot(w["tuần"], w["cảnh báo / trẻ / tuần"], label=name)
    axes[0].set_title("Tỷ lệ báo nhầm theo tuần")
    axes[1].set_title("Số cảnh báo / trẻ / tuần")
    for ax in axes:
        ax.tick_params(axis="x", rotation=30)
    axes[1].legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def baseline_json_sizes(hours: pd.DataFrame) -> pd.Series:
    sizes = [len(json.dumps(build_baseline(g, pid, SPLIT))) for pid, g in hours.groupby("profileId")]
    return pd.Series(sizes, name="byte")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    hours, _, _ = sim_m2_frames(args.sim)
    weekly = {name: run_policy(hours, noise, base) for name, (base, noise) in POLICIES.items()}
    plot(weekly, args.out / "m2_feedback.png")
    sizes = baseline_json_sizes(hours)
    text = "\n".join(
        [
            "# Vòng phản hồi của phụ huynh (tuần 6)",
            "",
            f"Tầng 1 trên dữ liệu mô phỏng từ {SPLIT:%d/%m/%Y}; phụ huynh mô phỏng trả lời {RESPOND_PROB:.0%} số cảnh báo.",
            "",
            summarize(weekly).round(3).to_markdown(),
            "",
            "![Vòng phản hồi](m2_feedback.png)",
            "",
            f"Kích thước JSON mức thường ngày gửi xuống máy trẻ: trung vị {sizes.median() / 1024:.1f} KB, "
            f"lớn nhất {sizes.max() / 1024:.1f} KB ({len(sizes)} trẻ).",
            "",
        ]
    )
    (args.out / "m2_feedback.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
