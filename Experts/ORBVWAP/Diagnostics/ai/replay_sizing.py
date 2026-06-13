#!/usr/bin/env python3
"""AI-2-001/002: Offline bucket sizing replay and ablation vs AI-1-only."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

from policy import (
    DEFAULT_SIZE_TIERS,
    ai1_tau,
    apply_ai1_filter,
    apply_ai2_sizing,
    calibrate_size_thresholds,
    executed_mask,
    load_ai1_config,
    score_executed_trades,
    sized_trade_metrics,
)
from train_eval import print_metrics, trade_metrics

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JOURNAL = ROOT / "Diagnostics" / "AI-test-journal.csv"
DEFAULT_AI2 = ROOT / "models" / "ai2_v1.json"
DEFAULT_MQH = ROOT / "Include" / "ORBVWAP" / "AiSizer.mqh"


def gate_verdict(prod: dict, ai1: dict, ai2: dict) -> str:
    """Protection sizing gate: no PF collapse vs AI-1, payoff holds, DD bounded."""
    if ai2["n"] < ai1["n"]:
        return "REJECT"
    pf_ok = ai2["pf"] >= ai1["pf"] * 0.98
    payoff_ok = ai2["payoff"] >= prod["payoff"] * 0.99
    dd_ok = ai2["max_dd"] <= ai1["max_dd"] * 1.15 if ai1["max_dd"] > 0 else True
    net_ok = ai2["net"] >= ai1["net"]
    if pf_ok and payoff_ok and dd_ok and net_ok:
        return "PASS"
    if pf_ok and dd_ok and net_ok:
        return "REVIEW"
    return "REJECT"


def export_mqh(
    path: Path,
    p50: float,
    p80: float,
    tiers: tuple[float, float, float],
) -> None:
    lines = [
        "//+------------------------------------------------------------------+",
        "//| AiSizer.mqh — AI-2 dynamic sizing (auto-generated)               |",
        "//+------------------------------------------------------------------+",
        "#ifndef __ORBVWAP_AISIZER_MQH__",
        "#define __ORBVWAP_AISIZER_MQH__",
        "",
        '#include "Inputs.mqh"',
        "",
        f"const double ORBVWAP_AI2_SCORE_P50 = {p50:.8f};",
        f"const double ORBVWAP_AI2_SCORE_P80 = {p80:.8f};",
        f"const double ORBVWAP_AI2_MULT_LOW  = {tiers[0]:.4f};",
        f"const double ORBVWAP_AI2_MULT_MID  = {tiers[1]:.4f};",
        f"const double ORBVWAP_AI2_MULT_HIGH = {tiers[2]:.4f};",
        "",
        "class CAiSizer",
        "  {",
        "public:",
        "   static double Multiplier(const double ai_score)",
        "     {",
        "      if(ai_score < ORBVWAP_AI2_SCORE_P50)",
        "         return(ORBVWAP_AI2_MULT_LOW);",
        "      if(ai_score < ORBVWAP_AI2_SCORE_P80)",
        "         return(ORBVWAP_AI2_MULT_MID);",
        "      return(ORBVWAP_AI2_MULT_HIGH);",
        "     }",
        "  };",
        "",
        "#endif // __ORBVWAP_AISIZER_MQH__",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="AI-2 sizing policy replay")
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--journal", type=Path, default=DEFAULT_JOURNAL)
    parser.add_argument("--ai2-out", type=Path, default=DEFAULT_AI2)
    parser.add_argument("--mqh-out", type=Path, default=DEFAULT_MQH)
    args = parser.parse_args()

    scored_train, scored_holdout, split = score_executed_trades(holdout_frac=args.holdout_frac)
    tau = ai1_tau()
    p50, p80 = calibrate_size_thresholds(scored_train, tau)

    prod_ho = trade_metrics(scored_holdout, executed_mask(scored_holdout))
    ai1_ho = trade_metrics(apply_ai1_filter(scored_holdout, tau))
    ai2_df = apply_ai2_sizing(apply_ai1_filter(scored_holdout, tau), p50, p80)
    ai2_ho = sized_trade_metrics(ai2_df)

    verdict = gate_verdict(prod_ho, ai1_ho, ai2_ho)

    print("=== AI-2 sizing replay ===")
    print(f"Holdout cut: {split.cut_time}")
    print(f"AI-1 tau={tau:.3f} | size p50={p50:.3f} p80={p80:.3f} | tiers={DEFAULT_SIZE_TIERS}")
    print_metrics("HOLDOUT PROD", prod_ho)
    print_metrics("HOLDOUT AI-1 only", ai1_ho)
    print_metrics("HOLDOUT AI-1+AI-2", ai2_ho)
    if not ai2_df.empty:
        dist = ai2_df["size_mult"].value_counts().sort_index()
        print(f"Size bucket counts: {dict(dist)}")
    print(f"\nAI-2 gate verdict: {verdict}")

    payload = {
        "model_id": "ai2_v1",
        "layer": "L2",
        "mode": "protection_sizing",
        "ai1_tau": tau,
        "score_p50": p50,
        "score_p80": p80,
        "mult_low": DEFAULT_SIZE_TIERS[0],
        "mult_mid": DEFAULT_SIZE_TIERS[1],
        "mult_high": DEFAULT_SIZE_TIERS[2],
        "holdout_cut": str(split.cut_time),
        "metrics": {"prod": prod_ho, "ai1": ai1_ho, "ai2": ai2_ho, "verdict": verdict},
    }
    args.ai2_out.parent.mkdir(parents=True, exist_ok=True)
    args.ai2_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {args.ai2_out}")

    export_mqh(args.mqh_out, p50, p80, DEFAULT_SIZE_TIERS)
    print(f"Wrote {args.mqh_out}")

    row = {
        "task_id": "AI-2-002",
        "preset": "AI2_Sizing_replay",
        "dataset": "ORBVWAP_ai_dataset_v1.parquet",
        "holdout_cut": str(split.cut_time),
        "n_full": ai2_ho["n"],
        "pf_full": round(ai2_ho["pf"], 2),
        "n_holdout": ai2_ho["n"],
        "pf_holdout": round(ai2_ho["pf"], 2),
        "verdict": verdict,
        "notes": f"ai1+ai2 payoff={ai2_ho['payoff']:.2f} net={ai2_ho['net']:.2f}",
    }
    journal_exists = args.journal.exists()
    pd.DataFrame([row]).to_csv(args.journal, mode="a", header=not journal_exists, index=False)
    print(f"Appended journal row -> {args.journal}")


if __name__ == "__main__":
    main()
