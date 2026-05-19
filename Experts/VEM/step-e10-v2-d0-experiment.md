# Step E10-v2 — Experiment lock (Invalidation on production stack)

**Status:** v1 **DISCARD** — prod stays E10 **off** · v2 bar 5 optional  
**Date:** 2026-05-19  
**Control:** `vem5m_d7_session_bb_rsi.set` — **D7 + E8c**, E10 **off**  
**Test v1:** `vem5m_e10v2_prod_mae045.set` — production + E10 (looser MAE)

---

## Why E10-v2 (not legacy E10)

| Run | Stack | OOS (ref) |
|-----|--------|-----------|
| E10 parked | D7 habitat **only** (no E8c) | +$5.95 · PF 1.18 · 113 tr |
| **Production** | D7 + **E8c** | **+$9.08** · PF **1.30** · 111 tr |
| **E10-v2** | D7 + **E8c** + E10 | _this test_ |

Retune E10 on the **current production** baseline, not pre-E8c D7.

**Exit order** (`VEM_Execution_ManageExits`): midline → **E10** → **E8c** → E8a/b.  
E8c can still fire @ bar 4–5; E10 from bar 6 when MFE/MAE match.

---

## Prerequisites

- **E8c-v2** park (min_pen 5) · **E8c-bar** v1 discard (bar 5) · prod bar **4**
- **C1b** OOS: losers **low MFE / high MAE** @ bar 6 — E10 grid on 111 trades
- One knob per build

---

## E10-v2 variants

| Build | Set file | `inv_exit_bars` | `inv_mae_min_r` | `inv_mfe_max_r` |
|-------|----------|-----------------|-----------------|-----------------|
| Parked E10 | `vem5m_e10_d7_invalidation.set` | 6 | **0.50** | 0.20 |
| **v1 (run first)** | `vem5m_e10v2_prod_mae045.set` | 6 | **0.45** | 0.20 |
| **v2 (after v1)** | `vem5m_e10v2_prod_bar5.set` | **5** | 0.50 | 0.20 |
| v3 (code) | — | 6 | 0.50 | 0.20 + only if E8c did not exit — backlog |

**Rule:** after `bars_in_trade >= N`, if `MFE <= 0.20R` and `MAE >= min_r` → close (`e10` in C1 log).

**C1 OOS proxy (111 tr, production):** MFE≤0.20 & MAE≥0.45 @ bar 6 → ~10 cuts, kept WR ~76%.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production control)

**Promote E10-v2** if on **OOS** (primary):

- [ ] Net **≥ +$9.08**
- [ ] PF **≥ 1.30**
- [ ] WR **≥ ~65%** (target ~70%)
- [ ] Trades **≥ ~100**
- [ ] IS net **≥ +$3.06**, PF **≥ 1.04**
- [ ] ↓ **SL** count or ↓ avg loss vs control (optional C1: `exit_type` **e10** / **sl**)

**Park** if WR/PF hold but net gain &lt; ~$0.50 OOS (same class as E10 v1).

**Discard** if below control on OOS net or WR collapses.

---

## Run checklist — v1 (MAE 0.45)

1. Compile **VEM.mq5**
2. Load **`vem5m_e10v2_prod_mae045.set`**
3. **OOS** then **IS**
4. Journal: `E10 inv exit` count vs production
5. Optional: C1 on OOS with trade log on — expect **`e10`** rows in CSV

---

## Results — v1 (MAE 0.45 @ bar 6)

| Window | Trades | Net $ | PF | WR % | Avg W / L | Notes |
|--------|--------|-------|-----|------|-----------|--------|
| **OOS (E10-v2)** | **113** | **+$5.54** | **1.16** | **69.03%** | +$0.51 / −$0.97 | tester 2026-05-19 |
| **IS (E10-v2)** | — | — | — | — | — | not run / not sent |
| OOS (prod) | 111 | +9.08 | 1.30 | 70.3% | +0.50 / −0.91 | E10 off |
| IS (prod) | 274 | +3.06 | 1.04 | 64.2% | +0.42 / −0.72 | |

### vs production (OOS)

| Δ trades | Δ net | Δ PF | Δ WR |
|----------|-------|------|------|
| +2 | **−$3.54** | **−0.14** | **−1.3 pp** |

**Interpretation:** Looser MAE (0.45) on **D7+E8c** still bleeds vs production-only. Extra E10 scratches do not beat E8c alone; avg loss **−$0.97** ≈ control. Same failure mode as parked E10 on old D7 stack (flat/slightly negative vs control).

### Verdict v1

- [ ] **KEEP** — merge E10 into `vem5m_d7_session_bb_rsi.set` with `mae_min_r=0.45`
- [ ] **PARK** — E10 off on production
- [x] **DISCARD** — do **not** promote E10 on production stack
- [ ] **Optional:** v2 `vem5m_e10v2_prod_bar5.set` only if you want one more null; else **close E10 line** → **D1b** / habitat micro-sweeps

---

## Results — v2 (bar 5, MAE 0.50)

| Window | Trades | Net $ | PF | WR % | Notes |
|--------|--------|-------|-----|------|--------|
| **OOS** | | | | | |
| **IS** | | | | | |

### Verdict v2

- [ ] **KEEP** / **PARK** / **DISCARD**

---

## Reference

- [`step-e10-d0-experiment.md`](step-e10-d0-experiment.md) — parked E10 without E8c  
- [`step-c1-results.md`](step-c1-results.md) — MAE/MFE @ bar 6 on production OOS CSV
