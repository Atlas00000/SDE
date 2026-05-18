# Step D7 — Experiment lock (Filter #3: RSI depth)

**Status:** **Done — habitat base locked for D8+**  
**Date locked:** 2026-05-16  
**Base decision (2026-05-16):** **D7** chosen over D6 for all Phase 2b work (D8, D9, E7–E9). Control for new tests = `vem5m_d7_session_bb_rsi.set`; D6 set used only as historical benchmark.

---

## Prerequisites

- Filters #1–#2 **kept** — `vem5m_d6_session_bbwidth.set` (session + BB width)
- Step E complete (E6 deferred)

---

## References

| Item | Path / value |
|------|----------------|
| Control | `MQL5/Profiles/Tester/vem5m_d6_session_bbwidth.set` |
| Test | `MQL5/Profiles/Tester/vem5m_d7_session_bb_rsi.set` |
| B5 evidence | [`step-b-complete-results.md`](step-b-complete-results.md) |
| D6 OOS control | 373 tr · −$4.58 · PF 0.96 · DD 8.4% |
| D6 IS | 724 tr · +$4.98 · PF 1.03 · DD 8.0% |

---

## Filter #3 — single hypothesis

**Name:** Deeper RSI at signal bar

**Hypothesis:** Entries on **shallow** band touches (RSI barely past 30/70) are net negative; require **deeper** oversold for longs and **deeper** overbought for shorts.

**Mechanism (one rule, two sides — same “depth” idea):**

| Side | Condition at signal bar (`inp_signal_shift`) |
|------|-----------------------------------------------|
| Long | `RSI <= inp_rsi_long_max_depth` (default **25**) — blocks shallow **25–30** bucket |
| Short | `RSI >= inp_rsi_short_min_depth` (default **75**) — blocks weak **70–75** zone |

Entry signal still uses `inp_rsi_os=30` / `inp_rsi_ob=70`; this filter **tightens** after raw signal passes.

**B5 (818-trade sample):**

| Bucket | Net P/L | Note |
|--------|---------|------|
| 25–30 (long) | −$10.05 | blocked by long max 25 |
| 70–75 (short) | −$1.77 | blocked by short min 75 |
| 75–80 (short) | −$12.95 | still allowed — fallback v7b if D7 fails |
| deep_<20 / 20–25 | positive | longs kept |

**Not in v1:** Change global `inp_rsi_ob`/`inp_rsi_os`, block 75–80, ADX/regime.

**Fallback v7b:** If D7 fails OOS, test `inp_rsi_short_min_depth=80` only (block 75–80).

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

Compare vs **`vem5m_d6_session_bbwidth.set`** on **identical dates**.

---

## Pass / fail (D7)

**Keep filter #3** if vs D6 control:

- [ ] Net profit improves (IS and/or OOS)
- [ ] PF ≥ D6 (1.03 IS / 0.96 OOS) or clearly better risk-adjusted
- [ ] Max DD not materially worse
- [ ] Trade count remains sufficient (OOS rough floor **> 250**)

**Discard** if trades collapse with no PF gain.

---

## Deliverables

- [x] D7 D0 — this file  
- [x] `VEM_Risk_CheckRSIDepth` + inputs in `VEM_Config.mqh`  
- [x] `vem5m_d7_session_bb_rsi.set`  
- [x] MetaEditor **F7** compile  
- [x] D7 IS backtest (screenshot 2026-05-16 · `20240101_20260515.ini`)  
- [x] D7 OOS backtest (screenshot 2026-05-16)  
- [x] D7 keep/discard — **conditional keep** (see below)  

---

## D7 IS result (tester screenshot 2026-05-16)

Window **2024.01.01 → 2026.05.15** (confirmed via `VEM.EURUSD.M5.20240101_20260515.000.ini`).

