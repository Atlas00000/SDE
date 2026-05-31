#!/usr/bin/env python3
"""C2 — Trade Logger v2 utilities (validate · archive · report · labels).

Typical workflow
----------------
1. Compile VEM.mq5 · load preset VEM.C2_Production in Strategy Tester
2. Run production backtest (2023-01-01 → 2026-05-28) — delete old v2 CSV first
3. python scripts/c2_trade_log.py validate
4. python scripts/c2_trade_log.py archive --tag YYYYMMDD
5. python scripts/c2_trade_log.py report
6. python scripts/c2_trade_log.py labels  # B7 offline labels on archive
"""
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data" / "c2"
MANIFEST = DATA_DIR / "manifest.json"
DEFAULT_V2 = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_v2_EURUSD_M5.csv"
)

C2_REQUIRED = {
    "log_schema",
    "trade_id",
    "entry_time",
    "exit_time",
    "symbol",
    "side",
    "profit",
    "exit_type",
    "rsi_depth",
    "bb_walk_count",
    "wick_pct",
    "ema_slope_bp",
    "atr_ratio",
    "bb_pen_pts",
    "htf_slope_bp",
    "mae_r_b4",
    "mfe_r_b4",
    "mae_r_b5",
    "mfe_r_b5",
    "mae_r_b6",
    "mfe_r_b6",
}

PATH_COLS = ["mae_r", "mfe_r", "mae_r_b4", "mfe_r_b4", "mae_r_b5", "mfe_r_b5", "mae_r_b6", "mfe_r_b6"]
EXCLUDE_EXITS = frozenset({"e10"})


def clean_r(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").replace(-1, np.nan)


def load_v2(csv: Path, dedupe: bool = True) -> pd.DataFrame:
    df = pd.read_csv(csv)
    if "log_schema" in df.columns:
        bad = df["log_schema"].astype(str) != "2"
        if bad.any():
            raise SystemExit(f"Not a C2 file: {bad.sum()} rows with log_schema != 2")
    missing = C2_REQUIRED - set(df.columns)
    if missing:
        raise SystemExit(f"Missing C2 columns: {sorted(missing)}")

    df["entry_time"] = pd.to_datetime(df["entry_time"])
    df = df[~df["exit_type"].astype(str).isin(EXCLUDE_EXITS)].copy()
    for c in PATH_COLS:
        if c in df.columns:
            df[c] = clean_r(df[c])
    if dedupe:
        n0 = len(df)
        df = df.drop_duplicates(subset=["entry_time", "side"], keep="last")
        if len(df) < n0:
            print(f"Deduped: {n0} -> {len(df)}")
    return df


def cmd_validate(args: argparse.Namespace) -> None:
    path = Path(args.csv)
    if not path.is_file():
        raise SystemExit(f"Not found: {path}\nRun tester with VEM.C2_Production first.")
    df = load_v2(path, dedupe=False)
    empty_b4 = df["mae_r_b4"].isna().mean() * 100 if "mae_r_b4" in df.columns else 100.0
    print(f"OK C2 schema · rows={len(df)} · missing bar-4 snap={empty_b4:.1f}%")
    if len(df) < 50:
        print("WARN: fewer than 50 trades — extend backtest window")


def split_counts(df: pd.DataFrame, train_end: str, val_end: str) -> dict[str, int]:
    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]
    return {"train": len(train), "val": len(val), "test": len(test)}


