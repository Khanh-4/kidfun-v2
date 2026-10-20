"""Các mô hình M1 — dự đoán tổng phút dùng máy ngày t+1 (y_next) từ bảng đặc trưng ngày.

Mọi mô hình có cùng giao diện fit(train) / predict(test) trên DataFrame của build_daily_features().
"""

import logging

import numpy as np
import pandas as pd
import xgboost as xgb

NON_FEATURES = {"profileId", "date", "target_date", "y_next", "over_limit_next", "ageGroup"}
AGE_MID = {"3-5": 4.0, "6-10": 8.0, "11-14": 12.5, "15-17": 16.0}


def feature_columns(df: pd.DataFrame) -> list[str]:
    return [c for c in df.columns if c not in NON_FEATURES]


def _matrix(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    x = df[cols].astype(float)
    return x.assign(age=df["ageGroup"].map(AGE_MID))


class Naive:
    """Ngày mai = ngày đầy đủ gần nhất (t−1); lúc 21:00 ngày t chưa biết tổng của ngày t."""

    name = "naive"

    def fit(self, train):
        return self

    def predict(self, test):
        return test["y_lag1"].to_numpy()


class SeasonalNaive:
    """Ngày mai = cùng thứ tuần trước; thiếu thì lấy naive."""

    name = "seasonal_naive"

    def fit(self, train):
        return self

    def predict(self, test):
        return test["y_same_dow_last_week"].fillna(test["y_lag1"]).to_numpy()


class MovingAverage7:
    name = "ma7"

    def fit(self, train):
        return self

    def predict(self, test):
        return test["mean7"].fillna(test["y_lag1"]).to_numpy()


XGB_PARAMS = dict(
    n_estimators=400,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    min_child_weight=5,
    objective="reg:absoluteerror",
    tree_method="hist",
    n_jobs=4,  # để mặc định (mọi luồng) chậm hơn ~140 lần trên WSL do tranh chấp luồng OpenMP
    random_state=0,
)


class XGBAbsolute:
    """Mô hình chung cho mọi trẻ, dự đoán thẳng số phút."""

    name = "xgb_abs"

    def fit(self, train):
        self.cols = feature_columns(train)
        self.model = xgb.XGBRegressor(**XGB_PARAMS).fit(_matrix(train, self.cols), train["y_next"])
        return self

    def predict(self, test):
        return self.model.predict(_matrix(test, self.cols))


class XGBRelative:
    """Mô hình chung dự đoán TỶ LỆ y_next / mean7 (đặc trưng tương đối — đề xuất sau EDA tuần 1),
    rồi nhân lại với mean7 của từng trẻ."""

    name = "xgb_rel"

    def fit(self, train):
        rows = train[train["mean7"] > 0]
        self.cols = feature_columns(train)
        ratio = (rows["y_next"] / rows["mean7"]).clip(upper=10)
        self.model = xgb.XGBRegressor(**XGB_PARAMS).fit(_matrix(rows, self.cols), ratio)
        return self

    def predict(self, test):
        ratio = self.model.predict(_matrix(test, self.cols))
        return np.where(test["mean7"] > 0, ratio * test["mean7"], test["y_lag1"])


class ProphetPerChild:
    """Mỗi trẻ một mô hình Prophet: xu hướng + chu kỳ tuần + biến lịch VN (ngày học, nghỉ, thi).
    Chỉ dùng chuỗi tổng theo ngày tới hết tập huấn luyện -> dự đoán nhiều bước (1–7 ngày) cho cả tuần
    kiểm tra, không dùng thông tin trong ngày như các mô hình khác."""

    name = "prophet"
    REGRESSORS = ("is_school_day", "is_exam_period", "is_summer", "is_holiday")
    MIN_DAYS = 14

    def fit(self, train):
        from prophet import Prophet  # import chậm: chỉ nạp khi dùng

        logging.getLogger("cmdstanpy").disabled = True
        self.models = {}
        for pid, g in train.groupby("profileId"):
            hist = g.dropna(subset=["y_next"])
            if len(hist) < self.MIN_DAYS:
                continue
            m = Prophet(
                weekly_seasonality=True,
                yearly_seasonality=False,
                daily_seasonality=False,
                uncertainty_samples=0,  # chỉ cần yhat
            )
            for r in self.REGRESSORS:
                m.add_regressor(r)
            m.fit(self._frame(hist).assign(y=hist["y_next"].to_numpy()))
            self.models[pid] = m
        return self

    def predict(self, test):
        out = pd.Series(np.nan, index=test.index)
        for pid, g in test.groupby("profileId"):
            if pid in self.models:
                out[g.index] = self.models[pid].predict(self._frame(g))["yhat"].clip(lower=0).to_numpy()
        return out.fillna(test["mean7"]).fillna(test["y_lag1"]).to_numpy()

    def _frame(self, g):
        regressors = {r: g[r].astype(float).to_numpy() for r in self.REGRESSORS}
        return pd.DataFrame({"ds": g["target_date"].to_numpy(), **regressors})


ALL_MODELS = (Naive, SeasonalNaive, MovingAverage7, XGBAbsolute, XGBRelative, ProphetPerChild)
