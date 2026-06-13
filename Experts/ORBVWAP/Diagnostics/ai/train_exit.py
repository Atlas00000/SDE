#!/usr/bin/env python3
"""AI-4-002: Train stall-scratch exit overlay + export AiExit.mqh."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from build_paths import DEFAULT_OUT, add_proxy_paths, build
from policy import DEFAULT_DATASET
from train_eval import payoff_ratio, profit_factor, time_split

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = ROOT / "models" / "ai4_v1.json"
DEFAULT_MQH = ROOT / "Include" / "ORBVWAP" / "AiExit.mqh"

STALL_MINUTES = 45
STALL_MFE_FRAC = 0.25
TAIL_CAP_MULT = 0.72


def metrics_from_train(sim: pd.Series, train: pd.DataFrame) -> dict:
    losses = sim[train["label_win"] == 0]
    wins = sim[train["label_win"] == 1]
    tail = abs(losses.min()) / abs(losses.mean()) if len(losses) and losses.mean() != 0 else 0.0
    return {
        "pf": profit_factor(sim),
        "payoff": payoff_ratio(wins, losses),
        "tail_ratio": float(tail),
    }


def export_mqh(path: Path, stall_min: int, stall_frac: float) -> None:
    text = f"""//+------------------------------------------------------------------+
//| AiExit.mqh — AI-4 stall-scratch exit overlay (auto-generated)    |
//+------------------------------------------------------------------+
#ifndef __ORBVWAP_AIEXIT_MQH__
#define __ORBVWAP_AIEXIT_MQH__

#include "Inputs.mqh"

const int    ORBVWAP_AI4_STALL_MINUTES = {stall_min};
const double ORBVWAP_AI4_STALL_MFE_FRAC = {stall_frac:.6f};

class CAiExit
  {{
public:
   static int StallMinutes() {{ return(ORBVWAP_AI4_STALL_MINUTES); }}

   static double StallMfeFrac() {{ return(ORBVWAP_AI4_STALL_MFE_FRAC); }}

   static bool ShouldStallScratch(const int hold_minutes, const double mfe_frac)
     {{
      if(hold_minutes < ORBVWAP_AI4_STALL_MINUTES)
         return(false);
      return(mfe_frac < ORBVWAP_AI4_STALL_MFE_FRAC);
     }}
  }};

#endif // __ORBVWAP_AIEXIT_MQH__
"""
    path.write_text(text, encoding="utf-8")


def simulate_stall_scratch(
    df: pd.DataFrame,
    stall_frac: float,
    tail_cap_mult: float = 0.72,
) -> pd.Series:
    """Stall scratch: losers with low MFE@45min get loss capped (tail trim)."""
    rw = df["range_width"].astype(float)
    mfe45 = df["mfe_at_45"].astype(float)
    mfe_frac = mfe45 / rw.replace(0, np.nan)
    stall = (df["label_win"] == 0) & (mfe_frac < stall_frac)
    profits = df["profit"].astype(float).copy()
    losses = profits[profits < 0]
    if len(losses):
        cap = -tail_cap_mult * abs(losses.mean())
        profits.loc[stall] = profits.loc[stall].clip(lower=cap)
    return profits


def main() -> None:
    parser = argparse.ArgumentParser(description="Train AI-4 exit overlay")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--decisions", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--paths", type=Path, default=None)
    parser.add_argument("--model-out", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--mqh-out", type=Path, default=DEFAULT_MQH)
    args = parser.parse_args()

    if args.dataset.exists():
        df = pd.read_parquet(args.dataset)
    else:
        df = build(args.decisions, args.paths)
        df = add_proxy_paths(df)

    split = time_split(df, train_frac=0.7)
    train, holdout = split.train, split.holdout

    best_frac = STALL_MFE_FRAC
    best_cap = TAIL_CAP_MULT
    best_score = -1e9
    for frac in np.arange(0.20, 0.36, 0.05):
        for cap in [0.65, 0.72, 0.80]:
            sim = simulate_stall_scratch(train, frac, cap)
            m = metrics_from_train(sim, train)
            score = m["pf"] + m["payoff"] - m["tail_ratio"]
            if score > best_score:
                best_score = score
                best_frac = float(frac)
                best_cap = float(cap)

    print("=== AI-4 exit training ===")
    print(f"Stall: {STALL_MINUTES} min | mfe_frac < {best_frac:.2f} | tail cap {best_cap:.2f}x avg loss")
    print(f"Train rows: {len(train)} | holdout cut: {split.cut_time}")

    payload = {
        "model_id": "ai4_v1",
        "type": "stall_scratch",
        "mode": "protection_exit",
        "stall_minutes": STALL_MINUTES,
        "stall_mfe_frac": best_frac,
        "tail_cap_mult": best_cap,
        "holdout_cut": str(split.cut_time),
    }
    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    args.model_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    export_mqh(args.mqh_out, STALL_MINUTES, best_frac)
    print(f"Wrote {args.model_out}")
    print(f"Wrote {args.mqh_out}")


if __name__ == "__main__":
    main()
