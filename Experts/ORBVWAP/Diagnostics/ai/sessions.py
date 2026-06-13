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


def build_sessions(dataset: Path = DEFAULT_DATASET) -> pd.DataFrame:
    raw = prepare_features(pd.read_parquet(dataset))
    trades = raw.loc[executed_mask(raw)].copy()
    trades["sess_key"] = session_key(trades)
    trades = trades.sort_values("bar_time_gmt").reset_index(drop=True)

    trades["prior_session_loss"] = 0.0
    for i in range(1, len(trades)):
        trades.loc[trades.index[i], "prior_session_loss"] = (
            1.0 if trades.iloc[i - 1]["label_win"] == 0 else 0.0
        )

    trades["label_chop"] = (1 - trades["label_win"]).astype(int)
    trades["regime"] = trades["label_chop"].map({0: "TRENDING", 1: "CHOPPY"})
    return trades


def attach_session_allow(trades: pd.DataFrame, allow: pd.Series) -> pd.DataFrame:
    out = trades.copy()
    out["session_allow"] = allow.astype(bool).values
    return out
