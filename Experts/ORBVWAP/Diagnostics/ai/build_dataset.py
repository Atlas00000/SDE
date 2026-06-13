#!/usr/bin/env python3
"""AI-0-002: Merge decisions + outcomes → labelled dataset."""

import argparse
import sys
from pathlib import Path

import pandas as pd

DEFAULT_OUT = Path(__file__).resolve().parent.parent / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"


def load_csv(path: Path) -> pd.DataFrame:
    return pd.read_csv(path, encoding="utf-8-sig")


def build(decisions: pd.DataFrame, outcomes: pd.DataFrame) -> pd.DataFrame:
    decisions = decisions.copy()
    outcomes = outcomes.copy()

    decisions["bar_time_gmt"] = pd.to_datetime(decisions["bar_time_gmt"])
    if len(outcomes):
        outcomes["close_time_gmt"] = pd.to_datetime(outcomes["close_time_gmt"])

    for col in ("position_id",):
        decisions[col] = pd.to_numeric(decisions[col], errors="coerce").astype("Int64")
        if len(outcomes):
            outcomes[col] = pd.to_numeric(outcomes[col], errors="coerce").astype("Int64")

    if len(outcomes):
        outcomes = outcomes.drop_duplicates(subset=["position_id"], keep="last")
        df = decisions.merge(outcomes, on="position_id", how="left")
    else:
        df = decisions.copy()
        df["profit"] = pd.NA
        df["label_win"] = pd.NA

    df["prod_taken"] = (df["prod_executed"] == 1).astype(int)
    df = df.sort_values("bar_time_gmt").reset_index(drop=True)

    dupes = df["decision_id"].duplicated().sum()
    if dupes:
        print(f"WARN: {dupes} duplicate decision_id rows", file=sys.stderr)

    return df


def summarize(df: pd.DataFrame) -> None:
    n = len(df)
    executed = int((df["prod_executed"] == 1).sum())
    labelled = int(df["label_win"].notna().sum())
    wins = int((df["label_win"] == 1).sum())
    print(f"=== AI-0 dataset summary ===")
    print(f"Rows: {n} | executed: {executed} | labelled: {labelled} | wins: {wins}")
    if labelled:
        print(f"WR: {100.0 * wins / labelled:.2f}%")
    setup_fail = int(((df["can_trade_ok"] == 1) & (df["setup_ok"] == 0)).sum())
    print(f"Setup failures (signal ok): {setup_fail}")


def main():
    parser = argparse.ArgumentParser(description="Build ORBVWAP AI dataset from tester exports")
    parser.add_argument("decisions", type=Path, help="ORBVWAP_decisions.csv")
    parser.add_argument("outcomes", type=Path, nargs="?", default=None, help="ORBVWAP_outcomes.csv")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    decisions = load_csv(args.decisions)
    outcomes = load_csv(args.outcomes) if args.outcomes and args.outcomes.exists() else pd.DataFrame()

    df = build(decisions, outcomes)
    summarize(df)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(args.output, index=False)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
