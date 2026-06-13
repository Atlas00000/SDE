#!/usr/bin/env python3
"""AI-3-003: Replay PROD vs AI-3 vs AI-3+AI-1 (+ AI-2)."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from policy import (
    ai1_tau,
    apply_ai1_filter,
    apply_ai2_sizing,
    calibrate_size_thresholds,
    score_executed_trades,
    sized_trade_metrics,
)
from regime_model import DEFAULT_AI3, add_session_allow, load_config
from sessions import build_sessions
from train_eval import print_metrics, time_split, trade_metrics_ordered

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JOURNAL = ROOT / "Diagnostics" / "AI-test-journal.csv"


def profit_session_loss_fraction(skipped: pd.DataFrame, all_trades: pd.DataFrame) -> float:
    win_sessions = all_trades[all_trades["label_win"] == 1]
    if win_sessions.empty:
        return 0.0
    gross = win_sessions["profit"].astype(float).clip(lower=0).sum()
    if gross <= 0:
        return 0.0
    lost = skipped.loc[skipped["label_win"] == 1, "profit"].astype(float).clip(lower=0).sum()
    return float(lost / gross)


def gate_verdict(prod: dict, ai3: dict, profit_frac_removed: float) -> str:
    streak_ok = ai3["max_consec_loss"] < prod["max_consec_loss"]
    dd_ok = ai3["max_dd"] < prod["max_dd"]
    profit_ok = profit_frac_removed <= 0.30
    pf_ok = ai3["pf"] >= prod["pf"] * 0.95
    if profit_ok and pf_ok and (streak_ok or dd_ok):
        return "PASS"
    if profit_ok and (streak_ok or dd_ok):
        return "REVIEW"
    return "REJECT"


def main() -> None:
    parser = argparse.ArgumentParser(description="AI-3 regime policy replay")
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--journal", type=Path, default=DEFAULT_JOURNAL)
    parser.add_argument("--ai3-config", type=Path, default=DEFAULT_AI3)
    args = parser.parse_args()

    if not args.ai3_config.exists():
        raise SystemExit(f"Run train_regime.py first. Missing {args.ai3_config}")

    cfg = load_config(args.ai3_config)
    sessions = add_session_allow(build_sessions(), cfg)
    split = time_split(sessions, train_frac=1.0 - args.holdout_frac)
    ho = split.holdout

    prod_ho = trade_metrics_ordered(ho)
    ai3_ho = trade_metrics_ordered(ho.loc[ho["session_allow"]])
    profit_frac = profit_session_loss_fraction(ho.loc[~ho["session_allow"]], ho)

    scored_train, scored_holdout, _ = score_executed_trades(holdout_frac=args.holdout_frac)
    tau = ai1_tau()
    scored_holdout = scored_holdout.copy()
    scored_holdout["sess_key"] = (
        scored_holdout["bar_time_gmt"].dt.date.astype(str) + "_" + scored_holdout["session"]
    )
    ho_scored = scored_holdout.merge(
        ho[["sess_key", "session_allow"]],
        on="sess_key",
        how="left",
    )
    ho_scored["session_allow"] = ho_scored["session_allow"].fillna(True)

    ai31 = apply_ai1_filter(ho_scored.loc[ho_scored["session_allow"]], tau)
    ai31_ho = trade_metrics_ordered(ai31)

    p50, p80 = calibrate_size_thresholds(scored_train, tau)
    ai312 = apply_ai2_sizing(apply_ai1_filter(ho_scored.loc[ho_scored["session_allow"]], tau), p50, p80)
    ai312_ho = sized_trade_metrics(ai312)
    ai312_ho["max_consec_loss"] = trade_metrics_ordered(ai312)["max_consec_loss"]

    verdict = gate_verdict(prod_ho, ai3_ho, profit_frac)

    print("=== AI-3 regime replay ===")
    print(f"Holdout cut: {split.cut_time} | skip if chop_prob >= {cfg['skip_prob_threshold']:.3f}")
    print(f"Sessions skipped: {int((~ho['session_allow']).sum())}/{len(ho)}")
    print(f"Win-profit removed: {100 * profit_frac:.1f}% (gate <=30%)")
    print_metrics("HOLDOUT PROD", prod_ho)
    print_metrics("HOLDOUT AI-3", ai3_ho)
    print_metrics("HOLDOUT AI-3+AI-1", ai31_ho)
    print_metrics("HOLDOUT AI-3+AI-1+AI-2", ai312_ho)
    print(f"\nAI-3 gate verdict: {verdict}")

    row = {
        "task_id": "AI-3-003",
        "preset": "AI3_Regime_replay",
        "dataset": "ORBVWAP_ai_dataset_v1.parquet",
        "holdout_cut": str(split.cut_time),
        "n_full": ai3_ho["n"],
        "pf_full": round(ai3_ho["pf"], 2),
        "n_holdout": ai3_ho["n"],
        "pf_holdout": round(ai3_ho["pf"], 2),
        "verdict": verdict,
        "notes": f"maxCL {prod_ho['max_consec_loss']}->{ai3_ho['max_consec_loss']} win_cut={profit_frac:.2f}",
    }
    journal_exists = args.journal.exists()
    pd.DataFrame([row]).to_csv(args.journal, mode="a", header=not journal_exists, index=False)
    print(f"Appended journal row -> {args.journal}")


if __name__ == "__main__":
    main()
