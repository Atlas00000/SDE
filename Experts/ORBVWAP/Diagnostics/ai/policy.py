#!/usr/bin/env python3
"""Shared AI policy helpers: score, AI-1 filter, AI-2 sizing."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

from train_eval import max_equity_drawdown, payoff_ratio, profit_factor, time_split

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
DEFAULT_AI1 = ROOT / "models" / "ai1_v1.json"

FEATURE_ORDER = [
    "range_width_atr",
    "vol_ratio",
    "vwap_dist_atr",
    "spread_pct_range",
    "min_rr",
    "hour_gmt",
    "weekday",
    "ny_min_since_open",
    "session_ny",
    "direction_sell",
]

DEFAULT_SIZE_TIERS = (1.0, 1.15, 1.25)


def executed_mask(df: pd.DataFrame) -> pd.Series:
    return (df["prod_executed"] == 1) & df["label_win"].notna()


def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["session_ny"] = (out["session"] == "NY").astype(float)
    out["direction_sell"] = (out["direction"] == "SELL").astype(float)
    return out


def load_ai1_config(path: Path = DEFAULT_AI1) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fit_scorer(train: pd.DataFrame) -> tuple[LogisticRegression, StandardScaler]:
    x = train[FEATURE_ORDER].astype(float).values
    y = train["label_win"].astype(int).values
    scaler = StandardScaler()
    x_scaled = scaler.fit_transform(x)
    model = LogisticRegression(max_iter=2000, C=0.3, random_state=42)
    model.fit(x_scaled, y)
    return model, scaler


def add_scores(
    df: pd.DataFrame,
    model: LogisticRegression,
    scaler: StandardScaler,
) -> pd.DataFrame:
    out = df.copy()
    x = out[FEATURE_ORDER].astype(float).values
    out["ai_score"] = model.predict_proba(scaler.transform(x))[:, 1]
    return out


def score_executed_trades(
    dataset: Path = DEFAULT_DATASET,
    holdout_frac: float = 0.3,
) -> tuple[pd.DataFrame, pd.DataFrame, object]:
    raw = pd.read_parquet(dataset)
    trades = prepare_features(raw.loc[executed_mask(raw)].copy())
    split = time_split(trades, train_frac=1.0 - holdout_frac)
    model, scaler = fit_scorer(split.train)
    scored_train = add_scores(split.train, model, scaler)
    scored_holdout = add_scores(split.holdout, model, scaler)
    return scored_train, scored_holdout, split


def ai1_tau(cfg: dict | None = None) -> float:
    cfg = cfg or load_ai1_config()
    return float(cfg.get("tau", 0.30))


def calibrate_size_thresholds(
    scored_train: pd.DataFrame,
    tau: float,
    p50_q: float = 0.50,
    p80_q: float = 0.80,
) -> tuple[float, float]:
    """Percentile cutoffs on train scores among AI-1 passing trades."""
    passing = scored_train.loc[executed_mask(scored_train) & (scored_train["ai_score"] >= tau), "ai_score"]
    if passing.empty:
        return tau, tau + 0.05
    return float(passing.quantile(p50_q)), float(passing.quantile(p80_q))


def size_multiplier(
    score: float,
    p50: float,
    p80: float,
    tiers: tuple[float, float, float] = DEFAULT_SIZE_TIERS,
) -> float:
    if score < p50:
        return tiers[0]
    if score < p80:
        return tiers[1]
    return tiers[2]


def sized_trade_metrics(df: pd.DataFrame) -> dict:
    if df.empty:
        return {"n": 0, "pf": 0.0, "wr": 0.0, "payoff": 0.0, "net": 0.0, "max_dd": 0.0}
    profits = (df["profit"].astype(float) * df["size_mult"].astype(float))
    wins = profits[df["label_win"] == 1]
    losses = profits[df["label_win"] == 0]
    return {
        "n": int(len(df)),
        "pf": profit_factor(profits),
        "wr": float(100.0 * (df["label_win"] == 1).mean()),
        "payoff": payoff_ratio(wins, losses),
        "net": float(profits.sum()),
        "max_dd": max_equity_drawdown(profits),
    }


def apply_ai1_filter(df: pd.DataFrame, tau: float) -> pd.DataFrame:
    return df.loc[executed_mask(df) & (df["ai_score"] >= tau)].copy()


def apply_ai2_sizing(
    df: pd.DataFrame,
    p50: float,
    p80: float,
    tiers: tuple[float, float, float] = DEFAULT_SIZE_TIERS,
) -> pd.DataFrame:
    out = df.copy()
    out["size_mult"] = out["ai_score"].apply(lambda s: size_multiplier(s, p50, p80, tiers))
    return out
