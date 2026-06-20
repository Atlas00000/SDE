"""ORBVWAP AI-1 runtime scoring from models/ai1_v1.json (INF-8)."""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Sequence

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "models" / "ai1_v1.json"
FAILOPEN_SCORE = 0.5


def load_model(path: Path | None = None) -> dict:
    model_path = (path or DEFAULT_MODEL).resolve()
    data = json.loads(model_path.read_text(encoding="utf-8"))
    if len(data.get("coef", [])) != len(data.get("features", [])):
        raise ValueError("coef/features length mismatch")
    return data


def sigmoid(x: float) -> float:
    if x >= 0.0:
        return 1.0 / (1.0 + math.exp(-x))
    ex = math.exp(x)
    return ex / (1.0 + ex)


def score_features(model: dict, features: Sequence[float]) -> float:
    names = model["features"]
    if len(features) != len(names):
        raise ValueError(f"expected {len(names)} features, got {len(features)}")

    z = float(model["intercept"])
    means = model["scaler_mean"]
    scales = model["scaler_scale"]
    coefs = model["coef"]

    for i, value in enumerate(features):
        scale = float(scales[i])
        if scale > 0.0:
            z += float(coefs[i]) * ((float(value) - float(means[i])) / scale)

    return sigmoid(z)


def score_from_json(model: dict, body: dict) -> tuple[float, list[float] | None]:
    """Parse feature dict or features[] list from HTTP JSON body."""
    raw = body.get("features")
    if isinstance(raw, list):
        try:
            feats = [float(x) for x in raw]
        except (TypeError, ValueError):
            return FAILOPEN_SCORE, None
        if len(feats) != len(model["features"]):
            return FAILOPEN_SCORE, None
        return score_features(model, feats), feats

    names = model["features"]
    if not all(name in body for name in names):
        return FAILOPEN_SCORE, None

    try:
        feats = [float(body[name]) for name in names]
    except (TypeError, ValueError):
        return FAILOPEN_SCORE, None

    return score_features(model, feats), feats
