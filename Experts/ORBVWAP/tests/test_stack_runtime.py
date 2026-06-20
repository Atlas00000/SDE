"""INF-8: full AI stack runtime tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "Scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from ai_stack_runtime import load_stack, score_ai2_mult, score_batch, score_regime  # noqa: E402


def test_stack_loads_all_models():
    stack = load_stack()
    assert stack["ai1"]["model_id"] == "ai1_v1"
    assert stack["ai2"]["model_id"] == "ai2_v1"
    assert stack["ai3"]["model_id"] == "ai3_v1"
    assert stack["ai4"]["model_id"] == "ai4_v1"


def test_ai2_tiers_match_mqh():
    stack = load_stack()
    ai2 = stack["ai2"]
    assert score_ai2_mult(ai2, 0.40) == pytest.approx(1.0)
    assert score_ai2_mult(ai2, 0.60) == pytest.approx(1.15)
    assert score_ai2_mult(ai2, 0.70) == pytest.approx(1.25)


def test_regime_allow_on_training_means():
    stack = load_stack()
    means = stack["ai1"]["scaler_mean"]
    body = {
        "range_width_atr": means[0],
        "vol_ratio": means[1],
        "spread_pct_range": means[3],
        "vwap_dist_atr": means[2],
        "weekday": 2.0,
        "session_ny": 1.0,
        "prior_session_loss": 0.0,
    }
    chop, allow, fb = score_regime(stack["ai3"], body)
    assert not fb
    assert 0.0 <= chop <= 1.0
    assert isinstance(allow, bool)


def test_batch_entry_returns_ai1_ai2_ai4():
    stack = load_stack()
    means = stack["ai1"]["scaler_mean"]
    body = {
        "entry": {
            "range_width_atr": means[0],
            "vol_ratio": means[1],
            "vwap_dist_atr": means[2],
            "spread_pct_range": means[3],
            "min_rr": means[4],
            "hour_gmt": means[5],
            "weekday": means[6],
            "ny_min_since_open": means[7],
            "session_ny": means[8],
            "direction_sell": means[9],
        }
    }
    out = score_batch(stack, body)
    assert "ai1_score" in out
    assert "ai2_mult" in out
    assert out["ai4_stall_minutes"] == 45
    assert out["ai4_stall_mfe_frac"] == pytest.approx(0.25)
    assert 0.0 <= out["ai1_score"] <= 1.0
