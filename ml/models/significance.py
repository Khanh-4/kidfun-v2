"""T8.4 — kiểm định thống kê cho M1 và M2 tầng 2.

- Wilcoxon cặp trên MAE theo từng người (mỗi người là một cặp quan sát: MAE của mô hình, MAE của MA7). Hai phía,
  hiệu chỉnh Holm trong mỗi bộ dữ liệu vì mỗi bộ có hai phép so sánh (XGBoost và LSTM cùng so với MA7).
- Khoảng tin cậy bootstrap 95% theo cụm người: lấy lại có hoàn lại NGUYÊN người, không lấy lại từng dòng, vì các
  ngày/giờ của cùng một người phụ thuộc nhau; lấy lại từng dòng sẽ cho khoảng hẹp giả tạo.

Giao thức huấn luyện/kiểm tra giữ nguyên tuần 4–5 (`m1.evaluate.walk_forward`, `m2.evaluate`).

Chạy từ thư mục ml/ (khoảng 10 phút):
    .venv/bin/python -m models.significance --sim data/sim --lsapp data/lsapp.tsv.gz \
        --studentlife data/dataset_rds --out reports
"""

import argparse
from collections.abc import Callable
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import wilcoxon
from sklearn.metrics import average_precision_score

ALPHA = 0.05
N_BOOT_M1 = 2000
N_BOOT_M2 = 1000
BASELINE = "ma7"
CHALLENGERS = ("xgb_rel", "lstm")


def per_subject_mae(preds: pd.DataFrame, names: list[str], subject: str = "profileId") -> pd.DataFrame:
    """MAE của từng mô hình theo từng người: một dòng / người, một cột / mô hình."""
    return pd.DataFrame({n: (preds[n] - preds["y_next"]).abs().groupby(preds[subject]).mean() for n in names})


def paired_wilcoxon(table: pd.DataFrame, model: str, baseline: str) -> dict:
    """Wilcoxon cặp hai phía. median_diff < 0 nghĩa là `model` sai ít hơn `baseline`.

    Người thiếu MAE ở một trong hai mô hình (vd chưa đủ 7 ngày liền trước nên MA7 không tính được) bị bỏ khỏi cặp.
    """
    pair = table[[model, baseline]].dropna()
    diff = pair[model] - pair[baseline]
    result = {"n": len(diff), "wins": int((diff < 0).sum()), "median_diff": float(diff.median())}
    if np.allclose(diff, 0):  # mọi cặp bằng nhau: scipy không tính được hạng, không có khác biệt
        return {**result, "W": float("nan"), "p": 1.0}
    stat = wilcoxon(pair[model], pair[baseline], alternative="two-sided")
    return {**result, "W": float(stat.statistic), "p": float(stat.pvalue)}


def holm(pvalues: list[float]) -> list[float]:
    """Hiệu chỉnh Holm–Bonferroni, giữ thứ tự đầu vào."""
    if any(not np.isfinite(p) for p in pvalues):
        raise ValueError(f"p-value không hợp lệ: {pvalues}")
    m = len(pvalues)
    order = np.argsort(pvalues)
    adjusted = np.empty(m)
    running = 0.0
    for rank, i in enumerate(order):
        running = max(running, (m - rank) * pvalues[i])
        adjusted[i] = min(running, 1.0)
    return adjusted.tolist()


