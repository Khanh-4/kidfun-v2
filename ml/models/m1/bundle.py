"""Đóng gói M1 (T7.1.4): huấn luyện MỘT lần trên dữ liệu mô phỏng, tác vụ ban đêm chỉ việc nạp và dự đoán.

Hai mô hình thắng ở báo cáo tuần 4 (reports/m1_round2.md):
  - số phút ngày mai: xgb_rel (dự đoán tỷ lệ y_next / mean7);
  - xác suất vượt giới hạn: xgb_clf_iso (XGBoost phân loại + hiệu chỉnh isotonic).

Thư mục gói chỉ gồm file JSON (không pickle): mô hình XGBoost ở định dạng gốc của nó, isotonic lưu dưới dạng
các mốc (x, y) và dự đoán bằng nội suy tuyến tính — đúng cách IsotonicRegression(out_of_bounds="clip") tính.

    .venv/bin/python -m models.m1.bundle --sim data/sim          # ghi vào models/m1/artifacts/
"""

import argparse
import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression

from .models import AGE_MID, XGB_PARAMS, feature_columns
from .over_limit import CALIBRATION_SHARE, CLF_PARAMS, limited

FORMAT_VERSION = 1
FILES = ("regressor.json", "classifier.json", "isotonic.json", "meta.json")
DEFAULT_DIR = Path(__file__).resolve().parent / "artifacts"
RATIO_CAP = 10  # như XGBRelative: chặn tỷ lệ bất thường khi mean7 rất nhỏ


class BundleError(RuntimeError):
    pass


def _matrix(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    """Như models._matrix, nhưng báo lỗi rõ khi thiếu cột và cho phép thiếu ageGroup (coi tuổi là thiếu)."""
    missing = [c for c in cols if c not in df.columns]
    if missing:
        raise BundleError(f"Thiếu cột đặc trưng: {', '.join(missing)}")
    age = df["ageGroup"].map(AGE_MID) if "ageGroup" in df.columns else np.nan
    return df[cols].astype(float).assign(age=age)


@dataclass(frozen=True)
class M1Bundle:
    regressor: xgb.XGBRegressor
    reg_cols: list[str]
    classifier: xgb.XGBClassifier
    clf_cols: list[str]
    iso_x: np.ndarray
    iso_y: np.ndarray

    def predict_minutes(self, df: pd.DataFrame) -> np.ndarray:
        ratio = self.regressor.predict(_matrix(df, self.reg_cols))
        minutes = np.where(df["mean7"] > 0, ratio * df["mean7"], df["y_lag1"])
        return np.clip(minutes, 0, None)

    def predict_over_limit(self, df: pd.DataFrame) -> np.ndarray:
        raw = self.classifier.predict_proba(_matrix(df, self.clf_cols))[:, 1]
        return np.interp(raw, self.iso_x, self.iso_y)


def train(daily: pd.DataFrame, n_estimators: int | None = None) -> M1Bundle:
    """Cùng công thức với XGBRelative và XGBClassifierIsotonic, trên toàn bộ dữ liệu có nhãn."""
    override = {} if n_estimators is None else {"n_estimators": n_estimators}

    labelled = daily[daily["y_next"].notna() & (daily["mean7"] > 0)]
    reg_cols = feature_columns(daily)
    ratio = (labelled["y_next"] / labelled["mean7"]).clip(upper=RATIO_CAP)
    regressor = xgb.XGBRegressor(**{**XGB_PARAMS, **override}).fit(_matrix(labelled, reg_cols), ratio)

    rows = daily[limited(daily)]
    if rows["over_limit_next"].nunique() < 2:
        raise BundleError("Dữ liệu có giới hạn chỉ có một lớp (toàn vượt hoặc toàn không) — không huấn luyện được")
    cut = rows["target_date"].quantile(1 - CALIBRATION_SHARE)
    fit_part, cal_part = rows[rows["target_date"] < cut], rows[rows["target_date"] >= cut]
    clf_cols = feature_columns(daily)
    classifier = xgb.XGBClassifier(**{**CLF_PARAMS, **override}).fit(
        _matrix(fit_part, clf_cols), fit_part["over_limit_next"].astype(int)
    )
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0, y_max=1).fit(
        classifier.predict_proba(_matrix(cal_part, clf_cols))[:, 1], cal_part["over_limit_next"].astype(int)
    )
    return M1Bundle(regressor, reg_cols, classifier, clf_cols, iso.X_thresholds_, iso.y_thresholds_)


def save(bundle: M1Bundle, out: Path, trained_on: str) -> None:
    out.mkdir(parents=True, exist_ok=True)
    bundle.regressor.save_model(out / "regressor.json")
    bundle.classifier.save_model(out / "classifier.json")
    iso = {"x": bundle.iso_x.tolist(), "y": bundle.iso_y.tolist()}
    (out / "isotonic.json").write_text(json.dumps(iso), encoding="utf-8")
    meta = {
        "version": FORMAT_VERSION,
        "trained_on": trained_on,
        "trained_at": date.today().isoformat(),
        "xgboost": xgb.__version__,
        "regressor": {"model": "xgb_rel", "columns": bundle.reg_cols},
        "classifier": {"model": "xgb_clf_iso", "columns": bundle.clf_cols},
    }
    (out / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def load(src: Path = DEFAULT_DIR) -> M1Bundle:
    missing = [name for name in FILES if not (src / name).exists()]
    if missing:
        raise BundleError(f"Gói M1 ở {src} thiếu: {', '.join(missing)}")
    meta = json.loads((src / "meta.json").read_text(encoding="utf-8"))
    if meta.get("version") != FORMAT_VERSION:
        raise BundleError(f"Gói M1 version {meta.get('version')}, cần {FORMAT_VERSION} — chạy lại bundle")
    regressor = xgb.XGBRegressor()
    regressor.load_model(src / "regressor.json")
    classifier = xgb.XGBClassifier()
    classifier.load_model(src / "classifier.json")
    iso = json.loads((src / "isotonic.json").read_text(encoding="utf-8"))
    return M1Bundle(
        regressor, meta["regressor"]["columns"], classifier, meta["classifier"]["columns"],
        np.asarray(iso["x"]), np.asarray(iso["y"]),
    )


def model_version(src: Path = DEFAULT_DIR) -> str:
    """Chuỗi ghi vào UsagePrediction.modelVersion, vd "xgb_rel+xgb_clf_iso@2026-11-05"."""
    meta = json.loads((src / "meta.json").read_text(encoding="utf-8"))
    return f"{meta['regressor']['model']}+{meta['classifier']['model']}@{meta['trained_at']}"


def main() -> None:
    from .data import sim_daily_features

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path, required=True, help="thư mục CSV của simulator")
    p.add_argument("--out", type=Path, default=DEFAULT_DIR)
    args = p.parse_args()
    daily = sim_daily_features(args.sim)
    save(train(daily), args.out, trained_on=f"sim:{args.sim.name} ({daily['profileId'].nunique()} trẻ)")
    print(f"Đã ghi gói M1 vào {args.out}")


if __name__ == "__main__":
    main()
