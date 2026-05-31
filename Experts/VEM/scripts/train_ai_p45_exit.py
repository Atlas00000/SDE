#!/usr/bin/env python3
"""P4-5 — bar-4/6 early-cut exit model (label_early_cut) on C2 archive."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
LABELED = ROOT / "data" / "c2" / "VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv"
MANIFEST = ROOT / "data" / "c2" / "manifest.json"
OUT_JSON = ROOT / "models" / "ai_p45_exit_logistic.json"
OUT_MD = ROOT / "step-p45-exit-results.md"

ENTRY_FEATS = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
    "side_sell",
    "rsi_depth",
    "bb_walk_count",
    "wick_pct",
    "ema_slope_bp",
    "atr_ratio",
    "bb_pen_pts",
    "htf_slope_bp",
]
PASS_NET = 9.08
PASS_PF = 1.30
MAX_EXIT_PCT_VAL = 20


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def clean_r(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s, errors="coerce").replace(-1, np.nan)


def calibrate_usd_per_r(df: pd.DataFrame) -> float:
    sl = df["exit_type"].astype(str) == "sl"
    mae = clean_r(df["mae_r"])
    sub = df[sl & mae.notna() & (mae > 0.05)]
    if len(sub) >= 5:
        return float((sub["profit"].astype(float).abs() / mae[sub.index]).median())
    sl_pts = pd.to_numeric(df.get("sl_pts", 200), errors="coerce").fillna(200.0)
    return float((sl_pts * 0.01).median())


def r_at_bar(row: pd.Series, bar: int) -> float:
    mae = float(row[f"mae_r_b{bar}"])
    mfe = float(row[f"mfe_r_b{bar}"])
    return mfe if mfe >= mae else -mae


def profit_at_bar(row: pd.Series, bar: int, usd_per_r: float) -> float:
    return r_at_bar(row, bar) * usd_per_r


def prepare(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["side_sell"] = (d["side"].astype(str).str.lower() == "sell").astype(int)
    for bar in (4, 5, 6):
        d[f"mae_r_b{bar}"] = clean_r(d[f"mae_r_b{bar}"])
        d[f"mfe_r_b{bar}"] = clean_r(d[f"mfe_r_b{bar}"])
    d["mae_r"] = clean_r(d["mae_r"])
    d["mfe_r"] = clean_r(d["mfe_r"])
    d["has_b4"] = d["mae_r_b4"].notna() & d["mfe_r_b4"].notna()
    d["has_b6"] = d["mae_r_b6"].notna() & d["mfe_r_b6"].notna()
    if "mae_r_b5" in d.columns:
        d["mae_delta_b4_b6"] = d["mae_r_b6"] - d["mae_r_b4"]
        d["mfe_delta_b4_b6"] = d["mfe_r_b6"] - d["mfe_r_b4"]
    return d


def feats_for_bar(bar: int) -> list[str]:
    path = [f"mae_r_b{bar}", f"mfe_r_b{bar}"]
    if bar >= 6:
        path += ["mae_r_b5", "mfe_r_b5", "mae_delta_b4_b6", "mfe_delta_b4_b6"]
    return ENTRY_FEATS + path


def sim_early_exit(
    part: pd.DataFrame,
    prob: np.ndarray,
    thr: float,
    bar: int,
    usd_per_r: float,
    path_mask: pd.Series,
) -> dict:
    profits = part["profit"].astype(float).values.copy()
    sub_idx = path_mask.values
    exit_mask = np.zeros(len(part), dtype=bool)
    for i in range(len(part)):
        if not sub_idx[i]:
            continue
        if prob[i] >= thr:
            exit_mask[i] = True
            profits[i] = profit_at_bar(part.iloc[i], bar, usd_per_r)
    return {
        "n": len(profits),
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "exited": int(exit_mask.sum()),
        "avg_loss": float(profits[profits < 0].mean()) if (profits < 0).any() else 0.0,
    }


def sim_rule_oracle(part: pd.DataFrame, bar: int, usd_per_r: float) -> dict:
    """Oracle: exit when B7 rule label_early_cut_bN would fire."""
    col = f"label_early_cut_b{bar}" if f"label_early_cut_b{bar}" in part.columns else "label_early_cut"
    thr_prob = np.ones(len(part))
    mask = part[f"has_b{bar}"] if bar == 4 else part["has_b6"]
    y = part[col].astype(int).values if col in part.columns else part["label_early_cut"].astype(int).values
    fake_prob = np.where(y == 1, 1.0, 0.0)
    return sim_early_exit(part, fake_prob, 0.5, bar, usd_per_r, mask)


def export_json(pipe: Pipeline, feats: list[str], bar: int, thr: float, usd_per_r: float) -> dict:
    scaler = pipe.named_steps["scaler"]
    clf = pipe.named_steps["clf"]
    return {
        "version": "p45_c2",
        "bar_index": bar,
        "target": "label_early_cut",
        "features": feats,
        "intercept": float(clf.intercept_[0]),
        "coef": {f: float(c) for f, c in zip(feats, clf.coef_[0])},
        "scaler_mean": {f: float(m) for f, m in zip(feats, scaler.mean_)},
        "scaler_scale": {f: float(s) for f, s in zip(feats, scaler.scale_)},
        "exit_prob_threshold": thr,
        "usd_per_r": usd_per_r,
        "policy": f"At bar {bar}: if P(early_cut)>=thr, close at MTM R",
    }


def run_bar(bar: int, csv_path: str) -> dict:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    train_end = m["splits"]["train_end"]
    val_end = m["splits"]["val_end"]
    oos = m["oos_pass_window"]

    raw = pd.read_csv(csv_path)
    raw["entry_time"] = pd.to_datetime(raw["entry_time"])
    raw = raw[~raw["exit_type"].astype(str).isin({"e10"})]
    df = prepare(raw)
    usd_per_r = calibrate_usd_per_r(df)

    feats = feats_for_bar(bar)
    path_col = f"has_b{bar}" if bar == 4 else "has_b6"
    cohort = df[df[path_col]].copy()
    target = "label_early_cut"

    train = cohort[cohort["entry_time"] <= train_end]
    val = cohort[(cohort["entry_time"] > train_end) & (cohort["entry_time"] <= val_end)]
    test = cohort[cohort["entry_time"] > val_end]
    test_oos = test[
        (test["entry_time"] >= oos["start"]) & (test["entry_time"] < oos["end"])
    ]

    test_full = df[df["entry_time"] > val_end]
    test_oos_full = test_full[
        (test_full["entry_time"] >= oos["start"]) & (test_full["entry_time"] < oos["end"])
    ]

    X_train = train[feats].astype(float)
    y_train = train[target].astype(int)
    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(max_iter=2000, class_weight="balanced", random_state=42)),
        ]
    )
    pipe.fit(X_train, y_train)

    val_prob = pipe.predict_proba(val[feats].astype(float))[:, 1] if len(val) else np.array([])
    test_prob_full = np.zeros(len(test_oos_full))
    path_mask_oos = test_oos_full[path_col].values
    if test_oos_full[path_col].any():
        idx = test_oos_full[path_col]
        test_prob_full[idx.values] = pipe.predict_proba(test_oos_full.loc[idx, feats].astype(float))[:, 1]

    val_base = float(val["profit"].sum()) if len(val) else 0.0
    best_thr = 1.0
    best_val_net = val_base
    max_exits = max(1, int(len(val) * MAX_EXIT_PCT_VAL / 100)) if len(val) else 0
    for pct in range(55, 100, 2):
        thr = float(np.percentile(val_prob, pct)) if len(val_prob) else 1.0
        s = sim_early_exit(val, val_prob, thr, bar, usd_per_r, val[path_col])
        if s["exited"] > max_exits or s["exited"] == 0:
            continue
        if s["net"] > best_val_net:
            best_val_net = s["net"]
            best_thr = thr

    base_profits = test_oos_full["profit"].astype(float).values
    base = {
        "net": float(base_profits.sum()),
        "pf": pf(base_profits),
        "wr": float((base_profits > 0).mean() * 100),
        "n": len(base_profits),
    }

    sim = sim_early_exit(test_oos_full, test_prob_full, best_thr, bar, usd_per_r, test_oos_full[path_col])
    oracle = sim_rule_oracle(test_oos_full[test_oos_full[path_col]], bar, usd_per_r)

    sweep = []
    best_oos = base["net"]
    best_pct = 100.0
    for pct in range(55, 100, 2):
        thr = float(np.percentile(val_prob, pct)) if len(val_prob) else 1.0
        s = sim_early_exit(test_oos_full, test_prob_full, thr, bar, usd_per_r, test_oos_full[path_col])
        sweep.append(f"| {pct} | {thr:.4f} | {s['net']:.2f} | {s['pf']:.2f} | {s['exited']} |")
        if s["net"] > best_oos:
            best_oos = s["net"]
            best_pct = pct

    wire_thr = best_thr
    if best_oos <= base["net"] + 0.01:
        wire_thr = 1.0
        sim = sim_early_exit(test_oos_full, test_prob_full, wire_thr, bar, usd_per_r, test_oos_full[path_col])

    oos_pass_c2 = sim["net"] >= base["net"] + 0.01 and sim["pf"] >= base["pf"]
    oos_pass_prod = sim["net"] >= PASS_NET and sim["pf"] >= PASS_PF and sim["wr"] >= 65

    try:
        val_auc = roc_auc_score(val[target], val_prob) if len(val) else float("nan")
    except ValueError:
        val_auc = float("nan")
    try:
        test_auc = (
            roc_auc_score(test_oos[target], test_prob_full[test_oos_full[path_col].values])
            if len(test_oos)
            else float("nan")
        )
    except ValueError:
        test_auc = float("nan")

    payload = export_json(pipe, feats, bar, wire_thr, usd_per_r)
    payload["offline_recommendation"] = "tester_shadow" if wire_thr < 0.999 and oos_pass_c2 else "no_wire"
    payload["val_auc"] = val_auc
    payload["test_auc"] = test_auc

    lines = [
        f"# P4-5 — Early-cut exit @ bar {bar} (`label_early_cut`)",
        "",
        f"**Source:** `{csv_path}` · path cohort n={len(cohort)} / all n={len(df)}",
        f"**usd/R:** {usd_per_r:.3f} · **target rate:** {cohort[target].mean()*100:.1f}%",
        "",
        "## Model",
        "",
        f"- Val AUC: **{val_auc:.3f}** · Test AUC: **{test_auc:.3f}**",
        f"- Tuned `exit_prob_threshold`: **{wire_thr:.4f}** (val pct ~{best_pct:.0f})",
        "",
        "## OOS ({oos['start']} → {oos['end']}, n={len(test_oos_full)})",
        "",
        "| Policy | Net $ | PF | WR % | early exits | avg loss $ |",
        "|--------|------:|---:|-----:|------------:|-----------:|",
        f"| Production (actual) | {base['net']:.2f} | {base['pf']:.2f} | {base['wr']:.1f} | 0 | "
        f"{base_profits[base_profits<0].mean() if (base_profits<0).any() else 0:.2f} |",
        f"| ML exit @ bar {bar} | {sim['net']:.2f} | {sim['pf']:.2f} | {sim['wr']:.1f} | {sim['exited']} | {sim['avg_loss']:.2f} |",
        f"| Rule oracle (B7 @ b{bar}) | {oracle['net']:.2f} | {oracle['pf']:.2f} | {oracle['wr']:.1f} | {oracle['exited']} | {oracle['avg_loss']:.2f} |",
        "",
        f"- Beats C2 OOS baseline: **{'Y' if oos_pass_c2 else 'N'}**",
        f"- Meets C1 pass bar ($9.08 / PF 1.30): **{'Y' if oos_pass_prod else 'N'}**",
        f"- **Wire:** `{payload['offline_recommendation']}`",
        "",
        "## Threshold sweep (full OOS)",
        "",
        "| val pct | thr | Net $ | PF | exited |",
        "|--------:|----:|------:|---:|-------:|",
        *sweep,
        "",
        f"Export: `models/ai_p45_exit_b{bar}_logistic.json`",
        "",
    ]
    out_md = ROOT / f"step-p45-exit-b{bar}-results.md"
    out_json = ROOT / f"models/ai_p45_exit_b{bar}_logistic.json"
    out_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    out_md.write_text("\n".join(lines), encoding="utf-8")
    print(f"bar={bar} val_auc={val_auc:.3f} test_auc={test_auc:.3f} thr={wire_thr:.4f}")
    print(f"OOS net base={base['net']:.2f} sim={sim['net']:.2f} oracle={oracle['net']:.2f} wire={payload['offline_recommendation']}")
    print(f"Wrote {out_md} {out_json}")
    return {"bar": bar, "wire": payload["offline_recommendation"], "sim_net": sim["net"], "base_net": base["net"]}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(LABELED))
    ap.add_argument("--bar", type=int, default=0, help="4, 6, or 0=both")
    args = ap.parse_args()
    bars = [4, 6] if args.bar == 0 else [args.bar]
    summary = [run_bar(b, args.csv) for b in bars]
    summary_md = ROOT / "step-p45-exit-results.md"
    lines = ["# P4-5 — Early-cut exit summary", ""]
    for s in summary:
        lines.append(
            f"- Bar **{s['bar']}**: base ${s['base_net']:.2f} → sim ${s['sim_net']:.2f} · **{s['wire']}**"
        )
    lines.append("")
    summary_md.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {summary_md}")


if __name__ == "__main__":
    main()
