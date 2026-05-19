# VEM Edge Discovery

Phase 2 playbook: find where the strategy already wins, then stop it from trading everywhere else.

**Prerequisite:** Phase 1 execution engine is operational (signal → risk → execution).  
**Companion docs:** `concept.md` (strategy definition), `edgeopt.md` (philosophy and isolation framework), `addtionalnotes.md` (trade profiles and first-filter ideas — merged below).

---

## Core mindset

Do **not** ask: *"Does RSI + BB + volume work?"*

Ask: *"In which market states does it already make money?"*

Most mean-reversion systems are **not** globally profitable. They work in subsets (range, exhaustion, stretch + rejection) and bleed in others (trend, BB walk, momentum expansion). Your job is to discover those subsets, protect them, and remove the rest.

**Sequence:** isolate profitable behavior → remove destructive behavior → make the edge repeatable → only then consider AI/scoring.

---

## What "isolating the edge" means

Answer:

> Under what exact market conditions does this RSI + BB + Volume setup make money consistently?

Not whether the strategy works on all bars, all sessions, or all volatility states.

**Likely winners (habitat):**

- Ranging environments
- Moderate volatility
- Temporary emotional extremes / overextensions
- Failed pushes, rejection wicks
- Volatility climax then stall (not acceleration)

**Likely losers (anti-habitat):**

- Persistent directional trends
- BB walk (price stays outside band)
- Breakout / momentum continuation
- Rising ATR with directional closes
- News-driven momentum

The EA currently treats both populations equally unless you add context filters.

---

## How this maps to VEM today

**In place:**

- Signal pipeline: BB pierce + RSI threshold + volume spike (`VEM_Signal.mqh`)
- Risk gates, sizing, SL/TP, optional BB midline exit
- Modular headers for future filters (`VEM_Risk.mqh`, etc.)

**Not yet in place (Phase 2 work):**

- Per-trade feature snapshot at entry
- MAE/MFE on close
- CSV export for bucket analysis

**Note:** Defaults in `VEM_Config.mqh` may target faster TFs (e.g. RSI 62/38, BB 14/1.8). `concept.md` describes classic H1–D settings (BB 20/2, RSI 30/70). Isolate edge **per symbol + timeframe + parameter set**, not as one global story.

---

## Regime-first, parameters-second

1. **Segment** trades by regime (trend/range, volatility, session, BB width, RSI depth).
2. Compare PF, expectancy, drawdown **per bucket**.
3. **Remove** whole categories of bad trades (filters).
4. **Optimize** only inside the surviving habitat.
5. Avoid stacking many filters on one in-sample period.

Filtering usually beats endlessly tweaking entry thresholds.

---

## Hypothesis buckets (manual / CSV)

| Bucket | What to test | If losers dominate |
|--------|----------------|---------------------|
| Trend | ADX high, strong EMA slope, price far from BB mid | Trend / slope filter |
| BB walk | Multiple closes outside same band | Cooldown, no same-side re-entry |
| Volatility | ATR percentile low vs high | Min/max ATR band |
| Band state | BB width narrow (squeeze) vs wide | Minimum BB width |
| RSI depth | Shallow OS/OB vs deep extreme | Tighten RSI threshold |
| Session | Asia / London / NY | Session allowlist |
| Direction | Long vs short separately | Direction permission |

**Trust rule of thumb:** prefer buckets with PF > 1.3 and at least **30–50 trades** before treating as real edge.

---

## Trade quality profiles (make this explicit)

Buckets, filters, and regimes are not enough until you write a formal **good trade vs bad trade** profile. This document becomes:

- the source of future filters
- labels for any later ML / scoring
- a checklist when reviewing CSV rows or chart samples

Refine these from your data; treat the tables below as **starting hypotheses**, not facts.

### Good long (habitat)

| Signal | Target pattern |
|--------|----------------|
| BB | Width expanded but expansion **slowing** (climax, not runaway) |
| RSI | Deep oversold, e.g. &lt; 22 (tune from CSV) |
| Candle | Long lower wick, rejection close |
| Volume | Spike clearly above baseline, e.g. &gt; 1.8× MA |
| ATR | Elevated but **stabilizing**, not exploding bar-over-bar |
| Mean | Price stretched from EMA / BB mid; weak opposing slope |
| Structure | Failed push, not clean continuation |

### Bad long (anti-habitat)

