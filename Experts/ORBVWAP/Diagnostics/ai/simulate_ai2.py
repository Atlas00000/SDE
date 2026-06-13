#!/usr/bin/env python3
"""Offline simulation: AI-2 sizing on full 6y + deploy-stack projection."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from policy import (
    ai1_tau,
    apply_ai1_filter,
    apply_ai2_sizing,
    calibrate_size_thresholds,
    executed_mask,
    prepare_features,
    score_executed_trades,
    sized_trade_metrics,
    DEFAULT_SIZE_TIERS,
)
from regime_model import DEFAULT_AI3, add_session_allow, load_config
from sessions import build_sessions
from train_eval import trade_metrics

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"


def fmt(m: dict, label: str) -> None:
    print(
        f"{label}: n={m['n']} PF={m['pf']:.2f} WR={m['wr']:.1f}% "
        f"net={m['net']:.2f} DD={m['max_dd']:.2f} payoff={m.get('payoff', 0):.2f}"
    )


def main() -> None:
    raw = pd.read_parquet(DEFAULT_DATASET)
    trades = prepare_features(raw.loc[executed_mask(raw)].copy())

    scored_train, scored_holdout, split = score_executed_trades(holdout_frac=0.3)
    all_scored = pd.concat([scored_train, scored_holdout]).sort_values("bar_time_gmt")
    tau = ai1_tau()
    p50, p80 = calibrate_size_thresholds(scored_train, tau)

    cfg = load_config(DEFAULT_AI3)
    sessions = add_session_allow(build_sessions(), cfg)
    all_scored["sess_key"] = all_scored["bar_time_gmt"].dt.date.astype(str) + "_" + all_scored["session"]
    merged = all_scored.merge(sessions[["sess_key", "session_allow"]], on="sess_key", how="left")
    merged["session_allow"] = merged["session_allow"].fillna(True)

    prod = trade_metrics(all_scored)
    ai1 = trade_metrics(apply_ai1_filter(all_scored, tau))
    ai12 = sized_trade_metrics(apply_ai2_sizing(apply_ai1_filter(all_scored, tau), p50, p80))
    ai31 = trade_metrics(apply_ai1_filter(merged.loc[merged["session_allow"]], tau))
    ai312_df = apply_ai2_sizing(
        apply_ai1_filter(merged.loc[merged["session_allow"]], tau), p50, p80
    )
    ai312 = sized_trade_metrics(ai312_df)

    print("=== FULL 6y OFFLINE SIMULATION ===")
    print(f"tau={tau:.2f} p50={p50:.3f} p80={p80:.3f} tiers={DEFAULT_SIZE_TIERS}")
    fmt(prod, "PROD")
    fmt(ai1, "AI-1 only")
    fmt(ai12, "AI-1+AI-2")
    print()
    fmt(ai31, "AI-3+AI-1 (deploy base)")
    fmt(ai312, "AI-3+AI-1+AI-2 (deploy + sizing)")

    ho = merged[merged["bar_time_gmt"] >= split.cut_time]
    ho31 = trade_metrics(apply_ai1_filter(ho.loc[ho["session_allow"]], tau))
    ho312 = sized_trade_metrics(
        apply_ai2_sizing(apply_ai1_filter(ho.loc[ho["session_allow"]], tau), p50, p80)
    )
    print()
    print("=== HOLDOUT ===")
    fmt(ho31, "AI-3+AI-1")
    fmt(ho312, "AI-3+AI-1+AI-2")

    ai312_df["sized_pnl"] = ai312_df["profit"].astype(float) * ai312_df["size_mult"]
    print()
    print("=== BUCKET CONTRIBUTION (deploy stack, full 6y) ===")
    for mult in DEFAULT_SIZE_TIERS:
        b = ai312_df[ai312_df["size_mult"] == mult]
        net = float(b["sized_pnl"].sum())
        wr = float(100.0 * (b["label_win"] == 1).mean()) if len(b) else 0.0
        print(f"  {mult}x: n={len(b)} net={net:.2f} WR={wr:.1f}%")

    print()
    print("=== PRODUCTION SAFETY (AI-3+AI-1+AI-2 full 6y) ===")
    checks = [
        ("PF >= 1.0", ai312["pf"] >= 1.0),
        ("PF >= PROD*0.95", ai312["pf"] >= prod["pf"] * 0.95),
        ("PF >= (AI-3+AI-1)*0.98", ai312["pf"] >= ai31["pf"] * 0.98),
        ("Net > AI-3+AI-1", ai312["net"] > ai31["net"]),
        ("Net > PROD", ai312["net"] > prod["net"]),
        ("DD <= PROD", ai312["max_dd"] <= prod["max_dd"]),
        ("DD <= (AI-3+AI-1)*1.15", ai312["max_dd"] <= ai31["max_dd"] * 1.15),
    ]
    for name, ok in checks:
        print(f"  {'PASS' if ok else 'FAIL'}: {name}")

    mt5_net = 46.33
    uplift = ai312["net"] / ai31["net"] if ai31["net"] else 1.0
    proj_net = mt5_net * uplift
    print()
    print("=== MT5 PROJECTION (AI1234 base: $46.33 net, 315 trades, fixed 0.01 lot) ===")
    print(f"  Offline stack net uplift from AI-2: {100 * (uplift - 1):+.1f}%")
    print(f"  Projected net with AI-2 LIVE: ${proj_net:.2f} (+${proj_net - mt5_net:.2f})")
    print("  Assumes same 315 trades; P/L scales linearly with lot multiplier.")


if __name__ == "__main__":
    main()
