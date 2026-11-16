"""M1 — xác suất ngày mai DÙNG HẾT GIỜ: P(y_next ≥ limit_tomorrow − 5 phút) (từ 16/11; trước đó là P(y_next > limit),
nhưng máy bị chặn khi hết giờ nên "vượt" chỉ xảy ra khi xin thêm giờ được duyệt — p bị chặn trên ~0,5).

Chỉ chấm các ngày trẻ có giới hạn cho ngày t+1. Ba cách:
  - normal_ma7: giả sử y_next ~ N(mean7, std7) -> P = 1 − Φ((L − mean7) / std7)  (mô hình cơ sở);
  - xgb_clf: XGBoost phân loại trên bộ đặc trưng ngày;
  - xgb_clf_iso: như trên + hiệu chỉnh isotonic trên 20% cuối (theo thời gian) của tập huấn luyện.
  - xgb_clf_platt: như trên nhưng hiệu chỉnh Platt (gói M1 dùng từ 16/11);
  - reg_resid: xác suất suy từ bộ hồi quy số phút (ứng viên nhất quán theo cấu trúc).
Cảnh báo cho phụ huynh dựa vào xác suất, nên xác suất phải đáng tin (Brier, ECE) chứ không chỉ xếp hạng đúng (ROC-AUC).
"""

import numpy as np
import pandas as pd
import xgboost as xgb
from scipy.stats import norm
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, roc_auc_score

from features.daily import HIT_LIMIT_MARGIN_MIN

from .models import XGB_PARAMS, XGBRelative, _matrix, feature_columns

M1_LABEL = "hit_limit_next"
CALIBRATION_SHARE = 0.2
MIN_STD = 10.0
CLF_PARAMS = {**XGB_PARAMS, "objective": "binary:logistic", "eval_metric": "logloss"}


def limited(daily: pd.DataFrame) -> pd.Series:
    return daily["has_limit"].astype(bool) & daily[M1_LABEL].notna()


class NormalMA7:
    name = "normal_ma7"

    def fit(self, train):
        return self

    def predict_proba(self, test):
        std = test["std7"].fillna(MIN_STD).clip(lower=MIN_STD)
        mean = test["mean7"].fillna(test["y_lag1"])
        return 1 - norm.cdf(((test["limit_tomorrow"] - HIT_LIMIT_MARGIN_MIN - mean) / std).to_numpy())


class XGBClassifier:
    name = "xgb_clf"

    def fit(self, train):
        self.cols = feature_columns(train)
        y = train[M1_LABEL].astype(int)
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
        self.iso.fit(self.base.predict_proba(cal_part), cal_part[M1_LABEL].astype(int))
        return self

    def predict_proba(self, test):
        return self.iso.predict(self.base.predict_proba(test))


def _logit(raw: np.ndarray) -> np.ndarray:
    raw = np.clip(np.asarray(raw, dtype=float), 1e-6, 1 - 1e-6)
    return np.log(raw / (1 - raw))


def fit_platt(raw: np.ndarray, y: np.ndarray) -> tuple[float, float]:
    """Platt scaling: p = σ(a·logit(raw) + b), học trên tập hiệu chỉnh. Trả (a, b)."""
    lr = LogisticRegression().fit(_logit(raw).reshape(-1, 1), np.asarray(y, dtype=int))
    return float(lr.coef_[0, 0]), float(lr.intercept_[0])


def apply_platt(raw: np.ndarray, a: float, b: float) -> np.ndarray:
    return 1 / (1 + np.exp(-(a * _logit(raw) + b)))


class XGBClassifierPlatt:
    """Như xgb_clf_iso nhưng hiệu chỉnh bằng Platt: Brier như nhau, ECE 0,006 → 0,014, đổi lại xác suất liên tục
    (isotonic gộp khối nên chỉ ~26 mức — hai trẻ khác hẳn nhau cùng ra 0,362). Gói M1 dùng cách này từ 16/11."""

    name = "xgb_clf_platt"

    def fit(self, train):
        cut = train["target_date"].quantile(1 - CALIBRATION_SHARE)
        fit_part, cal_part = train[train["target_date"] < cut], train[train["target_date"] >= cut]
        self.base = XGBClassifier().fit(fit_part)
        self.a, self.b = fit_platt(self.base.predict_proba(cal_part), cal_part[M1_LABEL])
        return self

    def predict_proba(self, test):
        return apply_platt(self.base.predict_proba(test), self.a, self.b)


class RegResidual:
    """Xác suất suy từ CHÍNH bộ hồi quy số phút (xgb_rel) + phân phối sai số thực nghiệm, thay vì một bộ phân
    loại học riêng — để số phút dự đoán và xác suất không mâu thuẫn (vd 76 phút > giới hạn 67 mà p = 0).
    Sai số log r = log((y+1)/(m+1)) đo trên 20% cuối theo thời gian, dời cho trung vị = 0, nên
    m > L − 5 ⇔ p ≥ 0,5. p = tỷ lệ sai số r với (m+1)·e^r − 1 > L − 5: mịn theo m và L, không bậc thang như isotonic."""

    name = "reg_resid"

    def fit(self, train):
        rows = train[train["y_next"].notna()]
        cut = rows["target_date"].quantile(1 - CALIBRATION_SHARE)
        fit_part, cal_part = rows[rows["target_date"] < cut], rows[rows["target_date"] >= cut]
        self.reg = XGBRelative().fit(fit_part)
        pred = np.clip(self.reg.predict(cal_part), 0, None)
        resid = np.log1p(cal_part["y_next"].to_numpy()) - np.log1p(pred)
        resid = resid[np.isfinite(resid)]
        self.resid = np.sort(resid - np.median(resid))
        return self

    def predict_minutes(self, test):
        return np.clip(self.reg.predict(test), 0, None)

    def predict_proba(self, test):
        m = self.predict_minutes(test)
        threshold = np.log1p(test["limit_tomorrow"].to_numpy() - HIT_LIMIT_MARGIN_MIN) - np.log1p(m)
        # Hàm phân phối thực nghiệm nội suy tuyến tính (mốc (i+0.5)/n): liên tục dù tập hiệu chỉnh nhỏ, và vì
        # trung vị đã dời về 0 nên CDF(0) = 0,5 đúng → giữ m > L − 5 ⇔ p ≥ 0,5.
        n = len(self.resid)
        cdf = np.interp(threshold, self.resid, (np.arange(n) + 0.5) / n, left=0.0, right=1.0)
        return 1 - cdf


ALL_CLASSIFIERS = (NormalMA7, XGBClassifier, XGBClassifierIsotonic, XGBClassifierPlatt, RegResidual)


def walk_forward_proba(daily, models, test_start, test_end, fold_days=7, min_history=7) -> pd.DataFrame:
    rows = daily[limited(daily)]
    scored = rows["history_days"] >= min_history
    out = []
    for fold_start in pd.date_range(test_start, test_end, freq=f"{fold_days}D"):
        fold_end = fold_start + pd.Timedelta(days=fold_days)
        train = rows[rows["target_date"] < fold_start]
        test = rows[scored & (rows["target_date"] >= fold_start) & (rows["target_date"] < fold_end)]
        if test.empty or train[M1_LABEL].nunique() < 2:
            continue
        fold = test[["profileId", "target_date", M1_LABEL]].copy()
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
    y = preds[M1_LABEL].astype(int).to_numpy()
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
        so_ngay=(M1_LABEL, "size"),
        xac_suat_du_doan=(name, "mean"),
        ty_le_thuc_te=(M1_LABEL, lambda s: s.astype(float).mean()),
    )
