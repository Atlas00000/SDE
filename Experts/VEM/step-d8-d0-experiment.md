# Step D8 — Experiment lock (Regime: EMA slope)

**Status:** **DISCARD** — v1 null effect (identical to D7 on IS + OOS)  
**Date locked:** 2026-05-16  
**Habitat base:** `vem5m_d7_session_bb_rsi.set` (D1 + D6 + D7)

---

## Prerequisites

- D7 habitat **locked** as base ([`step-d7-d0-experiment.md`](step-d7-d0-experiment.md))
- Step E complete (E6 deferred)
- **Do not** combine D9 in this run

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `MQL5/Profiles/Tester/vem5m_d7_session_bb_rsi.set` |
| **Test D8** | `MQL5/Profiles/Tester/vem5m_d8_d7_ema_slope.set` |
| **Test D8b** | `MQL5/Profiles/Tester/vem5m_d8b_d7_ema_slope3.set` |
| B1 evidence | [`step-b-complete-results.md`](step-b-complete-results.md) — `against` bucket; slope thresholds ±5 bp |
| D7 OOS control | 119 tr · **+$6.00** · PF **1.17** · DD **3.2%** |
| D7 IS control | 270 tr · −$0.38 · PF 0.99 |

---

## Filter #4 — single hypothesis

**Name:** Block mean-reversion entries that fade a strong EMA drift

**Hypothesis:** Longs into sustained down-drift and shorts into sustained up-drift behave like Step B1 **`against`** trades and hurt PF.

**Mechanism (one rule)** on **signal bar** (`inp_signal_shift`):

1. `slope_bp = (EMA[shift] − EMA[shift + lookback]) / EMA[shift + lookback] × 10000`
2. **Block long** if `slope_bp < −inp_ema_slope_block_bp`
3. **Block short** if `slope_bp > +inp_ema_slope_block_bp`

**Rule v1 (B1-aligned):**

| Parameter | Value |
|-----------|--------|
| `inp_ema_slope_filter_enable` | `true` in D8 set only |
| `inp_ema_period` | **20** |
| `inp_ema_slope_lookback_bars` | **5** |
| `inp_ema_slope_block_bp` | **5.0** |
| D1 / D6 / D7 | unchanged from D7 set |

**Code:** `VEM_Indicators_EMASlopeBp()`, `VEM_Risk_CheckEMASlope()` in `VEM_Risk.mqh`

**Not in v1:** ADX combo, HTF EMA, dynamic slope terciles, EMA50 period (optional v8b if v1 too weak/strong).

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** deposit · 0.01 lots (match D7 runs).

**Fair compare:** D8 test vs **`vem5m_d7_session_bb_rsi.set`** on **identical dates**.

---

## Pass / fail (D8)

**Keep filter #4** if vs D7 control on **OOS** (primary) and IS not materially worse:

- [ ] Net profit **improves** OOS — **no** (tie +$6.00)
- [ ] PF **≥** D7 OOS — **tie** 1.17
- [ ] Max DD **not worse** — **tie** ~3.2%
- [ ] Trade count changes — **no** (119 OOS = D7; **0 blocks**)
- [ ] IS not worse — **tie** −$0.38 / PF 0.99 / 270 tr

**Verdict (2026-05-16):** **DISCARD v1** — no measurable effect vs D7; habitat stays **`vem5m_d7_session_bb_rsi.set`**.

---

## D8 results (tester screenshots 2026-05-16)

Assume run with `vem5m_d8_d7_ema_slope.set` (if trade counts differ from table, re-check **Inputs → EMA slope filter enable**).

### OOS 2025.01.01 → 2026.05.15

| Metric | D7 control | D8 (+ EMA slope) | Δ |
|--------|------------|------------------|---|
| Trades | 119 | **119** | **0** |
| Net $ | +6.00 | **+6.00** | 0 |
| PF | 1.17 | **1.17** | 0 |
| Max equity DD | 3.2% | **3.19%** | ~0 |
| Win rate | 68.9% | **68.91%** | ~0 |
| Sharpe | 4.20 | **4.20** | 0 |
| Avg win / loss | 0.51 / −0.97 | **0.51 / −0.97** | 0 |

