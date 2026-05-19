# Step E8c-bar — Experiment lock (Worse-structure start bar)

**Status:** v1 **DISCARD** (bar 5) · v2 **bar 3** next · prod stays **4**  
**Date:** 2026-05-19  
**Habitat:** unchanged (D1 + D6 + D7)  
**Control:** `vem5m_d7_session_bb_rsi.set` — `inp_worse_struct_exit_bars` = **4** · `min_pen_pts` = **0**  
**E8c-v2:** **PARK** (min_pen 5) — prod stays 0

---

## Prerequisites

- **E8c** production @ **bar 4**
- One knob per run — do not change `min_pen_pts` or stack E10

---

## Hypothesis

| Variant | `inp_worse_struct_exit_bars` | Intent |
|---------|------------------------------|--------|
| **v2 early** | **3** | Catch structural worsen sooner → fewer full SLs; risk more false scratches |
| **Control** | **4** | Production |
| **v1 late** | **5** | Give reversion one more bar → fewer e8c on “still red” winners; risk deeper SL |

**Rule unchanged:** after `bars_held >= N`, if still outside band and `pen_now > entry_pen` → E8c close.

**Code:** `VEM_Execution_CheckWorseStructureExits()` — parameter only.

---

## Test profiles

| Build | Set file | Start bar |
|-------|----------|-----------|
| **v1 (run first)** | `vem5m_e8cbar_d7_bar5.set` | **5** |
| Control | `vem5m_d7_session_bb_rsi.set` | **4** |
| **v2 (after v1)** | `vem5m_e8cbar_d7_bar3.set` | **3** |
| Optional v3 | create `vem5m_e8cbar_d7_bar6.set` only if 3 and 5 both fail | **6** |

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production)

**Promote new bar to production** if on **OOS** (primary):

- [ ] Net **≥ +$9.08**
- [ ] PF **≥ 1.30**
- [ ] WR **≥ ~65%**
- [ ] Trades **≥ ~100**
- [ ] IS net **≥ +$3.06**, PF **≥ 1.04**
- [ ] ↓ **SL** count or ↓ avg loss vs control (C1 log optional)

**Discard** if below control on OOS net/PF or WR collapses.

---

## Run checklist — v1 (bar 5)

1. Compile **VEM.mq5**
2. Load **`vem5m_e8cbar_d7_bar5.set`**
3. **OOS** then **IS**
4. Journal: count `E8c worse-struct` (expect **≤** control if bar 5 is looser)
5. Optional: C1 with `vem5m_d7_c1_trade_log.set` + `exit_bars=5` on a copy

---

## Results — v1 bar 5

| Window | Trades | Net $ | PF | WR % | Avg W / L | Notes |
|--------|--------|-------|-----|------|-----------|--------|
| **OOS (bar 5)** | **113** | **−$0.43** | **0.99** | **67.26%** | +$0.48 / −$1.00 | tester report 2026-05-19 |
| **IS (bar 5)** | — | — | — | — | — | skipped (OOS fail) |
| OOS (control @4) | 111 | +9.08 | 1.30 | 70.3% | +0.50 / −0.91 | production |

### vs control (OOS)

| Δ trades | Δ net | Δ PF | Δ WR |
|----------|-------|------|------|
| +2 | **−$9.51** | **−0.31** | **−3.0 pp** |

**Interpretation:** Waiting until bar **5** lets losers run deeper (avg loss **−$1.00** vs **−$0.91**); WR and PF collapse. Looser E8c timing hurts more than it helps.

### Verdict v1

- [ ] **KEEP** — merge `inp_worse_struct_exit_bars=5` into production
- [x] **DISCARD** — do **not** promote bar 5
- [ ] **PARK** — production stays **4**
- [ ] **Next:** run **v2 bar 3** (`vem5m_e8cbar_d7_bar3.set`) — only remaining bar direction worth one test

---

## Results — v2 bar 3

| Window | Trades | Net $ | PF | WR % | Notes |
|--------|--------|-------|-----|------|--------|
| **OOS** | | | | | |
| **IS** | | | | | |

### Verdict v2

- [ ] **KEEP** / **DISCARD** / **PARK** — production bar **4** unless clear win

---

## Reference — E8c-v2 (parked)

| Window | min_pen 5 | Control |
|--------|-----------|---------|
| OOS | +9.44 / PF 1.32 | +9.08 / 1.30 |
| IS | +2.58 / PF 1.04 | +3.06 / 1.04 |

Bar sweep is independent of min_pen delta.
