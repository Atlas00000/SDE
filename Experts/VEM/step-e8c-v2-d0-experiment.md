# Step E8c-v2 — Experiment lock (Min penetration delta)

**Status:** **PARK** — v1 min_pen **5 pts** — OOS tiny lift, IS net below control  
**Verdict date:** 2026-05-19  
**Date:** 2026-05-19  
**Habitat:** unchanged (D1 + D6 + D7)  
**Control:** `vem5m_d7_session_bb_rsi.set` (`inp_worse_struct_min_pen_pts` = **0**)  
**Test:** `vem5m_e8c2_d7_min_pen5.set` (`inp_worse_struct_min_pen_pts` = **5**)

---

## Prerequisites

- **E8c** **KEEP** on production (min_pen **0**)
- **C1b** OOS CSV confirms production: 111 tr · **+$9.08** · PF **1.30** · 3× `e8c` exits
- **One knob** per build — do not combine with E10, D1b, or bar sweep in this run

---

## Hypothesis

E8c v1 exits on **any** deepen vs entry (`min_pen_pts = 0`). Some scratches may be **noise** (1–2 point wobble outside the band) and hurt WR.

**E8c-v2:** require penetration to deepen by at least **N points** beyond entry penetration before exit.

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 4` | Start checking |
| Still outside band (`pen_now > 0`) | — |
| `pen_now > entry_pen + N * point` | **Close** (E8c) |

**v1 test:** **N = 5** (EURUSD 5-digit: 5 points = 0.5 pip).

**Code:** existing `inp_worse_struct_min_pen_pts` in `VEM_Execution_CheckWorseStructureExits()` — no new exit path.

**Journal:** `E8c worse-struct exit` … `delta_pts=` … `min_pts=5`

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production control)

**Keep E8c-v2 (promote `min_pen_pts` to production)** if on **OOS** (primary):

- [x] Net **≥ +$9.08** — **+$9.44**
- [x] PF **≥ 1.30** — **1.32**
- [x] WR **≥ ~65%** — **70.27%**
- [x] Trade count **≥ ~100** — **111**
- [ ] IS net **≥ +$3.06** — **+$2.58** (below control)
- [x] IS PF **≥ 1.04** — **1.04** (flat)
- [ ] Fewer SL / lower avg loss — not verified (no C1 CSV this run)

**Discard** if net/PF below control or WR drops materially with no SL improvement.

**Parked:** OOS-only micro-gain (+$0.36, +0.02 PF) does not justify IS net −$0.48 vs control; production stays **`min_pen_pts=0`**.

**If DISCARD at 5 pts:** optional follow-up **only** `vem5m_e8c2_d7_min_pen10.set` (N=10) — separate charter row; do not optimize both in one grid.

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Load **`vem5m_e8c2_d7_min_pen5.set`**
3. Run **OOS** then **IS**
4. Journal: count `E8c worse-struct exit` — expect **≤** control (stricter rule)
5. Optional C1: `vem5m_d7_c1_trade_log.set` + set `inp_worse_struct_min_pen_pts=5` on a copy, compare `e8c` / `sl` mix

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % | Notes |
|--------|--------|-------|-----|------|-----------|----------|--------|
| **OOS (E8c-v2)** | **111** | **+$9.44** | **1.32** | **70.27%** | +$0.50 / −$0.90 | 3.19% eq | `vem5m_e8c2_d7_min_pen5.set` |
| **IS (E8c-v2)** | **268** | **+$2.58** | **1.04** | **64.93%** | +$0.42 / −$0.75 | 7.65% eq | |
| OOS (control) | 111 | +9.08 | 1.30 | 70.3% | +$0.50 / −$0.91 | ~3.2% | `min_pen_pts=0` |
| IS (control) | 274 | +3.06 | 1.04 | 64.2% | +$0.42 / −$0.72 | 7.2% | |

### vs control (delta)

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | 0 | **+$0.36** | **+0.02** | ~0 pp |
| IS | −6 | **−$0.48** | 0.00 | +0.7 pp |

**C1 CSV:** not written this run (`inp_trade_log_enable=false`). Prior OOS control log: 8 SL, 3× e8c @ min_pen **0**.

### Verdict

- [ ] **KEEP** — merge `min_pen_pts=5` into production
- [x] **PARK** — production stays **`min_pen_pts=0`**; OOS edge too small, IS net worse
- [ ] **DISCARD** (hard) — optional **N=10** only if revisiting; else **E8c-bar** or **E10-v2**

---

## Later E8c-v2 variants (not this build)

| ID | Knob | Set file |
|----|------|----------|
| E8c-v2b | `min_pen_pts` = **10** | `vem5m_e8c2_d7_min_pen10.set` (create if 5 fails) |
| E8c-v2c | No midline reclaim | new input — separate build |
| E8c-v2d | Deepen + ATR rising | new input — separate build |
