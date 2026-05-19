#!/usr/bin/env python3
"""AI-PASS A1–A5: archive C1 CSV, verify splits, print inventory."""
from __future__ import annotations

import argparse
import json
import shutil
from datetime import date
from pathlib import Path

import pandas as pd

DEFAULT_CSV = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_EURUSD_M5.csv"
)
ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data" / "c1"
MANIFEST = DATA_DIR / "manifest.json"
EXCLUDE_EXITS = frozenset({"e10"})


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def load_trades(csv: Path, dedupe: bool = True) -> pd.DataFrame:
    df = pd.read_csv(csv)
    df["entry_time"] = pd.to_datetime(df["entry_time"])
    df = df[~df["exit_type"].isin(EXCLUDE_EXITS)].copy()
    if dedupe:
        n_before = len(df)
        df = df.drop_duplicates(subset=["entry_time", "side"], keep="last")
        if len(df) < n_before:
            print(f"Deduped: {n_before} -> {len(df)} rows (drop duplicate entry_time+side)")
    return df


def split_counts(df: pd.DataFrame, train_end: str, val_end: str) -> dict:
    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]
    return {"train": len(train), "val": len(val), "test": len(test)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--archive", action="store_true", help="Copy CSV into data/c1/")
    ap.add_argument("--tag", default=None, help="Archive suffix YYYYMMDD (default today)")
    ap.add_argument(
        "--write-clean",
        action="store_true",
        help="Overwrite source CSV with deduped production-path rows",
    )
    args = ap.parse_args()

    src = Path(args.csv)
    if not src.is_file():
        raise SystemExit(f"CSV not found: {src}")

    m = load_manifest()
    splits = m["splits"]
    oos = m["oos_pass_window"]

    df = load_trades(src)
    sc = split_counts(df, splits["train_end"], splits["val_end"])
    oos_df = df[
        (df["entry_time"] >= oos["start"]) & (df["entry_time"] < oos["end"])
    ]

    e10_check = "e10" in pd.read_csv(src)["exit_type"].astype(str).values
    lines = [
        "# AI-PASS A1–A5 inventory",
        "",
        f"**Source:** `{src}`",
        f"**Rows (production-path):** {len(df)}",
        f"**Net $ (all):** {df['profit'].astype(float).sum():.2f}",
        f"**e10 present:** {'yes — NOT clean' if e10_check else 'no — OK'}",
        "",
        "## Splits (from `data/c1/manifest.json`)",
        "",
        f"- train <= `{splits['train_end']}` -> **{sc['train']}** trades",
        f"- val through `{splits['val_end']}` -> **{sc['val']}** trades",
        f"- test after val_end -> **{sc['test']}** trades",
        f"- OOS pass window `{oos['start']}` -> `{oos['end']}` -> **{len(oos_df)}** tr / "
        f"${oos_df['profit'].astype(float).sum():.2f}",
        "",
        "## A1-A5 status",
        "",
        f"- **A1** clean CSV: {'PASS' if not e10_check else 'FAIL'}",
        f"- **A2** size {m['a2_target']['min_trades']}-{m['a2_target']['max_trades']}: "
        f"**{m['a2_target']['status'].upper()}** ({len(df)} / {m['a2_target']['min_trades']})",
        f"- **A3** archive: `data/c1/{m['archived_csv']}`",
        f"- **A4** splits: `data/c1/manifest.json`",
        f"- **A5** val >= 50: {'PASS' if sc['val'] >= 50 else 'FAIL'} ({sc['val']} trades)",
        "",
    ]

    out_md = ROOT / "step-ai-pass-a-data.md"
    text = "\n".join(lines)
    out_md.write_text(text, encoding="utf-8")
    print(text.encode("ascii", errors="replace").decode("ascii"))

    if args.write_clean:
        df.sort_values("entry_time").to_csv(src, index=False)
        print(f"Wrote deduped {len(df)} rows -> {src}")

    if args.archive:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        tag = args.tag or date.today().strftime("%Y%m%d")
        name = m.get("archived_csv") or f"VEM_trades_EURUSD_M5_prod_{tag}.csv"
        dest = DATA_DIR / name
        df.sort_values("entry_time").to_csv(dest, index=False)
        m["archived_csv"] = name
        m["counts"]["total"] = len(df)
        oos_df = df[
            (df["entry_time"] >= oos["start"]) & (df["entry_time"] < oos["end"])
        ]
        m["counts"]["oos_2025_2026"] = len(oos_df)
        m["counts"]["oos_net_usd"] = round(float(oos_df["profit"].sum()), 2)
        m["counts"]["full_span_net_usd"] = round(float(df["profit"].sum()), 2)
        MANIFEST.write_text(json.dumps(m, indent=2), encoding="utf-8")
        print(f"Archived -> {dest}")


if __name__ == "__main__":
    main()
