#!/usr/bin/env python3
"""AI-4-001: Merge path export with decisions dataset."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from policy import DEFAULT_DATASET, executed_mask, prepare_features

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_paths_v1.parquet"


def build(decisions: Path, paths: Path | None) -> pd.DataFrame:
    raw = prepare_features(pd.read_parquet(decisions))
    trades = raw.loc[executed_mask(raw)].copy()
    trades["sess_key"] = trades["bar_time_gmt"].dt.date.astype(str) + "_" + trades["session"]

    if paths and paths.exists():
        p = pd.read_csv(paths, encoding="utf-8-sig")
        p["position_id"] = pd.to_numeric(p["position_id"], errors="coerce").astype("Int64")
        trades["position_id"] = pd.to_numeric(trades["position_id"], errors="coerce").astype("Int64")
        df = trades.merge(p, on="position_id", how="left", suffixes=("", "_path"))
    else:
        df = trades.copy()
        df["mfe_frac"] = pd.NA
        df["mfe_at_45"] = pd.NA

    return df.sort_values("bar_time_gmt").reset_index(drop=True)


def add_proxy_paths(df: pd.DataFrame) -> pd.DataFrame:
    """Bootstrap path features from entry + outcome when path CSV missing."""
    out = df.copy()
    rw = out["range_width"].astype(float).replace(0, pd.NA)
    profit = out["profit"].astype(float)
    win = out["label_win"] == 1

    out["mfe_frac_proxy"] = (profit / rw).clip(lower=0.0, upper=2.0)
    out.loc[~win, "mfe_frac_proxy"] = out.loc[~win, "vol_ratio"].apply(
        lambda v: max(0.05, 0.35 - 0.08 * min(v, 3.0))
    )
    out["mfe_at_45_proxy"] = out["mfe_frac_proxy"] * rw
    out["mfe_frac"] = out["mfe_frac"].fillna(out["mfe_frac_proxy"])
    out["mfe_at_45"] = out["mfe_at_45"].fillna(out["mfe_at_45_proxy"])
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Build AI-4 path dataset")
    parser.add_argument("decisions", type=Path, nargs="?", default=DEFAULT_DATASET)
    parser.add_argument("paths", type=Path, nargs="?", default=None)
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    df = build(args.decisions, args.paths)
    if df["mfe_frac"].isna().all():
        df = add_proxy_paths(df)
        print("WARN: no path CSV — using proxy mfe features")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(args.output, index=False)
    print(f"Rows: {len(df)} | wrote {args.output}")


if __name__ == "__main__":
    main()
