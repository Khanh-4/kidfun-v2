import numpy as np
import pandas as pd
import pytest

from models.explain import explain_day, explain_hour, explain_over_limit, minutes, times, top_reasons
from models.m2.data import sim_m2_frames
from models.m2.detectors import day_detectors, hour_detectors
from models.m2.evaluate import explanation_accuracy, score_level
from simulator import simulate

SPLIT = pd.Timestamp("2025-12-15")


@pytest.fixture(scope="module")
def frames(tmp_path_factory):
    out = tmp_path_factory.mktemp("sim")
    for name, df in simulate(8, "2025-09-01", 150, seed=5).items():
        df.to_csv(out / f"{name}.csv", index=False)
    hours, days, stats = sim_m2_frames(out)
    hours = hours[(hours["hour_min"] > 0) & (hours["base_days"] >= 7)].reset_index(drop=True)
    return hours, days[days["day_ratio"].notna()].reset_index(drop=True), stats


def test_labels_only_on_hours_that_still_have_usage(frames):
    hours, days, stats = frames
    assert hours["label"].sum() > 0 and days["label"].sum() > 0
    assert (hours.loc[hours["label"], "hour_min"] > 0).all()
    assert not hours["kind"].isin(["binge_day", "danger_content"]).any()
    assert stats["nhãn giờ còn dùng máy (giữ)"] <= stats["nhãn giờ cài vào"]


@pytest.mark.parametrize("level", ["hour", "day"])
def test_detectors_give_finite_scores(frames, level):
    hours, days, _ = frames
    frame, detectors = (hours, hour_detectors()) if level == "hour" else (days, day_detectors())
    for det in detectors:
        s = det.fit(frame).score(frame)
        assert s.shape == (len(frame),) and np.isfinite(s).all()


def test_rules_catch_night_use_and_threshold_comes_from_train(frames):
    hours, _, _ = frames
    table, test, alerts = score_level(hours, hour_detectors()[:2], 0.01, split=SPLIT)
    assert {"PR-AUC", "Precision", "Recall", "F1"} <= set(table.columns)
    assert table.loc["luật tầng 1", "recall night_use"] > 0.8
    assert len(alerts["z-score"]) == len(test)


def test_explanation_accuracy_table(frames):
    hours, _, _ = frames
    table, test, alerts = score_level(hours, hour_detectors()[:1], 0.01, split=SPLIT)
    acc, examples = explanation_accuracy(test, alerts["luật tầng 1"], explain_hour)
    assert acc["câu giải thích đúng loại"].between(0, 1).all()
    assert examples["cau"].str.startswith("Bé").all()


def test_readable_numbers():
    assert times(2.87) == "gấp 3 lần" and times(1.46) == "gấp 1,5 lần"
    assert minutes(45) == "45 phút" and minutes(150) == "2 giờ 30 phút" and minutes(120) == "2 giờ"


def test_hour_sentences_pick_the_right_reason():
    base = {
        "hour": 2, "hour_min": 35, "base_mean": 0.5, "is_night": True, "in_sleep_window": True,
        "new_app_min": 0, "hour_min_game": 35, "hour_min_video": 0,
    }
    kind, text = explain_hour(pd.Series(base))
    assert kind == "night_use" and "chơi game lúc 2h trong 35 phút" in text and "z" not in text.lower()
    spike = {**base, "hour": 20, "is_night": False, "in_sleep_window": False, "hour_min": 60, "base_mean": 20}
    assert explain_hour(pd.Series(spike)) == (
        "spike",
        "Bé chơi game lúc 20h gấp 3 lần so với bình thường (1 giờ, thường khoảng 20 phút).",
    )
    assert explain_hour(pd.Series({**spike, "new_app_min": 40}), "Roblox")[0] == "new_app"


def test_day_and_over_limit_sentences():
    day = {"yt_danger_high": 2, "new_app_min": 0, "night_min": 0, "day_ratio": 1.0, "day_min": 100, "max_hour_min": 30}
    assert explain_day(pd.Series(day))[0] == "danger_content"
    binge = {**day, "yt_danger_high": 0, "day_ratio": 2.6, "day_min": 390, "day_type": "school"}
    kind, text = explain_day(pd.Series(binge))
    assert kind == "binge_day" and "gấp 3 lần một ngày đi học bình thường" in text
    _, text = explain_over_limit(pd.Timestamp("2026-10-11"), 120, 0.68, "is_weekend")
    assert text == (
        "Ngày mai (Chủ nhật) bé có khả năng dùng quá giới hạn 2 giờ (khoảng 70%). Lý do chính: ngày mai là cuối tuần."
    )


def test_top_reasons_uses_xgboost_shap():
    import xgboost as xgb

    x = pd.DataFrame({"is_weekend": [0, 1] * 50, "noise": np.random.default_rng(0).random(100)})
    model = xgb.XGBClassifier(n_estimators=20, max_depth=2, n_jobs=1).fit(x, x["is_weekend"])
    assert top_reasons(model, x.iloc[[1]], k=1) == [["is_weekend"]]
