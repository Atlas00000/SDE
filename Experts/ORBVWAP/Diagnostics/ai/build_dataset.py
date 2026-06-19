#!/usr/bin/env python3
"""AI-0-002 / INF-0-003: Merge decisions + outcomes → labelled dataset."""

import argparse
import sys
from pathlib import Path

import pandas as pd

from schema import format_results, validate_dataset, validate_export_pair

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
    return df


def summarize(df: pd.DataFrame) -> None:
    n = len(df)
    executed = int((df["prod_executed"] == 1).sum())
    labelled = int(df["label_win"].notna().sum())
    wins = int((df["label_win"] == 1).sum())
    print("=== AI-0 dataset summary ===")
    print(f"Rows: {n} | executed: {executed} | labelled: {labelled} | wins: {wins}")
    if labelled:
        print(f"WR: {100.0 * wins / labelled:.2f}%")
    setup_fail = int(((df["can_trade_ok"] == 1) & (df["setup_ok"] == 0)).sum())
    print(f"Setup failures (signal ok): {setup_fail}")


def validate_inputs(decisions: pd.DataFrame, outcomes: pd.DataFrame, *, version: int) -> int:
    results = validate_export_pair(decisions, outcomes if len(outcomes) else None, version=version)
    print(format_results(results))
    return 0 if all(r.ok for r in results) else 1


def main():
    parser = argparse.ArgumentParser(description="Build ORBVWAP AI dataset from tester exports")
    parser.add_argument("decisions", type=Path, nargs="?", help="ORBVWAP_decisions.csv")
    parser.add_argument("outcomes", type=Path, nargs="?", default=None, help="ORBVWAP_outcomes.csv")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate export schema before build (INF-0-003; exit 1 on failure)",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate exports and exit without writing parquet",
    )
    parser.add_argument(
        "--validate-parquet",
        type=Path,
        metavar="PATH",
        help="Validate built parquet against dataset.v1 contract",
    )
    parser.add_argument("--schema-version", type=int, default=1, help="Contract version (default 1)")
    args = parser.parse_args()

    if args.validate_parquet:
        df = pd.read_parquet(args.validate_parquet)
        result = validate_dataset(df, version=args.schema_version)
        print(format_results([result]))
        raise SystemExit(0 if result.ok else 1)

    if not args.decisions:
        parser.error("decisions CSV path required unless --validate-parquet is set")

    decisions = load_csv(args.decisions)
    outcomes = load_csv(args.outcomes) if args.outcomes and args.outcomes.exists() else pd.DataFrame()

    if args.validate or args.validate_only:
        code = validate_inputs(decisions, outcomes, version=args.schema_version)
        if code != 0 or args.validate_only:
            raise SystemExit(code)

    df = build(decisions, outcomes)

    post = validate_dataset(df, version=args.schema_version)
    if not post.ok:
        print(format_results([post]), file=sys.stderr)
        raise SystemExit(1)

    summarize(df)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(args.output, index=False)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
