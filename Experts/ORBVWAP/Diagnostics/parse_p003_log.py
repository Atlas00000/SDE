import re
from collections import Counter

LOG = r"C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\logs\20260611.log"
START, END = 3552888, 3563123

counts = Counter()
signals = Counter()
range_locked = 0

with open(LOG, "r", encoding="utf-16", errors="ignore") as f:
    for i, line in enumerate(f, 1):
        if i < START:
            continue
        if i > END:
            break
        m = re.search(r"REJECT (\S+)", line)
        if m:
            counts[m.group(1)] += 1
        if "Signal BUY" in line:
            signals["BUY"] += 1
        if "Signal SELL" in line:
            signals["SELL"] += 1
        if "Range LOCKED" in line:
            range_locked += 1

total = sum(counts.values())
print(f"=== P0-003 June run lines {START}-{END} ===")
for code, n in counts.most_common():
    pct = 100.0 * n / total if total else 0
    print(f"{code:22} {n:6} {pct:6.2f}%")
print(f"TOTAL REJECTIONS {total}")
print(f"SIGNALS BUY={signals['BUY']} SELL={signals['SELL']}")
print(f"RANGE LOCKED {range_locked}")