| Signal | Avoid pattern |
|--------|----------------|
| Trend | Strong down EMA slope |
| BB walk | Multiple prior closes already outside lower band |
| ATR | Rapid expansion (acceleration, not exhaustion) |
| Candle | Small or no lower wick; body closes weakly |
| Structure | Momentum continuation candles in trend direction |

### Good short / bad short

Mirror the long profiles (upper wick rejection, closes outside upper band walk, strong up slope, etc.).

**Workflow:** After Step C CSV exists, compare median feature values for winners vs losers and **edit this section** with your symbol/TF-specific numbers.

---

## Market structure context (gap beyond indicators)

Current edge work mostly measures **indicator state** at entry. BB + RSI + volume alone struggle to separate:

- **Exhaustion** (snapback habitat)  
- **Acceleration** (trend / walk habitat)

Eventually log and bucket **structure**, not only oscillators:

| Dimension | Examples to log or score |
|-----------|---------------------------|
| HTF context | Distance from higher-TF mean / midline |
| Local slope | EMA slope or simple regression over N bars |
| Compression vs expansion | BB width change rate; range vs breakout |
| Impulse vs exhaustion | Large directional bar vs rejection bar |
| Persistence | Consecutive same-direction closes; closes outside BB |

This is likely where the **largest PF gains** appear after basic habitat filters. Add structure fields to CSV in Step C when indicator-only buckets plateau.

---

## First filters to test (priority order)

> **Updated after Step B (EURUSD M5 baseline).** Theoretical order below; **actual Step D order** follows B6/B7 evidence in `step-b-complete-results.md`.

| Priority | Filter | Hypothesis | Rule sketch | Step B evidence |
|----------|--------|------------|-------------|-----------------|
| **1 — Step D1** | **Session / hour** | NY overlap / hour-13 momentum kills mean reversion | Block entries **13:00–15:00** server time (tester); optional expand to **13–21** after OOS | B6 full 1,429 trades: hour 13 −$18.55; NY 13–21 −$34 |
| **2 — Step D2** | Min BB width | Wide bands = continuation / noise | Require minimum BB width or block `wide` tercile | B4: wide −$11.92 vs narrow +$3.97 |
| **3 — Step D3** | RSI depth | Shallow extremes fail on shorts | Tighten short OB / prefer deep OS on longs | B5 bucket P/L |
| **4 — optional trial** | BB walk prevention | Persistence outside band | No entry if **2–3** prior closes outside same band | B9 **weak** (~26% losers vs winners) |
| **5 — defer** | Wick rejection | No rejection at signal bar | Min wick % of range | B10 **weak** |
| **6 — later** | Trend / slope | Drift overwhelms touch | EMA slope or ADX cap | B1: combine with session, not alone |

**Why session first now:** Only filter with strong **$** separation on **all** trades (Excel report). BB walk / wick looked good in theory but did not separate winners vs losers in bar analysis (818-trade sample).

---

## Filter design: hypothesis, not condition trees

Do **not** grow filters into giant AND trees (`RSI &lt; 22 AND ATR &lt; … AND ADX &lt; …`).

Each filter should represent **one market hypothesis** with one primary rule.

| Bad | Good |
|-----|------|
| Opaque stack of thresholds | Named hypothesis + single mechanism |
| “More indicators = safer” | “Remove one failure mode per iteration” |

**Example (current Step D1)**

- **Hypothesis:** Mean reversion fails during NY overlap / hour-13 expansion.  
- **Filter:** No entries when signal-bar hour is 13, 14, or 15 (server time).  
- **Validate:** Strategy Tester IS + OOS vs `baseline-eurusd-m5-20260516.md`; not a new CSV export.

Implement filters in `VEM_Risk` (or a dedicated gate module) with **on/off inputs** and documented rationale in config comments.

---

## Feature logging (highest-ROI code change)

Log one row per **closed** trade. Minimum fields:

**Identity & outcome**

- Entry time, exit time, symbol, timeframe, side
- Profit (money and R), exit type (SL / TP / midline / opposite signal)
- Bars held

**At entry**

- RSI, BB width, distance outside band
- Volume ratio (bar vol / vol MA)
- ATR, spread (points)
- Candle body size, wick size, wick % of range (for rejection filter backtest)
- Consecutive closes outside same BB (count at signal bar)
- BB width and optional width change rate (compression vs expansion)
- Optional: hour, day of week, EMA distance, EMA slope, ATR change rate, HTF distance

