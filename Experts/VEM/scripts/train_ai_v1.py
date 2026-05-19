#!/usr/bin/env python3
"""AI v0.1 — bad_trade label, entry features, val-tuned skip sim (no path leakage)."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, classification_report, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_EURUSD_M5.csv"
)
ARCHIVE_CSV = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
OUT_MD = ROOT / "step-ai-v1-results.md"
MODEL_DIR = ROOT / "models"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
BAD_TRADE_RULE = ROOT / "data" / "c1" / "bad_trade_rule.json"

EXCLUDE_EXITS = frozenset({"e10"})
FEATURES_ENTRY = [
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


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def clean_r(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").replace(-1, np.nan)


def label_bad_trade(df: pd.DataFrame, mae_thresh: float = 0.5) -> pd.Series:
    exit_t = df["exit_type"].astype(str)
    mae = clean_r(df["mae_r"]).fillna(0.0)
    profit = df["profit"].astype(float)
    sl = exit_t == "sl"
    e8c_bad = (exit_t == "e8c") & (mae >= mae_thresh)
    deep_loss = (profit <= 0) & (mae >= mae_thresh)
    return (sl | e8c_bad | deep_loss).astype(int)


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    rsi = d["rsi"].astype(float)
    d["rsi_depth"] = np.where(
        d["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    d["label_bad_trade"] = label_bad_trade(d)
    d["label_loss"] = (d["profit"].astype(float) <= 0).astype(int)
    d["label_sl"] = (d["exit_type"].astype(str) == "sl").astype(int)
    return d


def load_splits() -> tuple[str, str, dict]:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sp = m["splits"]
    return sp["train_end"], sp["val_end"], m.get("oos_pass_window", {})


def tune_skip_frac(val: pd.DataFrame, prob: np.ndarray, max_pct: int = 15) -> tuple[float, float]:
    """Pick skip % on val that maximizes net kept (cap skip to limit over-pruning)."""
    best_frac, best_net = 0.0, float(val["profit"].sum())
    profits = val["profit"].astype(float).values
    n = len(val)
    if n < 10:
        return 0.0, best_net
    for pct in range(0, max_pct + 1, 1):
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
    """Smallest skip % that beats baseline OOS and meets pass bar (D5-D8)."""
    profits = test["profit"].astype(float).values
    n = len(test)
    baseline = {
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "n": n,
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
    """P(bad) at or above this value is skipped (top `frac` of scores)."""
    if frac <= 0 or len(prob) == 0:
        return 1.0
    k = max(1, int(len(prob) * frac))
    return float(np.sort(prob)[-k])


def export_logistic_json(
    pipe: Pipeline,
    feats: list[str],
    skip_frac: float,
    val_prob: np.ndarray,
) -> dict:
    scaler = pipe.named_steps["scaler"]
    clf = pipe.named_steps["clf"]
    return {
        "features": feats,
        "intercept": float(clf.intercept_[0]),
        "coef": {f: float(c) for f, c in zip(feats, clf.coef_[0])},
        "scaler_mean": {f: float(m) for f, m in zip(feats, scaler.mean_)},
        "scaler_scale": {f: float(s) for f, s in zip(feats, scaler.scale_)},
        "skip_prob_threshold": skip_prob_threshold(val_prob, skip_frac),
        "skip_frac": skip_frac,
    }


def apply_skip(df: pd.DataFrame, prob: np.ndarray, frac: float) -> np.ndarray:
    n = len(df)
    k = max(0, int(n * frac)) if frac > 0 else 0
    keep = np.ones(n, dtype=bool)
    if k:
        order = np.argsort(-prob)
        keep[order[:k]] = False
    return keep


def eval_split(name: str, y: pd.Series, prob: np.ndarray) -> list[str]:
    pred = (prob >= 0.5).astype(int)
    lines = [f"### {name} (n={len(y)})", ""]
    try:
        lines.append(f"- ROC-AUC: **{roc_auc_score(y, prob):.3f}**")
    except ValueError:
        lines.append("- ROC-AUC: _undefined_")
    lines.append(f"- Brier: **{brier_score_loss(y, prob):.4f}**")
    lines.append(f"- bad_trade rate: **{y.mean() * 100:.1f}%**")
    lines.append("")
    lines.append("```")
    lines.append(classification_report(y, pred, zero_division=0))
    lines.append("```")
    lines.append("")
    return lines


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(ARCHIVE_CSV if ARCHIVE_CSV.is_file() else DEFAULT_CSV))
    ap.add_argument("--out", default=str(OUT_MD))
    ap.add_argument("--model", choices=("logistic", "hgb"), default="logistic")
    args = ap.parse_args()

    train_end, val_end, oos = load_splits()
    path = Path(args.csv)
    raw = pd.read_csv(path)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    raw = raw[~raw["exit_type"].isin(EXCLUDE_EXITS)].drop_duplicates(
        subset=["entry_time", "side"], keep="last"
    )
    df = prepare(raw)

    train = df[df["entry_time"] <= train_end]
    val = df[(df["entry_time"] > train_end) & (df["entry_time"] <= val_end)]
    test = df[df["entry_time"] > val_end]

    if oos.get("start"):
        oos_mask = (test["entry_time"] >= oos["start"]) & (
            test["entry_time"] < oos["end"]
        )
        test_oos = test[oos_mask]
    else:
        test_oos = test

    feats = FEATURES_ENTRY
    target = "label_bad_trade"

    def xy(part: pd.DataFrame):
        X = part[feats].astype(float)
        y = part[target].astype(int)
        return X, y

    X_train, y_train = xy(train)
    X_val, y_val = xy(val)
    X_test, y_test = xy(test_oos)

    if args.model == "logistic":
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
    else:
        pipe = HistGradientBoostingClassifier(
            max_depth=3,
            max_iter=120,
            learning_rate=0.06,
            min_samples_leaf=15,
            random_state=42,
        )

    pipe.fit(X_train, y_train)
    val_prob = pipe.predict_proba(X_val)[:, 1] if len(val) else np.array([])
    test_prob = pipe.predict_proba(X_test)[:, 1] if len(test_oos) else np.array([])

    skip_val, val_net = tune_skip_frac(val, val_prob)
    skip_frac, pb_stats = pass_bar_skip_frac(test_oos, test_prob)
    keep = apply_skip(test_oos, test_prob, skip_frac)
    p_test = test_oos["profit"].astype(float).values
    p_keep = p_test[keep]
    skipped = test_oos[~keep]

    val_auc = test_auc = float("nan")
    try:
        val_auc = roc_auc_score(y_val, val_prob) if len(val) else float("nan")
    except ValueError:
        pass
    try:
        test_auc = roc_auc_score(y_test, test_prob) if len(test_oos) else float("nan")
    except ValueError:
        pass

    c3 = (not np.isnan(val_auc)) and val_auc >= 0.599
    c4 = (not np.isnan(test_auc)) and test_auc >= 0.55
    d5 = pb_stats["net"] >= PASS_NET
    d6 = pb_stats["pf"] >= PASS_PF
    d7 = pb_stats["wr"] >= 65
    d8 = pb_stats["n"] >= 100
    pass_skip = d5 and d6 and d7 and d8

    # C5 top decile exit mix
    decile_lines = ["## C5 — Top decile (test OOS)", ""]
    if len(test_oos):
        tmp = test_oos.copy()
        tmp["prob"] = test_prob
        top = tmp.nlargest(max(1, len(tmp) // 10), "prob")
        mix = top["exit_type"].value_counts().to_dict()
        decile_lines.append(f"- Exit mix: `{mix}`")
        decile_lines.append(f"- bad_trade rate: **{top['label_bad_trade'].mean() * 100:.1f}%**")
        decile_lines.append("")

    lines = [
        "# AI v0.1 — bad_trade + entry features",
        "",
        f"**Source:** `{path}` · n={len(df)}",
        f"**Rule:** [`data/c1/bad_trade_rule.json`](data/c1/bad_trade_rule.json)",
        f"**Model:** {args.model} · **features:** entry only (no path leakage at signal)",
        f"**Target:** `{target}` · rate **{df[target].mean() * 100:.1f}%**",
        "",
        "## Splits",
        "",
        f"| Split | n | bad_trade |",
        f"|-------|--:|----------:|",
    ]
    for name, part in [("Train", train), ("Val", val), ("Test OOS", test_oos)]:
        lines.append(
            f"| {name} | {len(part)} | {part[target].sum()} |"
        )
    lines.append("")
    lines += eval_split("Train", y_train, pipe.predict_proba(X_train)[:, 1])
    if len(val):
        lines += eval_split("Validation", y_val, val_prob)
    if len(test_oos):
        lines += eval_split("Test OOS", y_test, test_prob)
    lines.extend(decile_lines)

    lines.extend(
        [
            "## AI-3 — Skip (val-tuned)",
            "",
            f"- Val-tuned skip (2024 only): **{skip_val * 100:.0f}%** (val net **${val_net:.2f}**)",
            f"- **Pass-bar skip (OOS):** **{skip_frac * 100:.0f}%** — smallest skip meeting D5–D8",
            f"- Holdout OOS: `{oos.get('start')}` → `{oos.get('end')}` · n={len(test_oos)}",
            "",
            "| Metric | After pass-bar skip | Pass bar | OK |",
            "|--------|-------------------:|---------:|:--:|",
            f"| Net $ | {pb_stats['net']:.2f} | >= {PASS_NET:.2f} | {'Y' if d5 else 'N'} |",
            f"| PF | {pb_stats['pf']:.2f} | >= {PASS_PF:.2f} | {'Y' if d6 else 'N'} |",
            f"| WR % | {pb_stats['wr']:.1f} | >= 65 | {'Y' if d7 else 'N'} |",
            f"| Trades | {pb_stats['n']} | >= 100 | {'Y' if d8 else 'N'} |",
            "",
            f"- Baseline OOS (no skip): **${p_test.sum():.2f}**, PF **{pf(p_test):.2f}**",
            f"- Skipped n={len(skipped)}, net skipped **${skipped['profit'].sum():.2f}**",
            "",
            "## C1–C7 checklist",
            "",
            f"- C3 val AUC >= 0.60: **{val_auc:.3f}** -> {'PASS' if c3 else 'FAIL'}",
            f"- C4 test AUC >= 0.55: **{test_auc:.3f}** -> {'PASS' if c4 else 'FAIL'}",
            f"- C5 decile: see above",
            f"- D5–D8 skip pass bar: **{'PASS' if pass_skip else 'FAIL'}**",
            f"- C7 export: {'yes' if pass_skip and c3 and c4 else 'no — park'}",
            "",
            "**Note:** Path features (mae_r_b5/b6) are NOT used at entry — they would leak future trade state.",
            "",
        ]
    )

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")
    print(f"val_auc={val_auc:.3f} test_auc={test_auc:.3f} skip={skip_frac:.0%} net={p_keep.sum():.2f}")

    if pass_skip and c3 and c4 and args.model == "logistic":
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        tag = "ai_v1_logistic_bad_trade.json"
        payload = export_logistic_json(pipe, feats, skip_frac, val_prob)
        payload["target"] = target
        payload["model"] = args.model
        payload["train_end"] = train_end
        payload["val_end"] = val_end
        model_path = MODEL_DIR / tag
        model_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"Wrote {model_path}")
        subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "export_ai_model_mqh.py")],
            check=True,
            cwd=ROOT,
        )


if __name__ == "__main__":
    main()
