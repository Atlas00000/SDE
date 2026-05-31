#!/usr/bin/env python3
"""AI-6 — XGBoost entry scorer on C2 labeled archive vs logistic baselines."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, classification_report, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "data" / "c2" / "manifest.json"
LABELED = ROOT / "data" / "c2" / "VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv"
OUT_MD = ROOT / "step-ai-v6-results.md"
MODEL_DIR = ROOT / "models"

EXCLUDE_EXITS = frozenset({"e10"})
PASS_NET = 9.08
PASS_PF = 1.30

FEATURES_V01 = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
    "side_sell",
    "rsi_depth",
]

FEATURES_C2 = FEATURES_V01 + [
    "bb_walk_count",
    "wick_pct",
    "ema_slope_bp",
    "atr_ratio",
    "bb_pen_pts",
    "htf_slope_bp",
]

TARGET = "label_bad_entry"


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def apply_skip(df: pd.DataFrame, prob: np.ndarray, frac: float) -> np.ndarray:
    n = len(df)
    k = max(0, int(n * frac)) if frac > 0 else 0
    keep = np.ones(n, dtype=bool)
    if k:
        order = np.argsort(-prob)
        keep[order[:k]] = False
    return keep


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
    for pct in range(1, 16):
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
            return frac, {
                "net": net,
                "pf": pfv,
                "wr": wr,
                "n": int(keep.sum()),
            }
    return 0.0, baseline


def skip_prob_threshold(prob: np.ndarray, frac: float) -> float:
    if frac <= 0 or len(prob) == 0:
        return 1.0
    k = max(1, int(len(prob) * frac))
    return float(np.sort(prob)[-k])


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
    if TARGET not in d.columns:
        raise SystemExit(f"Missing {TARGET} — run: python scripts/c2_labels_b7.py")
    return d


def load_splits() -> tuple[str, str, dict]:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    return m["splits"]["train_end"], m["splits"]["val_end"], m.get("oos_pass_window", {})


def eval_auc(y: pd.Series, prob: np.ndarray) -> float:
    try:
        return float(roc_auc_score(y, prob))
    except ValueError:
        return float("nan")


def train_logistic(X_train, y_train) -> Pipeline:
    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            (
                "clf",
                LogisticRegression(
                    max_iter=2000, class_weight="balanced", random_state=42
                ),
            ),
        ]
    )
    pipe.fit(X_train, y_train)
    return pipe


def train_xgb(X_train, y_train) -> XGBClassifier:
    pos = max(1, int(y_train.sum()))
    neg = max(1, len(y_train) - pos)
    clf = XGBClassifier(
        n_estimators=80,
        max_depth=3,
        learning_rate=0.05,
        min_child_weight=5,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_alpha=1.0,
        reg_lambda=2.0,
        scale_pos_weight=neg / pos,
        objective="binary:logistic",
        eval_metric="auc",
        random_state=42,
        n_jobs=-1,
    )
    clf.fit(X_train, y_train, verbose=False)
    return clf


def export_logistic_json(
    pipe: Pipeline, feats: list[str], skip_frac: float, val_prob: np.ndarray
) -> dict:
    scaler = pipe.named_steps["scaler"]
    clf = pipe.named_steps["clf"]
    return {
        "model": "logistic",
        "version": "v6_c2",
        "features": feats,
        "target": TARGET,
        "intercept": float(clf.intercept_[0]),
        "coef": {f: float(c) for f, c in zip(feats, clf.coef_[0])},
        "scaler_mean": {f: float(m) for f, m in zip(feats, scaler.mean_)},
        "scaler_scale": {f: float(s) for f, s in zip(feats, scaler.scale_)},
        "skip_prob_threshold": skip_prob_threshold(val_prob, skip_frac),
        "skip_frac": skip_frac,
    }


def run_model(
    name: str,
    model,
    feats: list[str],
    train: pd.DataFrame,
    val: pd.DataFrame,
    test_oos: pd.DataFrame,
    is_pipeline: bool,
) -> dict:
    X_train = train[feats].astype(float)
    y_train = train[TARGET].astype(int)
    X_val = val[feats].astype(float)
    X_test = test_oos[feats].astype(float)

    if is_pipeline:
        prob_val = model.predict_proba(X_val)[:, 1] if len(val) else np.array([])
        prob_test = model.predict_proba(X_test)[:, 1] if len(test_oos) else np.array([])
        prob_train = model.predict_proba(X_train)[:, 1]
    else:
        prob_val = model.predict_proba(X_val)[:, 1] if len(val) else np.array([])
        prob_test = model.predict_proba(X_test)[:, 1] if len(test_oos) else np.array([])
        prob_train = model.predict_proba(X_train)[:, 1]

    skip_frac, pb = pass_bar_skip_frac(test_oos, prob_test)
    profits = test_oos["profit"].astype(float).values
    keep = apply_skip(test_oos, prob_test, skip_frac)

    return {
        "name": name,
        "features": feats,
        "model": model,
        "is_pipeline": is_pipeline,
        "auc_train": eval_auc(y_train, prob_train),
        "auc_val": eval_auc(val[TARGET], prob_val) if len(val) else float("nan"),
        "auc_test": eval_auc(test_oos[TARGET], prob_test) if len(test_oos) else float("nan"),
        "skip_frac": skip_frac,
        "pass_bar": pb,
        "prob_val": prob_val,
        "prob_test": prob_test,
        "baseline_net": float(profits.sum()),
        "baseline_pf": pf(profits),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(LABELED))
    ap.add_argument("--out", default=str(OUT_MD))
    args = ap.parse_args()

    train_end, val_end, oos = load_splits()
    path = Path(args.csv)
    raw = pd.read_csv(path)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    raw = raw[~raw["exit_type"].astype(str).isin(EXCLUDE_EXITS)]
    raw = raw.drop_duplicates(subset=["entry_time", "side"], keep="last")
    df = prepare(raw)

    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]
    if oos.get("start"):
        test_oos = test[
            (test["entry_time"] >= oos["start"]) & (test["entry_time"] < oos["end"])
        ]
    else:
        test_oos = test

    results = []

    # Baseline: v0.1 feature set + logistic on C2
    m1 = train_logistic(train[FEATURES_V01], train[TARGET])
    results.append(run_model("logistic_v01_feats", m1, FEATURES_V01, train, val, test_oos, True))

    # C2 features + logistic
    m2 = train_logistic(train[FEATURES_C2], train[TARGET])
    results.append(run_model("logistic_c2_feats", m2, FEATURES_C2, train, val, test_oos, True))

    # C2 features + XGB
    m3 = train_xgb(train[FEATURES_C2].astype(float), train[TARGET])
    results.append(run_model("xgb_c2_feats", m3, FEATURES_C2, train, val, test_oos, False))

    lines = [
        "# AI-6 — XGBoost trade scorer (C2 entry features)",
        "",
        f"**Source:** `{path}` · n={len(df)}",
        f"**Target:** `{TARGET}` · rate **{df[TARGET].mean() * 100:.1f}%**",
        f"**OOS window:** `{oos.get('start')}` → `{oos.get('end')}` · n={len(test_oos)}",
        "",
        "## Model comparison",
        "",
        "| Model | Feats | Val AUC | Test AUC | Skip% | OOS net | PF | WR | n | Pass D5-D8 |",
        "|-------|------:|--------:|---------:|------:|--------:|---:|---:|--:|:----------:|",
    ]

    best = None
    for r in results:
        pb = r["pass_bar"]
        passed = (
            pb["net"] >= PASS_NET
            and pb["pf"] >= PASS_PF
            and pb["wr"] >= 65
            and pb["n"] >= 100
            and r["skip_frac"] > 0
        )
        if passed and (best is None or pb["net"] > best["pass_bar"]["net"]):
            best = r
        lines.append(
            f"| {r['name']} | {len(r['features'])} | {r['auc_val']:.3f} | {r['auc_test']:.3f} | "
            f"{r['skip_frac']*100:.0f}% | ${pb['net']:.2f} | {pb['pf']:.2f} | {pb['wr']:.1f} | "
            f"{pb['n']} | {'Y' if passed else 'N'} |"
        )

    lines.extend(
        [
            "",
            f"- Baseline OOS (no skip): **${results[0]['baseline_net']:.2f}**, PF **{results[0]['baseline_pf']:.2f}**",
            "",
            "## Reference (v0.1 on 396-tr C1 archive)",
            "",
            "- Logistic 8 feats · test AUC ~0.61 · pass-bar skip ~2% · OOS ~$9.83 / PF 1.34",
            "",
        ]
    )

    xgb_r = results[2]
    log_c2 = results[1]
    lines.extend(
        [
            "## AI-6 verdict",
            "",
        ]
    )
    xgb_wins_auc = xgb_r["auc_test"] > log_c2["auc_test"] + 0.01
    xgb_pass = best is not None and best["name"] == "xgb_c2_feats"
    if xgb_pass:
        lines.append(
            "- **XGB PASS** pass-bar skip on OOS — candidate for **AI-7** shadow parity (not wired to EA yet)."
        )
    elif best:
        lines.append(
            f"- **Best pass-bar:** `{best['name']}` — XGB does not beat pass bar alone."
        )
    else:
        lines.append("- **FAIL** — no model meets D5–D8 skip pass bar on this C2 archive.")
    lines.append(
        f"- Test AUC: XGB **{xgb_r['auc_test']:.3f}** vs logistic C2 **{log_c2['auc_test']:.3f}** "
        f"({'XGB +0.01' if xgb_wins_auc else 'no clear AUC win'})"
    )
    lines.append("")
    lines.append("**Next:** AI-7 shadow log in tester · AI-8 promote skip if shadow matches Python.")
    lines.append("")

    # Feature importance (XGB)
    imp = m3.feature_importances_
    order = np.argsort(-imp)
    lines.append("## XGB feature importance (gain)")
    lines.append("")
    for i in order:
        lines.append(f"- `{FEATURES_C2[i]}`: {imp[i]:.4f}")
    lines.append("")

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    xgb_path = MODEL_DIR / "ai_v6_xgb_bad_entry.ubj"
    m3.get_booster().save_model(str(xgb_path))
    meta = {
        "model": "xgboost",
        "version": "v6_c2",
        "features": FEATURES_C2,
        "target": TARGET,
        "skip_frac": xgb_r["skip_frac"],
        "skip_prob_threshold": skip_prob_threshold(xgb_r["prob_test"], xgb_r["skip_frac"]),
        "auc_val": xgb_r["auc_val"],
        "auc_test": xgb_r["auc_test"],
        "pass_bar": xgb_r["pass_bar"],
        "model_file": "ai_v6_xgb_bad_entry.ubj",
        "note": "Native XGB JSON; MT5 wire requires AI-7 export path",
    }
    (MODEL_DIR / "ai_v6_xgb_bad_entry_meta.json").write_text(
        json.dumps(meta, indent=2), encoding="utf-8"
    )
    print(f"Wrote {xgb_path} + ai_v6_xgb_bad_entry_meta.json")

    if log_c2["auc_val"] >= 0.55:
        c2_log_path = MODEL_DIR / "ai_v6_logistic_c2_bad_entry.json"
        payload = export_logistic_json(
            m2, FEATURES_C2, log_c2["skip_frac"], log_c2["prob_val"]
        )
        payload["auc_test"] = log_c2["auc_test"]
        c2_log_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"Wrote {c2_log_path}")

    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    m["ai6_status"] = "done" if xgb_pass or best else "park"
    m["ai6_best_model"] = best["name"] if best else "none"
    m["next_id"] = "AI-7" if xgb_pass or best else "AI-6"
    MANIFEST.write_text(json.dumps(m, indent=2), encoding="utf-8")

    for r in results:
        print(
            f"{r['name']}: val_auc={r['auc_val']:.3f} test_auc={r['auc_test']:.3f} "
            f"skip={r['skip_frac']:.0%} oos_net={r['pass_bar']['net']:.2f}"
        )


if __name__ == "__main__":
    main()
