# Step D6b — Experiment lock (Tighter max BB width)

**Status:** **DISCARD** — IS worse; OOS not in report (confirm if run)  
**Date:** 2026-05-19  
**Control:** `vem5m_d7_session_bb_rsi.set` — `inp_bb_max_width_ratio` = **0.00165**  
**Test:** `vem5m_d6b_d7_bbwidth_0015.set` — max width **0.0015** (~9% tighter)

---

## Prerequisites

- **D1b** null (hour 7 block) — prod session unchanged  
- Exit sweeps closed — **E8c @ bar 4**, E10 **off**  
- **C1b:** BB width did not separate W/L at entry on OOS — still test one D6 step (wide-band losers in Step B)

---

## Hypothesis

Wide bands at signal = continuation / noisy MR. Tightening D6 cap drops the widest-volatility entries while keeping D1+D7+E8c.

| Parameter | Control (D6) | D6b test |
|-----------|--------------|----------|
| `inp_bb_width_filter_enable` | true | true |
| `inp_bb_max_width_ratio` | **0.00165** | **0.0015** |

**Rule:** block entry if `(upper − lower) / middle > max_ratio` on signal bar.

**Code:** existing `VEM_Risk_CheckBBWidth()` — parameter only.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production)

**Keep D6b** if on **OOS** (primary):

- [ ] Net **≥ +$9.08**
- [ ] PF **≥ 1.30**
- [ ] WR **≥ ~65%**
- [ ] Trades **≥ ~95** (allow modest drop from 111)
- [ ] IS net **≥ +$3.06**, PF **≥ 1.04**

**Discard** if below control on OOS net/PF or trade count &lt; ~90.

**Do not** also change D7 RSI in this build.

---

## Run checklist

1. Compile **VEM.mq5** (no change required if already built for D1b)
2. Load **`vem5m_d6b_d7_bbwidth_0015.set`**
3. **OOS** then **IS**
4. Journal: `BB width` block reasons — expect fewer entries vs control

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Notes |
|--------|--------|-------|-----|------|-----------|--------|
| **OOS (D6b)** | — | — | — | — | — | _not in tester screenshot — run if missing_ |
| **IS (D6b)** | **238** | **−$1.35** | **0.98** | **64.29%** | +$0.40 / −$0.73 | tester 2026-05-19 |
| OOS (prod) | 111 | +9.08 | 1.30 | 70.3% | +0.50 / −0.91 | width 0.00165 |
| IS (prod) | 274 | +3.06 | 1.04 | 64.2% | +0.42 / −0.72 | |

### vs production (IS)

| Δ trades | Δ net | Δ PF | Δ WR |
|----------|-------|------|------|
| **−36** | **−$4.41** | **−0.06** | ~+0.1 pp |

**Interpretation:** Tighter width **0.0015** removed ~36 IS trades but turned IS **negative** (PF 0.98). Avg loss **−$0.73** vs prod **−$0.72** — no loss-quality win. Wide-band cap at **0.00165** remains correct.

### Verdict

- [ ] **KEEP** — merge `inp_bb_max_width_ratio=0.0015` into production
- [x] **DISCARD** — prod stays **0.00165**
- [ ] **Next:** **D7b** (tighter RSI long ≤22 / short ≥78) — one step only

---

## Reference — original D6

D6 added on top of D1; p66.7 OOS calibration → **0.00165**. D6b is a **single** tighter step, not a re-grid.
