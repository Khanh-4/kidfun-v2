import pandas as pd
import pytest

from models import survey


@pytest.fixture(scope="module")
def days():
    # Bảng ngày nhỏ có nhãn, đủ các loại bất thường, như sim_m2_frames trả về
    rows = []
    kinds = ["danger_content", "new_app", "night_use", "binge_day", "spike"] * 8
    for i, kind in enumerate(kinds):
        rows.append({
            "profileId": i % 7, "date": pd.Timestamp("2026-03-02") + pd.Timedelta(days=i), "label": True, "kind": kind,
            # số liệu đổi theo i để mỗi ngày ra một câu khác nhau; "spike" có thêm ứng dụng mới → câu nói sai loại
            "day_min": (300.0 if kind == "binge_day" else 120.0) + i, "day_ratio": 2.5 if kind == "binge_day" else 1.1,
            "night_min": 40.0 + i if kind == "night_use" else 0.0,
            "new_app_min": 30.0 + i if kind in ("new_app", "spike") else 0.0,
            "yt_danger_high": 1 + i if kind == "danger_content" else 0, "max_hour_min": 50.0 + i, "ext_req": 0,
        })
    return pd.DataFrame(rows)


def test_twenty_items_mixing_correct_and_wrong_explanations(days):
    items = survey.build_items(days, n=20, n_wrong=6, seed=1)
    assert len(items) == 20
    assert (~items["đúng"]).sum() == 6
    assert items["câu cảnh báo"].is_unique


def test_wrong_items_pair_a_situation_with_another_days_sentence_of_a_different_kind(days):
    # Câu "sai" phải mâu thuẫn với CHÍNH tình huống phụ huynh thấy — không dựa vào nhãn nội bộ của bộ mô phỏng
    # (vd ngày "tăng đột biến" được cài bằng một ứng dụng mới: câu "dùng ứng dụng mới" là đúng với số liệu).
    items = survey.build_items(days, n=20, n_wrong=6, seed=1)
    wrong = items[~items["đúng"]]
    assert (wrong["loại câu nói"] != wrong["loại tình huống"]).all()
    assert (items.loc[items["đúng"], "loại câu nói"] == items.loc[items["đúng"], "loại tình huống"]).all()


def test_situation_does_not_repeat_the_sentence_and_survey_hides_the_key(days):
    items = survey.build_items(days, n=20, n_wrong=6, seed=1)
    assert all(s not in t for s, t in zip(items["câu cảnh báo"], items["tình huống"]))
    text = survey.survey_markdown(items)
    for secret in ("binge_day", "night_use", "danger_content", "True", "False"):
        assert secret not in text
    assert text.count("Mức dễ hiểu") == 20


def test_score_reports_understandability_and_whether_parents_catch_wrong_ones():
    key = pd.DataFrame({"câu": [1, 2, 3, 4], "đúng": [True, True, False, False]})
    resp = pd.DataFrame({"người": ["a"] * 4 + ["b"] * 4, "câu": [1, 2, 3, 4] * 2,
                         "dễ hiểu": [5, 4, 2, 3, 4, 4, 3, 1], "nhận xét": ["Đúng", "Đúng", "Sai", "Đúng"] * 2})
    s = survey.score(resp, key)
    assert s["điểm dễ hiểu TB"] == pytest.approx(3.25)
    assert s["% câu đúng được phụ huynh công nhận"] == pytest.approx(100.0)
    assert s["% câu sai bị phụ huynh phát hiện"] == pytest.approx(50.0)
