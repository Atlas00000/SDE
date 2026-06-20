#!/usr/bin/env python3
"""INF-4-003: Feature parity gate — Python training vs export vs recompute."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

from features import FEATURE_ORDER, PARITY_EPS, RECOMPUTABLE, check_parity
from policy import executed_mask

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP AI-1 feature parity gate (INF-4)")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--eps", type=float, default=PARITY_EPS, help="Max abs delta tolerance")
    parser.add_argument(
        "--all-rows",
        action="store_true",
        help="Check all executed rows (default: same 200-row sample as export)",
    )
    parser.add_argument("--rows", type=int, default=200)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    if not args.dataset.exists():
        print(f"Missing dataset: {args.dataset}", file=sys.stderr)
        return 1

    raw = pd.read_parquet(args.dataset)
    pool = raw.loc[executed_mask(raw)].copy()
    if pool.empty:
        print("No executed labelled rows", file=sys.stderr)
        return 1

    if args.all_rows:
        sample = pool.sort_values("bar_time_gmt").reset_index(drop=True)
    else:
        sample = pool.sample(n=min(args.rows, len(pool)), random_state=args.seed)
        sample = sample.sort_values("bar_time_gmt").reset_index(drop=True)

    errors, summary = check_parity(sample, eps=args.eps)

    print(f"=== INF-4 parity check ({len(sample)} executed rows, eps={args.eps}) ===")
    for name in FEATURE_ORDER:
        train_delta = summary.get(f"max_delta_train_{name}", 0.0)
        recomp_delta = summary.get(f"max_delta_recomp_{name}", 0.0)
        flag = ""
        if train_delta > args.eps:
            flag += " TRAIN_FAIL"
        if name in RECOMPUTABLE and recomp_delta > args.eps:
            flag += " RECOMP_FAIL"
        print(
            f"  {name}: train={train_delta:.2e} recomp={recomp_delta:.2e}{flag or ' OK'}"
        )

    if errors:
        print("[FAIL]")
        for err in errors:
            print(f"  - {err}")
        return 1

    print("[PASS] all FEATURE_ORDER columns within tolerance")
    print(f"  train-path: all {len(FEATURE_ORDER)} features vs export")
    print(f"  recompute-path: {', '.join(sorted(RECOMPUTABLE))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
