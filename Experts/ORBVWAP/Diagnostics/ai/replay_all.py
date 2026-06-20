#!/usr/bin/env python3
"""INF-2 gate: run all offline AI replay scripts; validate PASS vs expectations."""

from __future__ import annotations

import argparse
import sys

from replay_runner import DATASET, DEFAULT_EPS_PF, run_all_replays, validate_against_expectations


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all ORBVWAP AI replay gates (INF-2)")
    parser.add_argument("--eps-pf", type=float, default=DEFAULT_EPS_PF, help="PF holdout tolerance")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if not DATASET.exists():
        print(f"Missing dataset: {DATASET}", file=sys.stderr)
        return 1

    try:
        journal, tmpdir = run_all_replays(verbose=args.verbose)
        with tmpdir:
            from replay_runner import REPLAY_STEPS, extract_journal_metrics

            for script in REPLAY_STEPS:
                print(f"[OK] {script}")
            metrics = extract_journal_metrics(journal)
    except RuntimeError as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    errors, summary = validate_against_expectations(metrics, args.eps_pf)
    print("\n=== INF-2 replay-all summary ===")
    for task_id, m in summary.items():
        print(f"  {task_id}: {m['verdict']} pf_holdout={m['pf_holdout']:.2f}")

    if errors:
        print("[FAIL]")
        for err in errors:
            print(f"  - {err}")
        return 1

    print("[PASS] all replay gates within tolerance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
