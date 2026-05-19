#!/usr/bin/env python3
"""P4-3 — export bar-5/6 path features + exit labels from C1 archive (no entry-only leakage)."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
OUT_CSV = ROOT / "data" / "c1" / "ai_v3_bar_matrix.csv"
OUT_MD = ROOT / "step-ai-v3-bar-matrix.md"

ENTRY_FEATURES = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
]
PATH_B5 = ["mae_r_b5", "mfe_r_b5"]
PATH_B6 = ["mae_r_b6", "mfe_r_b6"]


def clean_r(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").replace(-1, np.nan)


def label_invalid(df: pd.DataFrame, mae_thresh: float = 0.5) -> pd.Series:
    """Outcome label for trades that should not be held (matches P4-3 charter)."""
    exit_t = df["exit_type"].astype(str)
    mae = clean_r(df["mae_r"]).fillna(0.0)
    profit = df["profit"].astype(float)
    sl = exit_t == "sl"
    e8c_bad = (exit_t == "e8c") & (mae >= mae_thresh)
    deep_loss = (profit <= 0) & (mae >= mae_thresh)
    return (sl | e8c_bad | deep_loss).astype(int)


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["entry_time"] = pd.to_datetime(d["entry_time"], utc=True)
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    rsi = d["rsi"].astype(float)
    d["rsi_depth"] = np.where(
        d["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    for c in PATH_B5 + PATH_B6 + ["mae_r", "mfe_r"]:
        d[c] = clean_r(d[c])
    d["mae_delta_b5_b6"] = d["mae_r_b6"] - d["mae_r_b5"]
    d["mfe_delta_b5_b6"] = d["mfe_r_b6"] - d["mfe_r_b5"]
    d["label_invalid"] = label_invalid(d)
    d["label_bad_trade"] = d["label_invalid"]  # alias for v1 scripts
    d["profit"] = d["profit"].astype(float)
    return d


def split_tag(entry_time: pd.Series, train_end: str, val_end: str) -> pd.Series:
    t = entry_time.dt.strftime("%Y-%m-%d")
    return np.where(
        t <= train_end,
        "train",
        np.where(t <= val_end, "val", "test"),
    )


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    train_end = manifest["splits"]["train_end"]
    val_end = manifest["splits"]["val_end"]

    raw = pd.read_csv(ARCHIVE)
    df = prepare(raw)
    df = df[df["exit_type"].astype(str) != "e10"].copy()
    df["split"] = split_tag(df["entry_time"], train_end, val_end)

    feature_cols = (
        ENTRY_FEATURES
        + ["side_sell", "rsi_depth"]
        + PATH_B5
        + PATH_B6
        + ["mae_delta_b5_b6", "mfe_delta_b5_b6"]
    )
    out_cols = ["entry_time", "split", "profit", "exit_type", "label_invalid"] + feature_cols
    out = df[out_cols].dropna(subset=PATH_B6)
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_CSV, index=False)

    lines = [
        "# AI v0.3 — bar path matrix (P4-3)",
        "",
        f"**Source:** `{ARCHIVE.name}` · **rows:** {len(out)} (after drop NaN b6 path)",
        "",
        "## Splits",
        "",
        f"- train ≤ {train_end} · val ≤ {val_end} · test OOS after",
        "",
        "| split | n | invalid % |",
        "|-------|--:|----------:|",
    ]
    for sp in ("train", "val", "test"):
        sub = out[out["split"] == sp]
        pct = 100.0 * sub["label_invalid"].mean() if len(sub) else 0.0
        lines.append(f"| {sp} | {len(sub)} | {pct:.1f} |")

    lines += [
        "",
        f"**Export:** `{OUT_CSV.relative_to(ROOT)}`",
        "",
        "Next: `scripts/train_ai_v3_exit.py`",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_CSV} {OUT_MD} rows={len(out)}")


if __name__ == "__main__":
    main()
