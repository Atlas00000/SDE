# Baseline: EURUSD M5 — 2026-05-16

Step A reference run for edge discovery. Compare all filter and exit tests against this cell.

---

## Test cell

| Field | Value |
|--------|--------|
| Symbol / TF | EURUSD, M5 |
| Period | 2024.01.01 → 2026.05.15 (~2.4 years) |
| Model | Every tick |
| Deposit / leverage | $200, 1:500 |
| Set file | `MQL5/Profiles/Tester/vem5m.set` |
| Tester log | `Tester/D0E8209F77C8CF37AD8BF550E51FF075/Agent-127.0.0.1-3000/logs/20260516.log` |
| EA | `Experts/VEM/VEM.ex5` |
| Magic | 2600511 |

### Inputs (`vem5m.set`)

| Group | Parameter | Value |
|--------|-----------|--------|
| Signal bar | `inp_signal_shift` | 1 |
| Bollinger | `inp_bb_period` / `inp_bb_dev` | 20 / 2.0 |
| RSI | `inp_rsi_period` / OB / OS | 14 / 70 / 30 |
| Volume | `inp_vol_ma_period` / `inp_vol_spike_mult` | 20 / 1.5 |
| BB pierce | `inp_bb_penetration_pts` | 0 |
| Risk | `inp_max_spread_pts` / positions / cooldown | 50 / 1 / 1 |
| Sizing | `inp_fixed_lots` / `inp_risk_pct` | 0.01 / 0 (fixed) |
| SL | `inp_sl_mode` / `inp_sl_points` | fixed points / 200 |
| TP | `inp_tp_mode` / `inp_tp_rr` | fixed R:R / 1.5 |
| Exits | midline / opposite signal | **on** / off |

Classic mean-reversion stack per `concept.md` (BB 20/2, RSI 30/70).

---

## Headline metrics

| Metric | Value | Notes |
|--------|-------|--------|
| Net profit | **−$47.63** | −23.8% on $200 deposit |
| Profit factor | **0.93** | Below 1.0 — no portfolio edge |
| Total trades | **1,429** | ~1.6 trades/day |
| Win rate | **61.09%** | 873 wins / 556 losses |
| Avg profit trade | **$0.69** | |
| Avg loss trade | **−$1.17** | Loss ≈ **1.7×** avg win |
| Largest profit | $3.06 | |
| Largest loss | −$5.31 | |
| Max balance DD | $66.00 (30.93%) | |
| Max equity DD | $67.21 (31.42%) | |
| Sharpe ratio | −2.28 | |
| Recovery factor | −0.71 | |
| Long / short trades | 705 / 724 | Balanced |
| Avg hold time | 0:52:24 | Intraday |
| History quality | 100% | |
| Ticks processed | 41,953,020 | |

**Expectancy check:** 0.61 × 0.69 − 0.39 × 1.17 ≈ **−$0.03/trade** → ~−$43–48 total (matches report).

---

## Exit mix (from tester log)

| Exit type | ~Count | ~Share |
|-----------|--------|--------|
| BB midline (`VEM Closed`) | ~1,139 | **~80%** |
| Stop loss (full 200 pts) | 263 | **~18%** |
| Take profit (broker TP @ 1.5R) | 26 | **~2%** |
| End of test | 1 | — |

**Implication:** Most trades close at midline with small wins; a minority hit full SL and dominate dollar losses. TP at 1.5R rarely fires because midline exits first.

---

## Time / distribution (tester report)

| Dimension | Observation |
|-----------|-------------|
| **Hours** | Entry peaks at **08:00** (London) and **13:00–14:00** (NY overlap); loss bars heavy in those windows |
| **Weekdays** | Fairly even Mon–Fri; slight lift Wed–Thu |
| **Months** | High activity Jan–Apr; weaker Jun–Aug |
| **MAE vs profit** | Correlation **0.76** — outcome tied to adverse excursion |
| **MFE vs profit** | Correlation **0.61** | |

