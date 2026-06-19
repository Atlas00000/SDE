#!/usr/bin/env python3
"""INF-2 gate: run all offline AI replay scripts; validate PASS vs expectations."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = Path(__file__).resolve().parent
DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
EXPECTATIONS = AI_DIR / "replay_expectations.json"

# Holdout PF tolerances vs committed journal (AI-test-journal.csv)
DEFAULT_EPS_PF = 0.05


def load_expectations() -> dict:
    if EXPECTATIONS.exists():
        return json.loads(EXPECTATIONS.read_text(encoding="utf-8"))
    return {
        "AI-0-003": {"verdict": "PASS", "pf_holdout": 1.43},
        "AI-2-002": {"verdict": "PASS", "pf_holdout": 1.47},
        "AI-3-003": {"verdict": "PASS", "pf_holdout": 1.43},
        "AI-4-003": {"verdict": "PASS", "pf_holdout": 1.55},
    }


def run_step(
    script: str,
    journal: Path,
    tmp: Path,
    extra: list[str] | None = None,
) -> subprocess.CompletedProcess:
    cmd = [
        sys.executable,
        str(AI_DIR / script),
        "--journal",
        str(journal),
    ]
    if script == "replay_policy.py":
        cmd.insert(2, str(DATASET))
    if script == "replay_sizing.py":
        cmd.extend(
            [
                "--ai2-out",
                str(tmp / "ai2_v1.json"),
                "--mqh-out",
                str(tmp / "AiSizer.mqh"),
            ]
        )
    if extra:
        cmd.extend(extra)
    return subprocess.run(cmd, cwd=str(AI_DIR), capture_output=True, text=True)


def validate_journal(journal: Path, eps_pf: float) -> tuple[list[str], dict]:
    errors: list[str] = []
    metrics: dict = {}
    expected = load_expectations()

    if not journal.exists():
        return ["journal not created"], metrics

    df = pd.read_csv(journal)
    for task_id, spec in expected.items():
        rows = df[df["task_id"] == task_id]
        if rows.empty:
            errors.append(f"missing journal row: {task_id}")
            continue
        row = rows.iloc[-1]
        verdict = str(row["verdict"])
        pf = float(row["pf_holdout"])
        metrics[task_id] = {"verdict": verdict, "pf_holdout": pf}

        if verdict != spec["verdict"]:
            errors.append(f"{task_id}: verdict {verdict} != {spec['verdict']}")
        exp_pf = float(spec["pf_holdout"])
        if abs(pf - exp_pf) > eps_pf:
            errors.append(f"{task_id}: pf_holdout {pf:.2f} vs expected {exp_pf:.2f} (eps={eps_pf})")

    return errors, metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all ORBVWAP AI replay gates (INF-2)")
    parser.add_argument("--eps-pf", type=float, default=DEFAULT_EPS_PF, help="PF holdout tolerance")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if not DATASET.exists():
        print(f"Missing dataset: {DATASET}", file=sys.stderr)
        return 1

    steps = [
        "replay_policy.py",
        "replay_regime.py",
        "replay_sizing.py",
        "replay_exit.py",
    ]

    with tempfile.TemporaryDirectory(prefix="orbvwap_replay_") as tmpdir:
        tmp = Path(tmpdir)
        journal = tmp / "replay_journal.csv"
        for script in steps:
            result = run_step(script, journal, tmp)
            if args.verbose and result.stdout:
                print(result.stdout)
            if result.returncode != 0:
                print(f"[FAIL] {script} exit {result.returncode}", file=sys.stderr)
                if result.stderr:
                    print(result.stderr, file=sys.stderr)
                if result.stdout:
                    print(result.stdout, file=sys.stderr)
                return 1
            print(f"[OK] {script}")

        errors, metrics = validate_journal(journal, args.eps_pf)
        print("\n=== INF-2 replay-all summary ===")
        for task_id, m in metrics.items():
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
