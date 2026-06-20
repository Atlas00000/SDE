#!/usr/bin/env python3
"""AI-3-001: Session-level table from decision export (one ORB session = one row)."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from policy import DEFAULT_DATASET, executed_mask, prepare_features

REGIME_FEATURES = [
    "range_width_atr",
    "vol_ratio",
    "spread_pct_range",
    "vwap_dist_atr",
    "weekday",
    "session_ny",
    "prior_session_loss",
]


def session_key(df: pd.DataFrame) -> pd.Series:
    return df["bar_time_gmt"].dt.date.astype(str) + "_" + df["session"]


def build_sessions_from_trades(trades: pd.DataFrame) -> pd.DataFrame:
    """Build session table from an executed-trade frame (walk-forward safe)."""
    out = prepare_features(trades.loc[executed_mask(trades)].copy())
    out["sess_key"] = session_key(out)
    out = out.sort_values("bar_time_gmt").reset_index(drop=True)

    out["prior_session_loss"] = 0.0
    for i in range(1, len(out)):
        out.loc[out.index[i], "prior_session_loss"] = (
            1.0 if out.iloc[i - 1]["label_win"] == 0 else 0.0
        )

    out["label_chop"] = (1 - out["label_win"]).astype(int)
    out["regime"] = out["label_chop"].map({0: "TRENDING", 1: "CHOPPY"})
    return out


def build_sessions(dataset: Path = DEFAULT_DATASET) -> pd.DataFrame:
    raw = prepare_features(pd.read_parquet(dataset))
    return build_sessions_from_trades(raw)


def attach_session_allow(trades: pd.DataFrame, allow: pd.Series) -> pd.DataFrame:
    out = trades.copy()
    out["session_allow"] = allow.astype(bool).values
    return out
