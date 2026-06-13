#!/usr/bin/env python3
"""AI-0-003: Offline policy replay — baseline PROD vs filtered subsets."""

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

from train_eval import print_metrics, time_split, trade_metrics

DEFAULT_DATASET = Path(__file__).resolve().parent.parent / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
DEFAULT_JOURNAL = Path(__file__).resolve().parent.parent / "AI-test-journal.csv"


def prod_baseline_mask(df: pd.DataFrame) -> pd.Series:
    return (df["prod_executed"] == 1) & df["label_win"].notna()


def replay_all_executed(df: pd.DataFrame) -> dict:
    return trade_metrics(df, prod_baseline_mask(df))


def replay_setup_ok(df: pd.DataFrame) -> dict:
  mask = (df["setup_ok"] == 1) & (df["prod_executed"] == 1) & df["label_win"].notna()
  return trade_metrics(df, mask)


def main():
    parser = argparse.ArgumentParser(description="Replay PROD policy on labelled dataset")
    parser.add_argument("dataset", type=Path, nargs="?", default=DEFAULT_DATASET)
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--journal", type=Path, default=DEFAULT_JOURNAL)
    parser.add_argument("--task-id", default="AI-0-003")
    args = parser.parse_args()

    if not args.dataset.exists():
        print(f"Missing dataset: {args.dataset}", file=sys.stderr)
        print("Run build_dataset.py first.", file=sys.stderr)
        sys.exit(1)

    df = pd.read_parquet(args.dataset)
    split = time_split(df, train_frac=1.0 - args.holdout_frac)
    holdout = split.holdout

    full = replay_all_executed(df)
    ho = replay_all_executed(holdout)

    print(f"=== {args.task_id} policy replay ===")
    print(f"Cut time (holdout start): {split.cut_time}")
    print_metrics("FULL (prod_executed)", full)
    print_metrics("HOLDOUT (prod_executed)", ho)

    verdict = "PENDING"
    gate_pf_delta = abs(ho["pf"] - full["pf"]) if ho["n"] > 0 and full["n"] > 0 else 0.0
    print(f"\nAI-0 gate check: holdout PF delta vs full = {gate_pf_delta:.3f} (expect ~0 if export complete)")
    if ho["n"] > 0 and full["n"] > 0:
        verdict = "PASS" if gate_pf_delta < 0.15 else "REVIEW"
        print(f"Verdict: {verdict}")

    row = {
        "task_id": args.task_id,
        "preset": "ORBVWAP_AI0_Export_PROD_EURUSD-M1_full",
        "dataset": str(args.dataset.name),
        "holdout_cut": str(split.cut_time),
        "n_full": full["n"],
        "pf_full": round(full["pf"], 2),
        "n_holdout": ho["n"],
        "pf_holdout": round(ho["pf"], 2),
        "verdict": verdict,
        "notes": "AI-0 baseline replay",
    }

    journal_exists = args.journal.exists()
    pd.DataFrame([row]).to_csv(
        args.journal,
        mode="a",
        header=not journal_exists,
        index=False,
    )
    print(f"Appended journal row -> {args.journal}")
    print(json.dumps(row, indent=2))


if __name__ == "__main__":
    main()
