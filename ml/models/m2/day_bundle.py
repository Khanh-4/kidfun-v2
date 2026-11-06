"""Đóng gói M2 tầng 2 mức ngày (T7.3.2): DBSCAN huấn luyện MỘT lần trên dữ liệu mô phỏng, tác vụ ban đêm nạp và chấm.

Mô hình thắng mức ngày ở docs/thesis/08 (PR-AUC 0,70): DBSCANDistance trên day_matrix — điểm = khoảng cách tới
điểm lõi DBSCAN gần nhất (sau chuẩn hoá). Ngưỡng cảnh báo = phân vị (1 − ALERT_RATE) của điểm trên tập huấn luyện,
cùng tỷ lệ cảnh báo đã dùng lúc đánh giá (evaluate.DAY_ALERT_RATE ≈ 5% số ngày).

Gói chỉ gồm JSON (không pickle): trung bình/độ lệch của StandardScaler, toạ độ các điểm lõi, ngưỡng.
Nạp + chấm chỉ cần numpy/pandas/scikit-learn (requirements-job.txt); huấn luyện mới cần detectors.py (có torch).

    .venv/bin/python -m models.m2.day_bundle --sim data/sim        # ghi vào models/m2/artifacts/
"""

import argparse
import json
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.neighbors import NearestNeighbors

from .data import day_matrix

FORMAT_VERSION = 1
ALERT_RATE = 0.05  # = evaluate.DAY_ALERT_RATE (test_m2_day_bundle kiểm tra hai số khớp)
FILES = ("dbscan.json", "meta.json")
DEFAULT_DIR = Path(__file__).resolve().parent / "artifacts"
MODEL_NAME = "dbscan_day"


class BundleError(RuntimeError):
    pass


@dataclass(frozen=True)
class DayBundle:
    columns: list[str]
    mean: np.ndarray
    scale: np.ndarray
    core: np.ndarray
    threshold: float
    _nn: NearestNeighbors = field(init=False, repr=False, compare=False)

    def __post_init__(self):
        object.__setattr__(self, "_nn", NearestNeighbors(n_neighbors=1).fit(self.core))

    def score(self, days: pd.DataFrame) -> np.ndarray:
        x = day_matrix(days)
        missing = [c for c in self.columns if c not in x.columns]
        if missing:
            raise BundleError(f"Thiếu cột đặc trưng: {', '.join(missing)}")
        z = (x[self.columns].to_numpy(dtype=float) - self.mean) / self.scale
        dist, _ = self._nn.kneighbors(z)
        return dist[:, 0]

    def flag(self, days: pd.DataFrame) -> np.ndarray:
        return self.score(days) > self.threshold


def train(days: pd.DataFrame) -> DayBundle:
    from .detectors import DBSCANDistance  # torch — chỉ cần lúc huấn luyện

    det = DBSCANDistance(day_matrix).fit(days)
    columns = list(day_matrix(days.head(1)).columns)
    core = np.asarray(det.core._fit_X)  # điểm lõi (đã chuẩn hoá) mà NearestNeighbors của DBSCANDistance giữ
    threshold = float(np.quantile(det.score(days), 1 - ALERT_RATE))
    return DayBundle(columns, det.scaler.mean_.copy(), det.scaler.scale_.copy(), core, threshold)


def save(bundle: DayBundle, out: Path, trained_on: str) -> None:
    out.mkdir(parents=True, exist_ok=True)
    payload = {"mean": bundle.mean.tolist(), "scale": bundle.scale.tolist(), "core": bundle.core.tolist()}
    (out / "dbscan.json").write_text(json.dumps(payload), encoding="utf-8")
    meta = {
        "version": FORMAT_VERSION,
        "model": MODEL_NAME,
        "trained_on": trained_on,
        "trained_at": date.today().isoformat(),
        "columns": bundle.columns,
        "threshold": bundle.threshold,
        "alert_rate": ALERT_RATE,
        "n_core": int(len(bundle.core)),
    }
    (out / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def load(src: Path = DEFAULT_DIR) -> DayBundle:
    missing = [name for name in FILES if not (src / name).exists()]
    if missing:
        raise BundleError(f"Gói M2 ngày ở {src} thiếu: {', '.join(missing)}")
    meta = json.loads((src / "meta.json").read_text(encoding="utf-8"))
    if meta.get("version") != FORMAT_VERSION:
        raise BundleError(f"Gói M2 ngày version {meta.get('version')}, cần {FORMAT_VERSION} — chạy lại day_bundle")
    data = json.loads((src / "dbscan.json").read_text(encoding="utf-8"))
    return DayBundle(meta["columns"], np.asarray(data["mean"]), np.asarray(data["scale"]),
                     np.asarray(data["core"]), float(meta["threshold"]))


def model_version(src: Path = DEFAULT_DIR) -> str:
    """vd "dbscan_day@2026-11-07"."""
    meta = json.loads((src / "meta.json").read_text(encoding="utf-8"))
    return f"{meta['model']}@{meta['trained_at']}"


def main() -> None:
    from .data import sim_m2_frames

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True, help="thư mục CSV của simulator")
    p.add_argument("--out", type=Path, default=DEFAULT_DIR)
    args = p.parse_args()
    _, days, _ = sim_m2_frames(args.sim)
    bundle = train(days)
    save(bundle, args.out, trained_on=f"sim:{args.sim.name} ({days['profileId'].nunique()} trẻ)")
    print(f"Đã ghi gói M2 ngày vào {args.out} ({len(bundle.core)} điểm lõi, ngưỡng {bundle.threshold:.3f})")


if __name__ == "__main__":
    main()
