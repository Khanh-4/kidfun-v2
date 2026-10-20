"""Câu giải thích tiếng Việt cho phụ huynh (đặc tả 05 mục 3).

Quy tắc: chọn 1 lý do lệch nhiều nhất; làm tròn số dễ đọc ("gấp 3 lần", không "gấp 2,87 lần");
không nêu điểm số, z-score hay tên đặc trưng kỹ thuật.
Mỗi hàm trả về (loại, câu) — "loại" dùng để kiểm tra câu giải thích có nói đúng loại bất thường không.
"""

import numpy as np
import pandas as pd
import xgboost as xgb

CATEGORY_VI = {
    "video": "xem video",
    "game": "chơi game",
    "social": "dùng mạng xã hội",
    "study": "dùng app học tập",
    "other": "dùng ứng dụng khác",
}
DAY_TYPE_VI = {"school": "ngày đi học", "weekend": "ngày cuối tuần", "off": "ngày nghỉ"}
WEEKDAY_VI = ("Chủ nhật", "thứ Hai", "thứ Ba", "thứ Tư", "thứ Năm", "thứ Sáu", "thứ Bảy")
NOTABLE_MINUTES = 10
SPIKE_RATIO = 2.0
MIN_BASE = 5.0


def times(ratio: float) -> str:
    """'gấp 3 lần', 'gấp 1,5 lần' — làm tròn tới số nguyên khi >= 2."""
    if ratio >= 2:
        return f"gấp {round(ratio)} lần"
    return f"gấp {ratio:.1f} lần".replace(".", ",")


def minutes(m: float) -> str:
    m = int(round(m))
    if m < 60:
        return f"{m} phút"
    h, rest = divmod(m, 60)
    return f"{h} giờ {rest} phút" if rest else f"{h} giờ"


def _top_category(row) -> str:
    cats = {c: row.get(f"hour_min_{c}", 0) for c in CATEGORY_VI}
    return max(cats, key=cats.get)


def explain_hour(row: pd.Series, new_app_name: str | None = None) -> tuple[str, str]:
    hour, used = int(row["hour"]), row["hour_min"]
    new_app = row.get("new_app_min", 0)
    if new_app and new_app >= NOTABLE_MINUTES:
        name = new_app_name or "một ứng dụng bé chưa từng dùng"
        return "new_app", f"Bé dùng {name} lúc {hour}h trong {minutes(new_app)}."
    if (row["is_night"] or row["in_sleep_window"]) and used >= NOTABLE_MINUTES:
        activity = CATEGORY_VI[_top_category(row)]
        return "night_use", f"Bé {activity} lúc {hour}h trong {minutes(used)} — giờ này bé thường đã ngủ."
    usual = row.get("base_mean", 0) or 0
    if used / max(usual, MIN_BASE) >= SPIKE_RATIO:
        activity = CATEGORY_VI[_top_category(row)]
        return "spike", (
            f"Bé {activity} lúc {hour}h {times(used / max(usual, MIN_BASE))} so với bình thường "
            f"({minutes(used)}, thường khoảng {minutes(usual)})."
        )
    return "other", f"Bé dùng máy lúc {hour}h trong {minutes(used)}, khác với thói quen thường ngày."


def explain_day(row: pd.Series) -> tuple[str, str]:
    if row.get("yt_danger_high", 0) > 0:
        return "danger_content", f"Hôm nay bé xem {int(row['yt_danger_high'])} video có thể không phù hợp với lứa tuổi."
    new_app = row.get("new_app_min", 0)
    if new_app and new_app >= NOTABLE_MINUTES:
        return "new_app", f"Hôm nay bé dùng một ứng dụng mới trong {minutes(new_app)}."
    if row.get("night_min", 0) >= NOTABLE_MINUTES:
        return "night_use", f"Bé dùng máy {minutes(row['night_min'])} vào giờ ngủ (từ 22h tới 6h sáng)."
    ratio = row.get("day_ratio")
    if ratio is not None and not np.isnan(ratio) and ratio >= SPIKE_RATIO:
        kind = DAY_TYPE_VI.get(row.get("day_type"), "ngày")
        return "binge_day", (
            f"Hôm nay bé dùng máy {minutes(row['day_min'])}, {times(ratio)} một {kind} bình thường "
            f"(khoảng {minutes(row['day_min'] / ratio)})."
        )
    return "spike", f"Hôm nay có lúc bé dùng máy nhiều bất thường (cao nhất {minutes(row['max_hour_min'])} trong 1 giờ)."


# --- M1: dự báo vượt giới hạn; lý do = đặc trưng có đóng góp SHAP dương lớn nhất ----------------------------
REASON_VI = {
    "today_until_cutoff": "hôm nay bé đã dùng nhiều hơn mọi khi",
    "today_until_cutoff_ratio": "hôm nay bé đã dùng nhiều hơn mọi khi",
    "y_lag1": "hôm qua bé dùng nhiều",
    "mean7": "tuần này bé dùng nhiều hơn",
    "mean14": "hai tuần nay bé dùng nhiều hơn",
    "lag1_ratio": "hôm qua bé dùng nhiều hơn mức thường ngày",
    "same_dow_ratio": "những ngày cùng thứ trước đây bé thường dùng nhiều",
    "y_same_dow_last_week": "cùng ngày này tuần trước bé dùng nhiều",
    "is_weekend": "ngày mai là cuối tuần",
    "dow_sin": "ngày mai là ngày trong tuần bé thường dùng nhiều",
    "dow_cos": "ngày mai là ngày trong tuần bé thường dùng nhiều",
    "is_holiday": "ngày mai là ngày lễ",
    "is_school_day": "lịch học của ngày mai",
    "is_summer": "đang nghỉ hè",
    "limit_tomorrow": "giới hạn ngày mai thấp so với thói quen của bé",
    "limit_tomorrow_ratio": "giới hạn ngày mai thấp so với thói quen của bé",
    "ext_req_7d": "tuần này bé xin thêm giờ nhiều lần",
    "ext_approve_rate_7d": "các lần xin thêm giờ gần đây thường được đồng ý",
    "night_min_7d": "tuần này bé hay thức khuya dùng máy",
    "share_game": "gần đây bé chơi game nhiều",
    "share_video": "gần đây bé xem video nhiều",
}


def top_reasons(model: xgb.XGBModel, x: pd.DataFrame, k: int = 1) -> list[list[str]]:
    """Tên k đặc trưng có đóng góp SHAP dương lớn nhất cho từng dòng (XGBoost tính sẵn: pred_contribs)."""
    contribs = model.get_booster().predict(xgb.DMatrix(x), pred_contribs=True)[:, :-1]  # bỏ cột bias
    order = np.argsort(-contribs, axis=1)[:, :k]
    return [[x.columns[j] for j in row if contribs[i, j] > 0] for i, row in enumerate(order)]


def explain_over_limit(target_date: pd.Timestamp, limit: float, prob: float, reason: str | None) -> tuple[str, str]:
    weekday = WEEKDAY_VI[(target_date.weekday() + 1) % 7]
    percent = int(round(prob * 10) * 10)
    text = f"Ngày mai ({weekday}) bé có khả năng dùng quá giới hạn {minutes(limit)} (khoảng {percent}%)."
    if reason in REASON_VI:
        text += f" Lý do chính: {REASON_VI[reason]}."
    return "over_limit", text