**On close**

- MAE (max adverse excursion), MFE (max favorable excursion), in points or R

Analyze: group by bucket → PF, avg R, win rate. Compare **medians** of winners vs losers, not only means.

---

## MAE/MFE interpretation

| Pattern | Likely issue | Action |
|---------|----------------|--------|
| Winners often dip far before TP | SL too tight or entry early | Wider ATR SL, or later entry |
| Losers reach high MFE then lose | TP too far or exit too slow | Midline exit, lower R:R, faster exit |
| Losers fail quickly with low MFE | Wrong context (trend) | **Filter**, not wider SL |
| Winners and losers similar MAE | Entry signal not selective enough | Regime filters first |

---

## Phase 2 priority stack

1. Feature logging (CSV)
2. Trade analytics (buckets)
3. Regime segmentation
4. Filter discovery (one at a time)
5. Retest on out-of-sample period
6. **Only then:** scoring / ML / confidence layers

---

## What not to do yet

- ML on small samples (< few hundred labeled trades)
- Global optimization of many inputs before segmentation
- Chase win rate alone (mean reversion can be ~45% WR with good PF)
- Assume one filter works on all symbols and timeframes
- Stack five filters fitted on one backtest window

---

## Checklist: Steps A → E

Use this as a working checklist. Check items in order; do not skip baseline (A) before logging (C).

---

## Recorded baselines

### baseline-eurusd-m5-20260516

Full write-up: [`baseline-eurusd-m5-20260516.md`](baseline-eurusd-m5-20260516.md)  
Set file: `MQL5/Profiles/Tester/vem5m.set` · Log: `Tester/.../logs/20260516.log`

| Metric | Value |
|--------|-------|
| Period | 2024.01.01 → 2026.05.15 · EURUSD M5 · every tick · $200 |
| Net profit | **−$47.63** |
| Profit factor | **0.93** |
| Total trades | **1,429** |
| Win rate | **61.09%** (873 / 556) |
| Avg win / avg loss | **$0.69 / −$1.17** |
| Max equity DD | **31.42%** ($67.21) |
| Long / short | 705 / 724 |
| Avg hold | ~52 min |

| Exit type | ~Share |
|-----------|--------|
| BB midline | **~80%** |
| Stop loss (200 pts) | **~18%** |
| Take profit (1.5R) | **~2%** |

**Diagnosis:** High WR + negative PF — small midline wins vs full SL in bad context (NY hours, M5). **Step B done** → **Step D1: session filter** → OOS retest. Use comparison table in baseline file for each filter run.

---

### Step A — Baseline (no new logic)

**Goal:** Know how the raw system behaves on one defined test cell (symbol + TF + inputs + date range).

- [x] **A1 — Define test cell** → [`baseline-eurusd-m5-20260516.md`](baseline-eurusd-m5-20260516.md)
  - [x] EURUSD M5 · `vem5m.set` · signal_shift=1
  - [x] 2024.01.01 → 2026.05.15 (~2.4y; extend to 2023 if full 3y needed)

- [x] **A2 — Strategy Tester setup**
  - [x] Every tick · $200 · 1:500 · magic 2600511

- [x] **A3 — Run baseline backtest**
  - [x] Log: `Tester/.../logs/20260516.log`
  - [ ] Optional: save HTML report · export deals CSV

- [x] **A4 — Record headline metrics** (see baseline file table)

- [x] **A5 — Split baseline views**
  - [x] Long/short · exit mix from log · hour 8 / 13–14 · summer months

- [x] **A6 — Write one-paragraph diagnosis** (in baseline file)

**Exit criteria for Step A:** Done for EURUSD M5 `vem5m` — proceed to Step B.

---

### Step B — Hypothesis buckets (manual first)

**How-to:** [`phase-b-guide.md`](phase-b-guide.md) · **Results:** [`step-b-complete-results.md`](step-b-complete-results.md)

**Goal:** Form testable regime hypotheses before building filters. **Status: complete** (818/1429 analyzed; download 2024 M5 history for full set).

