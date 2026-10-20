import numpy as np
import pandas as pd
import pytest

from features import Calendar, build_daily_features, load_categories
from models.m1 import evaluate
from models.m1.models import MovingAverage7, Naive, SeasonalNaive, XGBAbsolute, XGBRelative
from simulator import simulate


@pytest.fixture(scope="module")
def daily():
    s = simulate(6, "2025-09-01", 120, seed=11)
    d = build_daily_features(
        s["app_usage_hourly"], calendar=Calendar.load(), categories=load_categories(), limits=s["time_limits"]
    )
    return d.merge(s["profiles"][["profileId", "ageGroup"]], on="profileId")


def test_baselines_use_the_documented_columns(daily):
    rows = daily.dropna(subset=["y_lag1", "mean7"]).head(5)
    np.testing.assert_array_equal(Naive().predict(rows), rows["y_lag1"])
    np.testing.assert_array_equal(MovingAverage7().predict(rows), rows["mean7"])
    expected = rows["y_same_dow_last_week"].fillna(rows["y_lag1"])
    np.testing.assert_array_equal(SeasonalNaive().predict(rows), expected)


def test_walk_forward_never_trains_on_the_future(daily):
    seen = []

    class Spy(Naive):
        name = "spy"

        def fit(self, train):
            seen.append(train["target_date"].max())
            return self

    preds = evaluate.walk_forward(daily, [Spy], pd.Timestamp("2025-11-03"), pd.Timestamp("2025-11-30"))
    folds = pd.date_range("2025-11-03", "2025-11-30", freq="7D")
    assert all(latest < start for latest, start in zip(seen, folds))
    assert (preds["target_date"] >= pd.Timestamp("2025-11-03")).all()


def test_only_rows_with_a_week_of_history_are_scored(daily):
    preds = evaluate.walk_forward(daily, [Naive], pd.Timestamp("2025-09-01"), pd.Timestamp("2025-09-30"))
    first = daily.groupby("profileId")["date"].min().min()
    assert (preds["target_date"] >= first + pd.Timedelta(days=8)).all()


@pytest.mark.parametrize("model_cls", [XGBAbsolute, XGBRelative])
def test_xgboost_models_beat_naive_in_sample(daily, model_cls):
    rows = daily[evaluate.evaluable(daily)]
    pred = model_cls().fit(rows).predict(rows)
    mae = np.abs(pred - rows["y_next"]).mean()
    assert mae < np.abs(Naive().predict(rows) - rows["y_next"]).mean()
