import json
from pathlib import Path

import pandas as pd
import pytest

from features import Calendar
from tier1.rules import DEFAULT_RULES, MAX_RELAX, build_baseline, check_hour, relax

VECTORS = Path(__file__).resolve().parents[1] / "tier1" / "test_vectors.json"

BASELINE = {
    "profileId": 1,
    "validUntil": "2026-10-21T00:00:00+07:00",
    "nightWindow": ["22:00", "06:00"],
    "baseline": [
        {"dayType": "school", "hour": 20, "cat": "game", "mean": 10.0, "std": 3.0},
        {"dayType": "school", "hour": 22, "cat": "video", "mean": 25.0, "std": 5.0},
        {"dayType": "weekend", "hour": 20, "cat": "game", "mean": 30.0, "std": 8.0},
    ],
    "rules": dict(DEFAULT_RULES),
}
CASES = [  # (tên, phút theo nhóm, giờ, loại ngày, kết quả mong đợi)
    ("2h sáng, thường ngủ", {"game": 25}, 2, "school", [["night", "game"], ["spike", "game"]]),
    ("22h, bé quen xem video giờ này", {"video": 30}, 22, "school", []),
    ("tối ngày học gấp 3,5 lần", {"game": 35}, 20, "school", [["spike", "game"]]),
    ("tối ngày học chưa tới 3 lần", {"game": 25}, 20, "school", []),
    ("cuối tuần quen chơi 30 phút", {"game": 35}, 20, "weekend", []),
    ("chưa tới 20 phút", {"study": 15}, 15, "school", []),
    ("khuya nhưng chưa tới 10 phút", {"social": 8}, 1, "off", []),
]


def test_vectors_file_matches_python_reference():
    """test_vectors.json là đặc tả dùng chung cho bản Kotlin; file phải khớp CASES và check_hour()."""
    data = json.loads(VECTORS.read_text(encoding="utf-8"))
    assert data["baseline"] == BASELINE
    assert [c["name"] for c in data["cases"]] == [c[0] for c in CASES]
    for case in data["cases"]:
        got = check_hour(case["minutes"], case["hour"], case["dayType"], data["baseline"])
        assert [list(a) for a in got] == case["expected"], case["name"]


@pytest.mark.parametrize("name, minutes, hour, day_type, expected", CASES)
def test_check_hour(name, minutes, hour, day_type, expected):
    assert [list(a) for a in check_hour(minutes, hour, day_type, BASELINE)] == expected, name


def test_relax_is_capped_and_pure():
    rules, counts = dict(DEFAULT_RULES), {}
    for _ in range(MAX_RELAX + 2):
        rules, counts = relax(rules, counts, "spike", "weekend", "game")
    assert rules["spikeRatioByKey"]["weekend:game"] == pytest.approx(3.0 * 1.25**MAX_RELAX)
    assert counts == {"weekend:game": MAX_RELAX}
    assert "spikeRatioByKey" not in DEFAULT_RULES
    relaxed = {**BASELINE, "rules": rules}
    assert check_hour({"game": 100}, 20, "weekend", relaxed) == []  # 100 < 4,69 × 30
    assert check_hour({"game": 35}, 20, "school", relaxed) == [("spike", "game")]  # ngày học không bị nới


def test_build_baseline_json():
    days = pd.date_range("2026-09-01", periods=28)
    cats = ("video", "game", "social", "study", "other")
    hours = pd.DataFrame(
        [
            {"date": d, "hour": h, "day_type": "school",
             **{f"hour_min_{c}": (20.0 if (h == 21 and c == "video") else 0.0) for c in cats}}
            for d in days
            for h in range(24)
        ]
    )
    b = build_baseline(hours, 7, pd.Timestamp("2026-09-29"), calendar=Calendar.load(),
                       categories={"com.google.android.youtube": "video"})
    assert b["profileId"] == 7 and b["validUntil"] == "2026-09-30T00:00:00+07:00"
    assert b["categories"] == {"com.google.android.youtube": "video"}
    assert b["dayTypes"] == {"2026-09-28": "school", "2026-09-29": "school", "2026-09-30": "school"}
    off = build_baseline(hours, 7, pd.Timestamp("2026-04-30"), calendar=Calendar.load())["dayTypes"]
    assert off == {"2026-04-29": "school", "2026-04-30": "off", "2026-05-01": "off"}  # 30/4, 1/5
    assert b["baseline"] == [{"dayType": "school", "hour": 21, "cat": "video", "mean": 20.0, "std": 0.0}]
    assert len(json.dumps(b)) < 20_000


def test_feedback_policy_reduces_alerts():
    from models.m2.feedback import run_policy

    days = pd.date_range("2026-01-05", periods=70)
    rows = []
    for d in days:
        late = d >= pd.Timestamp("2026-03-02")
        for h in range(24):
            game = 12.0 if (late and h == 1) else (10.0 if h == 20 else 0.0)  # chỉ vượt luật khuya (>= 10)
            rows.append({"profileId": 1, "date": d, "hour": h, "day_type": "school", "hour_min": game,
                         "hour_min_game": game, "hour_min_video": 0.0, "hour_min_social": 0.0,
                         "hour_min_study": 0.0, "hour_min_other": 0.0, "label": False})
    hours = pd.DataFrame(rows)  # dùng khuya đều đặn từ 02/03 nhưng phụ huynh coi là "được phép"
    without = run_policy(hours, None)
    with_feedback = run_policy(hours, 0.0)
    assert with_feedback["cảnh báo"].sum() < without["cảnh báo"].sum()


def test_kotlin_copy_of_vectors_is_identical():
    """App trẻ test luật tầng 1 bằng bản sao này — sửa ca kiểm thử thì phải copy lại."""
    kotlin = VECTORS.parents[2] / "mobile/android/app/src/test/resources/tier1_test_vectors.json"
    assert kotlin.read_text(encoding="utf-8") == VECTORS.read_text(encoding="utf-8")
