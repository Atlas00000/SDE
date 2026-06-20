#!/usr/bin/env python3
"""INF-5: Walk-forward gate — 3 rolling OOS windows on AI-3+AI-1+AI-2 stack."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

from policy import (
    add_scores,
    ai1_tau,
    apply_ai1_filter,
    apply_ai2_sizing,
    calibrate_size_thresholds,
    executed_mask,
    fit_scorer,
    prepare_features,
    sized_trade_metrics,
)
from regime_model import DEFAULT_AI3, add_session_allow, load_config
from sessions import build_sessions_from_trades, session_key
from train_eval import print_metrics, trade_metrics_ordered

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"
DEFAULT_INF_JOURNAL = ROOT / "Diagnostics" / "INF-test-journal.csv"

DEFAULT_FOLDS = 3
DEFAULT_PF_FLOOR = 0.95
DEFAULT_MIN_OOS_N = 20


@dataclass
class WalkFold:
    fold_id: str
    train_end_frac: float
    test_end_frac: float
    train_end: pd.Timestamp
    test_start: pd.Timestamp
    test_end: pd.Timestamp


@dataclass
class FoldResult:
    fold: WalkFold
    prod: dict
    stack: dict
    verdict: str
    pf_floor: float


def rolling_folds(trades: pd.DataFrame, n_folds: int = DEFAULT_FOLDS) -> list[WalkFold]:
    """Expanding train + next-segment OOS (4 segments → 3 test windows)."""
    data = trades.sort_values("bar_time_gmt").reset_index(drop=True)
    segment = 1.0 / (n_folds + 1)
    folds: list[WalkFold] = []

    for i in range(n_folds):
        train_end_idx = max(1, int(len(data) * segment * (i + 1)) - 1)
        test_end_idx = max(train_end_idx + 1, int(len(data) * segment * (i + 2)) - 1)
        test_end_idx = min(test_end_idx, len(data) - 1)

        train_end = pd.Timestamp(data.loc[train_end_idx, "bar_time_gmt"])
        test_start = pd.Timestamp(data.loc[train_end_idx + 1, "bar_time_gmt"])
        test_end = pd.Timestamp(data.loc[test_end_idx, "bar_time_gmt"])

        folds.append(
            WalkFold(
                fold_id=f"WF-{i + 1}",
                train_end_frac=segment * (i + 1),
                test_end_frac=segment * (i + 2),
                train_end=train_end,
                test_start=test_start,
                test_end=test_end,
            )
        )
    return folds


def slice_fold(trades: pd.DataFrame, fold: WalkFold) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    train = trades.loc[trades["bar_time_gmt"] <= fold.train_end].copy()
    oos = trades.loc[
        (trades["bar_time_gmt"] >= fold.test_start) & (trades["bar_time_gmt"] <= fold.test_end)
    ].copy()
    history = trades.loc[trades["bar_time_gmt"] <= fold.test_end].copy()
    return train, oos, history


def evaluate_stack_fold(
    fold: WalkFold,
    train: pd.DataFrame,
    oos: pd.DataFrame,
    history: pd.DataFrame,
    ai3_cfg: dict,
    pf_floor: float = DEFAULT_PF_FLOOR,
    min_oos_n: int = DEFAULT_MIN_OOS_N,
) -> FoldResult | None:
    if len(train) < 30 or len(oos) < min_oos_n:
        return None

    model, scaler = fit_scorer(train)
    train_scored = add_scores(train, model, scaler)
    oos_scored = add_scores(oos, model, scaler)

    tau = ai1_tau()
    p50, p80 = calibrate_size_thresholds(train_scored, tau)

    sessions = add_session_allow(build_sessions_from_trades(history), ai3_cfg)
    oos_scored = oos_scored.copy()
    oos_scored["sess_key"] = session_key(oos_scored)
    merged = oos_scored.merge(
        sessions[["sess_key", "session_allow"]].drop_duplicates("sess_key"),
        on="sess_key",
        how="left",
    )
    merged["session_allow"] = merged["session_allow"].fillna(True)

    prod = trade_metrics_ordered(oos)
    stack_df = apply_ai2_sizing(
        apply_ai1_filter(merged.loc[merged["session_allow"]], tau),
        p50,
        p80,
    )
    stack = sized_trade_metrics(stack_df)

    floor = prod["pf"] * pf_floor
    if stack["n"] < min_oos_n:
        verdict = "REJECT"
    elif stack["pf"] >= floor:
        verdict = "PASS"
    else:
        verdict = "REJECT"

    return FoldResult(
        fold=fold,
        prod=prod,
        stack=stack,
        verdict=verdict,
        pf_floor=floor,
    )


def run_walkforward(
    dataset: Path = DEFAULT_DATASET,
    *,
    n_folds: int = DEFAULT_FOLDS,
    pf_floor: float = DEFAULT_PF_FLOOR,
    min_oos_n: int = DEFAULT_MIN_OOS_N,
    ai3_config: Path = DEFAULT_AI3,
) -> tuple[list[FoldResult], pd.DataFrame]:
    if not dataset.exists():
        raise FileNotFoundError(f"Missing dataset: {dataset}")
    if not ai3_config.exists():
        raise FileNotFoundError(f"Missing AI-3 config: {ai3_config}")

    raw = pd.read_parquet(dataset)
    trades = prepare_features(raw.loc[executed_mask(raw)].copy())
    trades = trades.sort_values("bar_time_gmt").reset_index(drop=True)

    cfg = load_config(ai3_config)
    folds = rolling_folds(trades, n_folds=n_folds)
    results: list[FoldResult] = []

    for fold in folds:
        train, oos, history = slice_fold(trades, fold)
        result = evaluate_stack_fold(
            fold,
            train,
            oos,
            history,
            cfg,
            pf_floor=pf_floor,
            min_oos_n=min_oos_n,
        )
        if result is None:
            raise RuntimeError(
                f"{fold.fold_id}: insufficient data (train={len(train)} oos={len(oos)})"
            )
        results.append(result)

    table = pd.DataFrame(
        [
            {
                "fold": r.fold.fold_id,
                "train_end": r.fold.train_end,
                "test_start": r.fold.test_start,
                "test_end": r.fold.test_end,
                "oos_n": r.stack["n"],
                "prod_pf": round(r.prod["pf"], 2),
                "stack_pf": round(r.stack["pf"], 2),
                "pf_floor": round(r.pf_floor, 2),
                "prod_net": round(r.prod["net"], 2),
                "stack_net": round(r.stack["net"], 2),
                "verdict": r.verdict,
            }
            for r in results
        ]
    )
    return results, table


def append_inf_journal(
    results: list[FoldResult],
    journal: Path,
    *,
    pf_floor: float,
) -> None:
    rows = []
    for r in results:
        rows.append(
            {
                "task_id": f"INF-5-{r.fold.fold_id}",
                "preset_or_artifact": "walkforward.py AI312 stack",
                "dataset_or_tool": "ORBVWAP_ai_dataset_v1.parquet",
                "holdout_cut": str(r.fold.test_start),
                "n_full": r.prod["n"],
                "pf_full": round(r.prod["pf"], 2),
                "n_holdout": r.stack["n"],
                "pf_holdout": round(r.stack["pf"], 2),
                "verdict": r.verdict,
                "notes": (
                    f"OOS {r.fold.test_start.date()}..{r.fold.test_end.date()} "
                    f"prod_pf={r.prod['pf']:.2f} stack_pf={r.stack['pf']:.2f} "
                    f"floor=prod*{pf_floor:.2f}={r.pf_floor:.2f}"
                ),
            }
        )

    all_pass = all(r.verdict == "PASS" for r in results)
    rows.append(
        {
            "task_id": "INF-5-006",
            "preset_or_artifact": "walkforward.py gate",
            "dataset_or_tool": f"{len(results)} folds pf_floor={pf_floor}",
            "holdout_cut": "rolling",
            "n_full": sum(r.prod["n"] for r in results),
            "pf_full": round(min(r.prod["pf"] for r in results), 2),
            "n_holdout": sum(r.stack["n"] for r in results),
            "pf_holdout": round(min(r.stack["pf"] for r in results), 2),
            "verdict": "PASS" if all_pass else "REJECT",
            "notes": "AI-3+AI-1+AI-2 stack; no OOS window PF < PROD*0.95",
        }
    )

    journal_exists = journal.exists()
    pd.DataFrame(rows).to_csv(journal, mode="a", header=not journal_exists, index=False)


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP walk-forward gate (INF-5)")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--ai3-config", type=Path, default=DEFAULT_AI3)
    parser.add_argument("--folds", type=int, default=DEFAULT_FOLDS)
    parser.add_argument("--pf-floor", type=float, default=DEFAULT_PF_FLOOR, help="Stack PF >= PROD * floor")
    parser.add_argument("--min-oos-n", type=int, default=DEFAULT_MIN_OOS_N)
    parser.add_argument("--journal", type=Path, default=None, help="Append INF-test-journal.csv rows")
    parser.add_argument("--write-journal", action="store_true", help="Append rows to INF-test-journal.csv")
    args = parser.parse_args()

    try:
        results, table = run_walkforward(
            args.dataset,
            n_folds=args.folds,
            pf_floor=args.pf_floor,
            min_oos_n=args.min_oos_n,
            ai3_config=args.ai3_config,
        )
    except (FileNotFoundError, RuntimeError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    print(f"=== INF-5 walk-forward ({args.folds} folds, floor=PROD*{args.pf_floor:.2f}) ===")
    print(f"Stack: AI-3 + AI-1 + AI-2 | tau={ai1_tau():.2f}")
    print()
    print(table.to_string(index=False))

    for r in results:
        print(f"\n--- {r.fold.fold_id} OOS {r.fold.test_start.date()} .. {r.fold.test_end.date()} ---")
        print_metrics("PROD", r.prod)
        print_metrics("AI-3+AI-1+AI-2", r.stack)
        print(f"PF floor: {r.pf_floor:.2f} | verdict: {r.verdict}")

    all_pass = all(r.verdict == "PASS" for r in results)
    if args.write_journal:
        journal = args.journal or DEFAULT_INF_JOURNAL
        append_inf_journal(results, journal, pf_floor=args.pf_floor)
        print(f"\nAppended {len(results) + 1} rows -> {journal}")

    if not all_pass:
        print("\n[FAIL] one or more walk-forward windows below PF floor")
        return 1

    print("\n[PASS] all walk-forward windows meet PF floor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
