import json

import numpy as np
import pytest

from features import Calendar, build_day_anomaly_features, load_categories
from models.m2 import day_bundle
from simulator import simulate


@pytest.fixture(scope="module")
def days():
    s = simulate(8, "2025-09-01", 90, seed=5)
    return build_day_anomaly_features(
        s["app_usage_hourly"], calendar=Calendar.load(), categories=load_categories(),
        youtube=s["youtube_logs"], ext_requests=s["time_extension_requests"],
    )


@pytest.fixture(scope="module")
def saved(days, tmp_path_factory):
    out = tmp_path_factory.mktemp("m2day")
    trained = day_bundle.train(days)
    day_bundle.save(trained, out, trained_on="test-sim")
    return trained, out


def test_save_writes_only_portable_json(saved):
    _, out = saved
    assert sorted(p.name for p in out.iterdir()) == sorted(day_bundle.FILES)
    meta = json.loads((out / "meta.json").read_text())
    assert meta["version"] == day_bundle.FORMAT_VERSION
    assert meta["trained_on"] == "test-sim"
    assert meta["alert_rate"] == day_bundle.ALERT_RATE


def test_loaded_bundle_scores_exactly_like_the_trained_one(saved, days):
    trained, out = saved
    loaded = day_bundle.load(out)
    np.testing.assert_allclose(loaded.score(days), trained.score(days), rtol=1e-9)
    assert loaded.threshold == trained.threshold


def test_flags_about_alert_rate_of_training_days(saved, days):
    trained, _ = saved
    rate = trained.flag(days).mean()
    assert 0.02 <= rate <= 0.08


def test_missing_files_raise_bundle_error(tmp_path):
    with pytest.raises(day_bundle.BundleError):
        day_bundle.load(tmp_path)


def test_alert_rate_matches_evaluation():
    from models.m2.evaluate import DAY_ALERT_RATE

    assert day_bundle.ALERT_RATE == DAY_ALERT_RATE
