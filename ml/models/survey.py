"""T8.5 — phiếu khảo sát câu giải thích cảnh báo cho phụ huynh (T8.5.1) và chấm kết quả (T8.5.3).

Lấy các ngày bất thường đã cài trong bộ mô phỏng, dựng câu cảnh báo bằng đúng hàm app dùng (explain_day), chọn 20
câu: 14 câu ĐÚNG (câu app dựng từ chính ngày đó) và 6 câu SAI (tình huống ghép với câu cảnh báo của ngày khác, loại
khác) để xem phụ huynh có đối chiếu câu cảnh báo với tình huống không. Mỗi câu kèm TÌNH HUỐNG bằng số liệu khách quan (tổng phút so
với thường ngày, phút khuya, phút ứng dụng mới, số video không phù hợp) — không chép lại câu cảnh báo. Đáp án để file
riêng, KHÔNG gửi phụ huynh.

    .venv/bin/python -m models.survey --sim data/sim --out reports
        → reports/t85_survey.md (gửi phụ huynh), t85_answer_key.csv (giữ lại), t85_responses_template.csv
    .venv/bin/python -m models.survey --score phan_hoi.csv --key reports/t85_answer_key.csv
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from .explain import explain_day, minutes

N_ITEMS, N_WRONG, SEED = 20, 6, 16
CHOICES = ("Đúng", "Sai", "Không chắc")


def _situation(row) -> str:
    ratio = row.get("day_ratio")
    usual = row["day_min"] / ratio if ratio and np.isfinite(ratio) and ratio > 0 else None
    parts = [f"Tổng thời gian dùng máy hôm nay: {minutes(row['day_min'])}"
             + (f" (thường ngày khoảng {minutes(usual)})" if usual else ""),
             f"Dùng trong giờ ngủ 22h–6h: {minutes(row.get('night_min', 0) or 0)}",
             f"Dùng ứng dụng bé chưa từng dùng: {minutes(row.get('new_app_min', 0) or 0)}",
             f"Video có thể không phù hợp lứa tuổi: {int(row.get('yt_danger_high', 0) or 0)}",
             f"Giờ dùng nhiều nhất: {minutes(row.get('max_hour_min', 0) or 0)} trong 1 giờ"]
    return "\n".join(f"- {p}" for p in parts)


def build_items(days: pd.DataFrame, n: int = N_ITEMS, n_wrong: int = N_WRONG, seed: int = SEED) -> pd.DataFrame:
    """n câu: n − n_wrong câu ĐÚNG (câu app dựng từ chính ngày đó, nói đúng loại đã cài, rải đều các loại) và n_wrong
    câu SAI = tình huống của một ngày ghép với câu cảnh báo của NGÀY KHÁC thuộc loại khác — câu mâu thuẫn với số liệu
    phụ huynh thấy (kiểm tra phụ huynh có đối chiếu không). Không dùng câu "sai so với nhãn mô phỏng" làm câu sai: vd
    ngày "tăng đột biến" được cài bằng một ứng dụng mới, nên câu "dùng ứng dụng mới" vẫn đúng với số liệu."""
    rows = days[days["label"].astype(bool)].copy()
    said = rows.apply(explain_day, axis=1)
    rows["loại tình huống"] = said.map(lambda ks: ks[0])
    rows["câu cảnh báo"] = said.map(lambda ks: ks[1])
    rows = rows.drop_duplicates("câu cảnh báo")
    right = rows[rows["loại tình huống"] == rows["kind"]]
    n_right = n - n_wrong
    if len(right) < n_right or len(rows) < n:
        raise ValueError(f"không đủ câu: {len(right)} câu đúng loại / {len(rows)} ngày")
    per_kind = -(-n_right // right["kind"].nunique())  # chia đều các loại, làm tròn lên
    right = (right.sample(frac=1, random_state=seed).groupby("kind").head(per_kind)
             .sample(n_right, random_state=seed))
    rng = np.random.default_rng(seed)
    pool = rows.drop(right.index)
    wrong = pool.sample(n_wrong, random_state=seed).copy()
    swapped, used = [], set(right["câu cảnh báo"])
    for kind in wrong["loại tình huống"]:
        donors = rows[(rows["loại tình huống"] != kind) & ~rows["câu cảnh báo"].isin(used)]
        donor = donors.iloc[int(rng.integers(len(donors)))][["câu cảnh báo", "loại tình huống"]]
        used.add(donor["câu cảnh báo"])  # mỗi câu chỉ xuất hiện một lần trong phiếu
        swapped.append(donor)
    wrong["câu cảnh báo"] = [d["câu cảnh báo"] for d in swapped]
    wrong["loại câu nói"] = [d["loại tình huống"] for d in swapped]
    right = right.assign(**{"loại câu nói": right["loại tình huống"]})
    picked = pd.concat([right.assign(đúng=True), wrong.assign(đúng=False)])
    picked = picked.sample(frac=1, random_state=seed).reset_index(drop=True)
    return pd.DataFrame({
        "câu": range(1, len(picked) + 1),
        "tình huống": picked.apply(_situation, axis=1),
        "câu cảnh báo": picked["câu cảnh báo"],
        "đúng": picked["đúng"],
        "loại tình huống": picked["loại tình huống"],
        "loại câu nói": picked["loại câu nói"],
        "loại đã cài (mô phỏng)": picked["kind"],
    })


def survey_markdown(items: pd.DataFrame) -> str:
    lines = [
        "# Phiếu khảo sát — câu cảnh báo của ứng dụng KidFun",
        "",
        "Mỗi câu dưới đây mô tả một ngày dùng điện thoại của một bé (số liệu có thật trong mô phỏng) và câu cảnh báo",
        "ứng dụng gửi cho phụ huynh ngày hôm đó. Anh/chị cho biết câu cảnh báo có dễ hiểu không, và có nói đúng điều",
        "bất thường nhất trong ngày không. Không có câu trả lời đúng/sai về phía anh/chị. Khoảng 10 phút.",
        "",
    ]
    for num, situation, sentence in zip(items["câu"], items["tình huống"], items["câu cảnh báo"]):
        lines += [
            f"## Câu {num}",
            "",
            "Tình huống:",
            "",
            situation,
            "",
            f"Ứng dụng gửi: **«{sentence}»**",
            "",
            "- Mức dễ hiểu (1 = rất khó hiểu … 5 = rất dễ hiểu): ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5",
            "- Câu cảnh báo có nói đúng điều bất thường nhất trong ngày không? " + " ".join(f"☐ {c}" for c in CHOICES),
            "",
        ]
    return "\n".join(lines)


def score(responses: pd.DataFrame, key: pd.DataFrame) -> dict:
    """responses: người, câu, dễ hiểu (1–5), nhận xét (Đúng/Sai/Không chắc). key: câu, đúng."""
    r = responses.merge(key[["câu", "đúng"]], on="câu", validate="many_to_one")
    right, wrong = r[r["đúng"].astype(bool)], r[~r["đúng"].astype(bool)]
    return {
        "số người": int(r["người"].nunique()),
        "điểm dễ hiểu TB": float(r["dễ hiểu"].mean()),
        "điểm dễ hiểu TB (câu đúng)": float(right["dễ hiểu"].mean()) if len(right) else float("nan"),
        "% câu đúng được phụ huynh công nhận": float((right["nhận xét"] == "Đúng").mean() * 100) if len(right) else float("nan"),
        "% câu sai bị phụ huynh phát hiện": float((wrong["nhận xét"] == "Sai").mean() * 100) if len(wrong) else float("nan"),
        "% trả lời Không chắc": float((r["nhận xét"] == "Không chắc").mean() * 100),
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sim", type=Path)
    p.add_argument("--out", type=Path, default=Path("reports"))
    p.add_argument("--score", type=Path, help="CSV câu trả lời: người, câu, dễ hiểu, nhận xét")
    p.add_argument("--key", type=Path, default=Path("reports/t85_answer_key.csv"))
    args = p.parse_args()
    if args.score:
        for k, v in score(pd.read_csv(args.score), pd.read_csv(args.key)).items():
            print(f"{k}: {round(v, 2) if isinstance(v, float) else v}")
        return
    from .m2.data import sim_m2_frames

    _, days, _ = sim_m2_frames(args.sim)
    items = build_items(days)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "t85_survey.md").write_text(survey_markdown(items), encoding="utf-8")
    items.drop(columns="tình huống").to_csv(args.out / "t85_answer_key.csv", index=False)
    pd.DataFrame(columns=["người", "câu", "dễ hiểu", "nhận xét"]).to_csv(
        args.out / "t85_responses_template.csv", index=False)
    print(f"{len(items)} câu ({(~items['đúng']).sum()} câu sai loại) → {args.out}/t85_survey.md")


if __name__ == "__main__":
    main()
