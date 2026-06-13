#!/usr/bin/env python3
"""AI-4-003: Replay exit overlay on AI-3+AI-1 stack vs full stack."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from build_paths import DEFAULT_OUT, add_proxy_paths, build
from policy import (
    DEFAULT_DATASET,
    ai1_tau,
    apply_ai1_filter,
    apply_ai2_sizing,
    calibrate_size_thresholds,
    score_executed_trades,
    sized_trade_metrics,
)
from regime_model import add_session_allow, load_config
from sessions import build_sessions
from train_eval import print_metrics, time_split, trade_metrics_ordered
from train_exit import simulate_stall_scratch

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_AI4 = ROOT / "models" / "ai4_v1.json"
DEFAULT_JOURNAL = ROOT / "Diagnostics" / "AI-test-journal.csv"


def stack_holdout(holdout_frac: float = 0.3) -> tuple[pd.DataFrame, pd.DataFrame, object]:
    cfg3 = load_config()
    sessions = add_session_allow(build_sessions(), cfg3)
    split = time_split(sessions, train_frac=1.0 - holdout_frac)
    ho = split.holdout.copy()

    scored_train, scored_holdout, _ = score_executed_trades(holdout_frac=holdout_frac)
    tau = ai1_tau()
    scored_holdout = scored_holdout.copy()
    scored_holdout["sess_key"] = (
        scored_holdout["bar_time_gmt"].dt.date.astype(str) + "_" + scored_holdout["session"]
    )
    ho_scored = scored_holdout.merge(ho[["sess_key", "session_allow"]], on="sess_key", how="left")
    ho_scored["session_allow"] = ho_scored["session_allow"].fillna(True)
    stack = apply_ai1_filter(ho_scored.loc[ho_scored["session_allow"]], tau)
    return stack, scored_train, split


def metrics_from_profits(df: pd.DataFrame, profits: pd.Series) -> dict:
    out = df.copy()
    out["exit_profit"] = profits.values
    out["size_mult"] = 1.0
    m = trade_metrics_ordered(out.assign(profit=out["exit_profit"]))
    losses = out.loc[out["label_win"] == 0, "exit_profit"].astype(float)
    wins = out.loc[out["label_win"] == 1, "exit_profit"].astype(float)
    tail = abs(losses.min()) / abs(losses.mean()) if len(losses) and losses.mean() != 0 else 0.0
    m["tail_ratio"] = float(tail)
    m["payoff"] = float(wins.mean() / abs(losses.mean())) if len(wins) and len(losses) and losses.mean() != 0 else 0.0
    return m


def gate_verdict(base: dict, ai4: dict) -> str:
    payoff_ok = ai4["payoff"] >= base["payoff"] * 0.99
    pf_ok = ai4["pf"] >= base["pf"] * 0.98
    tail_ok = ai4["tail_ratio"] <= base["tail_ratio"] * 1.02
    dd_ok = ai4["max_dd"] <= base["max_dd"]
    if payoff_ok and pf_ok and (tail_ok or dd_ok):
        return "PASS"
    if pf_ok and dd_ok:
        return "REVIEW"
    return "REJECT"


def main() -> None:
    parser = argparse.ArgumentParser(description="AI-4 exit replay")
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--ai4-config", type=Path, default=DEFAULT_AI4)
    parser.add_argument("--journal", type=Path, default=DEFAULT_JOURNAL)
    args = parser.parse_args()

    if not args.ai4_config.exists():
        raise SystemExit("Run train_exit.py first")

    cfg4 = json.loads(args.ai4_config.read_text(encoding="utf-8"))
    stall_frac = float(cfg4["stall_mfe_frac"])
    tail_cap = float(cfg4.get("tail_cap_mult", 0.72))

    if DEFAULT_OUT.exists():
        paths_df = pd.read_parquet(DEFAULT_OUT)
    else:
        paths_df = add_proxy_paths(build(DEFAULT_DATASET, None))

    stack, scored_train, split = stack_holdout(args.holdout_frac)
    stack = stack.merge(
        paths_df[["position_id", "mfe_at_45", "mfe_frac", "range_width"]],
        on="position_id",
        how="left",
        suffixes=("", "_p"),
    )
    stack["mfe_at_45"] = stack["mfe_at_45"].fillna(stack.get("mfe_at_45_proxy", stack["range_width"] * 0.2))
    stack["range_width"] = stack["range_width"].fillna(stack.get("range_width_p", stack["range_width"]))

    base_m = metrics_from_profits(stack, stack["profit"].astype(float))
    exit_profits = simulate_stall_scratch(stack, stall_frac, tail_cap)
    ai4_m = metrics_from_profits(stack, exit_profits)

    p50, p80 = calibrate_size_thresholds(scored_train, ai1_tau())
    sized = apply_ai2_sizing(stack, p50, p80)
    sized_exit = simulate_stall_scratch(sized, stall_frac, tail_cap)
    sized["sized_profit"] = sized["profit"] * sized["size_mult"]
    sized_m = sized_trade_metrics(sized)
    sized_exit_df = sized.copy()
    sized_exit_df["profit"] = sized_exit * sized["size_mult"]
    full_m = trade_metrics_ordered(sized_exit_df)

    verdict = gate_verdict(base_m, ai4_m)

    print("=== AI-4 exit replay (AI-3+AI-1 stack holdout) ===")
    print(f"Cut: {split.cut_time} | stall mfe<{stall_frac:.2f} tail cap {tail_cap:.2f}x avg loss")
    print_metrics("STACK (no AI-4)", base_m)
    print(f"  tail_ratio={base_m['tail_ratio']:.2f}")
    print_metrics("STACK + AI-4", ai4_m)
    print(f"  tail_ratio={ai4_m['tail_ratio']:.2f}")
    print_metrics("FULL + AI-4 + AI-2", full_m)
    print(f"\nAI-4 gate verdict: {verdict}")

    row = {
        "task_id": "AI-4-003",
        "preset": "AI4_Exit_replay",
        "dataset": "ORBVWAP_ai_paths_v1.parquet",
        "holdout_cut": str(split.cut_time),
        "n_full": ai4_m["n"],
        "pf_full": round(ai4_m["pf"], 2),
        "n_holdout": ai4_m["n"],
        "pf_holdout": round(ai4_m["pf"], 2),
        "verdict": verdict,
        "notes": f"payoff {base_m['payoff']:.2f}->{ai4_m['payoff']:.2f} tail {base_m['tail_ratio']:.2f}->{ai4_m['tail_ratio']:.2f}",
    }
    journal_exists = args.journal.exists()
    pd.DataFrame([row]).to_csv(args.journal, mode="a", header=not journal_exists, index=False)
    print(f"Appended journal row -> {args.journal}")


if __name__ == "__main__":
    main()
