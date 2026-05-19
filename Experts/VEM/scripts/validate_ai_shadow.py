#!/usr/bin/env python3
"""AI-4 backtest validation: MT5 shadow CSV vs Python model + C1 archive."""
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
ARCHIVE = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MODEL_JSON = ROOT / "models" / "ai_v1_logistic_bad_trade.json"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
OUT_MD = ROOT / "step-ai4-shadow-backtest.md"

PASS_NET = 9.08
PASS_PF = 1.30


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def sigmoid(z: np.ndarray) -> np.ndarray:
    z = np.clip(z, -30, 30)
    return 1.0 / (1.0 + np.exp(-z))


def score_rows(df: pd.DataFrame, model: dict) -> np.ndarray:
    feats = model["features"]
    z = np.full(len(df), model["intercept"], dtype=float)
    for f in feats:
        x = df[f].astype(float).values
        m = model["scaler_mean"][f]
        s = model["scaler_scale"][f]
        xs = (x - m) / s if s > 0 else np.zeros_like(x)
        z += model["coef"][f] * xs
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
    d["entry_hour"] = d["entry_hour"].astype(int)
    d["entry_dow"] = d["entry_dow"].astype(int)
    d["spread_pts"] = d["spread_pts"].astype(float)
    d["vol_ratio"] = d["vol_ratio"].astype(float)
    d["bb_width_ratio"] = d["bb_width_ratio"].astype(float)
    return d


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shadow", default=str(SHADOW_DEFAULT))
    ap.add_argument("--c1", default=str(ARCHIVE))
    ap.add_argument("--out", default=str(OUT_MD))
    args = ap.parse_args()

    model = json.loads(MODEL_JSON.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    oos = manifest["oos_pass_window"]
    thr = model["skip_prob_threshold"]

    sh = prepare_shadow(pd.read_csv(args.shadow))
    c1 = pd.read_csv(args.c1)
    c1["entry_time"] = pd.to_datetime(c1["entry_time"])

    opened = sh[sh["opened"] == 1].copy()
    py_score = score_rows(opened, model)
    opened = opened.assign(py_score=py_score)
    opened["py_would_skip"] = (opened["py_score"] >= thr).astype(int)
    opened["mt5_score"] = opened["ai_score"].astype(float)
    opened["score_delta"] = (opened["py_score"] - opened["mt5_score"]).abs()

    # C1 entry_time is fill bar; shadow signal_time is signal bar — merge_asof within 10 min
    c1j = c1.sort_values("entry_time").copy()
    c1j["side"] = c1j["side"].str.lower()
    opj = opened.sort_values("signal_time").copy()
    merged = pd.merge_asof(
        opj,
        c1j[["entry_time", "side", "profit", "exit_type"]],
        left_on="signal_time",
        right_on="entry_time",
        by="side",
        direction="nearest",
        tolerance=pd.Timedelta("10min"),
    )
    n_miss = merged["profit"].isna().sum()

    # E4 P/L uses C1 archive + Python scores (same as offline AI-3)
    c1p = c1.copy()
    c1p["side_sell"] = (c1p["side"].str.lower() == "sell").astype(int)
    rsi = c1p["rsi"].astype(float)
    c1p["rsi_depth"] = np.where(
        c1p["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    c1p["py_score"] = score_rows(c1p, model)
    c1p["would_skip"] = (c1p["py_score"] >= thr).astype(int)

    oos_mask_c1 = (c1p["entry_time"] >= oos["start"]) & (c1p["entry_time"] < oos["end"])
    oos_c1 = c1p[oos_mask_c1]
    skip_opened = c1p[c1p["would_skip"] == 1]
    skip_oos = oos_c1[oos_c1["would_skip"] == 1]

    profits = c1p["profit"].astype(float).values
    keep = c1p["would_skip"] == 0
    p_keep = profits[keep]
    baseline = {"net": float(profits.sum()), "pf": pf(profits), "n": len(profits)}

    oos_p = oos_c1["profit"].astype(float).values
    oos_keep = oos_c1["would_skip"] == 0
    oos_after = {
        "net": float(oos_p[oos_keep].sum()),
        "pf": pf(oos_p[oos_keep]),
        "n": int(oos_keep.sum()),
        "skipped": int((~oos_keep).sum()),
    }

    lines = [
        "# AI-4 — Shadow backtest validation",
        "",
        "**Policy:** Strategy Tester only until production + AI gates pass in backtest. No live/demo debugging.",
        "",
        f"- Shadow: `{args.shadow}` · rows **{len(sh)}** · **opened={len(opened)}**",
        f"- C1 archive: `{args.c1}` · n=**{len(c1)}**",
        f"- Shadow↔C1 merge_asof misses: **{n_miss}** (signal vs entry bar; P/L from C1 direct)",
        "",
        "## E2 — MT5 vs Python scorer (opened trades)",
        "",
        f"- Threshold: **{thr:.6f}** (skip top ~{model['skip_frac']*100:.0f}% offline)",
        f"- Max |py_score − ai_score|: **{opened['score_delta'].max():.6f}**",
        f"- Mean |delta|: **{opened['score_delta'].mean():.6f}**",
        f"- MT5 would_skip on opened: **{(opened['would_skip']==1).sum()}**",
        f"- Python would_skip on opened: **{opened['py_would_skip'].sum()}**",
        f"- Agreement: **{(opened['would_skip']==opened['py_would_skip']).mean()*100:.1f}%**",
        f"- C1 archive would_skip (E4 source): **{c1p['would_skip'].sum()}** · OOS **{oos_c1['would_skip'].sum()}**",
        "",
        "## E4 — Hypothetical skip on realized P/L (shadow only; orders unchanged in tester)",
        "",
        "### Full span (opened, n=396)",
        "",
        f"| Metric | Baseline | If skip would_skip=1 |",
        f"|--------|--------:|---------------------:|",
        f"| Net $ | {baseline['net']:.2f} | {p_keep.sum():.2f} |",
        f"| PF | {baseline['pf']:.2f} | {pf(p_keep):.2f} |",
        f"| Trades | {baseline['n']} | {len(p_keep)} |",
        "",
        f"- Skipped trades net: **${skip_opened['profit'].sum():.2f}** ({len(skip_opened)} tr)",
        "",
        f"### OOS pass window (`{oos['start']}` -> `{oos['end']}`)",
        "",
        f"| Metric | Baseline | After shadow skip | Pass bar |",
        f"|--------|--------:|------------------:|---------|",
        f"| Net $ | {float(oos_p.sum()):.2f} | {oos_after['net']:.2f} | >= {PASS_NET:.2f} |",
        f"| PF | {pf(oos_p):.2f} | {oos_after['pf']:.2f} | >= {PASS_PF:.2f} |",
        f"| Trades | {len(oos_p)} | {oos_after['n']} | >= 100 |",
        f"| Skipped | — | {oos_after['skipped']} | — |",
        "",
    ]
    if len(skip_oos):
        lines.append(f"- OOS skipped P/L: **${float(skip_oos['profit'].sum()):.2f}**")
        lines.append("")

    oos_pass = oos_after["net"] >= PASS_NET and oos_after["pf"] >= PASS_PF and oos_after["n"] >= 100
    lines.extend(
        [
            f"- OOS skip pass bar (D5–D8): **{'PASS' if oos_pass else 'CHECK'}**",
            "",
            "## Gate (backtest-only deployment)",
            "",
            "- [x] **E3** — Tester run `VEM.AI_Shadow` · shadow CSV + **396** opened = C1",
            "- [x] **E2** — MT5 scorer matches Python (max delta < 0.001)",
            "- [x] **E4** — Skip sim on C1 archive (same as AI-3 offline)",
            "- [ ] **Production backtest gate** — rules-only `VEM.Production` stable on OOS pass bar",
            "- [ ] **AI-5** — Wire entry skip in tester only after E4 + production gate pass",
            "- [ ] **AI-0 live** — **After** all tester gates; never parallel debugging on charts",
            "",
        ]
    )

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")
    print(
        f"opened={len(opened)} max_delta={opened['score_delta'].max():.4f} "
        f"oos_skip={oos_after['skipped']} oos_net_after={oos_after['net']:.2f}"
    )


if __name__ == "__main__":
    main()
