#!/usr/bin/env python3
"""INF-4: Shared AI-1 feature definitions and Python mirror of CAiFeatures.mqh."""

from __future__ import annotations

import pandas as pd

from policy import FEATURE_ORDER, prepare_features

PARITY_EPS = 1e-4

# Derived from categorical export columns; exact recompute expected.
RECOMPUTABLE = frozenset({"session_ny", "direction_sell"})

# Stored verbatim in decision export; training reads these columns directly.
STORED = frozenset(
    {
        "vol_ratio",
        "vwap_dist_atr",
        "spread_pct_range",
        "min_rr",
        "hour_gmt",
        "weekday",
        "ny_min_since_open",
    }
)


def train_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Feature matrix used by offline training (policy.prepare_features)."""
    prepared = prepare_features(df)
    return prepared[FEATURE_ORDER].astype(float)


def recompute_from_raw(row: pd.Series) -> dict[str, float]:
    """Python mirror of derived fields that are exact from export categoricals."""
    base = export_row_features(row)
    base["session_ny"] = 1.0 if str(row["session"]) == "NY" else 0.0
    base["direction_sell"] = 1.0 if str(row["direction"]) == "SELL" else 0.0
    return base


def export_row_features(row: pd.Series) -> dict[str, float]:
    """Feature values implied by EA decision export columns."""
    derived = prepare_features(pd.DataFrame([row])).iloc[0]
    out: dict[str, float] = {}
    for name in FEATURE_ORDER:
        if name in row.index:
            out[name] = float(row[name])
        else:
            out[name] = float(derived[name])
    return out


def parity_deltas(df: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, float]]:
    """Compare stored export columns vs train + raw recompute paths."""
    train = train_feature_frame(df)
    rows: list[dict] = []
    max_abs: dict[str, float] = {name: 0.0 for name in FEATURE_ORDER}

    for idx, row in df.iterrows():
        stored = export_row_features(row)
        train_vals = train.loc[idx].to_dict()
        recompute = recompute_from_raw(row)

        record: dict = {"decision_id": int(row["decision_id"])}
        for name in FEATURE_ORDER:
            train_val = float(train_vals[name])
            recomp_val = float(recompute[name])
            stored_val = float(stored[name])

            delta_train = abs(stored_val - train_val)
            delta_recomp = abs(stored_val - recomp_val)

            record[f"ea_{name}"] = stored_val
            record[f"py_train_{name}"] = train_val
            record[f"py_recomp_{name}"] = recomp_val
            record[f"delta_train_{name}"] = delta_train
            record[f"delta_recomp_{name}"] = delta_recomp

            max_abs[f"max_delta_train_{name}"] = max(
                max_abs.get(f"max_delta_train_{name}", 0.0), delta_train
            )
            max_abs[f"max_delta_recomp_{name}"] = max(
                max_abs.get(f"max_delta_recomp_{name}", 0.0), delta_recomp
            )

        rows.append(record)

    return pd.DataFrame(rows), max_abs


FEAT_COLUMN_MAP = {
    "range_width_atr": "feat_range_width_atr",
    "vol_ratio": "feat_vol_ratio",
    "vwap_dist_atr": "feat_vwap_dist_atr",
    "spread_pct_range": "feat_spread_pct_range",
    "min_rr": "feat_min_rr",
    "hour_gmt": "feat_hour_gmt",
    "weekday": "feat_weekday",
    "ny_min_since_open": "feat_ny_min_since_open",
    "session_ny": "feat_session_ny",
    "direction_sell": "feat_direction_sell",
}


def check_feat_columns(df: pd.DataFrame, eps: float = PARITY_EPS) -> list[str]:
    """When feat_* columns exist (INF-4 export), compare to primary export columns."""
    errors: list[str] = []
    for feat, col in FEAT_COLUMN_MAP.items():
        if col not in df.columns:
            continue
        delta = (df[col].astype(float) - df[feat].astype(float)).abs().max()
        if delta > eps:
            errors.append(f"{col} vs {feat}: max delta {delta:.2e} > eps {eps}")
    return errors


def check_parity(df: pd.DataFrame, eps: float = PARITY_EPS) -> tuple[list[str], dict[str, float]]:
    """Return errors if any feature delta exceeds epsilon."""
    _, max_abs = parity_deltas(df)
    errors: list[str] = []

    for name in FEATURE_ORDER:
        train_key = f"max_delta_train_{name}"
        recomp_key = f"max_delta_recomp_{name}"
        train_delta = max_abs.get(train_key, 0.0)
        recomp_delta = max_abs.get(recomp_key, 0.0)

        if train_delta > eps:
            errors.append(f"{name}: train delta {train_delta:.2e} > eps {eps}")
        if name in RECOMPUTABLE and recomp_delta > eps:
            errors.append(f"{name}: recompute delta {recomp_delta:.2e} > eps {eps}")

    errors.extend(check_feat_columns(df, eps=eps))

    summary = {k: v for k, v in max_abs.items()}
    return errors, summary
