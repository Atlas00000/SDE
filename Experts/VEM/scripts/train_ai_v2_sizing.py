#!/usr/bin/env python3
"""P4-1 — v0.2 tiered sizing: skip top %, 0.5x lot on medium P(bad) band (val-tuned)."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
MODEL_V1 = ROOT / "models" / "ai_v1_logistic_bad_trade.json"
OUT_JSON = ROOT / "models" / "ai_v2_sizing.json"
OUT_MD = ROOT / "step-ai-v2-sizing-results.md"

FEATURES = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
    "side_sell",
    "rsi_depth",
]
PASS_NET = 9.08
PASS_PF = 1.30
SKIP_FRAC = 0.02


def pf(p: np.ndarray) -> float:
    w = p[p > 0].sum()
    l = -p[p < 0].sum()
    return w / l if l > 0 else (float("inf") if w > 0 else 0.0)


def label_bad_trade(df: pd.DataFrame) -> pd.Series:
    exit_t = df["exit_type"].astype(str)
    mae = pd.to_numeric(df["mae_r"], errors="coerce").fillna(0.0)
    profit = df["profit"].astype(float)
    sl = exit_t == "sl"
    e8c_bad = (exit_t == "e8c") & (mae >= 0.5)
    deep = (profit <= 0) & (mae >= 0.5)
    return (sl | e8c_bad | deep).astype(int)


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    rsi = d["rsi"].astype(float)
    d["rsi_depth"] = np.where(
        d["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    return d


def skip_threshold(prob: np.ndarray, frac: float) -> float:
    if frac <= 0 or len(prob) == 0:
        return 1.0
    k = max(1, int(len(prob) * frac))
    return float(np.sort(prob)[-k])


def tier_mult(prob: np.ndarray, skip_thr: float, half_thr: float) -> np.ndarray:
    m = np.ones(len(prob), dtype=float)
    m[prob >= skip_thr] = 0.0
    m[(prob >= half_thr) & (prob < skip_thr)] = 0.5
    return m


def stats(profits: np.ndarray, mult: np.ndarray) -> dict:
    p = profits * mult
    kept = mult > 0
    if kept.sum() == 0:
        return {"n": 0, "net": 0.0, "pf": 0.0, "wr": 0.0, "skipped": len(profits)}
    pk = p[kept]
    return {
        "n": int(kept.sum()),
        "net": float(pk.sum()),
        "pf": pf(pk),
        "wr": float((pk > 0).mean() * 100),
        "skipped": int((mult == 0).sum()),
        "half": int((mult == 0.5).sum()),
    }


def main() -> None:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    train_end = m["splits"]["train_end"]
    val_end = m["splits"]["val_end"]
    oos = m["oos_pass_window"]

    df = prepare(pd.read_csv(ARCHIVE))
    df["entry_time"] = pd.to_datetime(df["entry_time"])

    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]
    oos_mask = (test["entry_time"] >= oos["start"]) & (test["entry_time"] < oos["end"])
    test_oos = test[oos_mask]

    X_train = train[FEATURES].astype(float)
    y_train = label_bad_trade(train)
    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(max_iter=2000, class_weight="balanced", random_state=42)),
        ]
    )
    pipe.fit(X_train, y_train)

    val_prob = pipe.predict_proba(val[FEATURES].astype(float))[:, 1]
    test_prob = pipe.predict_proba(test_oos[FEATURES].astype(float))[:, 1]

    v1 = json.loads(MODEL_V1.read_text(encoding="utf-8"))
    skip_thr = float(v1["skip_prob_threshold"])  # frozen v0.1 skip (~2%)

    best_half_thr = skip_thr
    best_val_net = float((val["profit"].astype(float) * tier_mult(val_prob, skip_thr, skip_thr)).sum())
    best_pct = 100.0

    for pct in range(50, 99):
        half_thr = float(np.percentile(val_prob, pct))
        if half_thr >= skip_thr - 1e-9:
            continue
        mult = tier_mult(val_prob, skip_thr, half_thr)
        net = float((val["profit"].astype(float).values * mult).sum())
        if net > best_val_net + 0.01:
            best_val_net = net
            best_half_thr = half_thr
            best_pct = pct

    val_profits = val["profit"].astype(float).values
    test_profits = test_oos["profit"].astype(float).values
    mult_val = tier_mult(val_prob, skip_thr, best_half_thr)
    mult_test = tier_mult(test_prob, skip_thr, best_half_thr)

    skip_only_test = tier_mult(test_prob, skip_thr, skip_thr)
    s_val = stats(val_profits, mult_val)
    s_test = stats(test_profits, mult_test)
    s_skip_only = stats(test_profits, skip_only_test)
    s_base = stats(test_profits, np.ones(len(test_profits)))

    oos_pass = s_test["net"] >= PASS_NET and s_test["pf"] >= PASS_PF and s_test["wr"] >= 65 and s_test["n"] >= 100

    payload = {
        "version": "v0.2",
        "skip_frac": SKIP_FRAC,
        "skip_prob_threshold": skip_thr,
        "half_lot_prob_min": best_half_thr,
        "half_lot_val_percentile": best_pct,
        "skip_prob_threshold_source": "ai_v1_logistic_bad_trade.json",
        "policy": "score>=skip: no trade; score>=half_min and <skip: 0.5*lots; else full",
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines = [
        "# AI v0.2 — tiered sizing (P4-1)",
        "",
        f"**Archive:** `{ARCHIVE.name}` · skip **{SKIP_FRAC:.0%}** fixed",
        "",
        "## Thresholds (val-tuned half band)",
        "",
        f"| Param | Value |",
        f"|-------|------:|",
        f"| `skip_prob_threshold` | **{skip_thr:.6f}** |",
        f"| `half_lot_prob_min` | **{best_half_thr:.6f}** (val pct **{best_pct:.0f}**) |",
        "",
        "## Val",
        "",
        f"- Net sim: **${s_val['net']:.2f}** · n={s_val['n']} · half={s_val['half']} · skipped={s_val['skipped']}",
        "",
        "## Test OOS",
        "",
        "| Policy | n | Net $ | PF | WR % | half | skip |",
        "|--------|--:|------:|---:|-----:|-----:|-----:|",
        f"| Production (1x) | {s_base['n']} | {s_base['net']:.2f} | {s_base['pf']:.2f} | {s_base['wr']:.1f} | 0 | 0 |",
        f"| Skip only (v0.1) | {s_skip_only['n']} | {s_skip_only['net']:.2f} | {s_skip_only['pf']:.2f} | {s_skip_only['wr']:.1f} | 0 | {s_skip_only['skipped']} |",
        f"| Skip + half (v0.2) | {s_test['n']} | {s_test['net']:.2f} | {s_test['pf']:.2f} | {s_test['wr']:.1f} | {s_test['half']} | {s_test['skipped']} |",
        "",
        f"- OOS pass bar: **{'PASS' if oos_pass else 'FAIL'}** (net>={PASS_NET}, PF>={PASS_PF})",
        "",
        f"Export: `{OUT_JSON.name}`",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_JSON} {OUT_MD}")
    print(f"skip_thr={skip_thr:.4f} half_min={best_half_thr:.4f} OOS net={s_test['net']:.2f} pf={s_test['pf']:.2f}")


if __name__ == "__main__":
    main()
