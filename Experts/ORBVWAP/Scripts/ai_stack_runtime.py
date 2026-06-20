"""ORBVWAP full AI stack runtime (INF-8) — models/*.json, no EA recompile."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Sequence

from ai1_runtime import FAILOPEN_SCORE, load_model as load_ai1, score_features, score_from_json

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_AI1 = ROOT / "models" / "ai1_v1.json"
DEFAULT_AI2 = ROOT / "models" / "ai2_v1.json"
DEFAULT_AI3 = ROOT / "models" / "ai3_v1.json"
DEFAULT_AI4 = ROOT / "models" / "ai4_v1.json"

REGIME_FEATURES = [
    "range_width_atr",
    "vol_ratio",
    "spread_pct_range",
    "vwap_dist_atr",
    "weekday",
    "session_ny",
    "prior_session_loss",
]

FAILOPEN_AI2_MULT = 1.0
FAILOPEN_AI3_ALLOW = True
DEFAULT_AI4_STALL_MINUTES = 45
DEFAULT_AI4_STALL_MFE_FRAC = 0.25


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_stack(
    ai1_path: Path | None = None,
    ai2_path: Path | None = None,
    ai3_path: Path | None = None,
    ai4_path: Path | None = None,
) -> dict[str, Any]:
    return {
        "ai1": load_ai1(ai1_path or DEFAULT_AI1),
        "ai2": load_json((ai2_path or DEFAULT_AI2).resolve()),
        "ai3": load_json((ai3_path or DEFAULT_AI3).resolve()),
        "ai4": load_json((ai4_path or DEFAULT_AI4).resolve()),
        "paths": {
            "ai1": str((ai1_path or DEFAULT_AI1).resolve()),
            "ai2": str((ai2_path or DEFAULT_AI2).resolve()),
            "ai3": str((ai3_path or DEFAULT_AI3).resolve()),
            "ai4": str((ai4_path or DEFAULT_AI4).resolve()),
        },
    }


def _features_from_body(body: dict, names: Sequence[str]) -> list[float] | None:
    raw = body.get("features")
    if isinstance(raw, list):
        try:
            feats = [float(x) for x in raw]
        except (TypeError, ValueError):
            return None
        return feats if len(feats) == len(names) else None
    if not all(name in body for name in names):
        return None
    try:
        return [float(body[name]) for name in names]
    except (TypeError, ValueError):
        return None


def chop_probability(row: Sequence[float], cfg: dict) -> float:
    tree = cfg["tree"]
    node = 0
    while tree["children_left"][node] != -1:
        fidx = tree["feature"][node]
        if row[fidx] <= tree["threshold"][node]:
            node = tree["children_left"][node]
        else:
            node = tree["children_right"][node]
    counts = tree["value"][node]
    total = float(counts[0] + counts[1])
    if total <= 0.0:
        return 0.0
    return float(counts[1] / total)


def score_regime(ai3: dict, body: dict) -> tuple[float, bool, bool]:
    """Return (chop_prob, allow, fallback)."""
    feats = _features_from_body(body, REGIME_FEATURES)
    if feats is None:
        return 0.0, FAILOPEN_AI3_ALLOW, True
    chop = chop_probability(feats, ai3)
    thr = float(ai3.get("skip_prob_threshold", 0.6))
    return chop, chop < thr, False


def score_ai2_mult(ai2: dict, ai1_score: float) -> float:
    p50 = float(ai2.get("score_p50", 0.5493886424141821))
    p80 = float(ai2.get("score_p80", 0.6354647410496095))
    if ai1_score < p50:
        return float(ai2.get("mult_low", 1.0))
    if ai1_score < p80:
        return float(ai2.get("mult_mid", 1.15))
    return float(ai2.get("mult_high", 1.25))


def ai4_params(ai4: dict) -> dict[str, float | int]:
    return {
        "stall_minutes": int(ai4.get("stall_minutes", DEFAULT_AI4_STALL_MINUTES)),
        "stall_mfe_frac": float(ai4.get("stall_mfe_frac", DEFAULT_AI4_STALL_MFE_FRAC)),
    }


def score_entry(ai1: dict, ai2: dict, body: dict) -> tuple[float, float, bool]:
    """Return (ai1_score, ai2_mult, fallback)."""
    score, _ = score_from_json(ai1, body)
    fallback = score == FAILOPEN_SCORE and bool(body)
    mult = score_ai2_mult(ai2, score) if not fallback else FAILOPEN_AI2_MULT
    return score, mult, fallback


def score_batch(stack: dict, body: dict) -> dict[str, Any]:
    """Score regime and/or entry layers from one JSON body."""
    out: dict[str, Any] = {
        "ok": True,
        "fallback": False,
        "bundle_id": "orbvwap-v1.23-ai1234",
    }
    a4 = ai4_params(stack["ai4"])
    out["ai4_stall_minutes"] = a4["stall_minutes"]
    out["ai4_stall_mfe_frac"] = a4["stall_mfe_frac"]
    out["ai1_tau"] = float(stack["ai1"].get("tau", 0.3))

    regime_body = body.get("regime") if isinstance(body.get("regime"), dict) else body
    entry_body = body.get("entry") if isinstance(body.get("entry"), dict) else body

    score_regime_block = isinstance(body.get("regime"), dict) or all(
        k in body for k in REGIME_FEATURES
    )
    score_entry_block = isinstance(body.get("entry"), dict) or all(
        k in body for k in stack["ai1"]["features"]
    )

    if score_regime_block and not isinstance(body.get("entry"), dict):
        chop, allow, fb = score_regime(stack["ai3"], regime_body)
        out["chop_prob"] = round(chop, 6)
        out["ai3_allow"] = allow
        if fb:
            out["fallback"] = True
            out["error"] = out.get("error", "invalid_regime_features")

    if score_entry_block and any(k in entry_body for k in stack["ai1"]["features"]):
        ai1_score, ai2_mult, fb = score_entry(stack["ai1"], stack["ai2"], entry_body)
        out["ai1_score"] = round(ai1_score, 6)
        out["ai2_mult"] = round(ai2_mult, 4)
        if fb:
            out["fallback"] = True
            out["error"] = out.get("error", "invalid_entry_features")

    if "ai1_score" not in out and "ai3_allow" not in out:
        out["fallback"] = True
        out["error"] = "missing_regime_or_entry_features"
        out["ai1_score"] = FAILOPEN_SCORE
        out["ai2_mult"] = FAILOPEN_AI2_MULT
        out["ai3_allow"] = FAILOPEN_AI3_ALLOW

    return out


def health_payload(stack: dict, uptime_s: float, log_path: str) -> dict[str, Any]:
    a4 = ai4_params(stack["ai4"])
    return {
        "ok": True,
        "uptime_s": round(uptime_s, 2),
        "bundle_id": "orbvwap-v1.23-ai1234",
        "models": {
            "ai1": stack["paths"]["ai1"],
            "ai2": stack["paths"]["ai2"],
            "ai3": stack["paths"]["ai3"],
            "ai4": stack["paths"]["ai4"],
        },
        "ai1_tau": float(stack["ai1"].get("tau", 0.3)),
        "ai2_mults": {
            "low": float(stack["ai2"].get("mult_low", 1.0)),
            "mid": float(stack["ai2"].get("mult_mid", 1.15)),
            "high": float(stack["ai2"].get("mult_high", 1.25)),
        },
        "ai3_skip_prob_threshold": float(stack["ai3"].get("skip_prob_threshold", 0.6)),
        "ai4_stall_minutes": a4["stall_minutes"],
        "ai4_stall_mfe_frac": a4["stall_mfe_frac"],
        "log_path": log_path,
        "routes": {
            "health": "GET /health",
            "ai1": "POST /score/ai1",
            "regime": "POST /score/regime",
            "entry": "POST /score/entry",
            "batch": "POST /score/batch",
        },
    }