- [x] **B1 — Trend vs range** — automated (`step-b-complete-results.md`)
- [x] **B2 / B9 — BB walk** — weak signal (~26% both sides)
- [x] **B3 — ATR terciles** — all buckets slightly negative; mid/high worst
- [x] **B4 — BB width** — narrow best (+$3.97), wide worst (−$11.92)
- [x] **B5 — RSI depth** — deep OS longs / shallow OB shorts ranked
- [x] **B6 — Session / hour** — hour 13, NY 13–21 worst
- [x] **B7 — Prioritize** — session → BB width → RSI → walk optional
- [x] **B8 — Trade quality profiles** — rule-based + worst-10 table
- [x] **B10 — Wick %** — weak (medians ~16% both)

**Exit criteria for Step B:** **Done** — see `step-b-complete-results.md`. **818/1429** until 2024 M5 history downloaded in MT5.

---

### Step C — Feature logging (implementation)

**Goal:** Every closed trade becomes one analyzable row.

**Status (2026-05-18):** C1 **implemented** — see [`step-c1-d0-experiment.md`](step-c1-d0-experiment.md) · `vem5m_d7_c1_trade_log.set` · `scripts/analyze_vem_trade_log.py`

- [x] **C1 — Design CSV schema**
  - [ ] Filename pattern: e.g. `VEM_trades_SYMBOL_TF.csv` under `MQL5/Files/`
  - [ ] Header row with all column names (document in code comment)
  - [ ] Decide: points vs pips vs ATR-normalized for distances

- [ ] **C2 — Capture at entry (store in state)**
  - [ ] Timestamp, ticket, side, entry price
  - [ ] RSI, BB upper/mid/lower, BB width, distance outside band
  - [ ] Volume, volume MA, volume ratio
  - [ ] ATR, spread at entry
  - [ ] Signal bar: body size, upper/lower wick size, wick % of range
  - [ ] `consecutive_closes_outside_bb` (same side as signal)
  - [ ] BB width; optional prior-bar width for expansion rate
  - [ ] Optional: hour, day of week, EMA distance, EMA slope, ATR delta

- [ ] **C3 — Track during trade**
  - [ ] Update running MAE (max adverse) and MFE (max favorable) in points or R
  - [ ] On tick or on bar — document which you use

- [ ] **C4 — Write row on close**
  - [ ] Hook: `OnTradeTransaction` or state sync when position closes
  - [ ] Append: exit time, exit price, profit, exit reason enum
  - [ ] Append: MAE, MFE, bars held
  - [ ] Flush file safely (avoid partial lines on crash)

- [ ] **C5 — Tester validation**
  - [ ] Run short backtest; confirm CSV created in `Files/`
  - [ ] Row count ≈ number of closed trades in report
  - [ ] Spot-check 3 rows against chart manually

- [ ] **C6 — Analysis template**
  - [ ] Excel or Python notebook: load CSV, pivot by bucket columns
  - [ ] Predefine bucket cuts (e.g. ADX < 20 / 20–30 / > 30) once data exists

**Exit criteria for Step C:** Reliable CSV for full baseline period from Step A.

---

### Step D — Remove bad environments (one filter at a time)

**Goal:** Improve PF by subtracting habitat violations, not by overfitting entries.

**Prerequisites:** Step A baseline saved · Step B complete (`step-b-complete-results.md`) · **Filter #1 = session hours** (B6/B7).

**Does not require:** OneDrive M5 CSV exports · 1429-trade Python bar file · Step C (optional, later).

**Needs MT5 for:** D3/D4 Strategy Tester backtests (tester loads its own bars).

---

- [x] **D0 — Lock experiment (before coding)** → [`step-d-d0-experiment.md`](step-d-d0-experiment.md)
  - [x] Baseline reference: `baseline-eurusd-m5-20260516.md` + `vem5m.set`
  - [x] **Filter #1 hypothesis:** NY / hour-13 momentum destroys mean reversion on M5
  - [x] **Rule v1:** block signal-bar hours **13, 14, 15** (server / tester time)
  - [x] **IS period:** 2024.01.01 → 2026.05.15 (same as Step A)
  - [x] **OOS period:** 2025.07.01 → 2026.05.15 (do not retune on OOS)
  - [x] Comparison table row added (`baseline-eurusd-m5-20260516.md`)

- [x] **D1 — Session filter implemented** (code + set file)
  - [x] B6 evidence: full 1,429 trades (`step-b-complete-results.md`)
  - [x] `VEM_Config.mqh` — `inp_session_filter_enable`, `inp_block_hour_start/end`
  - [x] `VEM_Risk.mqh` — `VEM_Risk_CheckSession` on **signal bar** time (`s.bar_time`)
  - [x] Default **off** — `vem5m.set` unchanged for baseline
  - [x] `MQL5/Profiles/Tester/vem5m_d1_session.set` — filter **on**, hours 13–15

