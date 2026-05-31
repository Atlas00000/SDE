#!/usr/bin/env python3
"""B7 — Quality labels v2 + B9 QA for C2 trade archive."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data" / "c2"
MANIFEST = DATA_DIR / "manifest.json"
RULES = DATA_DIR / "label_rules.json"
OUT_MD = ROOT / "step-b7-results.md"

ENTRY_ONLY_COLS = [
    "rsi",
    "bb_width_ratio",
    "vol_ratio",
    "spread_pts",
    "entry_hour",
    "entry_dow",
    "rsi_depth",
    "bb_walk_count",
    "wick_pct",
    "ema_slope_bp",
    "atr_ratio",
    "bb_pen_pts",
    "htf_slope_bp",
]


def clean_r(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").replace(-1, np.nan)


def load_rules() -> dict:
    return json.loads(RULES.read_text(encoding="utf-8"))


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def archived_csv_path() -> Path:
    m = load_manifest()
    name = m.get("archived_csv")
    if not name:
        raise SystemExit("No archived_csv in data/c2/manifest.json — run c2_trade_log.py archive")
    return DATA_DIR / name


def split_tag(df: pd.DataFrame, train_end: str, val_end: str) -> pd.Series:
    t = pd.to_datetime(df["entry_time"])
    return np.where(
        t <= train_end,
        "train",
        np.where(t <= val_end, "val", "test"),
    )


def label_bad_entry(df: pd.DataFrame, mae_thresh: float = 0.5) -> pd.Series:
    exit_t = df["exit_type"].astype(str)
    mae = clean_r(df["mae_r"]).fillna(0.0)
    profit = df["profit"].astype(float)
    sl = exit_t == "sl"
    e8c_bad = (exit_t == "e8c") & (mae >= mae_thresh)
    deep_loss = (profit <= 0) & (mae >= mae_thresh)
    return (sl | e8c_bad | deep_loss).astype(int)


def label_tail_loss(df: pd.DataFrame, mae_thresh: float = 0.75) -> pd.Series:
    exit_t = df["exit_type"].astype(str)
    mae = clean_r(df["mae_r"]).fillna(0.0)
    return ((exit_t == "sl") | (mae >= mae_thresh)).astype(int)


def label_early_cut(df: pd.DataFrame) -> pd.Series:
    mae_b6 = clean_r(df["mae_r_b6"])
    mfe_b6 = clean_r(df["mfe_r_b6"])
    mae_b4 = clean_r(df["mae_r_b4"])
    mfe_b4 = clean_r(df["mfe_r_b4"])
    cut_b6 = mae_b6.notna() & mfe_b6.notna() & (mfe_b6 <= 0.20) & (mae_b6 >= 0.50)
    cut_b4 = mae_b4.notna() & mfe_b4.notna() & (mfe_b4 <= 0.15) & (mae_b4 >= 0.45)
    return (cut_b6 | cut_b4).astype(int)


def label_early_cut_b4(df: pd.DataFrame) -> pd.Series:
    mae_b4 = clean_r(df["mae_r_b4"])
    mfe_b4 = clean_r(df["mfe_r_b4"])
    ok = mae_b4.notna() & mfe_b4.notna()
    return (ok & (mfe_b4 <= 0.15) & (mae_b4 >= 0.45)).astype(int)


def label_early_cut_b6(df: pd.DataFrame) -> pd.Series:
    mae_b6 = clean_r(df["mae_r_b6"])
    mfe_b6 = clean_r(df["mfe_r_b6"])
    ok = mae_b6.notna() & mfe_b6.notna()
    return (ok & (mfe_b6 <= 0.20) & (mae_b6 >= 0.50)).astype(int)


def label_regime(df: pd.DataFrame) -> pd.Series:
    slope = pd.to_numeric(df.get("htf_slope_bp", 0), errors="coerce").fillna(0.0)
    width = pd.to_numeric(df["bb_width_ratio"], errors="coerce").fillna(0.0)
    walk = pd.to_numeric(df.get("bb_walk_count", 0), errors="coerce").fillna(0).astype(int)
    wick = pd.to_numeric(df.get("wick_pct", 0), errors="coerce").fillna(0.0)

    tags = np.full(len(df), "range", dtype=object)
    tags[(walk >= 3) & (wick < 12.0)] = "chop"
    tags[width >= 0.00165] = "volatile"
    tags[np.abs(slope) >= 6.0] = "trend"
    return pd.Series(tags, index=df.index)


def _profile_flags(df: pd.DataFrame) -> tuple[pd.Series, pd.Series]:
    is_sell = df["side"].astype(str).str.lower() == "sell"
    rsi_d = pd.to_numeric(df["rsi_depth"], errors="coerce").fillna(0.0)
    wick = pd.to_numeric(df["wick_pct"], errors="coerce").fillna(0.0)
    vol = pd.to_numeric(df["vol_ratio"], errors="coerce").fillna(0.0)
    ema = pd.to_numeric(df["ema_slope_bp"], errors="coerce").fillna(0.0)
    htf = pd.to_numeric(df.get("htf_slope_bp", 0), errors="coerce").fillna(0.0)
    walk = pd.to_numeric(df["bb_walk_count"], errors="coerce").fillna(0).astype(int)

    good = np.zeros(len(df), dtype=int)
    good += (rsi_d >= 2.0).astype(int)
    good += (wick >= 15.0).astype(int)
    good += (vol >= 1.5).astype(int)
    good += (np.abs(ema) <= 5.0).astype(int)
    good += ((walk >= 1) & (walk <= 2)).astype(int)

    bad = np.zeros(len(df), dtype=int)
    bad += np.where(is_sell, (ema > 5.0).astype(int), (ema < -5.0).astype(int))
    bad += (walk >= 3).astype(int)
    bad += (wick < 10.0).astype(int)
    bad += np.where(is_sell, (htf > 6.0).astype(int), (htf < -6.0).astype(int))

    label_good = (good >= 3).astype(int)
    label_bad = (bad >= 2).astype(int)
    return pd.Series(label_good, index=df.index), pd.Series(label_bad, index=df.index)


def apply_b7_labels(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    d["label_bad_entry"] = label_bad_entry(d)
    d["label_tail_loss"] = label_tail_loss(d)
    d["label_early_cut_b4"] = label_early_cut_b4(d)
    d["label_early_cut_b6"] = label_early_cut_b6(d)
    d["label_early_cut"] = label_early_cut(d)
    d["label_regime"] = label_regime(d)
    d["label_profile_good"], d["label_profile_bad"] = _profile_flags(d)

    d["label_bad_trade"] = d["label_bad_entry"]
    d["label_loss"] = (d["profit"].astype(float) <= 0).astype(int)
    d["label_sl"] = (d["exit_type"].astype(str) == "sl").astype(int)
    return d


def qa_report(df: pd.DataFrame) -> str:
    m = load_manifest()
    train_end = m["splits"]["train_end"]
    val_end = m["splits"]["val_end"]
    df = df.copy()
    df["split"] = split_tag(df, train_end, val_end)

    lines = [
        "# B7 — Quality labels results",
        "",
        f"**Source:** `data/c2/{m.get('archived_csv', '')}`",
        f"**Rules:** `data/c2/label_rules.json`",
        f"**Trades:** {len(df)}",
        "",
        "## Label prevalence (all)",
        "",
        "| Label | % positive | n |",
        "|-------|------------|---|",
    ]
    for col in [
        "label_bad_entry",
        "label_tail_loss",
        "label_early_cut",
        "label_early_cut_b4",
        "label_early_cut_b6",
        "label_profile_good",
        "label_profile_bad",
        "label_loss",
        "label_sl",
    ]:
        if col not in df.columns:
            continue
        s = df[col].astype(int)
        lines.append(f"| {col} | {s.mean() * 100:.1f}% | {int(s.sum())} |")

    lines += ["", "## By split", "", "| Split | n | bad_entry% | early_cut% | profile_bad% | net $ |", "|-------|---|------------|--------------|--------------|-------|"]
    for sp in ("train", "val", "test"):
        g = df[df["split"] == sp]
        if g.empty:
            continue
        lines.append(
            f"| {sp} | {len(g)} | {g['label_bad_entry'].mean()*100:.1f}% | "
            f"{g['label_early_cut'].mean()*100:.1f}% | {g['label_profile_bad'].mean()*100:.1f}% | "
            f"${g['profit'].astype(float).sum():.2f} |"
        )

    lines += ["", "## Regime mix", "", "```", str(df["label_regime"].value_counts().to_dict()), "```", ""]

    lines += [
        "## Outcome vs profile (entry-only proxies)",
        "",
        "| | bad_entry rate | n |",
        "|--|----------------|---|",
    ]
    for name, mask in [
        ("profile_good=1", df["label_profile_good"] == 1),
        ("profile_good=0", df["label_profile_good"] == 0),
        ("profile_bad=1", df["label_profile_bad"] == 1),
        ("profile_bad=0", df["label_profile_bad"] == 0),
    ]:
        g = df[mask]
        if len(g) == 0:
            continue
        lines.append(f"| {name} | {g['label_bad_entry'].mean()*100:.1f}% | {len(g)} |")

    lines += [
        "",
        "## Leakage checklist (B9)",
        "",
        "- Entry skip (**AI-6**): use **entry columns only** — see `label_rules.json` → `leakage.entry_models_may_use`",
        "- Exit model (**P4-5**): may use `mae_r_b4/b6`, `mfe_r_b4/b6`, `label_early_cut`",
        "- `label_bad_entry` / `label_tail_loss` use **post-trade** outcome — **do not** feed into entry features",
        "",
        "## Exit cross-tab (bad_entry)",
        "",
        "```",
    ]
    ct = pd.crosstab(df["exit_type"], df["label_bad_entry"])
    lines.append(ct.to_string())
    lines += ["```", "", "---", "", "*Next: **AI-6** train XGB on entry features → `label_bad_entry`*", ""]

    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser(description="B7 labels + B9 QA")
    ap.add_argument("--csv", default=None, help="Archived C2 CSV (default from manifest)")
    ap.add_argument("--out", default=None, help="Labeled CSV out path")
    ap.add_argument("--qa-only", action="store_true", help="Skip write if labeled file exists")
    args = ap.parse_args()

    src = Path(args.csv) if args.csv else archived_csv_path()
    df = pd.read_csv(src)
    df["entry_time"] = pd.to_datetime(df["entry_time"])
    labeled = apply_b7_labels(df)

    out = Path(args.out) if args.out else DATA_DIR / (
        load_manifest().get("labeled_csv") or src.stem + "_labeled.csv"
    )
    if not args.qa_only:
        labeled.to_csv(out, index=False)
        print(f"Wrote {len(labeled)} rows -> {out}")

    report = qa_report(labeled)
    OUT_MD.write_text(report, encoding="utf-8")
    print(f"Wrote {OUT_MD}")

    m = load_manifest()
    m["b7_status"] = "done"
    m["labeled_csv"] = out.name
    m["label_rules"] = "label_rules.json"
    m["label_counts"] = {
        "bad_entry_pct": round(float(labeled["label_bad_entry"].mean()) * 100, 1),
        "early_cut_pct": round(float(labeled["label_early_cut"].mean()) * 100, 1),
        "profile_bad_pct": round(float(labeled["label_profile_bad"].mean()) * 100, 1),
    }
    MANIFEST.write_text(json.dumps(m, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
