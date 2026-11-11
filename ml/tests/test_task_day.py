import pandas as pd
import pytest

from jobs.baseline import task_day


# Lỗi 07/11: cron "5 14 * * *" (21:05 VN) nhưng GitHub chạy trễ 6–7 giờ (03–04h sáng VN). Nếu lấy
# "hôm nay" theo đồng hồ thì tác vụ tính cho ngày MỚI gần như rỗng: M1 bỏ qua trẻ, M2 chấm lệch ngày.
@pytest.mark.parametrize("utc, expected", [
    ("2026-11-10 14:05", "2026-11-10"),  # 21:05 VN — đúng giờ hẹn
    ("2026-11-10 16:59", "2026-11-10"),  # 23:59 VN
    ("2026-11-10 21:00", "2026-11-10"),  # 04:00 VN hôm sau — GitHub trễ 7 giờ, vẫn là ngày 10
    ("2026-11-10 22:59", "2026-11-10"),  # 05:59 VN hôm sau
    ("2026-11-10 23:00", "2026-11-11"),  # 06:00 VN — mốc sang ngày, khớp vnQuotaDayRange ở backend
])
def test_ngay_tac_vu_lui_ve_ngay_vua_ket_thuc_truoc_6h_sang(utc, expected):
    assert task_day(pd.Timestamp(utc, tz="UTC")) == pd.Timestamp(expected)
