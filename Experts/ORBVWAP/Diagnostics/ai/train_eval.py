#!/usr/bin/env python3
"""AI-0-004: Time-based train/holdout split and metric helpers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import numpy as np
import pandas as pd


@dataclass
class SplitResult:
    train: pd.DataFrame
    holdout: pd.DataFrame
    cut_time: pd.Timestamp


def time_split(df: pd.DataFrame, train_frac: float = 0.7, time_col: str = "bar_time_gmt") -> SplitResult:
    data = df.sort_values(time_col).reset_index(drop=True)
    cut_idx = int(len(data) * train_frac)
    cut_idx = max(1, min(cut_idx, len(data) - 1))
    cut_time = data.loc[cut_idx - 1, time_col]
    train = data.iloc[:cut_idx].copy()
    holdout = data.iloc[cut_idx:].copy()
    return SplitResult(train=train, holdout=holdout, cut_time=pd.Timestamp(cut_time))


def profit_factor(profits: Iterable[float]) -> float:
    arr = np.asarray(list(profits), dtype=float)
    if arr.size == 0:
        return 0.0
    gross_profit = arr[arr > 0].sum()
    gross_loss = -arr[arr < 0].sum()
    if gross_loss <= 0:
        return float("inf") if gross_profit > 0 else 0.0
    return float(gross_profit / gross_loss)


def payoff_ratio(wins: Iterable[float], losses: Iterable[float]) -> float:
    w = np.asarray(list(wins), dtype=float)
    l = np.asarray(list(losses), dtype=float)
    if w.size == 0 or l.size == 0:
        return 0.0
    avg_win = w.mean()
    avg_loss = abs(l.mean())
    if avg_loss <= 0:
        return 0.0
    return float(avg_win / avg_loss)


def max_equity_drawdown(profits: Iterable[float]) -> float:
    """Peak-to-trough drawdown on cumulative trade P/L (absolute units)."""
    arr = np.asarray(list(profits), dtype=float)
    if arr.size == 0:
        return 0.0
    equity = np.cumsum(arr)
    peak = np.maximum.accumulate(equity)
    dd = peak - equity
    return float(dd.max()) if dd.size else 0.0


def trade_metrics(df: pd.DataFrame, mask: pd.Series | None = None) -> dict:
    sub = df if mask is None else df.loc[mask].copy()
    sub = sub[sub["label_win"].notna()]
    if sub.empty:
        return {"n": 0, "pf": 0.0, "wr": 0.0, "payoff": 0.0, "net": 0.0, "max_dd": 0.0}

    profits = sub["profit"].astype(float)
    wins = sub.loc[sub["label_win"] == 1, "profit"].astype(float)
    losses = sub.loc[sub["label_win"] == 0, "profit"].astype(float)

    return {
        "n": int(len(sub)),
        "pf": profit_factor(profits),
        "wr": float(100.0 * (sub["label_win"] == 1).mean()),
        "payoff": payoff_ratio(wins, losses),
        "net": float(profits.sum()),
        "max_dd": max_equity_drawdown(profits),
    }


def max_consecutive_losses(label_wins: Iterable) -> int:
    best = cur = 0
    for w in label_wins:
        if int(w) == 0:
            cur += 1
            best = max(best, cur)
        else:
            cur = 0
    return int(best)


def trade_metrics_ordered(df: pd.DataFrame, time_col: str = "bar_time_gmt") -> dict:
    """Trade metrics preserving time order (for streak / DD)."""
    sub = df.sort_values(time_col).copy()
    sub = sub[sub["label_win"].notna()]
    if sub.empty:
        return {"n": 0, "pf": 0.0, "wr": 0.0, "payoff": 0.0, "net": 0.0, "max_dd": 0.0, "max_consec_loss": 0}
    if "size_mult" in sub.columns:
        sub = sub.copy()
        sub["sized_profit"] = sub["profit"].astype(float) * sub["size_mult"].astype(float)
        profits = sub["sized_profit"]
        wins = sub.loc[sub["label_win"] == 1, "sized_profit"]
        losses = sub.loc[sub["label_win"] == 0, "sized_profit"]
        return {
            "n": int(len(sub)),
            "pf": profit_factor(profits),
            "wr": float(100.0 * (sub["label_win"] == 1).mean()),
            "payoff": payoff_ratio(wins, losses),
            "net": float(profits.sum()),
            "max_dd": max_equity_drawdown(profits),
            "max_consec_loss": max_consecutive_losses(sub["label_win"]),
        }
    m = trade_metrics(sub)
    m["max_consec_loss"] = max_consecutive_losses(sub["label_win"])
    return m


def print_metrics(label: str, m: dict) -> None:
    dd = m.get("max_dd", 0.0)
    streak = m.get("max_consec_loss")
    extra = f" maxCL={streak}" if streak is not None else ""
    print(
        f"{label}: n={m['n']} PF={m['pf']:.2f} WR={m['wr']:.1f}% "
        f"payoff={m['payoff']:.2f} net={m['net']:.2f} max_dd={dd:.2f}{extra}"
    )
