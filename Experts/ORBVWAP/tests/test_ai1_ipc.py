"""INF-8: AI-1 IPC block roundtrip and runtime scoring tests."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "Scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from ai1_ipc import BLOCK_SIZE, N_FEATURES, pack_block, unpack_block  # noqa: E402
from ai1_runtime import load_model, score_features  # noqa: E402


def test_ipc_block_size():
    assert BLOCK_SIZE == 116
    assert N_FEATURES == 10


def test_ipc_roundtrip():
    feats = [float(i) + 0.123 for i in range(N_FEATURES)]
    raw = pack_block(7, 7, 2, 0.456789, feats)
    assert len(raw) == BLOCK_SIZE
    block = unpack_block(raw)
    assert block["request_seq"] == 7
    assert block["response_seq"] == 7
    assert block["status"] == 2
    assert block["ai1_score"] == pytest.approx(0.456789)
    assert block["features"] == pytest.approx(feats)


def test_runtime_matches_mqh_weights():
    model = load_model(ROOT / "models" / "ai1_v1.json")
    means = model["scaler_mean"]
    feats = means  # scaled input = 0 -> z = intercept only
    score = score_features(model, feats)
    import math

    expected = 1.0 / (1.0 + math.exp(-model["intercept"]))
    assert score == pytest.approx(expected, rel=1e-9)


def test_runtime_matches_dataset_sample():
    dataset = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
    if not dataset.exists():
        pytest.skip("dataset missing")

    import pandas as pd

    ai_dir = ROOT / "Diagnostics" / "ai"
    if str(ai_dir) not in sys.path:
        sys.path.insert(0, str(ai_dir))
    from policy import FEATURE_ORDER, executed_mask, prepare_features

    df = pd.read_parquet(dataset)
    trades = prepare_features(df.loc[executed_mask(df)].head(5))
    model = load_model(ROOT / "models" / "ai1_v1.json")

    for _, row in trades.iterrows():
        feats = [float(row[name]) for name in FEATURE_ORDER]
        score = score_features(model, feats)
        assert 0.0 <= score <= 1.0


def test_model_json_contract():
    data = json.loads((ROOT / "models" / "ai1_v1.json").read_text(encoding="utf-8"))
    assert len(data["coef"]) == len(data["features"]) == 10
    assert data["model_id"] == "ai1_v1"
