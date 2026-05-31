#!/usr/bin/env python3
"""P4-2 — tail-loss entry skip (logistic) on C2 labeled archive."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, classification_report, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
LABELED = ROOT / "data" / "c2" / "VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv"
C1_ARCHIVE = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MANIFEST_C2 = ROOT / "data" / "c2" / "manifest.json"
OUT_MD = ROOT / "step-p4-2-tail-results.md"
MODEL_JSON = ROOT / "models" / "ai_tail_logistic.json"
OUT_MD_COMBO = ROOT / "step-p4-2-tail-combo-sim.md"

EXCLUDE_EXITS = frozenset({"e10"})
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
MAE_TAIL = 0.75


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def clean_r(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s, errors="coerce").replace(-1, np.nan)


def label_tail_loss(df: pd.DataFrame, mae_thresh: float = MAE_TAIL) -> pd.Series:
    exit_t = df["exit_type"].astype(str)
    mae = clean_r(df["mae_r"]).fillna(0.0)
    return ((exit_t == "sl") | (mae >= mae_thresh)).astype(int)


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    if "rsi_depth" not in d.columns:
        rsi = d["rsi"].astype(float)
        d["rsi_depth"] = np.where(
            d["side_sell"] == 0,
            np.maximum(25.0 - rsi, 0.0),
            np.maximum(rsi - 75.0, 0.0),
        )
    if "label_tail_loss" not in d.columns:
        d["label_tail_loss"] = label_tail_loss(d)
    return d


def load_splits() -> tuple[str, str, dict]:
    p = MANIFEST_C2 if MANIFEST_C2.is_file() else ROOT / "data" / "c1" / "manifest.json"
    m = json.loads(p.read_text(encoding="utf-8"))
    return m["splits"]["train_end"], m["splits"]["val_end"], m.get("oos_pass_window", {})


def apply_skip(df: pd.DataFrame, prob: np.ndarray, frac: float) -> np.ndarray:
    n = len(df)
    k = max(0, int(n * frac)) if frac > 0 else 0
    keep = np.ones(n, dtype=bool)
    if k:
        order = np.argsort(-prob)
        keep[order[:k]] = False
    return keep


def skip_prob_threshold(prob: np.ndarray, frac: float) -> float:
    if frac <= 0 or len(prob) == 0:
        return 1.0
    k = max(1, int(len(prob) * frac))
    return float(np.sort(prob)[-k])


def tune_skip_frac(val: pd.DataFrame, prob: np.ndarray, max_pct: int = 12) -> tuple[float, float]:
    best_frac, best_net = 0.0, float(val["profit"].sum())
    profits = val["profit"].astype(float).values
    for pct in range(0, max_pct + 1):
        frac = pct / 100.0
        keep = apply_skip(val, prob, frac)
        net = profits[keep].sum()
        if net > best_net:
            best_net = float(net)
            best_frac = frac
    return best_frac, best_net


def pass_bar_skip_frac(
    test: pd.DataFrame, prob: np.ndarray, min_trades: int = 100
) -> tuple[float, dict]:
    profits = test["profit"].astype(float).values
    baseline = {
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "n": len(test),
    }
    for pct in range(1, 13):
        frac = pct / 100.0
        keep = apply_skip(test, prob, frac)
        p = profits[keep]
        if len(p) < min_trades:
            continue
        net = float(p.sum())
        pfv = pf(p)
        wr = float((p > 0).mean() * 100)
        improves = net > baseline["net"] + 0.01 or pfv > baseline["pf"] + 0.01
        if improves and net >= PASS_NET and pfv >= PASS_PF and wr >= 65:
            return frac, {"net": net, "pf": pfv, "wr": wr, "n": int(keep.sum())}
    return 0.0, baseline


def export_json(pipe: Pipeline, feats: list[str], skip_frac: float, val_prob: np.ndarray) -> dict:
    scaler = pipe.named_steps["scaler"]
    clf = pipe.named_steps["clf"]
    return {
        "model": "logistic",
        "version": "p42_tail",
        "target": "label_tail_loss",
        "mae_thresh": MAE_TAIL,
        "features": feats,
        "intercept": float(clf.intercept_[0]),
        "coef": {f: float(c) for f, c in zip(feats, clf.coef_[0])},
        "scaler_mean": {f: float(m) for f, m in zip(feats, scaler.mean_)},
        "scaler_scale": {f: float(s) for f, s in zip(feats, scaler.scale_)},
        "skip_prob_threshold": skip_prob_threshold(val_prob, skip_frac),
        "skip_frac": skip_frac,
    }


def score_logistic(model: dict, X: pd.DataFrame) -> np.ndarray:
    z = np.full(len(X), model["intercept"], dtype=float)
    for f in model["features"]:
        x = X[f].astype(float).values
        m, s = model["scaler_mean"][f], model["scaler_scale"][f]
        z += model["coef"][f] * ((x - m) / s if s > 0 else 0.0)
    return 1.0 / (1.0 + np.exp(-np.clip(z, -30, 30)))


def sim_combo_oos(
    trades: pd.DataFrame,
    tail_prob: np.ndarray,
    tail_thr: float,
    bad_model_path: Path,
) -> dict:
    """Simulate AI_Skip + tail skip on opened trades (merge shadow-style with C1 profits)."""
    bad_m = json.loads(bad_model_path.read_text(encoding="utf-8"))
    bad_thr = bad_m["skip_prob_threshold"]
    # Rebuild entry features from trade row (approx — same as signal)
    X = trades[FEATURES].astype(float)
    bad_p = score_logistic(bad_m, X)
    profits = trades["profit"].astype(float).values.copy()
    n = len(trades)
    for i in range(n):
        if bad_p[i] >= bad_thr or tail_prob[i] >= tail_thr:
            profits[i] = 0.0
    kept = profits != 0.0
    p = profits[kept]
    return {
        "net": float(p.sum()),
        "pf": pf(p),
        "wr": float((p > 0).mean() * 100) if len(p) else 0.0,
        "n": int(kept.sum()),
        "skipped": n - int(kept.sum()),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(LABELED))
    ap.add_argument("--no-export", action="store_true")
    args = ap.parse_args()

    train_end, val_end, oos = load_splits()
    raw = pd.read_csv(args.csv)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    raw = raw[~raw["exit_type"].astype(str).isin(EXCLUDE_EXITS)]
    raw = raw.drop_duplicates(subset=["entry_time", "side"], keep="last")
    df = prepare(raw)

    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]
    test_oos = test[(test["entry_time"] >= oos["start"]) & (test["entry_time"] < oos["end"])]

    target = "label_tail_loss"
    X_train, y_train = train[FEATURES].astype(float), train[target].astype(int)

    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(max_iter=2000, class_weight="balanced", random_state=42)),
        ]
    )
    pipe.fit(X_train, y_train)
    val_prob = pipe.predict_proba(val[FEATURES].astype(float))[:, 1] if len(val) else np.array([])
    test_prob = pipe.predict_proba(test_oos[FEATURES].astype(float))[:, 1] if len(test_oos) else np.array([])

    skip_val, val_net = tune_skip_frac(val, val_prob, max_pct=12)
    skip_frac, pb = pass_bar_skip_frac(test_oos, test_prob)
    use_frac = skip_frac if skip_frac > 0 else skip_val

    val_auc = roc_auc_score(val[target], val_prob) if len(val) and val[target].nunique() > 1 else float("nan")
    test_auc = roc_auc_score(test_oos[target], test_prob) if len(test_oos) and test_oos[target].nunique() > 1 else float("nan")

    tail_only = apply_skip(test_oos, test_prob, use_frac)
    p_tail = test_oos["profit"].astype(float).values[tail_only]
    pb_tail = {
        "net": float(p_tail.sum()),
        "pf": pf(p_tail),
        "wr": float((p_tail > 0).mean() * 100) if len(p_tail) else 0.0,
        "n": int(tail_only.sum()),
    }
    thr_export = skip_prob_threshold(val_prob, use_frac)

    lines = [
        "# P4-2 — Tail-loss entry skip",
        "",
        f"**Source:** `{args.csv}` · n={len(df)}",
        f"**Target:** `{target}` (SL or MAE≥{MAE_TAIL}R) · rate **{df[target].mean()*100:.1f}%**",
        "",
        "## Model",
        "",
        f"- Val AUC: **{val_auc:.3f}** · Test OOS AUC: **{test_auc:.3f}**",
        f"- Val-tuned skip: **{skip_val*100:.0f}%** · Pass-bar skip: **{skip_frac*100:.0f}%** · Export: **{use_frac*100:.0f}%**",
        f"- `skip_prob_threshold`: **{thr_export:.6f}**",
        "",
        "## OOS tail-only skip",
        "",
        f"| Metric | Value | Pass |",
        f"|--------|------:|:----:|",
        f"| Net $ | {pb_tail['net']:.2f} | {'Y' if pb_tail['net'] >= PASS_NET else 'N'} |",
        f"| PF | {pb_tail['pf']:.2f} | {'Y' if pb_tail['pf'] >= PASS_PF else 'N'} |",
        f"| WR % | {pb_tail['wr']:.1f} | {'Y' if pb_tail['wr'] >= 65 else 'N'} |",
        f"| Trades | {pb_tail['n']} | {'Y' if pb_tail['n'] >= 100 else 'N'} |",
        f"| Skipped | {int(len(test_oos) - pb_tail['n'])} | |",
        "",
        f"- Baseline OOS (no tail skip): **${test_oos['profit'].sum():.2f}**",
        "",
        "## Next",
        "",
        "1. `python scripts/export_ai_tail_model_mqh.py`",
        "2. Tester **`VEM.AI_Tail_Shadow`** → validate shadow",
        "3. **`VEM.AI_Tail_Skip`** if combo sim passes",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_MD}")

    payload = export_json(pipe, FEATURES, use_frac, val_prob)
    MODEL_JSON.parent.mkdir(parents=True, exist_ok=True)
    MODEL_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {MODEL_JSON}")

    if C1_ARCHIVE.is_file() and len(test_oos):
        c1 = prepare(pd.read_csv(C1_ARCHIVE))
        c1["entry_time"] = pd.to_datetime(c1["entry_time"])
        c1_oos = c1[(c1["entry_time"] >= oos["start"]) & (c1["entry_time"] < oos["end"])]
        # align by entry_time+side
        key = ["entry_time", "side"]
        merged = c1_oos.merge(test_oos[key + FEATURES], on=key, how="inner", suffixes=("_c1", ""))
        feat_cols = []
        for f in FEATURES:
            if f in merged.columns:
                feat_cols.append(f)
            elif f"{f}_c1" in merged.columns:
                feat_cols.append(f"{f}_c1")
        if len(merged) >= 50 and len(feat_cols) == len(FEATURES):
            tp = merged[feat_cols].astype(float)
            tp.columns = FEATURES
            tp_prob = pipe.predict_proba(tp)[:, 1]
            prof_col = "profit_c1" if "profit_c1" in merged.columns else "profit"
            sim_df = merged[[prof_col] + feat_cols].copy()
            sim_df.columns = ["profit"] + FEATURES
            bad_path = ROOT / "models" / "ai_v1_logistic_bad_trade.json"
            combo = sim_combo_oos(sim_df, tp_prob, payload["skip_prob_threshold"], bad_path)
            combo_lines = [
                "# P4-2 — Combined skip sim (bad + tail) on matched OOS trades",
                "",
                f"Matched trades: {len(merged)}",
                "",
                f"| Policy | Net $ | PF | n | skipped |",
                f"|--------|------:|---:|--:|--------:|",
                f"| Production | {merged['profit'].sum():.2f} | {pf(merged['profit'].values):.2f} | {len(merged)} | 0 |",
                f"| Bad+Tail skip | {combo['net']:.2f} | {combo['pf']:.2f} | {combo['n']} | {combo['skipped']} |",
                "",
            ]
            OUT_MD_COMBO.write_text("\n".join(combo_lines), encoding="utf-8")
            print(f"Wrote {OUT_MD_COMBO}")

    if not args.no_export and use_frac > 0:
        subprocess.run([sys.executable, str(ROOT / "scripts" / "export_ai_tail_model_mqh.py")], check=True, cwd=ROOT)

    print(f"val_auc={val_auc:.3f} test_auc={test_auc:.3f} skip={use_frac:.0%} oos_net={pb_tail['net']:.2f}")


if __name__ == "__main__":
    main()
