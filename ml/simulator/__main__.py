"""Sinh dữ liệu mô phỏng ra thư mục CSV (mỗi bảng một file).

Chạy từ thư mục ml/:
    .venv/bin/python -m simulator --children 100 --start 2025-09-01 --days 365 --out data/sim
"""

import argparse
from pathlib import Path

from .generate import simulate


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--children", type=int, default=100)
    p.add_argument("--start", default="2025-09-01")
    p.add_argument("--days", type=int, default=365)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", type=Path, default=Path("data/sim"))
    args = p.parse_args()

    tables = simulate(args.children, args.start, args.days, seed=args.seed)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, df in tables.items():
        df.to_csv(args.out / f"{name}.csv", index=False)
        print(f"{name}: {len(df):,} dòng")


if __name__ == "__main__":
    main()
