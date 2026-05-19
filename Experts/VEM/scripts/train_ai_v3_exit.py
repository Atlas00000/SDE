#!/usr/bin/env python3
"""P4-3/P4-4 — AI v0.3 bar-6 invalidation model + offline early-exit sim."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, classification_report, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "data" / "c1" / "VEM_trades_EURUSD_M5_prod_2023_2026_396.csv"
MATRIX = ROOT / "data" / "c1" / "ai_v3_bar_matrix.csv"
MANIFEST = ROOT / "data" / "c1" / "manifest.json"
OUT_JSON = ROOT / "models" / "ai_v3_exit_logistic.json"
OUT_MD = ROOT / "step-ai-v3-exit-results.md"

FEATURES = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
    "side_sell",
    "rsi_depth",
    "mae_r_b5",
    "mfe_r_b5",
    "mae_r_b6",
    "mfe_r_b6",
    "mae_delta_b5_b6",
    "mfe_delta_b5_b6",
]
PASS_NET = 9.08
PASS_PF = 1.30
BAR_EXIT = 6
MAX_EXIT_PCT_VAL = 25  # cap early exits on val when tuning threshold


def pf(profits: np.ndarray) -> float:
    wins = profits[profits > 0].sum()
    losses = -profits[profits < 0].sum()
    if losses <= 0:
        return float("inf") if wins > 0 else 0.0
    return float(wins / losses)


def clean_r(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").replace(-1, np.nan)


def calibrate_usd_per_r(df: pd.DataFrame) -> float:
    sl = df["exit_type"].astype(str) == "sl"
    mae = clean_r(df["mae_r"])
    sub = df[sl & (mae > 0.05)]
    if len(sub) >= 5:
        return float((sub["profit"].astype(float).abs() / mae[sl & (mae > 0.05)]).median())
    sl_pts = pd.to_numeric(df.get("sl_pts", 200), errors="coerce").fillna(200.0)
    return float((sl_pts * 0.01).median())


def r_at_bar6(row: pd.Series) -> float:
    mae6 = float(row["mae_r_b6"])
    mfe6 = float(row["mfe_r_b6"])
    return mfe6 if mfe6 >= mae6 else -mae6


def profit_at_bar6(row: pd.Series, usd_per_r: float) -> float:
    return r_at_bar6(row) * usd_per_r


def load_splits() -> tuple[str, str, dict]:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sp = m["splits"]
    return sp["train_end"], sp["val_end"], m.get("oos_pass_window", {})


def load_matrix(archive_path: Path, matrix_path: Path) -> pd.DataFrame:
    arch = pd.read_csv(archive_path)
    arch["entry_time"] = pd.to_datetime(arch["entry_time"], utc=True)
    arch = arch[~arch["exit_type"].astype(str).isin({"e10"})].copy()
    for c in ["mae_r", "mfe_r", "sl_pts"]:
        if c in arch.columns:
            arch[c] = clean_r(arch[c]) if c.startswith("mae") or c.startswith("mfe") else pd.to_numeric(
                arch[c], errors="coerce"
            )

    mat = pd.read_csv(matrix_path)
    mat["entry_time"] = pd.to_datetime(mat["entry_time"], utc=True)
    extra = arch[
        ["entry_time", "mae_r", "mfe_r", "sl_pts", "bars_held", "exit_type"]
    ].drop_duplicates(subset=["entry_time"])
    df = mat.merge(extra, on="entry_time", how="left", suffixes=("", "_arch"))
    if "exit_type_arch" in df.columns:
        df["exit_type"] = df["exit_type"].fillna(df["exit_type_arch"])
        df.drop(columns=["exit_type_arch"], inplace=True)
    return df


def export_logistic_json(
    pipe: Pipeline,
    feats: list[str],
    exit_thr: float,
    exit_pct_val: float,
    usd_per_r: float,
) -> dict:
    scaler = pipe.named_steps["scaler"]
    clf = pipe.named_steps["clf"]
    return {
        "version": "v0.3",
        "bar_index": BAR_EXIT,
        "features": feats,
        "intercept": float(clf.intercept_[0]),
        "coef": {f: float(c) for f, c in zip(feats, clf.coef_[0])},
        "scaler_mean": {f: float(m) for f, m in zip(feats, scaler.mean_)},
        "scaler_scale": {f: float(s) for f, s in zip(feats, scaler.scale_)},
        "exit_prob_threshold": exit_thr,
        "exit_val_percentile": exit_pct_val,
        "usd_per_r": usd_per_r,
        "policy": f"At bar {BAR_EXIT}: if P(invalid)>=threshold, close at MTM R (mfe6 vs mae6); else rules exit",
        "label": "label_invalid",
    }


def sim_full_oos(
    test_oos: pd.DataFrame,
    b6: pd.DataFrame,
    prob_map: dict[pd.Timestamp, float],
    exit_thr: float,
    usd_per_r: float,
) -> tuple[np.ndarray, dict]:
    """Apply bar-6 exit only where path exists; others keep actual profit."""
    profits = test_oos["profit"].astype(float).values.copy()
    exited = 0
    improved = 0
    b6_lookup = b6.set_index("entry_time")
    for i, row in test_oos.reset_index(drop=True).iterrows():
        et = row["entry_time"]
        if et not in prob_map or et not in b6_lookup.index:
            continue
        if prob_map[et] < exit_thr:
            continue
        path_row = b6_lookup.loc[et]
        if isinstance(path_row, pd.DataFrame):
            path_row = path_row.iloc[0]
        p6 = profit_at_bar6(path_row, usd_per_r)
        if p6 > profits[i]:
            improved += 1
        profits[i] = p6
        exited += 1
    stats = {
        "n": len(profits),
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "exited_b6": exited,
        "improved_vs_hold": improved,
    }
    losers = profits[profits < 0]
    stats["avg_loss"] = float(losers.mean()) if len(losers) else 0.0
    return profits, stats


def sim_b6_subset(
    part: pd.DataFrame,
    prob: np.ndarray,
    exit_thr: float,
    usd_per_r: float,
) -> dict:
    profits = part["profit"].astype(float).values.copy()
    p6 = np.array([profit_at_bar6(part.iloc[i], usd_per_r) for i in range(len(part))])
    exit_mask = prob >= exit_thr
    profits[exit_mask] = p6[exit_mask]
    kept = ~exit_mask
    return {
        "n": len(profits),
        "net": float(profits.sum()),
        "pf": pf(profits),
        "wr": float((profits > 0).mean() * 100),
        "exited": int(exit_mask.sum()),
        "avg_loss": float(profits[profits < 0].mean()) if (profits < 0).any() else 0.0,
        "hold_n": int(kept.sum()),
    }


def avg_loss_r(part: pd.DataFrame) -> float:
    losers = part[part["profit"].astype(float) < 0]
    if len(losers) == 0:
        return 0.0
    mae = clean_r(losers["mae_r"]).replace(0, np.nan)
    return float((losers["profit"].astype(float).abs() / mae).mean())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", default=str(ARCHIVE))
    ap.add_argument("--matrix", default=str(MATRIX))
    ap.add_argument("--out-md", default=str(OUT_MD))
    ap.add_argument("--out-json", default=str(OUT_JSON))
    args = ap.parse_args()

    train_end, val_end, oos_win = load_splits()
    df = load_matrix(Path(args.archive), Path(args.matrix))
    usd_per_r = calibrate_usd_per_r(pd.read_csv(args.archive))

    df["profit_b6"] = df.apply(lambda r: profit_at_bar6(r, usd_per_r), axis=1)
    df["r_b6"] = df.apply(r_at_bar6, axis=1)

    train = df[df["split"] == "train"]
    val = df[df["split"] == "val"]
    test_b6 = df[df["split"] == "test"]

    X_train = train[FEATURES].astype(float)
    y_train = train["label_invalid"].astype(int)
    pipe = Pipeline(
        [
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(max_iter=2000, class_weight="balanced", random_state=42)),
        ]
    )
    pipe.fit(X_train, y_train)

    val_prob = pipe.predict_proba(val[FEATURES].astype(float))[:, 1] if len(val) else np.array([])
    test_prob = pipe.predict_proba(test_b6[FEATURES].astype(float))[:, 1] if len(test_b6) else np.array([])

    # Tune exit threshold on val (b6 subset); default thr=1.0 = no wire (safe)
    val_profits_base = val["profit"].astype(float).values
    val_base_net = float(val_profits_base.sum())
    best_thr = 1.0
    best_val_net = val_base_net
    best_pct = 100.0
    max_exits = max(1, int(len(val) * MAX_EXIT_PCT_VAL / 100))
    for pct in range(50, 100):
        thr = float(np.percentile(val_prob, pct)) if len(val_prob) else 1.0
        s = sim_b6_subset(val, val_prob, thr, usd_per_r)
        if s["exited"] > max_exits or s["exited"] == 0:
            continue
        if s["net"] > best_val_net:
            best_val_net = s["net"]
            best_thr = thr
            best_pct = float(pct)

    # Full-archive OOS window (111 trades)
    arch = pd.read_csv(args.archive)
    arch["entry_time"] = pd.to_datetime(arch["entry_time"], utc=True)
    arch = arch[~arch["exit_type"].astype(str).isin({"e10"})]
    test_full = arch[arch["entry_time"] > val_end]
    if oos_win.get("start"):
        test_oos = test_full[
            (test_full["entry_time"] >= oos_win["start"]) & (test_full["entry_time"] < oos_win["end"])
        ].copy()
    else:
        test_oos = test_full.copy()

    prob_map = dict(zip(test_b6["entry_time"], test_prob))
    val_prob_map = dict(zip(val["entry_time"], val_prob))
    for et, p in val_prob_map.items():
        prob_map.setdefault(et, p)
    train_prob = pipe.predict_proba(train[FEATURES].astype(float))[:, 1]
    for et, p in zip(train["entry_time"], train_prob):
        prob_map.setdefault(et, p)

    base_profits = test_oos["profit"].astype(float).values
    base = {
        "n": len(base_profits),
        "net": float(base_profits.sum()),
        "pf": pf(base_profits),
        "wr": float((base_profits > 0).mean() * 100),
        "exited_b6": 0,
        "avg_loss": float(base_profits[base_profits < 0].mean()) if (base_profits < 0).any() else 0.0,
    }
    sim_profits, sim = sim_full_oos(test_oos, test_b6, prob_map, best_thr, usd_per_r)
    b6_only = sim_b6_subset(test_b6, test_prob, best_thr, usd_per_r)

    sweep_rows: list[str] = []
    best_oos_net = base["net"]
    best_oos_pct = 100.0
    for pct in range(50, 100, 2):
        thr = float(np.percentile(val_prob, pct)) if len(val_prob) else 1.0
        _, s_row = sim_full_oos(test_oos, test_b6, prob_map, thr, usd_per_r)
        sweep_rows.append(
            f"| {pct} | {thr:.4f} | {s_row['net']:.2f} | {s_row['pf']:.2f} | {s_row['exited_b6']} |"
        )
        if s_row["net"] > best_oos_net:
            best_oos_net = s_row["net"]
            best_oos_pct = float(pct)

    # Wire only if full OOS beats production; else export safe no-exit threshold
    if best_oos_net <= base["net"] + 0.01 or best_oos_net < PASS_NET:
        best_thr = 1.0
        best_pct = 100.0
        best_val_net = val_base_net
        _, sim = sim_full_oos(test_oos, test_b6, prob_map, best_thr, usd_per_r)
        b6_only = sim_b6_subset(test_b6, test_prob, best_thr, usd_per_r)

    oos_pass = (
        sim["net"] >= PASS_NET
        and sim["pf"] >= PASS_PF
        and sim["wr"] >= 65
        and sim["n"] >= 100
    )

    try:
        val_auc = roc_auc_score(val["label_invalid"], val_prob) if len(val) else float("nan")
    except ValueError:
        val_auc = float("nan")
    try:
        test_auc = roc_auc_score(test_b6["label_invalid"], test_prob) if len(test_b6) else float("nan")
    except ValueError:
        test_auc = float("nan")

    payload = export_logistic_json(pipe, FEATURES, best_thr, best_pct, usd_per_r)
    payload["train_rows_b6"] = int(len(train))
    payload["matrix_rows"] = int(len(df))
    payload["offline_recommendation"] = (
        "no_wire" if best_thr >= 0.999 else "tester_required"
    )
    payload["oos_sweep_best_pct"] = best_oos_pct
    payload["oos_sweep_best_net"] = best_oos_net
    Path(args.out_json).write_text(json.dumps(payload, indent=2), encoding="utf-8")

    # Exit mix on exited OOS trades
    exited_rows = []
    for _, row in test_oos.iterrows():
        et = row["entry_time"]
        if et in prob_map and prob_map[et] >= best_thr and et in test_b6["entry_time"].values:
            exited_rows.append(row["exit_type"])
    exit_mix = pd.Series(exited_rows).value_counts().to_dict() if exited_rows else {}

    lines = [
        "# AI v0.3 — bar-6 exit model (P4-3/P4-4)",
        "",
        f"**Matrix:** `{Path(args.matrix).name}` ({len(df)} rows, bar-{BAR_EXIT} path) · **usd/R:** {usd_per_r:.3f}",
        "",
        "## Model (train on b6 cohort)",
        "",
        f"- Val ROC-AUC: **{val_auc:.3f}** · Test b6 AUC: **{test_auc:.3f}**",
        f"- `exit_prob_threshold`: **{best_thr:.6f}** (val pct **{best_pct:.0f}**)",
        "",
        "### Train classification (0.5)",
        "",
        "```",
        classification_report(
            y_train, (pipe.predict_proba(X_train)[:, 1] >= 0.5).astype(int), zero_division=0
        ).strip(),
        "```",
        "",
        "## Val (b6 subset only)",
        "",
        f"- Baseline net: **${val_profits_base.sum():.2f}** · tuned early-exit net: **${best_val_net:.2f}**",
        "",
        "## Test OOS — full **111** trade window",
        "",
        "| Policy | n | Net $ | PF | WR % | early@b6 | avg loss $ |",
        "|--------|--:|------:|---:|-----:|---------:|-----------:|",
        f"| Production (hold) | {base['n']} | {base['net']:.2f} | {base['pf']:.2f} | {base['wr']:.1f} | 0 | {base['avg_loss']:.2f} |",
        f"| AI exit @ bar {BAR_EXIT} | {sim['n']} | {sim['net']:.2f} | {sim['pf']:.2f} | {sim['wr']:.1f} | {sim['exited_b6']} | {sim['avg_loss']:.2f} |",
        "",
        f"- OOS pass bar @ tuned thr: **{'PASS' if oos_pass else 'FAIL'}** (net≥{PASS_NET}, PF≥{PASS_PF}, WR≥65%, n≥100)",
        f"- Improved vs hold on exited trades: **{sim['improved_vs_hold']}** / {sim['exited_b6']}",
        f"- Exit mix (early-closed): `{exit_mix}`",
        f"- **Offline verdict:** {'**PARK** — no val-tuned thr beats production OOS; export thr=1.0 (no exit)' if best_thr >= 0.999 else 'candidate for P4-5 tester'}",
        "",
        "## OOS threshold sweep (val percentiles → full 111 window)",
        "",
        "| val pct | thr | Net $ | PF | early@b6 |",
        "|--------:|----:|------:|---:|---------:|",
        *sweep_rows,
        "",
        f"- Best sweep net: **${best_oos_net:.2f}** @ pct **{best_oos_pct:.0f}** (still vs prod **${base['net']:.2f}**)",
        "",
        f"## Test OOS — b6-path cohort only ({len(test_b6)} trades)",
        "",
        f"| Policy | n | Net $ | PF | exited |",
        f"|--------|--:|------:|---:|-------:|",
        f"| Hold | {len(test_b6)} | {test_b6['profit'].astype(float).sum():.2f} | {pf(test_b6['profit'].astype(float).values):.2f} | 0 |",
        f"| AI exit | {b6_only['n']} | {b6_only['net']:.2f} | {b6_only['pf']:.2f} | {b6_only['exited']} |",
        "",
        f"Export: `{Path(args.out_json).name}` · wire in EA: **P4-5**",
        "",
    ]
    Path(args.out_md).write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {args.out_json} {args.out_md}")
    print(f"thr={best_thr:.4f} OOS full net={sim['net']:.2f} pf={sim['pf']:.2f} exited={sim['exited_b6']} pass={oos_pass}")


if __name__ == "__main__":
    main()
