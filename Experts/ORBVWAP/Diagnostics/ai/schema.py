#!/usr/bin/env python3
"""INF-0-002: Versioned data contracts for ORBVWAP exports and datasets."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SCHEMAS_DIR = ROOT / "schemas"

DECISIONS_COLS = [
    "decision_id",
    "bar_time_gmt",
    "direction",
    "session",
    "hour_gmt",
    "weekday",
    "ny_min_since_open",
    "range_width",
    "range_width_atr",
    "atr",
    "vol_ratio",
    "vwap_dist_atr",
    "spread_pct_range",
    "spread_points",
    "min_rr",
    "entry",
    "sl",
    "tp",
    "can_trade_ok",
    "setup_ok",
    "prod_executed",
    "reject_stage",
    "reject_code",
    "position_id",
]

OUTCOMES_COLS = ["position_id", "close_time_gmt", "profit", "label_win"]


@dataclass
class ValidationResult:
    artifact: str
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    def add(self, msg: str) -> None:
        self.errors.append(msg)


def load_contract(name: str, version: int = 1) -> dict[str, Any]:
    path = SCHEMAS_DIR / f"{name}.v{version}.json"
    if not path.exists():
        raise FileNotFoundError(f"Schema contract not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _expected_columns(contract: dict[str, Any]) -> list[str]:
    return [col["name"] for col in contract["columns"]]


def _check_required_columns(df: pd.DataFrame, contract: dict[str, Any], result: ValidationResult) -> None:
    expected = _expected_columns(contract)
    missing = [c for c in expected if c not in df.columns]
    extra = [c for c in df.columns if c not in expected]
    if missing:
        result.add(f"missing columns: {', '.join(missing)}")
    if extra:
        result.add(f"unexpected columns: {', '.join(extra)}")


def _coerce_flag(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def _check_enum(series: pd.Series, values: list[Any], col: str, result: ValidationResult) -> None:
    allowed = set(values)
    bad = series[~series.isin(allowed) & series.notna()]
    if len(bad):
        sample = bad.head(3).tolist()
        result.add(f"{col}: invalid enum values (expected {sorted(allowed)}), examples {sample}")


def _check_numeric_range(
    series: pd.Series,
    col: str,
    result: ValidationResult,
    *,
    min_val: float | None = None,
    max_val: float | None = None,
) -> None:
    numeric = pd.to_numeric(series, errors="coerce")
    if numeric.isna().any():
        result.add(f"{col}: non-numeric values")
        return
    if min_val is not None and (numeric < min_val).any():
        result.add(f"{col}: values below minimum {min_val}")
    if max_val is not None and (numeric > max_val).any():
        result.add(f"{col}: values above maximum {max_val}")


def validate_decisions(df: pd.DataFrame, *, version: int = 1) -> ValidationResult:
    contract = load_contract("decisions", version)
    result = ValidationResult(artifact=f"decisions.v{version}")
    if df.empty:
        result.add("empty decisions frame")
        return result

    _check_required_columns(df, contract, result)
    if not result.ok:
        return result

    work = df.copy()
    work["bar_time_gmt"] = pd.to_datetime(work["bar_time_gmt"], errors="coerce")
    if work["bar_time_gmt"].isna().any():
        result.add("bar_time_gmt: unparseable datetime values")

    for text_col in ("reject_stage", "reject_code"):
        work[text_col] = work[text_col].fillna("").astype(str).str.strip()

    for spec in contract["columns"]:
        col = spec["name"]
        if col == "bar_time_gmt":
            continue
        if spec["dtype"] == "enum":
            _check_enum(work[col].astype(str).str.strip(), spec["values"], col, result)
        elif spec["dtype"] in ("int64", "float64"):
            _check_numeric_range(
                work[col],
                col,
                result,
                min_val=spec.get("min"),
                max_val=spec.get("max"),
            )
            if spec.get("values") is not None:
                _check_enum(_coerce_flag(work[col]), spec["values"], col, result)
        elif spec["dtype"] == "string" and col not in ("reject_stage", "reject_code"):
            if work[col].isna().any():
                result.add(f"{col}: null values not allowed")

    if work["decision_id"].duplicated().any():
        n = int(work["decision_id"].duplicated().sum())
        result.add(f"decision_id: {n} duplicate rows (must be unique)")

    executed = work["prod_executed"] == 1
    if executed.any():
        ex = work.loc[executed]
        if (ex["can_trade_ok"] != 1).any():
            result.add("prod_executed=1 but can_trade_ok!=1")
        if (ex["setup_ok"] != 1).any():
            result.add("prod_executed=1 but setup_ok!=1")
        pos = pd.to_numeric(ex["position_id"], errors="coerce")
        if (pos <= 0).any() or pos.isna().any():
            result.add("prod_executed=1 requires position_id > 0")
        dup_pos = ex.assign(position_id=pos)["position_id"].duplicated()
        if dup_pos.any():
            result.add(
                f"duplicate executed position_id: {int(dup_pos.sum())} rows "
                "(INF-0-004: no dup executed rows)"
            )

    can_fail = work["can_trade_ok"] == 0
    if can_fail.any():
        bad = work.loc[can_fail & (work["reject_stage"] != "CAN_TRADE")]
        if len(bad):
            result.add(f"can_trade_ok=0 but reject_stage!=CAN_TRADE ({len(bad)} rows)")

    setup_fail = (work["can_trade_ok"] == 1) & (work["setup_ok"] == 0)
    if setup_fail.any():
        bad = work.loc[setup_fail & (work["reject_stage"] != "SETUP")]
        if len(bad):
            result.add(f"setup_ok=0 but reject_stage!=SETUP ({len(bad)} rows)")

    passed = (work["can_trade_ok"] == 1) & (work["setup_ok"] == 1)
    if passed.any():
        bad = work.loc[passed & (work["reject_stage"] != "")]
        if len(bad):
            result.add(f"setup passed but reject_stage non-empty ({len(bad)} rows)")

    return result


def validate_outcomes(df: pd.DataFrame, *, version: int = 1) -> ValidationResult:
    contract = load_contract("outcomes", version)
    result = ValidationResult(artifact=f"outcomes.v{version}")
    if df.empty:
        result.add("empty outcomes frame (optional for build, invalid for executed label gate)")
        return result

    _check_required_columns(df, contract, result)
    if not result.ok:
        return result

    work = df.copy()
    work["close_time_gmt"] = pd.to_datetime(work["close_time_gmt"], errors="coerce")
    if work["close_time_gmt"].isna().any():
        result.add("close_time_gmt: unparseable datetime values")

    pos = pd.to_numeric(work["position_id"], errors="coerce")
    if pos.isna().any() or (pos <= 0).any():
        result.add("position_id: must be positive integers")
    if pos.duplicated().any():
        result.add(f"position_id: {int(pos.duplicated().sum())} duplicate rows")

    _check_enum(_coerce_flag(work["label_win"]), [0, 1], "label_win", result)

    return result


def validate_dataset(df: pd.DataFrame, *, version: int = 1) -> ValidationResult:
    decisions_view = df[[c for c in DECISIONS_COLS if c in df.columns]].copy()
    result = validate_decisions(decisions_view, version=version)
    result.artifact = f"dataset.v{version}"

    if "prod_taken" not in df.columns:
        result.add("missing derived column: prod_taken")
    else:
        expected = (df["prod_executed"] == 1).astype(int)
        if not (df["prod_taken"] == expected).all():
            result.add("prod_taken inconsistent with prod_executed")

    executed = df["prod_executed"] == 1
    if executed.any():
        ex = df.loc[executed]
        for col in ("label_win", "profit", "close_time_gmt"):
            if col not in df.columns:
                result.add(f"executed rows missing column: {col}")
            elif ex[col].isna().any():
                n = int(ex[col].isna().sum())
                result.add(f"executed rows with null {col}: {n}")

    return result


def validate_export_pair(
    decisions: pd.DataFrame,
    outcomes: pd.DataFrame | None = None,
    *,
    version: int = 1,
) -> list[ValidationResult]:
    results = [validate_decisions(decisions, version=version)]
    if outcomes is not None and len(outcomes):
        results.append(validate_outcomes(outcomes, version=version))
        executed_ids = set(
            pd.to_numeric(decisions.loc[decisions["prod_executed"] == 1, "position_id"], errors="coerce")
            .dropna()
            .astype("int64")
        )
        outcome_ids = set(pd.to_numeric(outcomes["position_id"], errors="coerce").dropna().astype("int64"))
        missing = executed_ids - outcome_ids
        if missing:
            join = ValidationResult(artifact="join")
            join.add(f"executed position_id missing from outcomes: {len(missing)} ids")
            results.append(join)
    return results


def format_results(results: list[ValidationResult]) -> str:
    lines: list[str] = []
    for res in results:
        status = "PASS" if res.ok else "FAIL"
        lines.append(f"[{status}] {res.artifact}")
        for err in res.errors:
            lines.append(f"  - {err}")
    return "\n".join(lines)


def run_validation(
    *,
    decisions_path: Path | None = None,
    outcomes_path: Path | None = None,
    dataset_path: Path | None = None,
    version: int = 1,
) -> int:
    results: list[ValidationResult] = []

    if dataset_path is not None:
        df = pd.read_parquet(dataset_path)
        results.append(validate_dataset(df, version=version))

    if decisions_path is not None:
        decisions = pd.read_csv(decisions_path, encoding="utf-8-sig")
        outcomes = None
        if outcomes_path is not None and outcomes_path.exists():
            outcomes = pd.read_csv(outcomes_path, encoding="utf-8-sig")
        results.extend(validate_export_pair(decisions, outcomes, version=version))

    if not results:
        print("No inputs to validate", file=sys.stderr)
        return 2

    print(format_results(results))
    return 0 if all(r.ok for r in results) else 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate ORBVWAP export/dataset contracts (INF-0)")
    parser.add_argument("--decisions", type=Path, help="ORBVWAP_decisions.csv")
    parser.add_argument("--outcomes", type=Path, help="ORBVWAP_outcomes.csv")
    parser.add_argument("--dataset", type=Path, help="ORBVWAP_ai_dataset_vN.parquet")
    parser.add_argument("--version", type=int, default=1, help="Schema version (default 1)")
    args = parser.parse_args()
    raise SystemExit(
        run_validation(
            decisions_path=args.decisions,
            outcomes_path=args.outcomes,
            dataset_path=args.dataset,
            version=args.version,
        )
    )


if __name__ == "__main__":
    main()
