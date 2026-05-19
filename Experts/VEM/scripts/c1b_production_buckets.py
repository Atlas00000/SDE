#!/usr/bin/env python3
"""C1b — bucket production-path losers for Phase 3 / DEV-G."""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

DEFAULT_CSV = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_EURUSD_M5.csv"
)
OUT_MD = Path(__file__).resolve().parent.parent / "step-c1b-results.md"

EXCLUDE_EXITS = frozenset({"e10"})  # non-production exit experiments


def pf(profits: pd.Series) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def bucket_table(df: pd.DataFrame, col: str, label: str) -> list[str]:
    lines = [f"### {label}", "", "| Bucket | n | Net $ | PF | WR% | SL | midline |", "|--------|---:|------:|---:|----:|---:|--------:|"]
    if df.empty or col not in df.columns:
        lines.append("| _empty_ | 0 | — | — | — | — | — |")
        lines.append("")
        return lines

    for key, g in df.groupby(col, dropna=False):
        p = g["profit"].astype(float)
        sl = (g["exit_type"] == "sl").sum()
        mid = (g["exit_type"] == "midline").sum()
        lines.append(
            f"| {key} | {len(g)} | {p.sum():.2f} | {pf(p):.2f} | "
            f"{(p > 0).mean() * 100:.1f} | {sl} | {mid} |"
        )
    lines.append("")
    return lines


def loser_focus(df: pd.DataFrame) -> list[str]:
    loss = df[df["profit"].astype(float) <= 0].copy()
    lines = [
        "## Loser-only buckets (profit ≤ 0)",
        "",
        f"**Losers:** {len(loss)} / {len(df)} ({100 * len(loss) / max(len(df), 1):.1f}%)",
        f"**Loser net:** ${loss['profit'].astype(float).sum():.2f}",
        "",
    ]
    if loss.empty:
        lines.append("_No losers._\n")
        return lines

    loss["bb_tercile"] = pd.qcut(
        loss["bb_width_ratio"].astype(float), 3, labels=["low", "mid", "high"], duplicates="drop"
    )
    loss["rsi_bucket"] = pd.cut(
        loss["rsi"].astype(float),
        bins=[0, 20, 25, 30, 70, 75, 80, 100],
        labels=["≤20", "20-25", "25-30", "30-70", "70-75", "75-80", ">80"],
    )
    loss["bars_bucket"] = pd.cut(
        loss["bars_held"].astype(float),
        bins=[0, 4, 8, 12, 999],
        labels=["1-4", "5-8", "9-12", "13+"],
    )

    lines += bucket_table(loss, "entry_hour", "Hour (server)")
    lines += bucket_table(loss, "bb_tercile", "BB width tercile (losers)")
    lines += bucket_table(loss, "rsi_bucket", "RSI bucket")
    lines += bucket_table(loss, "exit_type", "Exit type")
    lines += bucket_table(loss, "bars_bucket", "Bars held")
    lines += bucket_table(loss, "side", "Side")

    # Promotion candidates: n≥30 and PF<1 on subset — here losers only so flag toxic hours
    lines.append("## Promotion gate (≥30 trades in bucket, PF < 1 on **all** trades in bucket)")
    lines.append("")
    for col, label in [("entry_hour", "hour"), ("bb_tercile", "bb_tercile"), ("exit_type", "exit")]:
        if col not in df.columns:
            continue
        for key, g in df.groupby(col):
            if len(g) < 30:
                continue
            p = g["profit"].astype(float)
            if pf(p) < 1.0:
                lines.append(f"- **{label}={key}**: n={len(g)}, net=${p.sum():.2f}, PF={pf(p):.2f}")
    lines.append("")
    return lines


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--out", default=str(OUT_MD))
    ap.add_argument("--oos-start", default="2025-01-01")
    ap.add_argument("--oos-end", default="2026-05-16")
    args = ap.parse_args()

    path = Path(args.csv)
    if not path.is_file():
        raise SystemExit(f"CSV not found: {path}")

    raw = pd.read_csv(path)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    prod = raw[~raw["exit_type"].isin(EXCLUDE_EXITS)].copy()

    oos = prod[(prod["entry_time"] >= args.oos_start) & (prod["entry_time"] < args.oos_end)]
    is_df = prod[prod["entry_time"] < args.oos_start]

    lines = [
        "# C1b — Production path re-bucket",
        "",
        f"**Source:** `{path}`",
        f"**Filter:** exclude exit types `{sorted(EXCLUDE_EXITS)}` (non-production experiments)",
        "",
        "## Dataset inventory",
        "",
        f"| Slice | Trades | Net $ | PF | WR% | SL | e8c |",
        f"|-------|-------:|------:|---:|----:|---:|----:|",
    ]
    for name, d in [("All production-path", prod), ("IS (<2025)", is_df), ("OOS 2025–2026", oos)]:
        p = d["profit"].astype(float)
        lines.append(
            f"| {name} | {len(d)} | {p.sum():.2f} | {pf(p):.2f} | {(p > 0).mean() * 100:.1f} | "
            f"{(d['exit_type'] == 'sl').sum()} | {(d['exit_type'] == 'e8c').sum()} |"
        )
    lines.append("")
    lines.append(
        "> **Note:** Mixed tester runs may be appended in one CSV. For **AI-1 canonical** data, "
        "re-run a **single** backtest with `vem5m_d7_c1_trade_log.set` and archive the file by date."
    )
    lines.append("")
    lines.append("## Full sample (production-path)")
    lines.append("")
    lines += bucket_table(prod, "entry_hour", "Hour — all trades")
    lines += loser_focus(prod)
    lines.append("## OOS window (2025–2026)")
    lines.append("")
    lines += bucket_table(oos, "entry_hour", "Hour — OOS")
    lines += loser_focus(oos)

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out} ({len(prod)} production-path trades)")


if __name__ == "__main__":
    main()