- [x] **D3 — In-sample retest** — see `baseline-eurusd-m5-20260516.md` comparison table
  - [x] 1161 trades (−268), PF **0.96**, net **−$17.08**, DD **15.4%** vs baseline 0.93 / −$47.63 / 31.4%
  - [x] **Keep filter** — run **D4 OOS** next (still PF &lt; 1 on IS)

- [x] **D4 — Out-of-sample retest** — `ReportTesterB-23489.xlsx`
  - [x] `vem5m_d1_session.set` · **2025.01.01 → 2026.05.15** (user window; charter was Jul 2025 start)
  - [x] 701 trades, PF **0.96**, net **−$13.69**, DD **15.2%**
  - [x] Baseline `vem5m.set` same dates — 841 trades, −$16.58, DD 20.6% → session **wins** net + DD
  - [x] D4 pass — v1b (hour 13 only) **not needed**

- [x] **D5 — Document**
  - [x] `baseline-eurusd-m5-20260516.md` — keep / discard + head-to-head table
  - [x] `VEM_Config.mqh` — session filter comment (hypothesis + default off)

- [x] **D6 D0 — BB width lock** → [`step-d6-d0-experiment.md`](step-d6-d0-experiment.md)
- [x] **D6 code** — `inp_bb_width_filter_enable`, `inp_bb_max_width_ratio`, `VEM_Risk_CheckBBWidth`
- [x] **`vem5m_d6_session_bbwidth.set`** — session on + block wide (`ratio > 0.00165`)
- [x] D6 OOS 2025.01–2026.05 — 373 trades, −$4.58, PF 0.96, DD 8.4% → **keep** vs session
- [x] D6 IS 2024.01–2026.05 — 724 tr, **+$4.98**, PF **1.03**, DD 8.0%
- [x] Comparison table OOS row in `baseline-eurusd-m5-20260516.md`
- [x] **D6 D5 OOS** — **keep** BB width filter (IS backtest pending)
- [x] **D7 D0 — RSI depth** → [`step-d7-d0-experiment.md`](step-d7-d0-experiment.md)
- [x] **D7 code** — `inp_rsi_depth_filter_enable`, long max 25 / short min 75
- [x] **`vem5m_d7_session_bb_rsi.set`**
- [x] D7 IS/OOS vs `vem5m_d6_session_bbwidth.set` — conditional keep; **habitat base locked to D7** (2026-05-16)
- [x] **D8 / D8b** — EMA slope **DISCARD** → [`step-d8-d0-experiment.md`](step-d8-d0-experiment.md)
- [x] **D9** — BB walk **DISCARD** (OOS −$4.81 vs D7 +$6) → [`step-d9-d0-experiment.md`](step-d9-d0-experiment.md)
- [x] **E8a** — failure exit **DISCARD** (OOS −$4.65, WR 47% vs D7 69%) → [`step-e8a-d0-experiment.md`](step-e8a-d0-experiment.md)
- [x] **E7** — breakeven v1 **DISCARD** (null vs D7) → [`step-e7-d0-experiment.md`](step-e7-d0-experiment.md)
- [x] **E9 code** — partial midline + `vem5m_e9_d7_partial_midline.set` → [`step-e9-d0-experiment.md`](step-e9-d0-experiment.md)
- [x] **E9** — **DISCARD** (same as D7 @ 0.02) → [`step-e9-d0-experiment.md`](step-e9-d0-experiment.md)
- [x] **E8b** — time-in-loss **DISCARD** (OOS −$4.48, WR ~34% vs D7 69%) → [`step-e8b-d0-experiment.md`](step-e8b-d0-experiment.md)
- [x] **E8c** — worse structure **KEEP** → [`step-e8c-d0-experiment.md`](step-e8c-d0-experiment.md)
- [x] **Production:** **`vem5m_d7_session_bb_rsi.set` @ 0.01** — D7 habitat + **E8c** (midline + structural scratch)

