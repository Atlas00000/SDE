#!/usr/bin/env python3
"""Aggregate ORBVWAP_journal.csv rejections by reason_code and direction (P4C-001)."""

import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

FOCUS_CODES = frozenset({"MIN_RR", "SPREAD_RANGE", "VOL_INSUFFICIENT", "WRONG_SIDE_OF_VWAP"})
DEFAULT_OUT = Path(__file__).resolve().parent / "P4C-001_reject-by-direction.csv"


def load_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        rows = list(reader)
    if not rows:
        return []

    header = [c.strip().lower() for c in rows[0]]
    if "reason_code" in header:
        start = 1
        idx_reason = header.index("reason_code")
        idx_direction = header.index("direction") if "direction" in header else None
        idx_detail = header.index("detail") if "detail" in header else None
        parsed = []
        for row in rows[start:]:
            if not row or len(row) <= idx_reason:
                continue
            reason = row[idx_reason].strip()
            direction = row[idx_direction].strip() if idx_direction is not None and len(row) > idx_direction else ""
            detail = row[idx_detail].strip() if idx_detail is not None and len(row) > idx_detail else ""
            parsed.append((reason, direction or "NONE", detail))
        return parsed

    # Legacy 3-column: timestamp, reason_code, detail
    parsed = []
    for row in rows:
        if len(row) < 2:
            continue
        if row[0].strip().lower() == "timestamp":
            continue
        reason = row[1].strip()
        direction = row[2].strip() if len(row) > 3 else ""
        detail = row[2].strip() if len(row) == 3 else (row[3].strip() if len(row) > 3 else "")
        if reason in ("BUY", "SELL") and detail == "":
            direction, detail = reason, detail
            reason = row[1].strip()
        parsed.append((reason, direction or "NONE", detail))
    return parsed


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_p4c_journal.py <ORBVWAP_journal.csv> [output.csv]")
        sys.exit(1)

    journal = Path(sys.argv[1])
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUT
    rows = load_rows(journal)
    if not rows:
        print(f"No rows in {journal}")
        sys.exit(1)

    total_by_code = Counter(r[0] for r in rows)
    by_code_dir = Counter((r[0], r[1]) for r in rows)
    total = sum(total_by_code.values())

    print(f"=== P4C-001 journal: {journal.name} ({total} rejections) ===")
    for code, n in total_by_code.most_common():
        pct = 100.0 * n / total
        print(f"{code:22} {n:6} {pct:6.2f}%")
        if code in FOCUS_CODES:
            buy = by_code_dir.get((code, "BUY"), 0)
            sell = by_code_dir.get((code, "SELL"), 0)
            none = by_code_dir.get((code, "NONE"), 0)
            print(f"  BUY={buy} SELL={sell} NONE={none}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["reason_code", "direction", "count", "pct_of_total", "notes"])
        for (code, direction), count in sorted(by_code_dir.items(), key=lambda x: (-x[1], x[0][0], x[0][1])):
            pct = round(100.0 * count / total, 2)
            note = "P4C focus" if code in FOCUS_CODES else ""
            w.writerow([code, direction, count, pct, note])
        w.writerow(["TOTAL", "ALL", total, 100.0, f"source={journal.name}"])

    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
