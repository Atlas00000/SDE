# Step E — MAE/MFE analysis

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Profiles\Tester\ReportTesterB-23489.xlsx` · **SL for 1R:** 200 pts (0.00200) · **Trades analyzed:** 681 / 701 (20 skipped — no bar overlap)

## E1 — Winner MAE (R)

| Stat | Winners |
| --- | --- |
| n | 406 |
| Median MAE | 0.18R |
| 75th %ile MAE | 0.34R |
| 90th %ile MAE | 0.56R |
| % winners with MAE > 0.8R | 2.7% |

**vs SL:** 75th percentile MAE < 1R — winners rarely need full SL room.

## E2 — Loser MFE (R)

| Stat | Losers |
| --- | --- |
| n | 275 |
| Median MFE | 0.15R |
| 75th %ile MFE | 0.28R |
| % losers MFE > 0.5R | 10.9% |
| % losers MFE > 0.8R | 4.4% |

## E3–E4 — Decisions

- **E3 SL:** Winner 75th MAE ~0.34R — SL at 1R rarely threatened on winners; **widening SL is not the first fix**.
- **E4 exit:** Losers show **low MFE** (median 0.15R, 10.9% >0.5R) — failures are fast; **habitat filters (session done) > exit tuning**.

**E6:** **Deferred** — only 10.9% of losers had MFE >0.5R; median loser MFE 0.15R. See [`step-e-d0-experiment.md`](step-e-d0-experiment.md). **Next: Step D6** (BB width on `vem5m_d1_session.set`).

## E5 — Hold time (M5 bars)

| Stat | Winners | Losers |
| --- | --- | --- |
| Median bars | 9 | 14 |
| 75th %ile | 12 | 18 |

## Exit type mix (deals comment)

| Exit | Count | % |
| --- | --- | --- |
| midline | 546 | 80.2% |
| sl | 122 | 17.9% |
| tp | 13 | 1.9% |

## Loser MAE / Winner MFE (context)

| Group | Median MAE (R) | Median MFE (R) |
| --- | --- | --- |
| Losers | 0.87 | 0.15 |
| Winners | 0.18 | 0.45 |

---

**Checklist:** See `edge-discovery.md` Step E — mark E1–E5 from this file; run **E6** in Strategy Tester after creating proposed `.set`.