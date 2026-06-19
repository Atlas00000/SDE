#!/usr/bin/env python3
"""INF-1-005: Audit ORBVWAP_ai_shadow.csv — detect fail-open / all-neutral SHADOW runs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "schemas" / "ai_shadow.v1.json"
NOT_EVAL = -1.0
NEUTRAL_SCORES = {0.5, 1.0}
AI2_TIERS = {1.0, 1.15, 1.25}


def load_contract() -> dict:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def validate_schema(df: pd.DataFrame) -> list[str]:
    contract = load_contract()
    expected = [c["name"] for c in contract["columns"]]
    errors: list[str] = []
    missing = [c for c in expected if c not in df.columns]
    if missing:
        errors.append(f"missing columns: {', '.join(missing)}")
        return errors

    if df["decision_id"].duplicated().any():
        errors.append(f"duplicate decision_id: {int(df['decision_id'].duplicated().sum())}")

    df["bar_time_gmt"] = pd.to_datetime(df["bar_time_gmt"], errors="coerce")
    if df["bar_time_gmt"].isna().any():
        errors.append("bar_time_gmt: unparseable values")

    return errors


def audit_scores(df: pd.DataFrame) -> tuple[list[str], dict]:
    """Return (errors, metrics) for INF-1 gate."""
    errors: list[str] = []
    metrics: dict = {"rows": len(df)}

    active = df[(df["mode_ai1"] > 0) & (pd.to_numeric(df["ai1_score"], errors="coerce") >= 0)].copy()
    metrics["ai1_active_rows"] = len(active)

    if active.empty:
        errors.append("no AI-1 active rows (mode_ai1>0 with ai1_score>=0)")
        return errors, metrics

    scores = pd.to_numeric(active["ai1_score"], errors="coerce")
    buckets = scores.round(2).unique()
    metrics["score_buckets"] = int(len(buckets))
    metrics["score_min"] = float(scores.min())
    metrics["score_max"] = float(scores.max())

    if len(buckets) < 2:
        errors.append(f"only {len(buckets)} distinct ai1_score bucket(s); need >= 2")

    dominant = scores.round(2).value_counts().iloc[0]
    pct_dominant = 100.0 * dominant / len(scores)
    metrics["dominant_bucket_pct"] = round(pct_dominant, 2)

    if pct_dominant >= 100.0:
        val = float(scores.round(2).mode().iloc[0])
        if val in NEUTRAL_SCORES or len(buckets) == 1:
            errors.append(
                f"100% of active rows share ai1_score={val} (fail-open / neutral stuck pattern)"
            )
        else:
            errors.append("100% of active rows share the same ai1_score")

    ai3 = df[df["mode_ai3"] > 0]
    if len(ai3):
        allow_vals = set(pd.to_numeric(ai3["ai3_allow"], errors="coerce").dropna().astype(int))
        metrics["ai3_allow_values"] = sorted(allow_vals)
        if allow_vals == {-1}:
            errors.append("AI-3 active but ai3_allow never evaluated")

    return errors, metrics


def audit_ai2_sizing(df: pd.DataFrame) -> tuple[list[str], dict]:
    """AI-2-004: confirm sizing multipliers logged (not stuck at 1.0 only)."""
    errors: list[str] = []
    metrics: dict = {}

    sized = df[
        (df["mode_ai2"] > 0)
        & (df["ai1_pass"] == 1)
        & (pd.to_numeric(df["ai2_mult"], errors="coerce") >= 0)
    ].copy()
    metrics["ai2_sized_rows"] = len(sized)

    if sized.empty:
        errors.append("no AI-2 sized rows (mode_ai2>0, ai1_pass=1, ai2_mult>=0)")
        return errors, metrics

    mults = pd.to_numeric(sized["ai2_mult"], errors="coerce").round(4)
    bad = mults[~mults.isin(AI2_TIERS)]
    if len(bad):
        errors.append(f"ai2_mult outside tiers {sorted(AI2_TIERS)}: {bad.head(3).tolist()}")

    tier_counts = mults.value_counts().sort_index()
    metrics["ai2_tier_counts"] = {float(k): int(v) for k, v in tier_counts.items()}
    metrics["ai2_tier_buckets"] = int(len(tier_counts))

    if metrics["ai2_tier_buckets"] < 2:
        errors.append(
            f"only {metrics['ai2_tier_buckets']} ai2_mult tier(s); need >= 2 (1.0/1.15/1.25)"
        )

    if (mults == 1.0).all():
        errors.append("100% ai2_mult=1.0 — sizing tiers not applied in shadow log")

    return errors, metrics


def audit(path: Path, *, check_ai2: bool = False) -> int:
    df = pd.read_csv(path, encoding="utf-8-sig")
    schema_errors = validate_schema(df)
    score_errors, metrics = audit_scores(df)
    ai2_errors: list[str] = []
    if check_ai2:
        ai2_errors, ai2_metrics = audit_ai2_sizing(df)
        metrics.update({f"ai2_{k}" if not k.startswith("ai2_") else k: v for k, v in ai2_metrics.items()})

    title = "INF-1 + AI-2 shadow audit" if check_ai2 else "INF-1 shadow audit"
    print(f"=== {title} ===")
    print(f"File: {path}")
    for key, val in metrics.items():
        print(f"  {key}: {val}")

    all_errors = schema_errors + score_errors + ai2_errors
    if all_errors:
        print("[FAIL]")
        for err in all_errors:
            print(f"  - {err}")
        return 1

    if check_ai2:
        print("[PASS] AI-1 scoring + AI-2 sizing tiers logged correctly")
    else:
        print("[PASS] shadow log shows live AI scoring (not fail-open neutral)")
    return 0


def self_test() -> int:
    """Sanity-check audit logic without MT5 export."""
    good = pd.DataFrame(
        {
            "bar_time_gmt": ["2024.01.16 14:00:00", "2024.01.16 15:00:00"],
            "sess_key": ["2024.01.16_NY", "2024.01.16_NY"],
            "decision_id": [1, 2],
            "ai1_score": [0.42, 0.71],
            "ai1_pass": [1, 1],
            "ai2_mult": [1.0, 1.15],
            "ai3_allow": [1, 1],
            "ai4_would_scratch": [0, 0],
            "mode_ai1": [2, 2],
            "mode_ai2": [1, 1],
            "mode_ai3": [2, 2],
            "mode_ai4": [1, 1],
            "ea_version": ["1.23", "1.23"],
            "bundle_id": ["orbvwap-v1.23-ai1234", "orbvwap-v1.23-ai1234"],
        }
    )
    bad = good.copy()
    bad["ai1_score"] = 0.5

    _, m_good = audit_scores(good)
    err_bad, _ = audit_scores(bad)

    if m_good.get("score_buckets", 0) < 2:
        print("self_test FAIL: good sample should pass buckets", file=sys.stderr)
        return 1
    if not err_bad:
        print("self_test FAIL: neutral-stuck sample should fail", file=sys.stderr)
        return 1

    sizing = good.copy()
    sizing.loc[0, "ai2_mult"] = 1.0
    sizing.loc[1, "ai2_mult"] = 1.25
    err_sz, m_sz = audit_ai2_sizing(sizing)
    if err_sz:
        print("self_test FAIL: valid sizing sample should pass", file=sys.stderr)
        return 1
    if m_sz.get("ai2_tier_buckets", 0) < 2:
        print("self_test FAIL: sizing tiers", file=sys.stderr)
        return 1

    print("self_test PASS")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit ORBVWAP AI shadow CSV (INF-1)")
    parser.add_argument("shadow_csv", type=Path, nargs="?", help="ORBVWAP_ai_shadow.csv path")
    parser.add_argument("--self-test", action="store_true", help="Run built-in audit logic checks")
    parser.add_argument(
        "--check-ai2",
        action="store_true",
        help="AI-2-004: require ai2_mult tiers 1.0/1.15/1.25 with >=2 buckets",
    )
    args = parser.parse_args()

    if args.self_test:
        raise SystemExit(self_test())

    if not args.shadow_csv:
        parser.error("shadow_csv path required unless --self-test")

    if not args.shadow_csv.exists():
        print(f"File not found: {args.shadow_csv}", file=sys.stderr)
        raise SystemExit(1)

    raise SystemExit(audit(args.shadow_csv, check_ai2=args.check_ai2))


if __name__ == "__main__":
    main()