---

## Diagnosis (Step A6)

On EURUSD M5 (2024–mid 2026), `vem5m` produces **many small mean-reversion wins** (61% WR, ~80% midline exits) but **pays for them with fewer, full-size stop losses** (avg loss 1.7× avg win, PF 0.93). Execution matches design; the issue is **negative expectancy from payoff shape + context**: fading extremes on M5 during **trend/persistence** (session opens) while **capping winners at BB mid** and taking **full 20-pip SL** on failures.

**Not the first fix:** global RSI tweaks, more trades, widen SL alone.  
**Step D filter #1:** Session block hours **13–15** (B6). Then BB width / RSI; BB walk optional.

---

## Step B priorities (from this baseline)

**Guide:** [`phase-b-guide.md`](phase-b-guide.md) · **Full Step B:** [`step-b-complete-results.md`](step-b-complete-results.md)

Step B **complete** on **818/1429** trades (2025-01 → 2026-05). Re-run after History Center download for 2024.

**Step D priorities:** (1) Session hour 13 / NY 13–21 (2) Min BB width / avoid wide bands (3) RSI depth for shorts (4) BB walk optional  

---

## Step A checklist status

- [x] A1 — Test cell defined  
- [x] A2 — Tester setup documented  
- [x] A3 — Backtest + log saved  
- [x] A4 — Headline metrics recorded  
- [x] A5 — Splits + exit mix + time notes  
- [x] A6 — Diagnosis written  

**Optional follow-up:** extend start to 2023.01.01 for a full 3-year window; export deals CSV from tester report.

---

## Step D0 — Experiment lock (2026-05-16)

**Charter:** [`step-d-d0-experiment.md`](step-d-d0-experiment.md)

| Item | Locked value |
|------|----------------|
| Filter #1 | Session block — signal-bar hours **13–15** (server time) |
| Hypothesis | NY overlap / hour-13 momentum destroys mean reversion on M5 |
| IS test | 2024.01.01 → 2026.05.15 · `vem5m_d1_session.set` (after D2) |
| OOS test | 2025.07.01 → 2026.05.15 · same set · no retuning |
| Control | `vem5m.set` · filter **off** · must match Step A |

---

## Comparison template (fill after filter tests)

