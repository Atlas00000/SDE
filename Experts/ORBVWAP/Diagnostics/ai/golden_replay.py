#!/usr/bin/env python3
"""INF-3: Compare live replay metrics to committed golden snapshots."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from replay_runner import (
    DATASET,
    DEFAULT_TOLERANCES,
    GOLDEN_DIR,
    TASK_TO_GOLDEN,
    extract_journal_metrics,
    metrics_to_golden,
    run_all_replays,
    script_for_task,
)


def load_golden(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def compare_metrics(golden: dict, actual: dict) -> list[str]:
    errors: list[str] = []
    tolerances = golden.get("tolerances", DEFAULT_TOLERANCES)

    if actual.get("verdict") != golden.get("verdict"):
        errors.append(
            f"verdict {actual.get('verdict')} != {golden.get('verdict')}"
        )

    for key in ("n_full", "n_holdout"):
        if key not in golden:
            continue
        tol = int(tolerances.get(key, 0))
        exp = int(golden[key])
        got = int(actual.get(key, -1))
        if abs(got - exp) > tol:
            errors.append(f"{key} {got} != {exp} (tol={tol})")

    for key in ("pf_full", "pf_holdout"):
        if key not in golden:
            continue
        tol = float(tolerances.get(key, DEFAULT_TOLERANCES["pf_holdout"]))
        exp = float(golden[key])
        got = float(actual.get(key, -1.0))
        if abs(got - exp) > tol:
            errors.append(f"{key} {got:.2f} != {exp:.2f} (tol={tol})")

    return errors


def compare_all(golden_dir: Path, metrics: dict[str, dict]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    checked: list[str] = []

    for task_id, filename in TASK_TO_GOLDEN.items():
        path = golden_dir / filename
        if not path.exists():
            errors.append(f"missing golden file: {path}")
            continue
        if task_id not in metrics:
            errors.append(f"missing replay metrics: {task_id}")
            continue

        golden = load_golden(path)
        task_errors = compare_metrics(golden, metrics[task_id])
        checked.append(task_id)
        for err in task_errors:
            errors.append(f"{task_id}: {err}")

    return errors, checked


def write_golden_files(golden_dir: Path, metrics: dict[str, dict]) -> list[Path]:
    golden_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for task_id, filename in TASK_TO_GOLDEN.items():
        if task_id not in metrics:
            raise KeyError(f"cannot update golden — missing metrics for {task_id}")
        path = golden_dir / filename
        golden = metrics_to_golden(task_id, metrics[task_id], script_for_task(task_id))
        path.write_text(json.dumps(golden, indent=2) + "\n", encoding="utf-8")
        written.append(path)

    return written


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP golden replay gate (INF-3)")
    parser.add_argument(
        "--golden-dir",
        type=Path,
        default=GOLDEN_DIR,
        help="Directory containing golden JSON snapshots",
    )
    parser.add_argument(
        "--update-golden",
        action="store_true",
        help="Rewrite golden files from current replay (explicit bump only)",
    )
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if not DATASET.exists():
        print(f"Missing dataset: {DATASET}", file=sys.stderr)
        return 1

    journal, tmpdir = run_all_replays(verbose=args.verbose)
    with tmpdir:
        metrics = extract_journal_metrics(journal)

    if args.update_golden:
        written = write_golden_files(args.golden_dir, metrics)
        print("[UPDATED] golden snapshots:")
        for path in written:
            task_id = json.loads(path.read_text(encoding="utf-8"))["task_id"]
            m = metrics[task_id]
            print(
                f"  {path.name}: {m['verdict']} "
                f"pf_holdout={m['pf_holdout']:.2f} n_holdout={m['n_holdout']}"
            )
        print("Commit golden files + INF-test-journal note when metrics change intentionally.")
        return 0

    errors, checked = compare_all(args.golden_dir, metrics)
    print("\n=== INF-3 golden replay summary ===")
    for task_id in checked:
        m = metrics[task_id]
        print(
            f"  {task_id}: {m['verdict']} "
            f"pf_holdout={m['pf_holdout']:.2f} n_holdout={m['n_holdout']}"
        )

    if errors:
        print("[FAIL]")
        for err in errors:
            print(f"  - {err}")
        print("To bump snapshots after intentional change: python Diagnostics/ai/golden_replay.py --update-golden")
        return 1

    print(f"[PASS] {len(checked)} golden snapshots match within tolerance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
