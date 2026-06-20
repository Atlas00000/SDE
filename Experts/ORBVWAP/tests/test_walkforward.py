"""INF-5: walk-forward gate smoke tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
AI_DIR = ROOT / "Diagnostics" / "ai"
sys.path.insert(0, str(AI_DIR))

from walkforward import (  # noqa: E402
    DEFAULT_DATASET,
    DEFAULT_FOLDS,
    DEFAULT_PF_FLOOR,
    run_walkforward,
)


@pytest.fixture(scope="module")
def wf_results():
    if not DEFAULT_DATASET.exists():
        pytest.skip(f"dataset missing: {DEFAULT_DATASET}")
    results, table = run_walkforward(DEFAULT_DATASET, n_folds=DEFAULT_FOLDS, pf_floor=DEFAULT_PF_FLOOR)
    return results, table


def test_walkforward_three_folds(wf_results):
    results, table = wf_results
    assert len(results) == DEFAULT_FOLDS
    assert len(table) == DEFAULT_FOLDS


def test_walkforward_gate_passes(wf_results):
    results, _ = wf_results
    assert all(r.verdict == "PASS" for r in results)
