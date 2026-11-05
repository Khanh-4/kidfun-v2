import json
from datetime import date

import numpy as np
import pytest

from features import Calendar, build_daily_features, load_categories
from models.m1 import bundle
from models.m1.over_limit import limited
from simulator import simulate


@pytest.fixture(scope="module")
def daily():
    s = simulate(6, "2025-09-01", 120, seed=11)
    d = build_daily_features(
        s["app_usage_hourly"], calendar=Calendar.load(), categories=load_categories(), limits=s["time_limits"]
    )
    return d.merge(s["profiles"][["profileId", "ageGroup"]], on="profileId")


@pytest.fixture(scope="module")
def saved(daily, tmp_path_factory):
    out = tmp_path_factory.mktemp("m1")
    trained = bundle.train(daily, n_estimators=30)
    bundle.save(trained, out, trained_on="test-sim")
    return trained, out


def test_save_writes_only_portable_files(saved):
    _, out = saved
    assert sorted(p.name for p in out.iterdir()) == sorted(bundle.FILES)
    meta = json.loads((out / "meta.json").read_text())
    assert meta["version"] == bundle.FORMAT_VERSION
    assert meta["trained_on"] == "test-sim"
    assert meta["regressor"]["columns"] and meta["classifier"]["columns"]


def test_loaded_bundle_predicts_exactly_like_the_trained_one(saved, daily):
    trained, out = saved
    loaded = bundle.load(out)
    rows = daily.dropna(subset=["y_next"]).tail(50)
    np.testing.assert_allclose(loaded.predict_minutes(rows), trained.predict_minutes(rows), rtol=1e-6)
    lim = daily[limited(daily)].tail(50)
    np.testing.assert_allclose(loaded.predict_over_limit(lim), trained.predict_over_limit(lim), rtol=1e-6)


def test_over_limit_probability_stays_in_unit_interval(saved, daily):
    p = bundle.load(saved[1]).predict_over_limit(daily[limited(daily)])
    assert ((p >= 0) & (p <= 1)).all()


def test_minutes_are_never_negative_and_nan_only_without_history(saved, daily):
    minutes = bundle.load(saved[1]).predict_minutes(daily)
    no_history = ~(daily["mean7"] > 0) & daily["y_lag1"].isna()
    np.testing.assert_array_equal(np.isnan(minutes), no_history.to_numpy())
    assert (minutes[~np.isnan(minutes)] >= 0).all()


def test_missing_feature_column_fails_loudly(saved, daily):
    rows = daily.drop(columns=["mean7"]).tail(5)
    with pytest.raises(bundle.BundleError, match="mean7"):
        bundle.load(saved[1]).predict_minutes(rows)


def test_missing_age_group_is_allowed_as_unknown(saved, daily):
    """Dữ liệu thật (thesis-data) chưa trả ageGroup — mô hình phải chạy được, coi tuổi là thiếu."""
    rows = daily.drop(columns=["ageGroup"]).dropna(subset=["y_next"]).tail(5)
    assert np.isfinite(bundle.load(saved[1]).predict_minutes(rows)).all()


def test_wrong_format_version_is_rejected(saved, tmp_path):
    _, out = saved
    for name in bundle.FILES:
        (tmp_path / name).write_bytes((out / name).read_bytes())
    meta = json.loads((tmp_path / "meta.json").read_text())
    (tmp_path / "meta.json").write_text(json.dumps({**meta, "version": 999}))
    with pytest.raises(bundle.BundleError, match="version"):
        bundle.load(tmp_path)


def test_model_version_doc_tu_meta(saved):
    assert bundle.model_version(saved[1]) == f"xgb_rel+xgb_clf_iso@{date.today().isoformat()}"
