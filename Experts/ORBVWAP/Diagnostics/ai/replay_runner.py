"""Shared offline replay runner for INF-2 gate and INF-3 golden CI."""

from __future__ import annotations

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
GOLDEN_DIR = ROOT / "tests" / "golden"

REPLAY_STEPS = [
    "replay_policy.py",
    "replay_regime.py",
    "replay_sizing.py",
    "replay_exit.py",
]

TASK_TO_GOLDEN: dict[str, str] = {
    "AI-0-003": "ai0_v1.json",
    "AI-2-002": "ai2_v1.json",
    "AI-3-003": "ai3_v1.json",
    "AI-4-003": "ai4_v1.json",
}

DEFAULT_EPS_PF = 0.05
DEFAULT_TOLERANCES = {
    "pf_holdout": DEFAULT_EPS_PF,
    "pf_full": DEFAULT_EPS_PF,
    "n_holdout": 0,
    "n_full": 0,
}


def load_expectations() -> dict:
    if EXPECTATIONS.exists():
        return json.loads(EXPECTATIONS.read_text(encoding="utf-8"))
    return {
        "AI-0-003": {"verdict": "PASS", "pf_holdout": 1.43},
        "AI-2-002": {"verdict": "PASS", "pf_holdout": 1.47},
        "AI-3-003": {"verdict": "PASS", "pf_holdout": 1.43},
        "AI-4-003": {"verdict": "PASS", "pf_holdout": 2.51},
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


def run_all_replays(verbose: bool = False) -> tuple[Path, tempfile.TemporaryDirectory[str]]:
    """Run all replay scripts into a temp journal. Caller must keep tmpdir alive."""
    tmpdir = tempfile.TemporaryDirectory(prefix="orbvwap_replay_")
    tmp = Path(tmpdir.name)
    journal = tmp / "replay_journal.csv"

    for script in REPLAY_STEPS:
        result = run_step(script, journal, tmp)
        if verbose and result.stdout:
            print(result.stdout)
        if result.returncode != 0:
            msg = f"{script} exit {result.returncode}"
            if result.stderr:
                msg += f"\n{result.stderr}"
            if result.stdout:
                msg += f"\n{result.stdout}"
            raise RuntimeError(msg)

    return journal, tmpdir


def journal_row_to_metrics(row: pd.Series) -> dict:
    metrics: dict = {
        "task_id": str(row["task_id"]),
        "verdict": str(row["verdict"]),
    }
    for key in ("n_full", "n_holdout"):
        if key in row.index and pd.notna(row[key]):
            metrics[key] = int(row[key])
    for key in ("pf_full", "pf_holdout"):
        if key in row.index and pd.notna(row[key]):
            metrics[key] = float(row[key])
    for key in ("holdout_cut", "notes"):
        if key in row.index and pd.notna(row[key]):
            metrics[key] = str(row[key])
    return metrics


def extract_journal_metrics(journal: Path) -> dict[str, dict]:
    if not journal.exists():
        raise FileNotFoundError(f"journal not created: {journal}")

    df = pd.read_csv(journal)
    metrics: dict[str, dict] = {}
    for task_id in load_expectations():
        rows = df[df["task_id"] == task_id]
        if rows.empty:
            continue
        metrics[task_id] = journal_row_to_metrics(rows.iloc[-1])
    return metrics


def metrics_to_golden(task_id: str, metrics: dict, script: str) -> dict:
    golden = {
        "schema_version": 1,
        "task_id": task_id,
        "replay_script": script,
        "verdict": metrics["verdict"],
        "tolerances": dict(DEFAULT_TOLERANCES),
    }
    for key in ("n_full", "pf_full", "n_holdout", "pf_holdout", "holdout_cut", "notes"):
        if key in metrics:
            golden[key] = metrics[key]
    return golden


def script_for_task(task_id: str) -> str:
    mapping = {
        "AI-0-003": "replay_policy.py",
        "AI-2-002": "replay_sizing.py",
        "AI-3-003": "replay_regime.py",
        "AI-4-003": "replay_exit.py",
    }
    return mapping[task_id]


def validate_against_expectations(metrics: dict[str, dict], eps_pf: float) -> tuple[list[str], dict]:
    errors: list[str] = []
    summary: dict = {}
    expected = load_expectations()

    for task_id, spec in expected.items():
        if task_id not in metrics:
            errors.append(f"missing journal row: {task_id}")
            continue

        row = metrics[task_id]
        verdict = row["verdict"]
        pf = float(row["pf_holdout"])
        summary[task_id] = {"verdict": verdict, "pf_holdout": pf}

        if verdict != spec["verdict"]:
            errors.append(f"{task_id}: verdict {verdict} != {spec['verdict']}")
        exp_pf = float(spec["pf_holdout"])
        if abs(pf - exp_pf) > eps_pf:
            errors.append(f"{task_id}: pf_holdout {pf:.2f} vs expected {exp_pf:.2f} (eps={eps_pf})")

    return errors, summary
