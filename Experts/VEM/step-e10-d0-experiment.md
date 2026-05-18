# Step E10 — Experiment lock (MAE/MFE invalidation exit)

**Status:** **MARGINAL KEEP (park)** — WR/PF hold; OOS net −$0.05 vs D7; not a production upgrade  
**Date locked:** 2026-05-18  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  
**Test:** `vem5m_e10_d7_invalidation.set` (D7 + E10 only)

---

## Prerequisites

- **C1** trade log complete — thresholds from [`step-c1-results.md`](step-c1-results.md)
- **E8a / E8b** **DISCARD** — do not combine with E10 in v1
- Production control: failure exit **OFF**, full midline **ON**

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_e10_d7_invalidation.set` |
| C1 analysis | [`step-c1-results.md`](step-c1-results.md) |
| D7 OOS control | 119 tr · **+$6.00** · PF **1.17** · WR **~69%** |
| D7 IS control | 270 tr · **−$0.38** · PF **0.99** |

---

## E10 — single hypothesis

**Name:** Scratch trades that show **no revert** by excursion state (not time/red alone).

**Hypothesis:** Losers cluster **low MFE + high MAE** after several bars; winners stay shallow. Cut those before full 1R SL while midline path stays primary for valid fades.

**Rule v1** (each new bar, **after** midline exit pass):

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 6` | Start checking |
| `MFE <= 0.20R` **and** `MAE >= 0.50R` (closed-bar excursions vs entry SL distance) | **Close position** |

| Parameter | Value |
|-----------|--------|
| `inp_inv_exit_enable` | `true` |
| `inp_inv_exit_bars` | **6** |
| `inp_inv_mfe_max_r` | **0.20** |
| `inp_inv_mae_min_r` | **0.50** |
| `inp_fail_exit_mode` | **0** (OFF) |
| SL / midline / entries | Same as D7 |

**Code:** `VEM_Execution_CheckInvalidationExits()` in `VEM_Execution.mqh`

**Not in v1:** E8c, E7 BE, E9 partial, trade log on (optional for post-mortem).

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** start · **0.01** lots · load **`vem5m_e10_d7_invalidation.set`**.

**Journal:** look for `E10 inv exit` lines (count vs C1 ~34/373 proxy cuts).

---

## Pass / fail (E10)

**Keep E10** if vs D7 on **OOS** (primary):

- [ ] Net **≥ +$6.00** — **no** (+$5.95, −$0.05)
- [x] PF **≥ 1.17** — **yes** (1.18)
- [x] WR **≥ ~65%** — **yes** (69.0%; no E8b collapse)
- [x] Avg loss similar — **yes** (−$0.96 vs D7 ~−$0.97)
- [x] IS not materially worse — **yes** (PF 1.00, net −$0.06 vs −$0.38)

**Discard** if WR collapses, net/PF below control, or inv exits fire on most midline winners.

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Strategy Tester → **VEM** → **EURUSD M5** → load **`vem5m_e10_d7_invalidation.set`**
3. Run **OOS** then **IS** (same dates as D7 charter)
4. Compare to D7 control table above
5. Optional: enable `inp_trade_log_enable` on one window → verify `inv` mix in CSV exit column

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % |
|--------|--------|-------|-----|------|-----------|----------|
| **IS (E10)** | 269 | **−$0.06** | **1.00** | **63.6%** | +$0.42 / −$0.74 | 7.3% |
| **OOS (E10)** | 113 | **+$5.95** | **1.18** | **69.0%** | +$0.51 / −$0.96 | 4.3% |
| IS (D7 ctrl) | 270 | −$0.38 | 0.99 | ~64% | — | — |
| OOS (D7 ctrl) | 119 | +$6.00 | 1.17 | ~69% | — | ~3.2% |

### vs D7 (delta)

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | −6 | −$0.05 | +0.01 | ~0 |
| IS | −1 | +$0.32 | +0.01 | ~flat |

**Interpretation:** E10 fires sparingly (~6 OOS scratches). **Win rate preserved** (unlike E8a/E8b). Payoff tweak is **neutral**: slightly better PF, essentially flat net, avg loss unchanged. OOS DD **~4.3%** vs D7 **~3.2%** — no DD win.

**Verdict:** **MARGINAL KEEP (park)** — code stays; **production default remains** `vem5m_d7_session_bb_rsi.set` (**E10 off**). Optional: retune MAE threshold (0.45) or bar 5 if you want another pass; else move to **E8c / D10** queue.
