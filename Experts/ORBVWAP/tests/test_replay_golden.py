"""INF-3-003: pytest gate — live replay metrics must match golden snapshots."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
AI_DIR = ROOT / "Diagnostics" / "ai"
sys.path.insert(0, str(AI_DIR))

from golden_replay import compare_all, load_golden  # noqa: E402
from replay_runner import (  # noqa: E402
    DATASET,
    GOLDEN_DIR,
    TASK_TO_GOLDEN,
    extract_journal_metrics,
    run_all_replays,
)


@pytest.fixture(scope="module")
def replay_metrics() -> dict[str, dict]:
    if not DATASET.exists():
        pytest.skip(f"dataset missing: {DATASET}")
    journal, tmpdir = run_all_replays()
    with tmpdir:
        return extract_journal_metrics(journal)


def test_dataset_present():
    assert DATASET.exists(), f"commit or build dataset: {DATASET}"


@pytest.mark.parametrize("task_id,filename", list(TASK_TO_GOLDEN.items()))
def test_golden_snapshot_exists(task_id: str, filename: str):
    path = GOLDEN_DIR / filename
    assert path.exists(), f"missing golden file for {task_id}: {path}"
    golden = load_golden(path)
    assert golden["task_id"] == task_id


def test_replay_matches_golden(replay_metrics: dict[str, dict]):
    errors, checked = compare_all(GOLDEN_DIR, replay_metrics)
    assert checked, "no golden files were checked"
    assert not errors, "golden drift:\n" + "\n".join(f"  - {e}" for e in errors)
