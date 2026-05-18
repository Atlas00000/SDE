#!/usr/bin/env python3
"""Analyze VEM C1 trade log CSV — winner/loser MAE/MFE at bars 5–6 for E10 thresholds."""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

DEFAULT_CSV = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_EURUSD_M5.csv"
)
OUT_MD = Path(__file__).resolve().parent.parent / "step-c1-results.md"


def pct(arr, q):
    a = np.array([x for x in arr if np.isfinite(x)], dtype=float)
    if len(a) == 0:
        return 0.0
    return float(np.percentile(a, q))


def summarize_group(df: pd.DataFrame, label: str) -> list[str]:
    lines = [f"### {label} (n={len(df)})", ""]
    if df.empty:
        lines.append("_No rows._\n")
        return lines

    cols = [
        ("mae_r", "MAE (R) final"),
        ("mfe_r", "MFE (R) final"),
        ("mae_r_b5", "MAE @ bar 5"),
        ("mfe_r_b5", "MFE @ bar 5"),
        ("mae_r_b6", "MAE @ bar 6"),
        ("mfe_r_b6", "MFE @ bar 6"),
    ]
    lines.append("| Metric | Median | 75th % |")
    lines.append("|--------|--------|--------|")
    for col, name in cols:
        if col not in df.columns:
            continue
        s = pd.to_numeric(df[col], errors="coerce").replace(-1, np.nan)
        lines.append(f"| {name} | {s.median():.3f} | {pct(s, 75):.3f} |")
    lines.append("")
    if "profit" in df.columns:
        lines.append(f"- Net P/L sum: **${df['profit'].astype(float).sum():.2f}**")
        lines.append(f"- Win rate: **{(df['profit'].astype(float) > 0).mean() * 100:.1f}%**")
    if "exit_type" in df.columns:
        lines.append(f"- Exit mix: `{df['exit_type'].value_counts().to_dict()}`")
    lines.append("")
    return lines


def e10_grid(df: pd.DataFrame) -> list[str]:
    lines = ["## E10 rule sweep (in-sample on this CSV)", ""]
    if df.empty:
        return lines

    mae_b = pd.to_numeric(df["mae_r_b6"], errors="coerce").replace(-1, np.nan)
    mfe_b = pd.to_numeric(df["mfe_r_b6"], errors="coerce").replace(-1, np.nan)
    profit = pd.to_numeric(df["profit"], errors="coerce")
    ok = mae_b.notna() & mfe_b.notna()

    lines.append("| MFE max | MAE min | Would cut | Cut WR | Cut avg $ | Kept WR | Kept n |")
    lines.append("|--------|---------|-----------|--------|-----------|---------|--------|")
    for mfe_max in (0.15, 0.20, 0.25):
        for mae_min in (0.45, 0.50, 0.55):
            cut = ok & (mfe_b <= mfe_max) & (mae_b >= mae_min)
            kept = ok & ~cut
            if cut.sum() == 0:
                continue
            cut_wr = (profit[cut] > 0).mean() * 100 if cut.any() else 0
            kept_wr = (profit[kept] > 0).mean() * 100 if kept.any() else 0
            lines.append(
                f"| {mfe_max:.2f} | {mae_min:.2f} | {int(cut.sum())} | "
                f"{cut_wr:.0f}% | {profit[cut].mean():.2f} | {kept_wr:.0f}% | {int(kept.sum())} |"
            )
    lines.append("")
    lines.append(
        "_Goal: high cut count among losers, cut WR low, kept WR ≥ ~65%._\n"
    )
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--out", default=str(OUT_MD))
    args = ap.parse_args()

    path = Path(args.csv)
    if not path.is_file():
        raise SystemExit(f"CSV not found: {path}\nRun D7 backtest with inp_trade_log_enable=true first.")

    df = pd.read_csv(path)
    for c in df.columns:
        if c.endswith("_r") or c.endswith("_b5") or c.endswith("_b6") or c in ("profit",):
            df[c] = pd.to_numeric(df[c], errors="coerce")

    wins = df[df["profit"] > 0]
    loss = df[df["profit"] <= 0]

    lines = [
        "# Step C1 — Trade log analysis",
        "",
        f"**Source:** `{path}`",
        f"**Trades:** {len(df)}",
        "",
    ]
    lines += summarize_group(wins, "Winners")
    lines += summarize_group(loss, "Losers")
    lines += e10_grid(df)

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")
    print(f"Trades: {len(df)} | Winners: {len(wins)} | Losers: {len(loss)}")


if __name__ == "__main__":
    main()
