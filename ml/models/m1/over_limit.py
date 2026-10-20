"""M1 — xác suất ngày mai dùng quá giới hạn: P(y_next > limit_tomorrow).

Chỉ chấm các ngày trẻ có giới hạn cho ngày t+1. Ba cách:
  - normal_ma7: giả sử y_next ~ N(mean7, std7) -> P = 1 − Φ((L − mean7) / std7)  (mô hình cơ sở);
  - xgb_clf: XGBoost phân loại trên bộ đặc trưng ngày;
  - xgb_clf_iso: như trên + hiệu chỉnh isotonic trên 20% cuối (theo thời gian) của tập huấn luyện.
Cảnh báo cho phụ huynh dựa vào xác suất, nên xác suất phải đáng tin (Brier, ECE) chứ không chỉ xếp hạng đúng (ROC-AUC).
"""

import numpy as np
import pandas as pd
import xgboost as xgb
from scipy.stats import norm
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss, roc_auc_score

from .models import XGB_PARAMS, _matrix, feature_columns

CALIBRATION_SHARE = 0.2
MIN_STD = 10.0
CLF_PARAMS = {**XGB_PARAMS, "objective": "binary:logistic", "eval_metric": "logloss"}


def limited(daily: pd.DataFrame) -> pd.Series:
    return daily["has_limit"].astype(bool) & daily["over_limit_next"].notna()


class NormalMA7:
    name = "normal_ma7"

    def fit(self, train):
        return self

    def predict_proba(self, test):
        std = test["std7"].fillna(MIN_STD).clip(lower=MIN_STD)
        mean = test["mean7"].fillna(test["y_lag1"])
        return 1 - norm.cdf(((test["limit_tomorrow"] - mean) / std).to_numpy())


class XGBClassifier:
    name = "xgb_clf"

    def fit(self, train):
        self.cols = feature_columns(train)
        y = train["over_limit_next"].astype(int)
        self.model = xgb.XGBClassifier(**CLF_PARAMS).fit(_matrix(train, self.cols), y)
        return self

    def predict_proba(self, test):
        return self.model.predict_proba(_matrix(test, self.cols))[:, 1]


class XGBClassifierIsotonic:
    name = "xgb_clf_iso"

    def fit(self, train):
        cut = train["target_date"].quantile(1 - CALIBRATION_SHARE)
        fit_part, cal_part = train[train["target_date"] < cut], train[train["target_date"] >= cut]
        self.base = XGBClassifier().fit(fit_part)
        self.iso = IsotonicRegression(out_of_bounds="clip", y_min=0, y_max=1)
        self.iso.fit(self.base.predict_proba(cal_part), cal_part["over_limit_next"].astype(int))
        return self

    def predict_proba(self, test):
        return self.iso.predict(self.base.predict_proba(test))


ALL_CLASSIFIERS = (NormalMA7, XGBClassifier, XGBClassifierIsotonic)


def walk_forward_proba(daily, models, test_start, test_end, fold_days=7, min_history=7) -> pd.DataFrame:
    rows = daily[limited(daily)]
    scored = rows["history_days"] >= min_history
    out = []
    for fold_start in pd.date_range(test_start, test_end, freq=f"{fold_days}D"):
        fold_end = fold_start + pd.Timedelta(days=fold_days)
        train = rows[rows["target_date"] < fold_start]
        test = rows[scored & (rows["target_date"] >= fold_start) & (rows["target_date"] < fold_end)]
        if test.empty or train["over_limit_next"].nunique() < 2:
            continue
        fold = test[["profileId", "target_date", "over_limit_next"]].copy()
        for model_cls in models:
            fold[model_cls.name] = model_cls().fit(train).predict_proba(test)
        out.append(fold)
    return pd.concat(out, ignore_index=True)


def expected_calibration_error(y: np.ndarray, p: np.ndarray, bins: int = 10) -> float:
    edges = np.linspace(0, 1, bins + 1)
    which = np.clip(np.digitize(p, edges) - 1, 0, bins - 1)
    return float(
        sum(abs(p[which == b].mean() - y[which == b].mean()) * (which == b).mean() for b in range(bins) if (which == b).any())
    )


def proba_metrics(preds: pd.DataFrame, names) -> pd.DataFrame:
    y = preds["over_limit_next"].astype(int).to_numpy()
    rows = [
        {
            "model": n,
            "ROC-AUC": roc_auc_score(y, preds[n]),
            "Brier": brier_score_loss(y, preds[n]),
            "ECE": expected_calibration_error(y, preds[n].to_numpy()),
        }
        for n in names
    ]
    return pd.DataFrame(rows).set_index("model")


def reliability_table(preds: pd.DataFrame, name: str, bins: int = 5) -> pd.DataFrame:
    band = pd.cut(preds[name], np.linspace(0, 1, bins + 1), include_lowest=True)
    return preds.groupby(band, observed=True).agg(
        so_ngay=("over_limit_next", "size"),
        xac_suat_du_doan=(name, "mean"),
        ty_le_vuot_thuc_te=("over_limit_next", lambda s: s.astype(float).mean()),
    )
