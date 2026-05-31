#!/usr/bin/env python3
"""Export models/ai_tail_logistic.json -> Include/VEM/VEM_AI_Tail_Model.inc.mqh"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "models" / "ai_tail_logistic.json"
OUT = ROOT.parent.parent / "Include" / "VEM" / "VEM_AI_Tail_Model.inc.mqh"


def main() -> None:
    m = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    feats = m["features"]
    lines = [
        "// Auto-generated — do not edit. Run: python scripts/export_ai_tail_model_mqh.py",
        f"static const double VEM_AI_TAIL_INTERCEPT = {m['intercept']:.16f};",
        f"static const double VEM_AI_TAIL_SKIP_THRESH_DEFAULT = {m['skip_prob_threshold']:.16f};",
        "",
    ]
    for key in ("scaler_mean", "scaler_scale", "coef"):
        for f in feats:
            name = f.upper()
            if key == "scaler_mean":
                const = f"VEM_AI_TAIL_MEAN_{name}"
            elif key == "scaler_scale":
                const = f"VEM_AI_TAIL_SCALE_{name}"
            else:
                const = f"VEM_AI_TAIL_COEF_{name}"
            lines.append(f"static const double {const} = {m[key][f]:.16f};")
        lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
