#!/usr/bin/env python3
"""AI-2 / AI-3 — offline trade-quality model v0 on C1 CSV."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    brier_score_loss,
    classification_report,
    roc_auc_score,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

DEFAULT_CSV = (
    r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
    r"\VEM_trades_EURUSD_M5.csv"
)
OUT_MD = Path(__file__).resolve().parent.parent / "step-ai-2-results.md"
MODEL_DIR = Path(__file__).resolve().parent.parent / "models"
MANIFEST = Path(__file__).resolve().parent.parent / "data" / "c1" / "manifest.json"

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


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    rsi = d["rsi"].astype(float)
    depth = np.where(
        d["side_sell"] == 0,
        np.maximum(25.0 - rsi, 0.0),
        np.maximum(rsi - 75.0, 0.0),
    )
    d["rsi_depth"] = depth
    d["label_sl"] = (d["exit_type"].astype(str) == "sl").astype(int)
    d["label_loss"] = (d["profit"].astype(float) <= 0).astype(int)
    d["label_midline_win"] = (
        (d["exit_type"].astype(str) == "midline") & (d["profit"].astype(float) > 0)
    ).astype(int)
    return d


def simulate_skip(
    test: pd.DataFrame,
    scores: np.ndarray,
    skip_frac: float,
    label: str,
) -> dict:
    """Skip highest-risk fraction by model score."""
    n = len(test)
    k = max(1, int(n * skip_frac))
    order = np.argsort(-scores)
    skip_idx = set(order[:k])
    keep = np.array([i not in skip_idx for i in range(n)])
    p_all = test["profit"].astype(float).values
    p_keep = p_all[keep]
    return {
        "label": label,
        "skip_frac": skip_frac,
        "skipped_n": k,
        "kept_n": int(keep.sum()),
        "net_all": float(p_all.sum()),
        "net_kept": float(p_keep.sum()),
        "pf_kept": pf(p_keep),
        "wr_kept": float((p_keep > 0).mean() * 100) if len(p_keep) else 0.0,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--out", default=str(OUT_MD))
    default_train, default_val = "2024-12-31", "2025-10-31"
    if MANIFEST.is_file():
        sp = json.loads(MANIFEST.read_text(encoding="utf-8")).get("splits", {})
        default_train = sp.get("train_end", default_train)
        default_val = sp.get("val_end", default_val)
    ap.add_argument("--train-end", default=default_train)
    ap.add_argument("--val-end", default=default_val)
    ap.add_argument("--target", choices=("label_sl", "label_loss"), default="label_loss")
    args = ap.parse_args()

    path = Path(args.csv)
    raw = pd.read_csv(path)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    raw = raw[~raw["exit_type"].isin(EXCLUDE_EXITS)]
    df = prepare(raw)

    train = df[df["entry_time"] <= args.train_end]
    val = df[(df["entry_time"] > args.train_end) & (df["entry_time"] <= args.val_end)]
    test = df[df["entry_time"] > args.val_end]

    X_train = train[FEATURES].astype(float)
    y_train = train[args.target].astype(int)
    X_val = val[FEATURES].astype(float)
    y_val = val[args.target].astype(int)
    X_test = test[FEATURES].astype(float)
    y_test = test[args.target].astype(int)

    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            (
                "clf",
                LogisticRegression(
                    max_iter=2000,
                    class_weight="balanced",
                    random_state=42,
                ),
            ),
        ]
    )
    pipe.fit(X_train, y_train)

    def eval_split(name: str, X: pd.DataFrame, y: pd.Series, part: pd.DataFrame) -> list[str]:
        if len(part) == 0:
            return [f"### {name}", "", "_No rows._", ""]
        prob = pipe.predict_proba(X)[:, 1]
        pred = (prob >= 0.5).astype(int)
        lines = [f"### {name} (n={len(part)})", ""]
        try:
            auc = roc_auc_score(y, prob)
            lines.append(f"- ROC-AUC: **{auc:.3f}**")
        except ValueError:
            lines.append("- ROC-AUC: _undefined (single class)_")
        lines.append(f"- Brier: **{brier_score_loss(y, prob):.4f}**")
        lines.append(f"- Positive rate: **{y.mean() * 100:.1f}%**")
        lines.append("")
        lines.append("```")
        lines.append(classification_report(y, pred, zero_division=0))
        lines.append("```")
        lines.append("")
        return lines

    val_prob = pipe.predict_proba(X_val)[:, 1] if len(val) else np.array([])
    test_prob = pipe.predict_proba(X_test)[:, 1] if len(test) else np.array([])

    sims = []
    for frac in (0.10, 0.15, 0.20):
        if len(test):
            sims.append(simulate_skip(test, test_prob, frac, args.target))

    # Pass bar reference (production OOS)
    pass_net = 9.08
    pass_pf = 1.30

    lines = [
        "# AI-2 — Offline model v0",
        "",
        f"**Source:** `{path}` (production-path, no `e10`)",
        f"**Target:** `{args.target}`",
        f"**Model:** logistic regression + standard scaler",
        "",
        "## Splits (time-based)",
        "",
        f"| Split | End | n | SL | loss |",
        f"|-------|-----|---:|---:|-----:|",
    ]
    for name, part in [
        ("Train", train),
        ("Val", val),
        ("Test (holdout)", test),
    ]:
        lines.append(
            f"| {name} | — | {len(part)} | {part['label_sl'].sum()} | "
            f"{part['label_loss'].sum()} |"
        )
    lines.append("")
    lines += eval_split("Train", X_train, y_train, train)
    lines += eval_split("Validation", X_val, y_val, val)
    lines += eval_split("Test / holdout", X_test, y_test, test)

    lines.append("## AI-3 — Skip simulation (holdout)")
    lines.append("")
    lines.append(
        f"Pass bar (production OOS): net **≥ ${pass_net:.2f}**, PF **≥ {pass_pf:.2f}**"
    )
    lines.append("")
    if not sims:
        lines.append("_No holdout rows._")
    else:
        p_test = test["profit"].astype(float).values
        lines.append(
            f"| Skip frac | Skipped | Kept n | Net kept | PF kept | WR kept | vs pass |"
        )
        lines.append("|----------:|--------:|-------:|---------:|--------:|--------:|---------|")
        for s in sims:
            ok = "✓" if s["net_kept"] >= pass_net and s["pf_kept"] >= pass_pf else "✗"
            lines.append(
                f"| {s['skip_frac']*100:.0f}% | {s['skipped_n']} | {s['kept_n']} | "
                f"${s['net_kept']:.2f} | {s['pf_kept']:.2f} | {s['wr_kept']:.1f}% | {ok} |"
            )
        lines.append("")
        lines.append(f"- Holdout baseline (no skip): **${p_test.sum():.2f}**, PF **{pf(p_test):.2f}**, n={len(test)}")
    lines.append("")

    # Coefficients for inspection
    clf = pipe.named_steps["clf"]
    coef = dict(zip(FEATURES, clf.coef_[0].tolist()))
    lines.append("## Feature coefficients (standardized)")
    lines.append("")
    for k, v in sorted(coef.items(), key=lambda x: abs(x[1]), reverse=True):
        lines.append(f"- `{k}`: {v:+.4f}")
    lines.append("")

    out_model = MODEL_DIR / f"ai_v0_logistic_{args.target}.json"
    out_model.parent.mkdir(parents=True, exist_ok=True)
    export = {
        "features": FEATURES,
        "target": args.target,
        "intercept": float(clf.intercept_[0]),
        "coef": coef,
        "train_end": args.train_end,
        "val_end": args.val_end,
    }
    out_model.write_text(json.dumps(export, indent=2), encoding="utf-8")
    lines.extend(
        [
            "## Verdict (AI-2 / AI-3)",
            "",
            "- **Val ROC-AUC** must be stable before **AI-4/AI-5** — weak val = do not wire.",
            "- Holdout skip sim is **exploratory** on a **mixed CSV**; re-run on **clean** `vem5m_d7_c1_trade_log.set` export before promotion.",
            "- **label_loss** v0: use for research / shadow design only unless val improves on clean data.",
            "- **label_sl** v0: too few SL events; prefer loss-quality gate over raw SL classifier.",
            "",
            f"**Exported:** `{out_model}`",
            "",
        ]
    )

    out = Path(args.out)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out}")
    print(f"Model: {out_model}")


if __name__ == "__main__":
    main()
