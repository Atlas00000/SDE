#!/usr/bin/env python3
"""INF-4-001: Export dual-column feature parity sample (EA vs Python)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from features import FEATURE_ORDER, parity_deltas
from policy import executed_mask

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
DEFAULT_OUT = ROOT / "Diagnostics" / "datasets" / "feature_parity_sample.parquet"


def main() -> int:
    parser = argparse.ArgumentParser(description="Export feature parity sample (INF-4-001)")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("-n", "--rows", type=int, default=200, help="Sample size (executed rows)")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    if not args.dataset.exists():
        print(f"Missing dataset: {args.dataset}", file=sys.stderr)
        return 1

    raw = pd.read_parquet(args.dataset)
    pool = raw.loc[executed_mask(raw)].copy()
    if pool.empty:
        print("No executed labelled rows in dataset", file=sys.stderr)
        return 1

    sample = pool.sample(n=min(args.rows, len(pool)), random_state=args.seed)
    sample = sample.sort_values("bar_time_gmt").reset_index(drop=True)

    dual, max_abs = parity_deltas(sample)
    dual["bar_time_gmt"] = sample["bar_time_gmt"].values

    args.output.parent.mkdir(parents=True, exist_ok=True)
    dual.to_parquet(args.output, index=False)

    print(f"=== INF-4 feature sample ({len(sample)} rows) ===")
    print(f"Wrote {args.output}")
    print(f"Features: {', '.join(FEATURE_ORDER)}")
    for name in FEATURE_ORDER:
        print(
            f"  {name}: max|ea-py_train|={max_abs.get(f'max_delta_train_{name}', 0):.2e} "
            f"max|ea-py_recomp|={max_abs.get(f'max_delta_recomp_{name}', 0):.2e}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