def cluster_bootstrap(
    frame: pd.DataFrame,
    cluster: str,
    stat: Callable[[pd.DataFrame], np.ndarray],
    n_boot: int,
    seed: int = 0,
    level: float = 0.95,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Khoảng tin cậy percentile cho một vector thống kê, lấy lại theo cụm. Trả về (điểm, cận dưới, cận trên)."""
    rng = np.random.default_rng(seed)
    groups = list(frame.groupby(cluster, sort=True).indices.values())
    point = np.asarray(stat(frame), dtype=float)
    draws = np.empty((n_boot, point.size))
    for b in range(n_boot):
        picked = rng.integers(0, len(groups), len(groups))
        draws[b] = stat(frame.iloc[np.concatenate([groups[g] for g in picked])])
    tail = 100 * (1 - level) / 2
    return point, np.nanpercentile(draws, tail, axis=0), np.nanpercentile(draws, 100 - tail, axis=0)


# --------------------------------------------------------------------------------------------- báo cáo M1


def _fmt_p(p: float) -> str:
    return "< 0,001" if p < 0.001 else f"{p:.3f}".replace(".", ",")


def m1_tests(preds: pd.DataFrame, names: list[str]) -> pd.DataFrame:
    table = per_subject_mae(preds, names)
    rows = [{"so sánh": f"{m} vs {BASELINE}", **paired_wilcoxon(table, m, BASELINE)} for m in CHALLENGERS]
    for row, p_adj in zip(rows, holm([r["p"] for r in rows])):
        row["p (Holm)"] = p_adj
        row["kết luận"] = "khác biệt có ý nghĩa" if p_adj < ALPHA else "chưa đủ bằng chứng"
    out = pd.DataFrame(rows).set_index("so sánh")
    out["thắng/tổng"] = out["wins"].astype(str) + "/" + out["n"].astype(str)
    out["p"] = out["p"].map(_fmt_p)
    out["p (Holm)"] = out["p (Holm)"].map(_fmt_p)
    return out[["thắng/tổng", "median_diff", "W", "p", "p (Holm)", "kết luận"]].rename(
        columns={"median_diff": "trung vị ΔMAE (phút)"}
    )


def m1_intervals(preds: pd.DataFrame, names: list[str], n_boot: int) -> pd.DataFrame:
    """MAE và ΔMAE (so với MA7) kèm khoảng tin cậy 95% bootstrap theo người."""
    err = pd.DataFrame({n: (preds[n] - preds["y_next"]).abs() for n in names})
    err["profileId"] = preds["profileId"].to_numpy()
    deltas = [n for n in names if n != BASELINE]

    def stat(f: pd.DataFrame) -> np.ndarray:
        mae = f[names].mean()  # bỏ qua NaN, khớp cách tính MAE ở m1.evaluate.metrics
        delta = [(f[n] - f[BASELINE]).mean() for n in deltas]  # chỉ trên dòng cả hai mô hình cùng có dự đoán
        return np.concatenate([mae.to_numpy(), delta])

    point, lo, hi = cluster_bootstrap(err, "profileId", stat, n_boot)
    k = len(names)
    rows = []
    for i, n in enumerate(names):
        row = {"model": n, "MAE": point[i], "KTC 95% MAE": f"[{lo[i]:.1f}; {hi[i]:.1f}]"}
        if n in deltas:
            j = k + deltas.index(n)
            row["ΔMAE so với ma7"] = point[j]
            row["KTC 95% ΔMAE"] = f"[{lo[j]:.1f}; {hi[j]:.1f}]"
        rows.append(row)
    return pd.DataFrame(rows).set_index("model").sort_values("MAE").round(1)


def m1_section(title: str, preds: pd.DataFrame, names: list[str], n_boot: int) -> list[str]:
    return [
        f"## M1 — {title}",
        "",
        f"{len(preds):,} dự đoán, {preds['profileId'].nunique()} người.",
        "",
        "Wilcoxon cặp trên MAE theo từng người (hai phía; ΔMAE < 0 là mô hình sai ít hơn MA7):",
        "",
        m1_tests(preds, names).round(2).to_markdown(),
        "",
        f"MAE và khoảng tin cậy 95% (bootstrap {n_boot} lần theo người):",
        "",
        m1_intervals(preds, names, n_boot).to_markdown(),
        "",
    ]


# --------------------------------------------------------------------------------------------- báo cáo M2


def _pr_auc(y: np.ndarray, s: np.ndarray) -> float:
    return average_precision_score(y, s) if y.any() else float("nan")


def m2_intervals(test: pd.DataFrame, scores: dict[str, np.ndarray], n_boot: int) -> pd.DataFrame:
    """PR-AUC từng bộ phát hiện + chênh lệch của bộ tốt nhất với bộ đứng thứ hai, bootstrap theo người."""
    frame = pd.DataFrame(scores)
    names = list(scores)
    frame["label"] = test["label"].to_numpy(dtype=bool)
    frame["profileId"] = test["profileId"].to_numpy()
    point_only = {n: _pr_auc(frame["label"].to_numpy(), frame[n].to_numpy()) for n in names}
    best, second = sorted(names, key=point_only.get, reverse=True)[:2]

    def stat(f: pd.DataFrame) -> np.ndarray:
        y = f["label"].to_numpy()
        auc = [_pr_auc(y, f[n].to_numpy()) for n in names]
        return np.array([*auc, auc[names.index(best)] - auc[names.index(second)]])

    point, lo, hi = cluster_bootstrap(frame, "profileId", stat, n_boot)
    rows = [{"bộ phát hiện": n, "PR-AUC": point[i], "KTC 95%": f"[{lo[i]:.3f}; {hi[i]:.3f}]"}
            for i, n in enumerate(names)]
    rows.append({"bộ phát hiện": f"Δ {best} − {second}", "PR-AUC": point[-1],
                 "KTC 95%": f"[{lo[-1]:.3f}; {hi[-1]:.3f}]"})
    return pd.DataFrame(rows).set_index("bộ phát hiện").round(3)


def m2_scores(frame: pd.DataFrame, detectors, split: pd.Timestamp):
    """Học trên các ngày trước split, chấm điểm từ split — như `m2.evaluate.score_level`, nhưng giữ điểm thô."""
    train = frame[frame["date"] < split]
    test = frame[frame["date"] >= split].reset_index(drop=True)
    return test, {det.name: det.fit(train).score(test) for det in detectors}


def m2_sections(sim_dir: Path, n_boot: int) -> list[str]:
    from .m2.data import sim_m2_frames
    from .m2.detectors import day_detectors, hour_detectors
    from .m2.evaluate import MIN_BASE_DAYS, SPLIT

    hours, days, _ = sim_m2_frames(sim_dir)
    hours = hours[(hours["hour_min"] > 0) & (hours["base_days"] >= MIN_BASE_DAYS)].reset_index(drop=True)
    days = days[days["day_ratio"].notna()].reset_index(drop=True)
    lines = []
    for title, frame, detectors in (("mức giờ", hours, hour_detectors()), ("mức ngày", days, day_detectors())):
        test, scores = m2_scores(frame, detectors, SPLIT)
        lines += [
            f"## M2 tầng 2 — {title}",
            "",
            f"{len(test):,} dòng kiểm tra, {int(test['label'].sum())} dòng bất thường, "
            f"{test['profileId'].nunique()} trẻ. Bootstrap {n_boot} lần theo trẻ:",
            "",
            m2_intervals(test, scores, n_boot).to_markdown(),
            "",
        ]
    return lines


# --------------------------------------------------------------------------------------------- chạy


def main() -> None:
    from .m1.data import lsapp_daily_features, sim_daily_features, studentlife_daily_features
    from .m1.evaluate import walk_forward
    from .m1.lstm import LSTMGlobal
    from .m1.models import MovingAverage7, XGBAbsolute, XGBRelative

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--lsapp", type=Path)
    p.add_argument("--studentlife", type=Path)
    p.add_argument("--sim-test-start", default="2026-03-02")
    p.add_argument("--n-boot-m1", type=int, default=N_BOOT_M1)
    p.add_argument("--n-boot-m2", type=int, default=N_BOOT_M2)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    models = (MovingAverage7, XGBRelative, XGBAbsolute, LSTMGlobal)
    names = [m.name for m in models]
    datasets = [("dữ liệu mô phỏng (trẻ em)", args.sim, sim_daily_features, pd.Timestamp(args.sim_test_start))]
    if args.lsapp:
        datasets.append(("LSApp (người lớn)", args.lsapp, lsapp_daily_features, None))
    if args.studentlife:
        datasets.append(("StudentLife (sinh viên)", args.studentlife, studentlife_daily_features, None))

    lines = ["# T8.4 — Kiểm định thống kê M1 và M2 tầng 2", ""]
    for title, path, loader, start in datasets:
        daily = loader(path)
        start = start if start is not None else daily["target_date"].quantile(0.5).normalize()
        preds = walk_forward(daily, models, start, daily["target_date"].max())
        lines += m1_section(title, preds, names, args.n_boot_m1)
        print(f"xong M1 — {title}", flush=True)
    lines += m2_sections(args.sim, args.n_boot_m2)

    text = "\n".join(lines)
    (args.out / "t8_significance.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
