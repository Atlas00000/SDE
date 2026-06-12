# P4C-003 — Direction bias decision memo

**Status:** **FINAL**  
**Verdict:** **NO-STACK** — do not add long-bias filters  
**EA:** ORBVWAP v1.17 · **PROD v3** stack  
**Date:** 2026-06-11

---

## Question

Should we add **long-bias filters** (e.g. D1 EMA, long-only sessions) given the short-heavy trade mix?

**Answer: No.** Short skew is **frequency** (more valid down-break setups), not **quality** (longs are not systematically worse or over-filtered).

---

## P4C-001 — Rejection journal (June 2026 · 11,487 bars)

| Code | BUY | SELL | Ratio | Gate (>2×) |
|------|-----|------|-------|------------|
| VOL_INSUFFICIENT | 989 | 678 | 1.46× long | **fail** |
| MIN_RR | 123 | 76 | 1.62× long | **fail** |
| WRONG_SIDE_OF_VWAP | 42 | 76 | 1.81× short | **fail** |
| SPREAD_RANGE | 0 | 0 | — | n/a |

No focus code exceeds the **2× directional rejection** gate. Skew is **mixed** (longs hit vol/R:R slightly more; shorts hit VWAP slightly more) — not a one-sided filter story.

---

## P4C-002 — Closed trades (PROD v3 · P0-002 window)

| Direction | Trades | Share | Win rate | Implied W/L |
|-----------|--------|-------|----------|-------------|
| **ALL** | 172 | 100% | 54.07% | 93 / 79 · PF **1.40** |
| **Long** | 55 | **32.0%** | **52.73%** | 29 / 26 |
| **Short** | 117 | **68.0%** | **54.70%** | 64 / 53 |

- Short share **68%** — stable vs PROD v2 (68.5%).
- Long WR **52.7%** vs short **54.7%** — within noise; longs are **not** under-performing dramatically.
- Overall PF **1.40**, payoff **1.20** — healthy; no direction needs rescue.

**P4C-002 gate:** Long PF not split in standard MT5 report, but long WR ≈ short WR and n=55 → **no long-quality crisis**. Asymmetry is **frequency**, not **filter bias**.

---

## Prior evidence (unchanged)

| Source | Finding |
|--------|---------|
| P2C-001 D1 EMA bias | **REJECT** — PF 1.15, n=81 |
| VWAP rule | Symmetric per direction |
| P0-003 June signals | BUY 6 vs SELL 8 (tiny n) |

---

## Decision

| Verdict | Rationale |
|---------|-----------|
| **NO-STACK** | P4C-001: no >2× rejection skew on focus codes · P4C-002: 68% short is structural frequency; long WR healthy at n=55 |

---

## Do not

- Add `InpTradePermission` long-only / short-only on PROD
- Re-open P2C-001 D1 EMA or other MTF bias filters
- Tune `InpVolumeMultiplier` or `InpMinRR` per direction

---

## Next

Phase **4C CLOSED**. Proceed to **P3-004** forward demo when you choose, or **P3-001–003** OOS / optimise / multi-symbol.
