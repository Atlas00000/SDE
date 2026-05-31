#!/usr/bin/env python3
"""P4-2 shadow validation: MT5 shadow CSV vs Python tail + bad models."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SHADOW_DEFAULT = (
    Path.home()
    / "AppData/Roaming/MetaQuotes/Terminal/Common/Files/VEM_ai_shadow_EURUSD_M5.csv"
)
BAD_JSON = ROOT / "models" / "ai_v1_logistic_bad_trade.json"
TAIL_JSON = ROOT / "models" / "ai_tail_logistic.json"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
OUT_MD = ROOT / "step-p4-2-tail-shadow.md"


def sigmoid(z: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(z, -30, 30)))


def score_rows(df: pd.DataFrame, model: dict) -> np.ndarray:
    z = np.full(len(df), model["intercept"], dtype=float)
    for f in model["features"]:
        x = df[f].astype(float).values
        m, s = model["scaler_mean"][f], model["scaler_scale"][f]
        z += model["coef"][f] * ((x - m) / s if s > 0 else 0.0)
    return sigmoid(z)


def prepare_shadow(sh: pd.DataFrame) -> pd.DataFrame:
    d = sh.copy()
    d["signal_time"] = pd.to_datetime(d["signal_time"])
    d["side_sell"] = (d["side"].str.lower() == "sell").astype(int)
    rsi = d["rsi"].astype(float)
    d["rsi_depth"] = np.where(
        d["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    return d


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shadow", default=str(SHADOW_DEFAULT))
    ap.add_argument("--out", default=str(OUT_MD))
    args = ap.parse_args()

    sh = pd.read_csv(args.shadow)
    d = prepare_shadow(sh)
    bad_m = json.loads(BAD_JSON.read_text(encoding="utf-8"))
    tail_m = json.loads(TAIL_JSON.read_text(encoding="utf-8"))

    d["py_bad"] = score_rows(d, bad_m)
    d["py_tail"] = score_rows(d, tail_m)

    bad_mae = (d["ai_score"].astype(float) - d["py_bad"]).abs().max()
    tail_col = "tail_score" if "tail_score" in d.columns else None
    tail_mae = float("nan")
    if tail_col:
        tail_mae = (d[tail_col].astype(float) - d["py_tail"]).abs().max()

    lines = [
        "# P4-2 — Tail shadow parity",
        "",
        f"**Rows:** {len(d)}",
        f"**Bad score max |Δ|:** {bad_mae:.6f}",
        f"**Tail score max |Δ|:** {tail_mae:.6f}" if tail_col else "**Tail score:** column missing (re-run with new shadow header)",
        "",
    ]
    if tail_col and "would_skip_tail" in d.columns:
        wt = d["would_skip_tail"].astype(int)
        py_wt = (d["py_tail"] >= tail_m["skip_prob_threshold"]).astype(int)
        lines += [
            f"**would_skip_tail match:** {(wt == py_wt).mean()*100:.1f}%",
            "",
        ]
    Path(args.out).write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {args.out} bad_mae={bad_mae:.6f} tail_mae={tail_mae}")


if __name__ == "__main__":
    main()
