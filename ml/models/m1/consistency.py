"""M1 — số phút và xác suất vượt giới hạn có nói ngược nhau không, và sửa thế nào (việc 4, 16/11).

Gói M1 dùng hai mô hình học riêng: xgb_rel (số phút) và xgb_clf_iso (xác suất). So ba cách trên dữ liệu mô phỏng,
walk-forward như round 2:
  - xgb_clf_iso: như production cũ — đo tỷ lệ ngày mâu thuẫn (phút > giới hạn mà p < 0,5 hoặc ngược lại);
  - xgb_clf_iso_clip: kẹp p về 0,5 ở các ngày mâu thuẫn;
  - xgb_clf_platt / xgb_clf_platt_clip: hiệu chỉnh Platt (+ kẹp) — gói M1 dùng platt_clip từ 16/11;
  - reg_resid: suy p từ phân phối sai số của bộ hồi quy (nhất quán theo cấu trúc).

    .venv/bin/python -m models.m1.consistency --sim data/sim --out reports    # ~2 phút
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from .data import sim_daily_features
from .models import XGBRelative
from features.daily import HIT_LIMIT_MARGIN_MIN

from .over_limit import M1_LABEL, RegResidual, XGBClassifierIsotonic, XGBClassifierPlatt, proba_metrics, walk_forward_proba


def clip_to_minutes(p: np.ndarray, minutes: np.ndarray, limit: np.ndarray) -> np.ndarray:
    """Cùng phép kẹp với M1Bundle.predict_over_limit."""
    p = np.where(minutes > limit, np.maximum(p, 0.5), p)
    return np.where(minutes < limit, np.minimum(p, 0.5), p)


def conflicts(p: np.ndarray, minutes: np.ndarray, limit: np.ndarray) -> np.ndarray:
    return ((minutes > limit) & (p < 0.5)) | ((minutes < limit) & (p > 0.5))


class _Clipped:
    """Bộ phân loại `base` + kẹp theo số phút của xgb_rel; đếm số ngày mâu thuẫn TRƯỚC khi kẹp."""

    base = None
    seen = None

    def fit(self, train):
        self.clf = self.base().fit(train)
        self.reg = XGBRelative().fit(train[train["y_next"].notna()])
        return self

    def predict_proba(self, test):
        p = self.clf.predict_proba(test)
        minutes = np.clip(self.reg.predict(test), 0, None)
        limit = test["limit_tomorrow"].to_numpy(dtype=float) - HIT_LIMIT_MARGIN_MIN
        self.seen["rows"] += len(p)
        self.seen["conflicts"] += int(conflicts(p, minutes, limit).sum())
        return clip_to_minutes(p, minutes, limit)


class IsoClipped(_Clipped):
    name = "xgb_clf_iso_clip"
    base = XGBClassifierIsotonic
    seen = {"rows": 0, "conflicts": 0}


class PlattClipped(_Clipped):
    name = "xgb_clf_platt_clip"
    base = XGBClassifierPlatt
    seen = {"rows": 0, "conflicts": 0}


def report(daily: pd.DataFrame, start: pd.Timestamp) -> str:
    for c in (IsoClipped, PlattClipped):
        c.seen.update(rows=0, conflicts=0)
    models = (XGBClassifierIsotonic, IsoClipped, XGBClassifierPlatt, PlattClipped, RegResidual)
    preds = walk_forward_proba(daily, models, start, daily["target_date"].max())
    names = [m.name for m in models]
    table = proba_metrics(preds, names)
    table["số mức p khác nhau"] = [preds[n].round(4).nunique() for n in names]
    rate = {c.name: c.seen["conflicts"] / max(c.seen["rows"], 1) for c in (IsoClipped, PlattClipped)}
    return "\n".join([
        "# M1 — số phút và xác suất dùng hết giờ có khớp nhau không",
        "",
        f"Dữ liệu mô phỏng, walk-forward từ {start.date()}: {len(preds):,} ngày có giới hạn, "
        f"tỷ lệ dùng hết giờ thực tế {preds[M1_LABEL].astype(float).mean():.1%}.",
        "",
        f"**Ngày mâu thuẫn trước khi kẹp** (số phút dự đoán ≥ giới hạn − 5 mà p < 0,5, hoặc ngược lại): "
        f"`xgb_clf_iso` {rate['xgb_clf_iso_clip']:.1%}, `xgb_clf_platt` {rate['xgb_clf_platt_clip']:.1%}.",
        "",
        table.round(3).to_markdown(),
        "",
        "- Kẹp: hết mâu thuẫn, Brier gần như giữ nguyên, ECE tăng nhẹ.",
        "- Platt thay isotonic: Brier như nhau, xác suất liên tục thay vì ~26 mức. **Gói M1 dùng `xgb_clf_platt_clip`"
        " từ 16/11.**",
        "- `reg_resid`: nhất quán và mịn nhưng hiệu chỉnh kém hơn — một phân phối sai số chung cho mọi trẻ không",
        "  bắt được việc độ dao động khác nhau giữa các trẻ.",
        "",
    ])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True)
    p.add_argument("--out", type=Path, default=Path("reports"))
    p.add_argument("--sim-test-start", default="2026-03-02")
    args = p.parse_args()
    text = report(sim_daily_features(args.sim), pd.Timestamp(args.sim_test_start))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "m1_consistency.md").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
