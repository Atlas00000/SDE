# Step D11 — Experiment lock (HTF regime gate)

**Status:** **DISCARD** — OOS net/PF below production; IS flat  
**Date locked:** 2026-05-18  
**Control:** `vem5m_d7_session_bb_rsi.set` (D7 + E8c)  
**Test:** `vem5m_d11_d7_htf_regime.set`

---

## Prerequisites

- **D8** M5 EMA slope **DISCARD** (null) — D11 uses **H1** only, not stacked with D8
- **D10** **DISCARD** — confirm bar off
- Production control = current default profile

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_d11_d7_htf_regime.set` |
| Control OOS | 111 tr · **+$9.08** · PF **1.30** · WR **70%** |
| Control IS | 274 tr · **+$3.06** · PF **1.04** |

---

## D11 — single hypothesis

**Name:** Do not fade into **HTF continuation**

**Hypothesis:** M5 extremes that align with **H1 drift** are continuation traps; block fades when H1 EMA slope shows clear directional drift.

**Rule v1** (evaluated at **signal bar** time, mapped to H1 bar):

| Side | Block when |
|------|------------|
| **Long** | H1 EMA slope **< −6 bp** over 5 H1 bars |
| **Short** | H1 EMA slope **> +6 bp** over 5 H1 bars |

Slope bp = `(EMA[now] − EMA[now+lookback]) / EMA[now+lookback] × 10000` (same formula as D8/B1).

| Parameter | Value |
|-----------|--------|
| `inp_htf_regime_enable` | `true` |
| `inp_htf_timeframe` | **H1** (`PERIOD_H1`) |
| `inp_htf_ema_period` | **50** |
| `inp_htf_slope_lookback_bars` | **5** |
| `inp_htf_slope_block_bp` | **6.0** |
| D1 / D6 / D7 / E8c | Same as production |

**Code:** `VEM_Indicators_HtfSlopeBp()`, `VEM_Risk_CheckHtfRegime()` in `VEM_Risk.mqh`

**Not in v1:** HTF distance from mean, ADX, D8+M5 slope stacked, D10 confirm.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots · ensure **H1** history loaded.

---

## Pass / fail (D11)

**Keep D11** if vs **production** on **OOS** (primary):

- [ ] Net **≥ +$9.08** — **no** (+$6.50, −$2.58)
- [ ] PF **≥ 1.30** — **no** (1.26)
- [ ] WR **≥ ~65%** — **yes** (69.5%)
- [ ] IS not materially worse — **no** (+$0.76 / PF 1.01 vs +$3.06 / 1.04)

**Discard** if trade count drops but net/PF/WR worse (D9/D10 pattern).

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Strategy Tester → **Every tick** → load **`vem5m_d11_d7_htf_regime.set`**
3. Run **OOS** then **IS**
4. Journal: `htf slope` skip messages (verbose if needed)

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % |
|--------|--------|-------|-----|------|-----------|----------|
| **IS (D11)** | 239 | **+$0.76** | **1.01** | **64.0%** | +$0.41 / −$0.71 | 7.0% |
| **OOS (D11)** | 95 | **+$6.50** | **1.26** | **69.5%** | +$0.48 / −$0.87 | 3.2% |
| IS (control) | 274 | +$3.06 | 1.04 | 64.2% | — | — |
| OOS (control) | 111 | +$9.08 | 1.30 | 70.3% | — | — |

### vs production (delta)

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | −16 | **−$2.58** | **−0.04** | −0.8 pp |
| IS | −35 | **−$2.30** | **−0.03** | ~flat |

**Interpretation:** H1 slope gate removes some losers but also **profitable counter-trend fades** — same class of result as D8 (M5 slope null) and D10. Entry regime filters after D7+E8c are **exhausted** for OOS uplift.

**Verdict:** **DISCARD** — **`inp_htf_regime_enable` off** on `vem5m_d7_session_bb_rsi.set`. Production unchanged (D7 + E8c).
