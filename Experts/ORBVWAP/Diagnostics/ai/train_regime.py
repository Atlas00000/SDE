#!/usr/bin/env python3
"""AI-3-002: Train session regime classifier + export MQL5 rules."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text

from sessions import REGIME_FEATURES, build_sessions
from train_eval import time_split

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = ROOT / "models" / "ai3_v1.json"
DEFAULT_MQH = ROOT / "Include" / "ORBVWAP" / "AiRegime.mqh"


def skip_threshold(train_proba: pd.Series, block_frac: float = 0.12) -> float:
    """Protection: skip worst block_frac sessions by predicted chop probability."""
    return float(train_proba.quantile(1.0 - block_frac))


def export_tree_mqh(
    path: Path,
    model: DecisionTreeClassifier,
    features: list[str],
    skip_prob: float,
) -> None:
    tree = model.tree_
    lines = [
        "//+------------------------------------------------------------------+",
        "//| AiRegime.mqh — AI-3 session gate (auto-generated)                |",
        "//+------------------------------------------------------------------+",
        "#ifndef __ORBVWAP_AIREGIME_MQH__",
        "#define __ORBVWAP_AIREGIME_MQH__",
        "",
        '#include "Inputs.mqh"',
        '#include "Types.mqh"',
        '#include "SessionUtils.mqh"',
        '#include "OpeningRange.mqh"',
        '#include "SessionVwap.mqh"',
        '#include "IndicatorManager.mqh"',
        "",
        f"const double ORBVWAP_AI3_SKIP_PROB = {skip_prob:.8f};",
        "",
        "class CAiRegime",
        "  {",
        "   static double ChopProbability(const double range_width_atr,",
        "                                 const double vol_ratio,",
        "                                 const double spread_pct_range,",
        "                                 const double vwap_dist_atr,",
        "                                 const double weekday,",
        "                                 const double session_ny,",
        "                                 const double prior_session_loss)",
        "     {",
    ]

    def walk(node_id: int, indent: int) -> list[str]:
        pad = " " * indent
        if tree.feature[node_id] < 0:
            val = float(tree.value[node_id][0][1])
            total = float(tree.value[node_id][0].sum())
            prob = val / total if total > 0 else 0.0
            return [f"{pad}return({prob:.8f});"]
        feat = features[tree.feature[node_id]]
        thr = float(tree.threshold[node_id])
        left = walk(tree.children_left[node_id], indent + 3)
        right = walk(tree.children_right[node_id], indent + 3)
        out = [f"{pad}if({feat} <= {thr:.8f})"]
        out.extend(left)
        out.append(f"{pad}else")
        out.extend(right)
        return out

    lines.extend(walk(0, 6))
    lines.extend(
        [
            "     }",
            "",
            "public:",
            "   static bool AllowSession(const double range_width_atr,",
            "                            const double vol_ratio,",
            "                            const double spread_pct_range,",
            "                            const double vwap_dist_atr,",
            "                            const int    weekday,",
            "                            const bool   is_ny_session,",
            "                            const double prior_session_loss)",
            "     {",
            "      const double session_ny = is_ny_session ? 1.0 : 0.0;",
            "      const double chop = ChopProbability(range_width_atr, vol_ratio, spread_pct_range,",
            "                                          vwap_dist_atr, (double)weekday, session_ny,",
            "                                          prior_session_loss);",
            "      return(chop < ORBVWAP_AI3_SKIP_PROB);",
            "     }",
            "",
            "   static bool AllowFromPipeline(const string               symbol,",
            "                                 const SSessionContext       &session,",
            "                                 COpeningRange               &opening_range,",
            "                                 CSessionVwap                &session_vwap,",
            "                                 CIndicatorManager           &indicators,",
            "                                 const double                 prior_session_loss)",
            "     {",
            "      double atr = 0.0;",
            "      indicators.GetATR(1, atr);",
            "      const double range_width = opening_range.Width();",
            "      double range_width_atr = 0.0;",
            "      if(atr > 0.0)",
            "         range_width_atr = range_width / atr;",
            "      long tick_vol = 0;",
            "      double vol_ma = 0.0;",
            "      indicators.GetTickVolume(1, tick_vol);",
            "      indicators.GetVolumeMA(1, vol_ma);",
            "      double vol_ratio = 0.0;",
            "      if(vol_ma > 0.0)",
            "         vol_ratio = (double)tick_vol / vol_ma;",
            "      double vwap = 0.0;",
            "      session_vwap.Value(vwap);",
            "      const double close = iClose(symbol, PERIOD_CURRENT, 1);",
            "      double vwap_dist_atr = 0.0;",
            "      if(atr > 0.0)",
            "         vwap_dist_atr = MathAbs(close - vwap) / atr;",
            "      double spread_pct_range = 0.0;",
            "      if(range_width > 0.0)",
            "        {",
            "         const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);",
            "         const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);",
            "         spread_pct_range = (ask - bid) / range_width * 100.0;",
            "        }",
            "      const datetime signal_bar_time = iTime(symbol, PERIOD_CURRENT, 1);",
            "      const datetime bar_gmt = CSessionUtils::BarTimeToGmt(signal_bar_time);",
            "      MqlDateTime dt;",
            "      TimeToStruct(bar_gmt, dt);",
            "      const bool is_ny = (session.session == ORBVWAP_SESSION_NY);",
            "      return(AllowSession(range_width_atr, vol_ratio, spread_pct_range, vwap_dist_atr,",
            "                          dt.day_of_week, is_ny, prior_session_loss));",
            "     }",
            "  };",
            "",
            "#endif // __ORBVWAP_AIREGIME_MQH__",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Train AI-3 session regime model")
    parser.add_argument("--holdout-frac", type=float, default=0.3)
    parser.add_argument("--block-frac", type=float, default=0.08)
    parser.add_argument("--model-out", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--mqh-out", type=Path, default=DEFAULT_MQH)
    args = parser.parse_args()

    sessions = build_sessions()
    split = time_split(sessions, train_frac=1.0 - args.holdout_frac)

    x_train = split.train[REGIME_FEATURES].astype(float).values
    y_train = split.train["label_chop"].astype(int).values
    model = DecisionTreeClassifier(max_depth=3, min_samples_leaf=8, random_state=42)
    model.fit(x_train, y_train)

    train_proba = pd.Series(model.predict_proba(x_train)[:, 1])
    thr = skip_threshold(train_proba, args.block_frac)

    print("=== AI-3 regime training ===")
    print(f"Sessions: {len(sessions)} | cut: {split.cut_time}")
    print(f"Skip threshold (chop prob): {thr:.3f} (block worst {100*args.block_frac:.0f}%)")
    print(export_text(model, feature_names=REGIME_FEATURES))

    payload = {
        "model_id": "ai3_v1",
        "type": "decision_tree",
        "mode": "protection_regime",
        "features": REGIME_FEATURES,
        "skip_prob_threshold": thr,
        "block_frac": args.block_frac,
        "holdout_cut": str(split.cut_time),
        "tree": {
            "children_left": model.tree_.children_left.tolist(),
            "children_right": model.tree_.children_right.tolist(),
            "feature": model.tree_.feature.tolist(),
            "threshold": model.tree_.threshold.tolist(),
            "value": model.tree_.value.reshape(-1, 2).tolist(),
        },
    }
    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    args.model_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {args.model_out}")

    export_tree_mqh(args.mqh_out, model, REGIME_FEATURES, thr)
    print(f"Wrote {args.mqh_out}")


if __name__ == "__main__":
    main()
