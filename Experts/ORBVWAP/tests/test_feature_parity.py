"""INF-4-003: pytest gate for AI-1 feature parity."""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]
AI_DIR = ROOT / "Diagnostics" / "ai"
sys.path.insert(0, str(AI_DIR))

from features import FEATURE_ORDER, PARITY_EPS, check_parity  # noqa: E402
from policy import DEFAULT_DATASET, executed_mask  # noqa: E402


@pytest.fixture(scope="module")
def executed_sample() -> pd.DataFrame:
    if not DEFAULT_DATASET.exists():
        pytest.skip(f"dataset missing: {DEFAULT_DATASET}")
    raw = pd.read_parquet(DEFAULT_DATASET)
    pool = raw.loc[executed_mask(raw)]
    if pool.empty:
        pytest.skip("no executed labelled rows")
    return pool.sample(n=min(200, len(pool)), random_state=42)


def test_feature_order_matches_policy():
    from features import FEATURE_ORDER as FO
    from policy import FEATURE_ORDER as PO

    assert FO == PO


def test_parity_on_executed_sample(executed_sample: pd.DataFrame):
    errors, _ = check_parity(executed_sample, eps=PARITY_EPS)
    assert not errors, "feature parity drift:\n" + "\n".join(f"  - {e}" for e in errors)


def test_all_rows_parity_smoke():
    if not DEFAULT_DATASET.exists():
        pytest.skip(f"dataset missing: {DEFAULT_DATASET}")
    raw = pd.read_parquet(DEFAULT_DATASET)
    pool = raw.loc[executed_mask(raw)]
    errors, summary = check_parity(pool, eps=PARITY_EPS)
    assert not errors
    for name in FEATURE_ORDER:
        assert summary.get(f"max_delta_train_{name}", 0.0) <= PARITY_EPS
