#!/usr/bin/env python3
"""AI-1-001..003: Train L1 logistic scorer, sweep tau, holdout gate, export MQL5."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

from train_eval import print_metrics, time_split, trade_metrics

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
DEFAULT_MODEL = ROOT / "models" / "ai1_v1.json"
DEFAULT_MQH = ROOT / "Include" / "ORBVWAP" / "AiScorer.mqh"
DEFAULT_JOURNAL = ROOT / "Diagnostics" / "AI-test-journal.csv"

NUMERIC_FEATURES = [
    "range_width_atr",
    "vol_ratio",
    "vwap_dist_atr",
    "spread_pct_range",
    "min_rr",
    "hour_gmt",
    "weekday",
    "ny_min_since_open",
]
BINARY_FEATURES = ["session_ny", "direction_sell"]
FEATURE_ORDER = NUMERIC_FEATURES + BINARY_FEATURES


def executed_mask(df: pd.DataFrame) -> pd.Series:
    return (df["prod_executed"] == 1) & df["label_win"].notna()


def prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["session_ny"] = (out["session"] == "NY").astype(float)
    out["direction_sell"] = (out["direction"] == "SELL").astype(float)
    return out


def fit_model(train: pd.DataFrame) -> tuple[LogisticRegression, StandardScaler]:
    x = train[FEATURE_ORDER].astype(float).values
    y = train["label_win"].astype(int).values
    scaler = StandardScaler()
    x_scaled = scaler.fit_transform(x)
    model = LogisticRegression(max_iter=2000, C=0.3, random_state=42)
    model.fit(x_scaled, y)
    return model, scaler


def add_scores(df: pd.DataFrame, model: LogisticRegression, scaler: StandardScaler) -> pd.DataFrame:
    out = df.copy()
    x = out[FEATURE_ORDER].astype(float).values
    out["ai_score"] = model.predict_proba(scaler.transform(x))[:, 1]
    return out


def sweep_tau(
    scored_train: pd.DataFrame,
    block_frac: float = 0.08,
    tau_cap: float = 0.30,
) -> tuple[float, dict]:
    """Protection mode: block worst tail on train, capped so holdout is not over-filtered."""
    scores = scored_train.loc[executed_mask(scored_train), "ai_score"]
    tau = min(float(scores.quantile(block_frac)), tau_cap)
    mask = executed_mask(scored_train) & (scored_train["ai_score"] >= tau)
    return tau, trade_metrics(scored_train, mask)


def gate_verdict(
    prod_ho: dict,
    ai_ho: dict,
    tau: float,
    min_retain_frac: float = 0.80,
    dd_mult: float = 1.0,
) -> str:
    """Protection gate: keep most trades; pass if DD improves without PF collapse."""
    if prod_ho["n"] == 0:
        return "PENDING"
    min_n = int(np.ceil(prod_ho["n"] * min_retain_frac))
    if ai_ho["n"] < min_n:
        return "REJECT"
    pf_ok = ai_ho["pf"] >= prod_ho["pf"] * 0.95
    dd_ok = ai_ho["max_dd"] <= prod_ho["max_dd"] * dd_mult if prod_ho["max_dd"] > 0 else True
    if pf_ok and dd_ok:
        return "PASS"
    if ai_ho["pf"] >= prod_ho["pf"] and dd_ok:
        return "PASS"
    return "REVIEW"


def export_mqh(
    path: Path,
    model: LogisticRegression,
    scaler: StandardScaler,
    tau: float,
    model_id: str,
) -> None:
    coef = model.coef_[0]
    bias = float(model.intercept_[0])
    means = scaler.mean_
    scales = scaler.scale_

    lines = [
        "//+------------------------------------------------------------------+",
        "//| AiScorer.mqh — AI-1 L1 logistic scorer (auto-generated)          |",
        "//+------------------------------------------------------------------+",
        "#ifndef __ORBVWAP_AISCORER_MQH__",
        "#define __ORBVWAP_AISCORER_MQH__",
        "",
        '#include "Inputs.mqh"',
        '#include "Types.mqh"',
        '#include "AiFeatures.mqh"',
        "",
        f'const string ORBVWAP_AI1_MODEL_ID = "{model_id}";',
        f"const double ORBVWAP_AI1_MIN_SCORE = {tau:.6f};",
        "",
        "class CAiScorer",
        "  {",
        "   static double Sigmoid(const double x)",
        "     {",
        "      if(x >= 0.0)",
        "         return(1.0 / (1.0 + MathExp(-x)));",
        "      const double ex = MathExp(x);",
        "      return(ex / (1.0 + ex));",
        "     }",
        "",
        "public:",
        "   static double MinScore() { return(ORBVWAP_AI1_MIN_SCORE); }",
        "",
        "   static double Score(const string               symbol,",
        "                       const SSessionContext       &session,",
        "                       const ENUM_ORBVWAP_SIGNAL    signal,",
        "                       COpeningRange               &opening_range,",
        "                       CSessionVwap                &session_vwap,",
        "                       CIndicatorManager           &indicators,",
        "                       const STradeSetup           &setup)",
        "     {",
        "      double feats[];",
        "      CAiFeatures::FillAi1(symbol, session, signal, opening_range, session_vwap, indicators,",
        "                           setup.risk_reward, feats);",
        "",
        "      const double means[10] = {",
    ]
    lines.append("         " + ", ".join(f"{m:.8f}" for m in means))
    lines.append("        };")
    lines.append("      const double scales[10] = {")
    lines.append("         " + ", ".join(f"{s:.8f}" for s in scales))
    lines.append("        };")
    lines.append("      const double weights[10] = {")
    lines.append("         " + ", ".join(f"{w:.8f}" for w in coef))
    lines.append("        };")
    lines.extend(
        [
            f"      const double bias = {bias:.8f};",
            "",
            "      double z = bias;",
            "      for(int i = 0; i < 10; i++)",
            "        {",
            "         if(scales[i] > 0.0)",
            "            z += weights[i] * ((feats[i] - means[i]) / scales[i]);",
            "        }",
            "      return(Sigmoid(z));",
            "     }",
            "",
            "   static bool Pass(const double score)",
            "     {",
            "      return(score >= ORBVWAP_AI1_MIN_SCORE);",
            "     }",
            "  };",
            "",
            "#endif // __ORBVWAP_AISCORER_MQH__",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Train ORBVWAP AI-1 L1 scorer")
    parser.add_argument("dataset", type=Path, nargs="?", default=DEFAULT_DATASET)
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--model-out", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--mqh-out", type=Path, default=DEFAULT_MQH)
    parser.add_argument("--journal", type=Path, default=DEFAULT_JOURNAL)
    args = parser.parse_args()

    if not args.dataset.exists():
        print(f"Missing dataset: {args.dataset}", file=sys.stderr)
        sys.exit(1)

    raw = pd.read_parquet(args.dataset)
    trades = prepare_features(raw.loc[executed_mask(raw)].copy())
    split = time_split(trades, train_frac=1.0 - args.holdout_frac)

    model, scaler = fit_model(split.train)
    scored_train = add_scores(split.train, model, scaler)
    scored_holdout = add_scores(split.holdout, model, scaler)
    scored_all = add_scores(trades, model, scaler)

    tau, train_pick_sweep = sweep_tau(scored_train, block_frac=0.08)
    train_pick = trade_metrics(
        scored_train,
        executed_mask(scored_train) & (scored_train["ai_score"] >= tau),
    )

    prod_ho = trade_metrics(split.holdout, executed_mask(split.holdout))
    ai_ho_mask = executed_mask(scored_holdout) & (scored_holdout["ai_score"] >= tau)
    ai_ho = trade_metrics(scored_holdout, ai_ho_mask)
    verdict = gate_verdict(prod_ho, ai_ho, tau)

    print("=== AI-1 L1 training ===")
    print(f"Model: logistic regression | features={len(FEATURE_ORDER)} | cut={split.cut_time}")
    retain_pct = 100.0 * ai_ho["n"] / prod_ho["n"] if prod_ho["n"] else 0.0
    print(f"Selected tau (protection cap {tau:.3f}): block worst ~8% on train, max tau=0.30")
    print(f"Holdout retention: {retain_pct:.1f}%")
    print_metrics("TRAIN @ tau", train_pick_sweep)
    print_metrics("HOLDOUT PROD", prod_ho)
    print_metrics(f"HOLDOUT AI-1 @ {tau:.2f}", ai_ho)
    print(f"\nAI-1 gate verdict: {verdict}")

    model_id = "ai1_v1"
    payload = {
        "model_id": model_id,
        "type": "logistic_regression",
        "features": FEATURE_ORDER,
        "tau": tau,
        "holdout_cut": str(split.cut_time),
        "coef": model.coef_[0].tolist(),
        "intercept": float(model.intercept_[0]),
        "scaler_mean": scaler.mean_.tolist(),
        "scaler_scale": scaler.scale_.tolist(),
        "metrics": {
            "train_at_tau": train_pick,
            "holdout_prod": prod_ho,
            "holdout_ai1": ai_ho,
            "verdict": verdict,
        },
    }
    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    args.model_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {args.model_out}")

    export_mqh(args.mqh_out, model, scaler, tau, model_id)
    print(f"Wrote {args.mqh_out}")

    row = {
        "task_id": "AI-1-003",
        "preset": "AI1_Scorer_train",
        "dataset": args.dataset.name,
        "holdout_cut": str(split.cut_time),
        "n_full": int(executed_mask(scored_all).sum()),
        "pf_full": round(trade_metrics(scored_all, executed_mask(scored_all) & (scored_all["ai_score"] >= tau))["pf"], 2),
        "n_holdout": ai_ho["n"],
        "pf_holdout": round(ai_ho["pf"], 2),
        "verdict": verdict,
        "notes": f"tau={tau:.2f} prod_ho_pf={prod_ho['pf']:.2f}",
    }
    journal_exists = args.journal.exists()
    pd.DataFrame([row]).to_csv(args.journal, mode="a", header=not journal_exists, index=False)
    print(f"Appended journal row -> {args.journal}")


if __name__ == "__main__":
    main()
