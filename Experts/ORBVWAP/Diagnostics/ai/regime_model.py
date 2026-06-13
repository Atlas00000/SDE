#!/usr/bin/env python3
"""AI-3 tree inference from exported JSON."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from sessions import REGIME_FEATURES

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_AI3 = ROOT / "models" / "ai3_v1.json"


def load_config(path: Path = DEFAULT_AI3) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def chop_probability(row: np.ndarray, cfg: dict) -> float:
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
    if total <= 0:
        return 0.0
    return float(counts[1] / total)


def add_session_allow(df: pd.DataFrame, cfg: dict) -> pd.DataFrame:
    thr = float(cfg["skip_prob_threshold"])
    out = df.copy()
    probs = []
    for _, row in out.iterrows():
        x = row[REGIME_FEATURES].astype(float).values
        probs.append(chop_probability(x, cfg))
    out["chop_prob"] = probs
    out["session_allow"] = out["chop_prob"] < thr
    return out
