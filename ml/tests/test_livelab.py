import pandas as pd
import pytest

from features.common import to_vn
from models.m1.data import livelab_events, livelab_hourly

# 2010-11-15 là giờ chuẩn miền Trung Mỹ (CST = UTC−6); 2010-07-01 là giờ mùa hè (CDT = UTC−5)
T_NOV = int(pd.Timestamp("2010-11-15 15:50", tz="UTC").timestamp())  # 09:50 giờ Houston
T_JUL = int(pd.Timestamp("2010-07-01 15:10", tz="UTC").timestamp())  # 10:10 giờ Houston

SQL = f"""--
-- header
CREATE TABLE appusage (id integer, uid character varying, name character varying, "time" integer, duration integer);

INSERT INTO appusage VALUES (1, 'A01', 'com.facebook.Facebook', {T_NOV}, 1200);
INSERT INTO appusage VALUES (2, 'A01', 'SpringBoard', {T_NOV + 1200}, 30);
INSERT INTO appusage VALUES (3, 'A01', 'com.apple.MobileSMS', {T_JUL}, 60);
INSERT INTO appusage VALUES (4, 'B02', 'com.empty.app', {T_JUL}, 0);
INSERT INTO appusage VALUES (5, 'B02', 'com.weather.TWC', {T_JUL}, 999999);
"""


@pytest.fixture
def sql_file(tmp_path):
    p = tmp_path / "appusage.sql"
    p.write_text(SQL, encoding="utf-8")
    return p


def test_events_parse_insert_rows_and_drop_home_screen_and_empty(sql_file):
    ev = livelab_events(sql_file)

    assert "SpringBoard" not in set(ev["name"])
    assert (ev["duration"] > 0).all()
    assert set(ev["uid"]) == {"A01", "B02"}


def test_long_sessions_are_capped(sql_file):
    ev = livelab_events(sql_file)

    assert ev.loc[ev["name"] == "com.weather.TWC", "duration"].item() == 4 * 3600


def test_session_crossing_an_hour_is_split_by_local_hour(sql_file):
    h = livelab_hourly(sql_file)
    fb = h[h["packageName"] == "com.facebook.Facebook"].sort_values("hourStart")

    # 09:50–10:10 giờ Houston: 10 phút giờ 9, 10 phút giờ 10
    assert fb["usageSeconds"].tolist() == [600, 600]
    # Quy ước như LSApp/StudentLife: to_vn() trả lại đúng giờ địa phương gốc
    assert to_vn(fb["hourStart"]).dt.hour.tolist() == [9, 10]


def test_daylight_saving_time_is_respected(sql_file):
    h = livelab_hourly(sql_file)
    sms = h[h["packageName"] == "com.apple.MobileSMS"]

    assert to_vn(sms["hourStart"]).dt.hour.tolist() == [10]  # CDT: 15:10 UTC = 10:10


def test_hourly_matches_app_usage_hourly_schema(sql_file):
    h = livelab_hourly(sql_file)

    assert list(h.columns) == ["profileId", "packageName", "hourStart", "usageSeconds", "launchCount"]
    assert str(h["hourStart"].dt.tz) == "UTC"
    assert (h["usageSeconds"] <= 3600).all()
