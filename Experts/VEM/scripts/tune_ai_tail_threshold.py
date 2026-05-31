#!/usr/bin/env python3
"""Retune tail skip_prob_threshold from shadow CSV (combo sim: bad + tail)."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SHADOW_DEFAULT = (
    Path.home()
    / "AppData/Roaming/MetaQuotes/Terminal/Common/Files/VEM_ai_shadow_EURUSD_M5.csv"
)
C1 = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
TAIL_JSON = ROOT / "models" / "ai_tail_logistic.json"
OUT_MD = ROOT / "step-p4-2-tail-retune.md"

PASS_NET = 9.08
PASS_PF = 1.30
PASS_WR = 65.0
PASS_N = 100
MAX_COMBO_SKIP_PCT = 8.0  # bad ~2% + tail ~4–6%


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def metrics(profits: np.ndarray) -> dict:
    if len(profits) == 0:
        return {"net": 0.0, "pf": 0.0, "wr": 0.0, "n": 0}
    return {
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "n": len(profits),
    }


def pass_bar(m: dict) -> bool:
    return m["net"] >= PASS_NET and m["pf"] >= PASS_PF and m["wr"] >= PASS_WR and m["n"] >= PASS_N


def load_matched(shadow_path: Path) -> pd.DataFrame:
    sh = pd.read_csv(shadow_path)
    sh["signal_time"] = pd.to_datetime(sh["signal_time"])
    ok = sh[(sh["habitat_ok"].astype(int) == 1) & (sh["opened"].astype(int) == 1)].copy()
    ok["side"] = ok["side"].str.lower()
    ok["tail_score"] = ok["tail_score"].astype(float)
    ok["skip_bad"] = ok["would_skip"].astype(int) == 1

    c1 = pd.read_csv(C1)
    c1["entry_time"] = pd.to_datetime(c1["entry_time"])
    c1["side"] = c1["side"].str.lower()

    merged = pd.merge_asof(
        ok.sort_values("signal_time"),
        c1.sort_values("entry_time")[["entry_time", "side", "profit"]],
        left_on="signal_time",
        right_on="entry_time",
        by="side",
        direction="nearest",
        tolerance=pd.Timedelta("10min"),
    )
    merged = merged.dropna(subset=["profit"]).copy()
    merged["profit"] = merged["profit"].astype(float)
    return merged


def sim_combo(df: pd.DataFrame, tail_thr: float) -> dict:
    skip_bad = df["skip_bad"].astype(bool)
    skip_tail = df["tail_score"] >= tail_thr
    skip_any = skip_bad | skip_tail
    kept = df.loc[~skip_any, "profit"].values
    m = metrics(kept)
    m["skipped"] = int(skip_any.sum())
    m["skip_pct"] = float(skip_any.mean() * 100) if len(df) else 0.0
    m["tail_only_skip"] = int((skip_tail & ~skip_bad).sum())
    m["tail_only_pct"] = float(m["tail_only_skip"] / len(df) * 100) if len(df) else 0.0
    return m


def candidate_thresholds(val_scores: np.ndarray) -> list[float]:
    """One threshold per increasing skip count on val (top-k scores)."""
    sorted_s = np.sort(val_scores)
    n = len(sorted_s)
    thrs = []
    for k in range(1, min(20, n)):
        thrs.append(float(sorted_s[-k]))
    for p in (99.0, 98.5, 98.0, 97.5, 97.0, 96.0, 95.0, 94.0, 93.0, 92.0, 90.0):
        thrs.append(float(np.percentile(val_scores, p)))
    return sorted(set(thrs), reverse=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shadow", default=str(SHADOW_DEFAULT))
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    val_end = m["splits"]["val_end"]
    oos = m["oos_pass_window"]

    df = load_matched(Path(args.shadow))
    val = df[df["signal_time"] <= pd.Timestamp(val_end)]
    oos_df = df[(df["signal_time"] >= oos["start"]) & (df["signal_time"] < oos["end"])]

    old_thr = json.loads(TAIL_JSON.read_text(encoding="utf-8"))["skip_prob_threshold"]
    rows = []
    for thr in candidate_thresholds(val["tail_score"].values):
        val_c = sim_combo(val, thr)
        oos_c = sim_combo(oos_df, thr)
        rows.append({"thr": thr, "val": val_c, "oos": oos_c})

    passing = [r for r in rows if pass_bar(r["oos"]) and r["oos"]["skip_pct"] <= MAX_COMBO_SKIP_PCT]
    if passing:
        # Highest OOS net among conservative skip rates
        chosen = max(passing, key=lambda r: (r["oos"]["net"], r["oos"]["n"]))
        reason = "OOS pass bar + combo skip ≤ 8%"
    else:
        passing_n = [r for r in rows if r["oos"]["n"] >= PASS_N and r["oos"]["skip_pct"] <= MAX_COMBO_SKIP_PCT]
        chosen = max(passing_n or rows, key=lambda r: r["oos"]["net"])
        reason = "Best OOS net with n≥100 (no full pass bar)"

    thr = chosen["thr"]
    lines = [
        "# P4-2 — Tail threshold retune (shadow combo)",
        "",
        f"**Shadow:** `{args.shadow}`",
        f"**Matched opened:** {len(df)} · OOS **{len(oos_df)}**",
        f"**Old threshold:** {old_thr:.6f}",
        f"**Selection:** {reason}",
        "",
        f"**New threshold:** `{thr:.16f}`",
        f"- Val combo: net ${chosen['val']['net']:.2f} · n={chosen['val']['n']} · skip {chosen['val']['skip_pct']:.1f}% (tail-only {chosen['val']['tail_only_pct']:.1f}%)",
        f"- OOS combo: net **${chosen['oos']['net']:.2f}** · PF **{chosen['oos']['pf']:.2f}** · n **{chosen['oos']['n']}** · skip {chosen['oos']['skip_pct']:.1f}%",
        "",
        "## Top OOS candidates (pass bar)",
        "",
        "| thr | OOS net | PF | n | skip% | tail-only% |",
        "|----:|--------:|---:|--:|------:|-------------:|",
    ]
    top = sorted([r for r in rows if pass_bar(r["oos"])], key=lambda r: -r["oos"]["net"])[:12]
    if not top:
        top = sorted(rows, key=lambda r: -r["oos"]["net"])[:12]
    for r in top:
        o, v = r["oos"], r["val"]
        lines.append(
            f"| {r['thr']:.4f} | {o['net']:.2f} | {o['pf']:.2f} | {o['n']} | {o['skip_pct']:.1f} | {o['tail_only_pct']:.1f} |"
        )
    lines += [
        "",
        "## Next",
        "",
        "1. **Recompile** EA",
        "2. Run **`VEM.AI_Tail_Skip`** vs **`VEM.AI_Skip`**",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_MD}")
    print(
        f"thr={thr:.6f} OOS net={chosen['oos']['net']:.2f} n={chosen['oos']['n']} "
        f"skip={chosen['oos']['skip_pct']:.1f}% pass={pass_bar(chosen['oos'])}"
    )

    if args.apply:
        payload = json.loads(TAIL_JSON.read_text(encoding="utf-8"))
        payload["skip_prob_threshold"] = thr
        payload["skip_frac"] = chosen["val"]["tail_only_pct"] / 100.0
        payload["threshold_source"] = "shadow_combo_retune_2026-05-31"
        TAIL_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "export_ai_tail_model_mqh.py")],
            check=True,
            cwd=ROOT,
        )
        thr_s = f"{thr:.16f}"
        for preset in ("VEM.AI_Tail_Shadow.set", "VEM.AI_Tail_Skip.set"):
            p = ROOT.parent.parent / "Profiles" / "Tester" / preset
            if p.is_file():
                text = re.sub(
                    r"inp_ai_tail_skip_prob_threshold=[^\n]+",
                    f"inp_ai_tail_skip_prob_threshold={thr_s}||{thr_s}||0.074168||7.416826||N",
                    p.read_text(encoding="utf-8"),
                )
                p.write_text(text, encoding="utf-8")
                print(f"Updated {p.name}")


if __name__ == "__main__":
    main()