| Run | Date | Change | Trades | PF | Net $ | Max DD % | Notes |
|-----|------|--------|--------|-----|-------|----------|-------|
| Baseline | 20260516 | `vem5m.set` | 1429 | 0.93 | −47.63 | 31.4 | Step A |
| D1 session IS | 20260516 | block hrs 13–15 · `vem5m_d1_session.set` | **1161** | **0.96** | **−17.08** | **15.4** | D3 — IS pass |
| Baseline OOS | 20260516 | `vem5m.set` · 2025.01–2026.05 | **841** | **0.96** | **−16.58** | **20.6** | control (same window) |
| D1 session OOS | 20260516 | `vem5m_d1_session.set` · `ReportTesterB-23489.xlsx` | **701** | **0.96** | **−13.69** | **15.2** | **beats baseline OOS** |
| D6 session+BB IS | 20260516 | `vem5m_d6_session_bbwidth.set` · 2024.01–2026.05 | **724** | **1.03** | **+4.98** | **8.0** | **habitat — keep** |
| D6 session+BB OOS | 20260516 | same · 2025.01–2026.05 | **373** | **0.96** | **−4.58** | **8.4** | **habitat — keep** |
| D7 +RSI depth IS | 20260516 | `vem5m_d7_session_bb_rsi.set` · 2024.01–2026.05 | **270** | **0.99** | **−0.38** | **7.8** | **fail vs D6 IS** |
| D7 +RSI depth OOS | 20260516 | `vem5m_d7_session_bb_rsi.set` · 2025.01–2026.05 | **119** | **1.17** | **+6.00** | **3.2** | habitat base — locked |
| D8 +EMA slope IS | 20260516 | `vem5m_d8_d7_ema_slope.set` · 2024.01–2026.05 | **270** | **0.99** | **−0.38** | **7.75** | **discard — identical to D7** |
| D8 +EMA slope OOS | 20260516 | same · 2025.01–2026.05 | **119** | **1.17** | **+6.00** | **3.2** | **discard — 0 trades blocked** |
| D9 +BB walk IS | 20260516 | `vem5m_d9_d7_bb_walk.set` · 2024.01–2026.05 | **115** | **0.63** | **−15.17** | **7.6** | **discard — worse than D7** |
| D9 +BB walk OOS | 20260516 | same · 2025.01–2026.05 | **44** | **0.72** | **−4.81** | **4.0** | **discard — killed +$6 OOS** |
| E8a fail exit IS | 20260516 | `vem5m_e8a_d7_fail_exit.set` · 2024.01–2026.05 | **293** | **0.89** | **−6.66** | **5.1** | **discard — WR 46%** |
| E8a fail exit OOS | 20260516 | same · 2025.01–2026.05 | **122** | **0.86** | **−4.65** | **4.6** | **discard — vs D7 +$6** |
| E8b time-loss IS | 20260516 | `vem5m_e8b_d7_time_loss.set` · 2024.01–2026.05 | **293** | **0.92** | **−4.73** | **4.5** | **discard — WR 35%** |
| E8b time-loss OOS | 20260516 | same · 2025.01–2026.05 | **122** | **0.86** | **−4.48** | **4.5** | **discard — vs D7 +$6 / WR 34%** |
| E7 breakeven IS | 20260516 | `vem5m_e7_d7_breakeven.set` · 2024.01–2026.05 | **270** | **0.99** | **−0.38** | **7.75** | **discard — identical to D7** |
| E7 breakeven OOS | 20260516 | same · 2025.01–2026.05 | **119** | **1.17** | **+6.00** | **3.2** | **discard — null vs D7** |
| E9 partial IS | 20260516 | `vem5m_e9_d7_partial_midline.set` · 0.02 lots · 2024.01–2026.05 | **418** | **0.96** | **−13.64** | **27.2** | IS fail vs D7 |
| E9 partial OOS | 20260516 | same · 0.02 lots · 2025.01–2026.05 | **202** | **1.12** | **+19.53** | **10.3** | **discard** (= D7 @ 0.02, not partial edge) |
| D7 @ 0.02 OOS | 20260516 | `vem5m_d7` · 0.02 lots · 2025.01–2026.05 | **202** | **1.12** | **+19.53** | **10.3** | same as E9 — size not exit |

### D1 vs baseline (IS 2024.01.01 → 2026.05.15)

| Metric | Baseline | D1 session | Δ |
|--------|----------|------------|---|
| Trades | 1429 | 1161 | **−268** (~19%) |
| Net profit | −$47.63 | **−$17.08** | **+$30.55** |
| Profit factor | 0.93 | **0.96** | +0.03 |
| Win rate | 61.1% | 62.0% | +0.9 pp |
| Avg win / avg loss | $0.69 / −$1.17 | $0.63 / −$1.06 | losses smaller |
| Max equity DD | 31.4% | **15.4%** | **−16 pp** |
| Sharpe | −2.28 | **−1.12** | improved |

**D3 verdict:** Session filter **works as intended** on IS (fewer trades, much lower DD, better net/PF). Still **not profitable** (PF &lt; 1).

### D4 OOS — `ReportTesterB-23489.xlsx` (`vem5m_d1_session.set`)