| Metric | D6 control (IS) | **D7 (+ RSI depth)** | Δ |
|--------|-----------------|----------------------|---|
| Trades | 724 | **270** | **−63%** |
| Net $ | **+$4.98** | **−$0.38** | **worse** |
| PF | **1.03** | **0.99** | −0.04 |
| Max equity DD | 8.0% | **7.75%** | ~flat |
| Win rate | 65.9% | **65.2%** | ~flat |
| Avg win / loss | $0.46 / −$0.87 | **$0.42 / −$0.79** | similar |

**IS verdict:** **Does not beat D6 on IS** — profitability lost (+$4.98 → −$0.38), trades cut too hard. **Do not adopt D7 yet.**

## D7 OOS result (tester screenshot 2026-05-16)

Window **2025.01.01 → 2026.05.15** (standard OOS; confirm in report tab).

| Metric | D6 control (OOS) | **D7 (+ RSI depth)** | Δ |
|--------|------------------|----------------------|---|
| Trades | 373 | **119** | **−68%** |
| Net $ | −$4.58 | **+$6.00** | **profitable OOS** |
| PF | 0.96 | **1.17** | +0.21 |
| Max equity DD | 8.4% | **3.2%** | much lower |
| Win rate | 64.3% | **68.9%** | +4.6 pp |
| Sharpe | — | **4.20** | strong |
| Avg win / loss | $0.46 / −$0.87 | **$0.51 / −$0.97** | loss still ~2× win |

**OOS verdict:** **Conditional keep** — metrics beat D6 clearly on net/PF/DD, but **119 trades** is below the ~250 OOS sample guideline (thin sample over ~16 months). **Recommendation:** adopt **`vem5m_d7_session_bb_rsi.set`** for forward testing **or** run **v7b** (`inp_rsi_short_min_depth=80` only) to recover trade count while keeping most of the edge.

**IS + OOS combined:** IS failed vs D6; OOS passed vs D6 — classic **IS/OOS split**. Prefer D7 for OOS-shaped validation; monitor live/demo trade frequency.

---

## D7 variants (retest OOS 2025.01.01 → 2026.05.15)

**Control for all:** `vem5m_d6_session_bbwidth.set` (373 tr, −$4.58, PF 0.96)  
**Reference full D7:** `vem5m_d7_session_bb_rsi.set` (119 tr, +$6.00, PF 1.17)

| Variant | Set file | Long gate | Short gate | Hypothesis |
|---------|----------|-----------|------------|------------|
| **D7 full** | `vem5m_d7_session_bb_rsi.set` | RSI ≤ 25 | RSI ≥ 75 | Both sides (done) |
| **D7b** | `vem5m_d7b_short80.set` | **off** | RSI ≥ **80** | Drop bad 75–80 shorts; **more trades** than full D7 (longs restored) |
| **D7 long-only** | `vem5m_d7_longonly_rsi.set` | RSI ≤ 25 | **off** | Test if **short** depth caused IS failure |

**Code:** `inp_rsi_depth_long_enable` / `inp_rsi_depth_short_enable` (master `inp_rsi_depth_filter_enable` must be true).

### Tester checklist (each variant)

1. F7 compile `VEM.mq5`  
2. EURUSD M5, every tick, **$200** deposit (match prior D6/D7 OOS)  
3. Dates: **2025.01.01 → 2026.05.15** (OOS); optional IS 2024.01.01 → 2026.05.15  
4. Save reports: `ReportTester-D7b-OOS.xlsx`, `ReportTester-D7-longonly-OOS.xlsx`

### Pass vs D6 OOS

- [ ] Net $ > −$4.58  
- [ ] PF ≥ 0.96 (prefer ≥ 1.05)  
- [ ] Trades **> 119** (full D7) and ideally **> 200**  
- [ ] DD ≤ ~10%

**Pick winner:** best net/PF with enough trades; if D7b or long-only beats full D7 on IS **and** OOS, update habitat `.set`.

## Expected shape

Moderate trade reduction (~10–25% vs D6) from removing shallow longs/shorts; net should improve if B5 holds on full tester sample. **Observed:** −28% trades, net −$0.38 vs −$4.58.
