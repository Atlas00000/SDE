# Phase 3 — DEV-G sign-off

**Date:** 2026-05-19  
**Status:** **PASS** (dev gate — proceed to AI-1 / offline v0 on tester C1; **AI-0 demo deferred**)

---

## Production lock

| Item | Value |
|------|--------|
| Profile | `Profiles/Tester/vem5m_d7_session_bb_rsi.set` |
| Stack | D1 (13–15) · D6 (0.00165) · D7 (RSI ≤25 / ≥75) · midline · **E8c @ bar 4** |
| Lot | 0.01 |
| OOS ref | 111 tr · **+$9.08** · PF **1.30** · WR **70%** |
| IS ref | 274 tr · **+$3.06** · PF **1.04** |

---

## Phase 2d rule queue

- Habitat micro-sweeps (**D1b, D6b, D7b**): **DISCARD / null**
- Exit micro-sweeps (**E8c-v2, E8c-bar, E10-v2**): **PARK / DISCARD**
- **E13 / E14:** **paused** — no C1b bucket ≥30 trades with PF &lt; 1 on full population (see [`step-c1b-results.md`](step-c1b-results.md))

**Sign-off:** No further deterministic exit/habitat IDs before validation track unless new C1 evidence opens E13/E14.

---

## C1b

- Script: [`scripts/c1b_production_buckets.py`](scripts/c1b_production_buckets.py)
- Output: [`step-c1b-results.md`](step-c1b-results.md)
- `trade-profile.md` — C1 medians section updated 2026-05-19

---

## AI-0 (forward/demo)

**Deferred** — still in dev; tester C1 accepted as substitute for **AI-1** until demo is scheduled.

When ready:

1. Attach `vem5m_d7_session_bb_rsi.set` on demo (no AI inputs).
2. Optional parallel `vem5m_d7_c1_trade_log.set` for logging only.
3. Compare rolling 30-trade PF / avg loss to OOS reference.

---

## Next IDs

| ID | Action |
|----|--------|
| **AI-1** | Archive **clean** production C1 run (`vem5m_d7_c1_trade_log.set`); target ≥200–300 closes |
| **AI-2** | v0 trained on current CSV — see [`step-ai-2-results.md`](step-ai-2-results.md) |
| **AI-3** | Holdout skip sim — pass bar check in same doc |
| **AI-4** | Shadow logging — not started |
| **AI-5** | EA wire — not started |
