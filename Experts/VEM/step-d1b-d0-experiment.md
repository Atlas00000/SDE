# Step D1b — Experiment lock (Second session block — hour 7)

**Status:** **DISCARD (null)** — identical to production; block2 hour 7 has no effect  
**Date:** 2026-05-19  
**Control:** `vem5m_d7_session_bb_rsi.set` — D1 blocks **13–15** only  
**Test:** `vem5m_d1b_d7_block_h7.set` — D1 + **block2 hour 7**

---

## Prerequisites

- **C1b** production OOS CSV (111 tr): loser hour **07** net **−$6.77** (6 loser trades) — worst bucket
- **E8c / E10-v2 / E8c-bar** exit sweeps closed — prod **E8c @ 4**, E10 **off**
- D1 unchanged (13–15); D1b adds **non-contiguous** block via `inp_session_block2_*`

---

## Hypothesis

London-open hour **07** (server time) adds toxic fades on top of already-filtered habitat. Removing entries at **07** should lift OOS net/PF without collapsing trade count.

| Window | Block |
|--------|--------|
| D1 | **13–15** (unchanged) |
| D1b | **7–7** (`inp_session_block2_enable=true`) |

**Code:** `VEM_Risk_CheckSession()` — `VEM_Risk_HourInBlock()` for each range.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production)

**Keep D1b** if on **OOS** (primary):

- [ ] Net **≥ +$9.08**
- [ ] PF **≥ 1.30**
- [ ] WR **≥ ~65%**
- [ ] Trades **≥ ~95** (allow ~15% drop from 111)
- [ ] IS net **≥ +$3.06**, PF **≥ 1.04**

**Discard** if net/PF below control or trade count collapses (&lt; ~90).

**Follow-up (separate build):** block **6–8** or hour **23** only if h7 fails — do not combine in v1.

---

## Run checklist

1. Compile **VEM.mq5** (F7) — needs new `inp_session_block2_*` inputs
2. Load **`vem5m_d1b_d7_block_h7.set`**
3. **OOS** then **IS**
4. Journal: `session block2 hour 7` on skipped signals

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Notes |
|--------|--------|-------|-----|------|-----------|--------|
| **OOS (D1b)** | **111** | **+$9.08** | **1.30** | **70.27%** | +$0.50 / −$0.91 | tester 2026-05-19 |
| **IS (D1b)** | **274** | **+$3.06** | **1.04** | **64.23%** | +$0.42 / −$0.72 | |
| OOS (prod) | 111 | +9.08 | 1.30 | 70.3% | +0.50 / −0.91 | |
| IS (prod) | 274 | +3.06 | 1.04 | 64.2% | +0.42 / −0.72 | |

### vs production

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | **0** | **0.00** | **0.00** | **0.0 pp** |
| IS | **0** | **0.00** | **0.00** | ~0 pp |

**Interpretation (null):** Blocking hour **7** did not change trade count or P/L vs control. Likely **no production signals** fire with `entry_hour == 7` after D6+D7 (C1 loser bucket was small n=6). Re-verify load was `vem5m_d1b_d7_block_h7.set` + recompiled EA; if confirmed, hour-7 block is not a lever on this stack.

### Verdict

- [ ] **KEEP** — merge `session_block2` into production set (7–7 on)
- [x] **DISCARD (null)** — prod stays D1 only (13–15); **block2 off**
- [ ] **Optional:** log `session block2` in journal on next run to confirm filter arms

---

## C1 reference (production OOS losers by hour)

| Hour | Loser n | Loser net $ |
|------|--------:|------------:|
| **07** | 6 | **−6.77** |
| 23 | 4 | −5.53 |
| 12 | 2 | −2.97 |