**Exit criteria for Step D (filter #1):** Session filter validated IS + OOS vs baseline on same window — **done 2026-05-16**.

**Working habitat (Phase 2b):** **`vem5m_d7_session_bb_rsi.set`** — D1 + D6 + D7. D6-only set = benchmark only.

**Phase 2b (D7 habitat + simple exits):** **Complete** — see [`filtersrecommedations.md`](filtersrecommedations.md) master list.

**Phase 2c complete (practical):** Production **D7+E8c** locked. E10 parked, E11 null, D8–D11 discard. **Phase 2d complete.** Dev next: **C1b** / optional E13–E14. **Forward/demo + AI layer:** [`filtersrecommedations.md`](filtersrecommedations.md) §9 (**DEV-G** → **AI-0…AI-5**) — not until dev gate. Profiles: [`trade-profile.md`](trade-profile.md).

---

### Step E — MAE/MFE and exit refinement

**Goal:** Tune exits and stops using excursion data, not gut feel.

**Prerequisites (must match this checklist — do not skip):**

- [x] Step D filter #1 **kept** — use **`vem5m_d1_session.set`** for all E work (session on)
- [x] Step A exit diagnosis read — ~80% BB midline, ~18% full SL, TP rare (`baseline-eurusd-m5-20260516.md`)
- [x] Step C **optional** — used `scripts/step_e_mae_mfe_analyze.py` on `ReportTesterB-23489.xlsx` instead
- [x] **Do not** run D6 until Step E complete — E6 deferred with rationale → **D6 eligible**

**Working profile:** `vem5m_d1_session.set` · control = prior session OOS row (701 trades, −$13.69, PF 0.96, DD 15.2%, **2025.01.01 → 2026.05.15**).

**Order:** Complete **E1 → E2 → E3 → E4 → E5** in sequence (analysis before retest). **E6** only after one coded change from E3 or E4.

- [x] **E1 — Winner MAE** — median **0.18R**, 75th **0.34R** ([`step-e-results.md`](step-e-results.md))
- [x] **E2 — Loser MFE** — median **0.15R**; **10.9%** >0.5R; **4.4%** >0.8R
- [x] **E3 — SL decision** — **keep 200 pts**; do not widen (winners rarely use 1R)
- [x] **E4 — TP / midline** — **keep midline**; do not lower `inp_tp_rr` (losers fail fast, low MFE)
- [x] **E5 — Hold time** — winners **9** bars median vs losers **14**; no max-bars rule
- [x] **E6 — Retest** — **deferred** (documented skip in [`step-e-d0-experiment.md`](step-e-d0-experiment.md))

**Exit criteria for Step E:** **Met** via analysis + documented E6 skip → proceed to **D6**.

**References:** [`step-e-results.md`](step-e-results.md) · `scripts/step_e_mae_mfe_analyze.py` · MAE/MFE table above · `concept.md` exit precedence.

---

## End-to-end flow (summary)

```
A Baseline → B Hypotheses → D filter #1 session (D0–D5) → E exits (E1–E6) → [optional D6 filter #2…] → Phase 3
         └─ optional C CSV logging (parallel; helps E1–E2, not required for D3/D4)
```

Step C can run in parallel but is **not** required before D3/D4 or before starting E (tester MAE/MFE charts are enough to begin E1–E2 qualitatively).

When **DEV-G** is met (locked prod + C1b + rule queue paused), use Phase 3 sequence in [`filtersrecommedations.md`](filtersrecommedations.md) §9: **AI-0** demo → **AI-1** C1 accumulate → **AI-2…AI-5** offline model → simulate → shadow → wire. Not during active Phase 2d backtest sweeps.

---

## References

- `baseline-eurusd-m5-20260516.md` — Step A baseline metrics, exit mix, diagnosis, comparison template
- `phase-b-guide.md` — Step B workflow, Excel/report layout, B6 hour table from `ReportTester-23489.xlsx`
- `step-b-complete-results.md` — B7 filter queue feeding Step D1 (session first)
- `step-d-d0-experiment.md` — Step D0 locked experiment (filter #1 session)
- `step-e-results.md` · `step-e-d0-experiment.md` — Step E MAE/MFE + E6 defer
- `step-d6-d0-experiment.md` — Step D6 filter #2 (BB width)
- `step-d7-d0-experiment.md` — Step D7 filter #3 (RSI depth)
- `edgeopt.md` — full isolation philosophy and examples
- `concept.md` — v1 signal definition and optimization groups (safe vs structural inputs)
- `roadmap.md` — Phase 1 scope; session/filters explicitly deferred until engine is stable
- `addtionalnotes.md` — original notes on trade profiles, structure gap, and first filters (content integrated above)
