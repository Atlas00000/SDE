# Step D10 — Experiment lock (Confirmation bar entry)

**Status:** **DISCARD** — fewer trades, worse OOS net/PF/WR vs production  
**Date locked:** 2026-05-18  
**Control:** `vem5m_d7_session_bb_rsi.set` (D7 + E8c, no D10)  
**Test:** `vem5m_d10_d7_confirm_bar.set`

---

## Prerequisites

- **E8c** production locked on control
- **No** other new entry filters in this run
- Habitat filters (D1/D6/D7) apply to **setup bar** (shift 2)

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_d10_d7_confirm_bar.set` |
| Control OOS | 111 tr · **+$9.08** · PF **1.30** · WR **70%** |
| Control IS | 274 tr · **+$3.06** · PF **1.04** |

---

## D10 — single hypothesis

**Name:** Enter only after **path confirmation** — not another RSI cosmetic.

**Hypothesis:** Continuation entries fail because price never shows rejection; require the bar **after** the extreme to re-enter the band or print a rejection body before fading.

**Two-bar model** (`inp_signal_shift = 1`):

| Bar | Shift | Role |
|-----|-------|------|
| **Setup** | **2** | BB pierce + RSI + volume (raw signal) + D1/D6/D7 gates |
| **Confirm** | **1** | Must pass confirmation rule below |
| **Entry** | Open of new bar | Market order after confirm bar closed |

**Confirmation rules** (`inp_confirm_mode`):

| Mode | Long | Short |
|------|------|-------|
| **Re-enter (0)** | `close >= bb_lower` | `close <= bb_upper` |
| **Reject (1)** | `close > open` | `close < open` |
| **Either (2)** | re-enter **or** reject body | re-enter **or** reject body |

**Test set default:** **Either (2)** — charter “re-entry inside band **or** rejection close”.

| Parameter | Value |
|-----------|--------|
| `inp_confirm_bar_enable` | `true` |
| `inp_confirm_mode` | **2** (EITHER) |
| E8c / midline / SL | Same as production control |

**Code:** `VEM_Signal_Evaluate()`, `VEM_Signal_ConfirmLong/Short()` in `VEM_Signal.mqh`

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (D10)

**Keep D10** if vs **production control** on **OOS** (primary):

- [ ] Net **≥ +$9.08** — **no** (+$2.82, −$6.26)
- [ ] PF **≥ 1.30** — **no** (1.16)
- [ ] WR **≥ ~65%** — **borderline** (65.0% vs 70%)
- [ ] Trade count lower OK if expectancy improves — **no** (80 vs 111)
- [ ] IS not materially worse — **no** (−$0.33 / PF 0.99 vs +$3.06 / 1.04)

**Discard** if fewer trades but net/PF/WR worse, or WR collapses.

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Load **`vem5m_d10_d7_confirm_bar.set`**
3. Run **OOS** then **IS** vs control on same dates
4. Optional: `inp_confirm_mode=0` only if EITHER is too loose

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % |
|--------|--------|-------|-----|------|-----------|----------|
| **IS (D10)** | 200 | **−$0.33** | **0.99** | **61.5%** | +$0.36 / −$0.57 | 5.0% |
| **OOS (D10)** | 80 | **+$2.82** | **1.16** | **65.0%** | +$0.40 / −$0.65 | 2.4% |
| IS (control) | 274 | +$3.06 | 1.04 | 64.2% | — | — |
| OOS (control) | 111 | +$9.08 | 1.30 | 70.3% | — | — |

### vs production (delta)

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | −31 | **−$6.26** | **−0.14** | **−5.3 pp** |
| IS | −74 | **−$3.39** | **−0.05** | −2.7 pp |

**Interpretation:** Confirmation bar filters ~28% of OOS trades but removes **high-quality fades** that would have reverted on the next bar without confirm. Same failure mode as D9 (over-filtering path) — not a production upgrade.

**Verdict:** **DISCARD** — keep **`vem5m_d7_session_bb_rsi.set`** (D7 + E8c, **D10 off**). Optional later: test `inp_confirm_mode=0` (re-enter only) as D10b — not in v1 charter.
