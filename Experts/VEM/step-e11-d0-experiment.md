# Step E11 — Experiment lock (Payoff after MFE proof)

**Status:** **DISCARD (null)** — identical IS + OOS vs production  
**Date locked:** 2026-05-18  
**Control:** `vem5m_d7_session_bb_rsi.set` (D7 + E8c)  
**Test:** `vem5m_e11_d7_payoff.set`

---

## Prerequisites

- **E7** BE @ 0.5R **DISCARD** (null vs D7)
- **E9** partial @ midline always **DISCARD** (null at 0.01 lots)
- **E11 ≠ E7/E9:** partial **only** when MFE already proved reversion

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_e11_d7_payoff.set` |
| Control OOS | 111 tr · **+$9.08** · PF **1.30** · WR **70%** |
| Control IS | 274 tr · **+$3.06** · PF **1.04** |

---

## E11 — single hypothesis

**Name:** Bank partial at midline only after reversion proof

**Hypothesis:** On D7, most winners hit midline quickly with modest MFE; trades that reach **≥ 0.35R** before midline may benefit from **50% bank + runner** vs full midline cap.

**Rule v1** (on BB midline touch):

| MFE (closed bars since entry) | Action |
|-------------------------------|--------|
| **< 0.35R** | **Full close** (same as production) |
| **≥ 0.35R** | Close **50%** at midline; runner to SL / later midline rules |

| Parameter | Value |
|-----------|--------|
| `inp_e11_payoff_enable` | `true` |
| `inp_e11_mfe_min_r` | **0.35** |
| `inp_e11_partial_pct` | **0.50** |
| E7 / E9 | **off** |
| E8c | **on** (production) |

**Code:** `VEM_Exec_MidlinePartialPct()`, `VEM_Execution_MidlineExits()` — journal: `E11 partial midline`

**Not in v1:** E7 BE @ 0.35R, E9 always-partial, ATR trail (E12).

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (E11)

**Keep E11** if vs **production** on **OOS** (primary):

- [x] Net **≥ +$9.08** — **tie** (+$9.08)
- [x] PF **≥ 1.30** — **tie** (1.30)
- [x] WR **≥ ~65%** — **tie** (70.3%)
- [x] IS not materially worse — **tie** (+$3.06 / PF 1.04 / 274 tr)

**Discard** if null (E7/E9 pattern) or net/PF down — **null confirmed**.

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Load **`vem5m_e11_d7_payoff.set`**
3. Run **OOS** then **IS**
4. Journal: count `E11 partial midline` vs full midline exits

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % |
|--------|--------|-------|-----|------|-----------|----------|
| **IS (E11)** | 274 | **+$3.06** | **1.04** | **64.2%** | +$0.42 / −$0.72 | 7.2% |
| **OOS (E11)** | 111 | **+$9.08** | **1.30** | **70.3%** | +$0.50 / −$0.91 | 3.2% |
| IS (control) | 274 | +$3.06 | 1.04 | 64.2% | — | — |
| OOS (control) | 111 | +$9.08 | 1.30 | 70.3% | — | — |

**Interpretation:** Same as **E7** / **E9** — on D7+E8c, midline touch usually occurs **before or with** MFE ≥ 0.35R, so conditional partial ≡ full midline path in practice. No journal-visible change in exit economics at 0.01 lots.

**Verdict:** **DISCARD (null)** — `inp_e11_payoff_enable` **off** on production. **Phase 2c payoff queue complete** for practical purposes.