### IS 2024.01.01 → 2026.05.15

| Metric | D7 control | D8 (+ EMA slope) | Δ |
|--------|------------|------------------|---|
| Trades | 270 | **270** | **0** |
| Net $ | −0.38 | **−0.38** | 0 |
| PF | 0.99 | **0.99** | 0 |
| Max equity DD | 7.75% | **7.75%** | 0 |
| Win rate | 65.2% | **65.19%** | ~0 |
| Sharpe | — | **−0.13** | — |

**Interpretation:** On the **D7 trade set**, almost no entries had EMA slope beyond ±5 bp in the “fade against trend” direction at the signal bar — filter never fired (or set not loaded). Step B1 `against` bucket mattered on the **full baseline** sample, not on this heavily pre-filtered habitat.

**Next queue if D8b fails:** **D9** (outside-BB streak).

---

## D8b — tighter slope threshold (retry)

**Status:** `.set` ready — **you:** backtest vs D7  
**Change vs D8 v1:** only `inp_ema_slope_block_bp` **5.0 → 3.0** (includes B1 `mild_trend` band per Step B script: |slope| ≥ 3).

| Item | Value |
|------|--------|
| Set file | `MQL5/Profiles/Tester/vem5m_d8b_d7_ema_slope3.set` |
| Control | `vem5m_d7_session_bb_rsi.set` |
| D8 v1 reference | 119 OOS / 270 IS — **identical** to D7 |

### Pass / fail (D8b)

**Keep** if vs D7 on **OOS** (primary):

- [ ] Trades **< 119** (filter actually firing)
- [ ] Net $ **≥ +$6.00** (or clearly better risk-adjusted)
- [ ] PF **≥ 1.17**
- [ ] Max DD **≤ ~3.5%**
- [ ] IS not materially worse than D7 (−$0.38 / 270 tr baseline)

**Discard D8 entirely** if trade count still **119 / 270** or OOS net/PF worse with no DD gain.

### D8b results

| Window | D7 | D8b (3 bp) | Δ |
|--------|-----|------------|---|
| OOS | 119 tr · +$6.00 · PF 1.17 | **same as D7** | 0 |
| IS | 270 tr · −$0.38 · PF 0.99 | **same as D7** | 0 |

**D8b verdict:** **DISCARD** — null effect; proceed to **D9**.

### Tester checklist (D8b)

1. Load **`vem5m_d8b_d7_ema_slope3.set`** — confirm **Min slope … = 3.0**
2. OOS **2025.01.01 → 2026.05.15** · $200 · every tick
3. IS **2024.01.01 → 2026.05.15**
4. If trades unchanged vs D7 → **discard D8/D8b**, proceed to **D9**

---

## Deliverables

- [x] D8 D0 — this file
- [x] `VEM_Risk_CheckEMASlope` + inputs in `VEM_Config.mqh`
- [x] `vem5m_d8_d7_ema_slope.set`
- [x] D8 IS + OOS backtest (screenshots)
- [x] **DISCARD** v1 — keep code/inputs default OFF
- [x] Row in `baseline-eurusd-m5-20260516.md`

---

## Tester checklist

1. Compile **F7** on `VEM.mq5`
2. Strategy Tester → load **`vem5m_d8_d7_ema_slope.set`**
3. Run **OOS** 2025.01.01 → 2026.05.15, then **IS** 2024.01.01 → 2026.05.15
4. Repeat with **`vem5m_d7_session_bb_rsi.set`** (control) if needed for side-by-side
5. Record: trades, net $, PF, DD %, WR, avg win/loss
6. Mark pass/fail above → update [`filtersrecommedations.md`](filtersrecommedations.md) D8 status

---

## Expected shape

Moderate trade reduction (blocking `against`-trend fades only). If B1 holds on full tester sample, losers in strong drift should drop and OOS PF/net should hold or improve without killing the +$6 OOS profile.
