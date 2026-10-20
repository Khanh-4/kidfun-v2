"""Đánh giá M2 tầng 2 (tuần 5) trên dữ liệu mô phỏng có nhãn bất thường cài sẵn.

Giao thức: học (không giám sát) trên các ngày trước SPLIT, chấm điểm các ngày từ SPLIT. Ngưỡng cảnh báo của mỗi
bộ phát hiện = phân vị (1 − tỷ lệ cảnh báo) của điểm trên tập huấn luyện, tức không dùng nhãn để chọn ngưỡng.
Chỉ chấm giờ có dùng máy và có mức thường ngày (>= 7 ngày cùng loại); ngày có mức thường ngày.

Chạy từ thư mục ml/:
    .venv/bin/python -m models.m2.evaluate --sim data/sim --out reports
"""

import argparse
import time
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import average_precision_score, roc_auc_score

from ..explain import explain_day, explain_hour, explain_over_limit, top_reasons
from ..m1.data import sim_daily_features
from ..m1.models import _matrix
from ..m1.over_limit import XGBClassifier, limited
from .data import sim_m2_frames
from .detectors import day_detectors, hour_detectors

SPLIT = pd.Timestamp("2026-03-01")
HOUR_ALERT_RATE = 0.01
DAY_ALERT_RATE = 0.05
MIN_BASE_DAYS = 7


def score_level(frame: pd.DataFrame, detectors, alert_rate: float, split: pd.Timestamp = SPLIT):
    """Trả về (bảng chỉ số, tập kiểm tra, {tên bộ: mảng cờ cảnh báo trên tập kiểm tra})."""
    train = frame[frame["date"] < split]
    test = frame[frame["date"] >= split].reset_index(drop=True)
    y = test["label"].to_numpy(dtype=bool)
    rows, alerts = [], {}
    for det in detectors:
        t0 = time.time()
        det.fit(train)
        threshold = np.quantile(det.score(train), 1 - alert_rate)
        s = det.score(test)
        flagged = s >= threshold
        tp = (flagged & y).sum()
        precision = tp / max(flagged.sum(), 1)
        recall = tp / max(y.sum(), 1)
        row = {
            "bộ phát hiện": det.name,
            "PR-AUC": average_precision_score(y, s),
            "ROC-AUC": roc_auc_score(y, s),
            "Precision": precision,
            "Recall": recall,
            "F1": 2 * precision * recall / max(precision + recall, 1e-9),
            "tỷ lệ cảnh báo": flagged.mean(),
            "giây": time.time() - t0,
        }
        for kind, g in test[y].groupby("kind"):
            row[f"recall {kind}"] = flagged[g.index].mean()
        rows.append(row)
        alerts[det.name] = flagged
    return pd.DataFrame(rows).set_index("bộ phát hiện"), test, alerts


def explanation_accuracy(test: pd.DataFrame, flagged: np.ndarray, explain):
    """Với các cảnh báo đúng: câu giải thích có nói đúng loại bất thường đã cài không."""
    hits = test[flagged & test["label"].to_numpy(dtype=bool)]
    said = hits.apply(lambda r: explain(r), axis=1)
    kinds = said.map(lambda ks: ks[0])
    table = (kinds == hits["kind"]).groupby(hits["kind"]).agg(["size", "mean"])
    table.columns = ["số cảnh báo đúng", "câu giải thích đúng loại"]
    examples = hits.assign(cau=said.map(lambda ks: ks[1])).groupby("kind").head(1)
    return table, examples[["kind", "cau"]]


def over_limit_examples(sim_dir: Path, n: int = 3) -> list[str]:
    daily = sim_daily_features(sim_dir)
    rows = daily[limited(daily) & (daily["history_days"] >= MIN_BASE_DAYS)]
    clf = XGBClassifier().fit(rows[rows["target_date"] < SPLIT])
    test = rows[rows["target_date"] >= SPLIT]
    top = test.assign(p=clf.predict_proba(test)).nlargest(200, "p").sample(n, random_state=0)
    reasons = top_reasons(clf.model, _matrix(top, clf.cols))
    return [
        explain_over_limit(r.target_date, r.limit_tomorrow, r.p, reason[0] if reason else None)[1]
        for r, reason in zip(top.itertuples(), reasons)
    ]


def section(title: str, table: pd.DataFrame, acc: pd.DataFrame, examples: pd.DataFrame) -> list[str]:
    return [
        f"## {title}",
        "",
        table.round(3).sort_values("PR-AUC", ascending=False).to_markdown(),
        "",
        "Câu giải thích của bộ có F1 cao nhất — tỷ lệ nói đúng loại bất thường:",
        "",
        acc.round(3).to_markdown(),
        "",
        "Ví dụ:",
        "",
        *[f"- `{k}`: {c}" for k, c in zip(examples["kind"], examples["cau"])],
        "",
    ]


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--out", type=Path, default=Path("reports"))
    args = p.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    hours, days, stats = sim_m2_frames(args.sim)
    hours = hours[(hours["hour_min"] > 0) & (hours["base_days"] >= MIN_BASE_DAYS)].reset_index(drop=True)
    days = days[days["day_ratio"].notna()].reset_index(drop=True)

    lines = [
        "# M2 tầng 2 — kết quả thực nghiệm (tuần 5)",
        "",
        f"Huấn luyện trước {SPLIT:%d/%m/%Y}, kiểm tra từ ngày đó. Làm sạch nhãn: {stats}.",
        "",
    ]
    levels = (
        (f"Mức giờ (cảnh báo {HOUR_ALERT_RATE:.0%} số giờ có dùng máy)", hours, hour_detectors(), HOUR_ALERT_RATE,
         explain_hour),
        (f"Mức ngày (cảnh báo {DAY_ALERT_RATE:.0%} số ngày)", days, day_detectors(), DAY_ALERT_RATE, explain_day),
    )
    for title, frame, detectors, rate, explain in levels:
        table, test, alerts = score_level(frame, detectors, rate)
        acc, examples = explanation_accuracy(test, alerts[table["F1"].idxmax()], explain)
        heading = f"{title} — {len(test):,} dòng kiểm tra, {int(test['label'].sum())} dòng bất thường"
        lines += section(heading, table, acc, examples)

    lines += [
        "## Câu cảnh báo M1 (dự báo vượt giới hạn, lý do từ SHAP của XGBoost)",
        "",
        *[f"- {s}" for s in over_limit_examples(args.sim)],
        "",
    ]
    text = "\n".join(lines)
    (args.out / "m2_round1.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