| Metric | Value |
|--------|-------|
| **Tester period** | **2025.01.01 → 2026.05.15** (charter OOS was **2025.07.01 → 2026.05.15** — wider window) |
| Trades | 701 (364 short / 337 long) |
| Net profit | **−$13.69** |
| Profit factor | **0.96** |
| Win rate | **60.2%** (422 W / 279 L) |
| Gross profit / loss | $308.48 / −$322.17 |
| Avg win / avg loss | **$0.73 / −$1.15** |
| Max equity DD | **15.20%** ($32.42) |
| Sharpe | −1.34 |

**D4 vs D3 (shape):** PF **unchanged** (~0.96), DD **still ~half** baseline IS (31%), still **PF &lt; 1**. Filter behavior **stable** on post-2024 data; not yet an edge.

### D4 head-to-head — same window **2025.01.01 → 2026.05.15**

| Metric | Baseline (`vem5m.set`) | Session (`vem5m_d1_session.set`) | Δ (session) |
|--------|------------------------|----------------------------------|---------------|
| Trades | 841 | 701 | **−140** (~17%) |
| Net profit | −$16.58 | **−$13.69** | **+$2.89** |
| Profit factor | 0.96 | 0.96 | tie |
| Max equity DD | 20.6% | **15.2%** | **−5.4 pp** |
| Win rate | 60.1% | 60.2% | ~flat |
| Avg win / avg loss | $0.79 / −$1.24 | $0.73 / −$1.15 | slightly smaller losses |

Baseline confirmed via tester ini `VEM.EURUSD.M5.20250101_20260515.000.ini` (`inp_session_filter_enable=false`).

**D5 verdict:** **Keep** session filter — beats baseline on **net $** and **DD** on identical OOS window; PF still &lt; 1 (not profitable).

**Step E (2026-05-16):** E1–E5 done · E6 **deferred** (low loser MFE — exit tweak not primary). See [`step-e-results.md`](step-e-results.md) · [`step-e-d0-experiment.md`](step-e-d0-experiment.md).

**Habitat base — locked (2026-05-16):** **`vem5m_d7_session_bb_rsi.set`** — session + BB width + RSI depth. Use for **D8+** and exit tests. OOS **+$6.00** / PF **1.17** / 119 tr; IS weaker than D6 (−$0.38 vs +$4.98) — accepted for stronger OOS / long-run profile. See [`step-d7-d0-experiment.md`](step-d7-d0-experiment.md).

**Comparison profile (not default base):** **`vem5m_d6_session_bbwidth.set`** — session + BB width only. IS **+$4.98** / PF **1.03**; OOS **−$4.58** / PF **0.96** ([`step-d6-d0-experiment.md`](step-d6-d0-experiment.md)).

### Long test — full habitat (authoritative stability run)

**Settings** (from `VEM.EURUSD.M5.20200101_20260515.000.ini`): **`vem5m_d7_session_bb_rsi.set`** (session + BB width + RSI depth) · **2020.01.01 → 2026.05.15** · **$500** deposit · 0.01 lots.

| Metric | Value |
|--------|-------|
| Trades | **725** |
| Net profit | **+$21.71** |
| Profit factor | **1.11** |
| Win rate | **65.4%** |
| Max equity DD | **3.0%** |
| Sharpe | **3.01** |
| Avg win / loss | $0.46 / −$0.78 |

~**113 trades/year** over 6+ years — low frequency but **stable** PF and drawdown.

**Note:** An earlier screenshot (**1,620** trades, **+$43**, $200 deposit, 2020.12.31 start) used **`vem5m_d6_session_bbwidth.set` only** (no RSI depth). Do not mix the two runs.

| Run label | Set | Period | Deposit | Trades | Net $ | PF |
|-----------|-----|--------|---------|--------|-------|-----|
| Long test (this) | **D7** all filters | 2020.01–2026.05 | **$500** | **725** | **+21.71** | **1.11** |
| Extended D6 only | D6 | 2020.12–2026.05 | $200 | 1,620 | +43.07 | 1.10 |
| Edge-discovery IS | D6 | 2024.01–2026.05 | $200 | 724 | +4.98 | 1.03 |