def resolve_archived_csv(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    m = load_manifest()
    if m.get("archived_csv"):
        p = DATA_DIR / m["archived_csv"]
        if p.is_file():
            return p
    return Path(DEFAULT_V2)


def load_manifest() -> dict:
    if MANIFEST.is_file():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    # inherit splits from C1 if present
    c1 = ROOT / "data" / "c1" / "manifest.json"
    base = json.loads(c1.read_text(encoding="utf-8")) if c1.is_file() else {}
    return {
        "log_schema": 2,
        "rules_version": "VEM.C2_Production",
        "splits": base.get("splits", {"train_end": "2023-12-31", "val_end": "2024-12-31"}),
        "oos_pass_window": base.get(
            "oos_pass_window",
            {"start": "2025-01-01", "end": "2026-05-15"},
        ),
        "counts": {},
    }


def cmd_archive(args: argparse.Namespace) -> None:
    src = Path(args.csv)
    df = load_v2(src)
    if getattr(args, "from_date", None):
        cutoff = pd.Timestamp(args.from_date)
        n0 = len(df)
        df = df[df["entry_time"] >= cutoff].copy()
        print(f"Filtered >= {args.from_date}: {n0} -> {len(df)} rows")
    m = load_manifest()
    splits = m["splits"]
    oos = m["oos_pass_window"]
    sc = split_counts(df, splits["train_end"], splits["val_end"])
    oos_df = df[
        (df["entry_time"] >= oos["start"]) & (df["entry_time"] < oos["end"])
    ]

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tag = args.tag or date.today().strftime("%Y%m%d")
    name = args.name or f"VEM_trades_v2_EURUSD_M5_prod_{tag}.csv"
    dest = DATA_DIR / name
    df.sort_values("entry_time").to_csv(dest, index=False)

    m["archived_csv"] = name
    m["counts"] = {
        "total": len(df),
        "oos_2025_2026": len(oos_df),
        "oos_net_usd": round(float(oos_df["profit"].sum()), 2),
        "full_span_net_usd": round(float(df["profit"].sum()), 2),
        "splits": sc,
    }
    m["c2_status"] = "archived"
    if getattr(args, "from_date", None):
        m["entry_filter_from"] = args.from_date
    MANIFEST.write_text(json.dumps(m, indent=2), encoding="utf-8")
    print(f"Archived {len(df)} rows -> {dest}")
    print(f"OOS {len(oos_df)} tr · ${m['counts']['oos_net_usd']:.2f}")


def cmd_labels(args: argparse.Namespace) -> None:
    """Delegate to B7 module (full multi-label + QA)."""
    import subprocess
    import sys

    cmd = [sys.executable, str(ROOT / "scripts" / "c2_labels_b7.py")]
    if args.csv:
        cmd += ["--csv", str(args.csv)]
    if args.out:
        cmd += ["--out", str(args.out)]
    raise SystemExit(subprocess.call(cmd))


def cmd_report(args: argparse.Namespace) -> None:
    path = resolve_archived_csv(args.csv)
    df = load_v2(path)
    wins = df[df["profit"].astype(float) > 0]
    loss = df[df["profit"].astype(float) <= 0]

    lines = [
        "# C2 — Trade log report",
        "",
        f"**Source:** `{path}`",
        f"**Trades:** {len(df)}",
        "",
        "## Structure @ entry (medians)",
        "",
        "| Feature | All | Winners | Losers |",
        "|---------|-----|---------|--------|",
    ]
    for col in ["rsi_depth", "bb_walk_count", "wick_pct", "ema_slope_bp", "atr_ratio", "bb_pen_pts"]:
        if col not in df.columns:
            continue
        s = pd.to_numeric(df[col], errors="coerce")
        lines.append(
            f"| {col} | {s.median():.3f} | "
            f"{pd.to_numeric(wins[col], errors='coerce').median():.3f} | "
            f"{pd.to_numeric(loss[col], errors='coerce').median():.3f} |"
        )
    lines += [
        "",
        "## Path snapshots (median R)",
        "",
        "| Metric | Winners | Losers |",
        "|--------|---------|--------|",
    ]
    for col, name in [
        ("mfe_r_b4", "MFE @ bar 4"),
        ("mae_r_b4", "MAE @ bar 4"),
        ("mfe_r_b6", "MFE @ bar 6"),
        ("mae_r_b6", "MAE @ bar 6"),
    ]:
        if col not in df.columns:
            continue
        w = clean_r(wins[col]).median()
        l = clean_r(loss[col]).median()
        lines.append(f"| {name} | {w:.3f} | {l:.3f} |")

    lines += [
        "",
        f"- Net: **${df['profit'].astype(float).sum():.2f}** · WR **{(df['profit'].astype(float) > 0).mean()*100:.1f}%**",
        f"- Exits: `{df['exit_type'].value_counts().to_dict()}`",
        "",
    ]

    out = Path(args.out) if args.out else ROOT / "step-c2-report.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")


def main() -> None:
    ap = argparse.ArgumentParser(description="C2 trade log utilities")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_val = sub.add_parser("validate", help="Check C2 CSV schema")
    p_val.add_argument("--csv", default=DEFAULT_V2)

    p_arc = sub.add_parser("archive", help="Copy to data/c2/ and update manifest")
    p_arc.add_argument("--csv", default=DEFAULT_V2)
    p_arc.add_argument("--tag", default=None)
    p_arc.add_argument("--name", default=None)
    p_arc.add_argument(
        "--from-date",
        default="2023-01-01",
        help="Keep trades on/after this date (default 2023-01-01 production window)",
    )

    p_rep = sub.add_parser("report", help="Markdown summary")
    p_rep.add_argument("--csv", default=None, help="Default: data/c2 archived CSV")
    p_rep.add_argument("--out", default=None)

    p_lab = sub.add_parser("labels", help="Apply B7 labels + QA (runs c2_labels_b7.py)")
    p_lab.add_argument("--csv", default=None, help="Default: data/c2 archived CSV")
    p_lab.add_argument("--out", default=None)

    args = ap.parse_args()
    if args.cmd == "validate":
        cmd_validate(args)
    elif args.cmd == "archive":
        cmd_archive(args)
    elif args.cmd == "report":
        cmd_report(args)
    elif args.cmd == "labels":
        cmd_labels(args)


if __name__ == "__main__":
    main()
