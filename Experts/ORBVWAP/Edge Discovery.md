# ORBVWAP — Edge Discovery & Refinement Plan

Reference: [compo report.md](./compo%20report.md) · [concept.md](./concept.md)

**Status:** **PRODUCTION v3 promoted** (defaults = PROD stack). EA **v1.22** · **AI offline training CLOSED** · MT5 validation partial · LIVE pending.

**Production preset:** `Presets/ORBVWAP_PROD_EURUSD-M1.set` (alias: `_v3.set`) · superseded: `_v2.set` · See [System Profile.md](./System%20Profile.md)

| Metric | PROD v3 (v1.17 defaults) | PROD v2 | P0-002 baseline |
|--------|----------------------------|---------|-----------------|
| Profit factor | **1.40** | 1.34 | 0.91 |
| Win rate | 54.07% | 54.35% | 62.52% |
| Payoff ratio | **1.20** | 1.12 | 0.54 |
| Max DD | **2.51%** | 3.24% | ~50% |
| Trades | **172** | 184 | 1,646 |

**Stack:** Skip Wed+Fri · NY cut 16:00 · **NY delay 30 min (13:30+)** · Time stop 120 · MinRR 0.9 · SpreadRange 20% · P2D off · partial off.

**Next (recommended order):** Promote **AI-1 + AI-3 LIVE** (stack candidate) → **AI-2** MT5 shadow → **AI-4** path export + LIVE (last). See [ailayers.md](./ailayers.md).

---

**Original baseline snapshot (pre-Phase 2):**

| Metric | Value | Implication |
|--------|-------|-------------|
| Net profit | −75.04 | Negative expectancy |
| Profit factor | 0.91 | Close to breakeven structurally, not there yet |
| Win rate | 62.52% (1029 / 617) | **Entries have edge** — problem is not signal frequency |
| Avg win / avg loss | 0.72 / −1.33 | **~1 : 1.85 loss:win ratio** — losses erase wins |
| Largest win / loss | 6.24 / −11.82 | Tail losses ~2× tail wins |
| Max DD | ~50% | Unacceptable without circuit breakers |
| Total trades | 1,646 | High sample — patterns are statistically meaningful |
| Avg hold | 1h 55m · max 91h+ | No time-based exit — losers can bleed for days |
| Corr (profit, MFE) | 0.42 | Trades go favourable but exits don’t capture it |
| Corr (profit, MAE) | 0.68 | Trades go adverse deep before SL — failure containment weak |

**Core diagnosis:** The EA wins often but **pays too much per loss**. This is a **risk geometry + exit management + regime selection** problem, not a broken execution engine.

---

## What we know about the EA (structural facts)

These are **code-level truths** from Phase 1 — they explain backtest behaviour regardless of symbol or period.

### Entry logic (working as designed)

| Condition | Rule |
|-----------|------|
| Session | London 07:00–12:00 GMT and/or NY 13:00–17:00 GMT |
| Range | First N minutes (default 5) high/low, then LOCKED |
| Min range | Width ≥ 0.8 × ATR(14) |
| Long | `Close[1] > range_high` AND above session VWAP AND vol ≥ 1.5× 20-bar MA |
| Short | `Close[1] < range_low` AND below session VWAP AND vol ≥ 1.5× MA |
| Frequency cap | One breakout per session (`ALREADY_TRADED`) |

### Exit logic (root cause of negative R:R)

| Direction | Stop loss | Take profit |
|-----------|-----------|-------------|
| Long | `range_low` (full range below entry) | `entry + range_width` (1× measured move) |
| Short | `range_high` (full range above entry) | `entry − range_width` (1× measured move) |

**Structural R:R flaw:** Entry is at market **after** the breakout close, but SL is at the **opposite range boundary**. Risk distance = `entry − range_low` (long), which is **wider than `range_width`** because entry gaps above `range_high`. Reward is only `range_width`. Realised R:R is typically **0.7–0.9 : 1**, not 1 : 1.

Example (long):

```
range_low  = 1.0990
range_high = 1.1000   → width = 10 pips
entry ASK  = 1.1002   (after breakout)
SL         = 1.0990   → risk  = 12 pips
TP         = 1.1012   → reward = 10 pips
R:R        ≈ 0.83 : 1
```

At 62% win rate, breakeven needs R:R ≈ 0.58 : 1 — so **you should be profitable on paper**. Spread, slippage, false breakouts that run to full SL, and **91-hour holds** push realised results below breakeven.

### What is NOT in the EA yet

- No trailing stop or partial TP (P2-007, P2-008)
- No break-even move (P2-006 tested — REJECT)
- No session **sub-window** (P2B-003)
- P2D circuit breakers — **implemented v1.09, off by default** (sweep NO-OP on harness)
- Breakout freshness filter — **P4B-003** (optional; off on PROD v3)
- Partial TP / runner trail (P2-008) — **not on PROD; Phase 4A**

### Implemented on PROD (v1.10 defaults)

- Time stop (`InpMaxHoldMinutes`) — **120 min on PROD**
- Minimum R:R gate (`InpMinRR`) — **0.9 on PROD**
- NY entry cutoff (`InpNoEntryAfterHour`) — **16:00 GMT on PROD**
- Weekday skip (`InpSkipWeekdays`) — **Wed+Fri on PROD**
- P2C entry filters — **SpreadRange20 on PROD v2**
- P2D circuit breakers (`CircuitBreakers.mqh`) — **off; sweep NO-OP**

---

## Pattern analysis — when the EA performs vs bleeds

From your backtest distributions (hourly, daily, monthly, MFE/MAE).

### Sessions and hours

| Window (GMT) | Behaviour | Likely cause |
|--------------|-----------|--------------|
| **00:00–08:00** | Near-zero entries | Session gate working — Asian noise excluded |
| **09:00–10:00** | High activity + mixed P/L | London post-range breakouts — **core edge zone** |
| **10:00–12:00** | Continued activity | London continuation / false breakouts |
| **13:00–14:00** | Moderate | Pre-NY / London close overlap |
| **15:00–16:00** | High activity + **largest loss bars** | NY open volatility — false breakouts, wide SL hits |
| **17:00–21:00** | Losses > wins consistently | Late session chop — ORB edge decays after open impulse |
| **22:00+** | Low activity | Outside primary windows |

**Strength:** London morning (post range-lock, ~09:00–11:00 GMT).  
**Weakness:** NY open hour (15:00–16:00) and entire late-US window (17:00–21:00).

### Weekdays

| Day | Pattern |
|-----|---------|
| Mon, Tue, Thu | Relatively balanced |
| **Wednesday** | Losses outweigh wins — mid-week reversal risk |
| **Friday** | Losses outweigh wins — position squaring, thinner follow-through |

### Months (seasonal)

Weaker months in test: **March, July, September, October** — often higher macro volatility / regime shifts. Treat as hypothesis until journal confirms per-symbol.

### Win vs loss trade morphology

| Observation | MFE / MAE data | Meaning |
|-------------|----------------|---------|
| High win rate | 62.52% | Breakout + VWAP + volume **does** predict direction often |
| Small avg win | 0.72 | TP capped at 1× range; many winners closed below full TP |
| Large avg loss | −1.33 | Full SL at opposite boundary; gaps and drift inflate loss |
| MFE corr 0.42 | Trades go +3–4 units then close flat/loss | **Leaving money on table AND not cutting early** |
| MAE corr 0.68 | Losers go deep (−12) before exit | SL too far OR no time stop OR no early invalidation |
| Max hold 91h | — | Positions held across sessions — **not an ORB scalp anymore** |

**Fundamental pattern:** The EA behaves like a **high-win-rate breakout system with asymmetric exits** — it confirms direction often, but **failure trades are full-sized and slow**, while winners are **capped**.

---

## Edge hypothesis (what to isolate)

| Hypothesis ID | Statement | Test approach |
|---------------|-----------|---------------|
| **H1** | Entry edge exists (~60%+ WR) | Compare WR by session sub-window without changing exits |
| **H2** | Negative PF is driven by R:R geometry, not entries | Same entries, vary TP mult / SL placement |
| **H3** | NY open (15–16 GMT) is net-negative | Session sub-filter; compare PF |
| **H4** | Late session (17–21 GMT) is net-negative | Cut trading after hour X |
| **H5** | Long holds (>2h) are net-negative | Time stop at 60/120 min |
| **H6** | Wednesday / Friday are net-negative | Day-of-week filter |
| **H7** | MTF alignment removes counter-trend losers | D1 EMA + H4 structure filter |
| **H8** | Volatility regime explains Mar/Jul/Sep/Oct | ADX + ATR expansion filter |

Validate one hypothesis per test cycle. Do not change ten inputs at once.

---

## Preset naming convention (testing workflow)

Save presets in: `MQL5/Presets/ORBVWAP/`

**Format:**

```
ORBVWAP_{TaskID}_{Context}_{Variant}.set
```

| Segment | Meaning | Example |
|---------|---------|---------|
| `TaskID` | Implementation ID from this doc | `P4A-001` |
| `Context` | Symbol + period + date range shorthand | `EURUSD-M1-2025H1` |
| `Variant` | What changed vs baseline | `TP15x-baseline` |

**Baseline preset (always keep one unchanged):**

```
ORBVWAP_BASELINE_P1_EURUSD-M1_full.set
```

**Examples after each implementation:**

```
ORBVWAP_P2-001_SLmidRange_EURUSD-M1_full.set
ORBVWAP_P2-002_TP15xRange_EURUSD-M1_full.set
ORBVWAP_P2-004_NYcut1600_EURUSD-M1_full.set
ORBVWAP_P4A-001_Partial50_Run15x_PROD_EURUSD-M1_full.set
ORBVWAP_P4B-001_NYstart1330_PROD_EURUSD-M1_full.set
```

**Test journal entry template (copy per run):**

```
TaskID: P2-003
Preset: ORBVWAP_P2-003_TimeStop120_EURUSD-M1_full.set
Symbol/TF: EURUSD M1
Period: YYYY.MM.DD – YYYY.MM.DD
vs Baseline: PF +0.XX | WR -X% | DD -X% | Trades -XXX
Verdict: KEEP / REJECT / TUNE
Notes: ...
```

---

## Implementation phases

Work **one Task ID at a time**. Compile → save preset → backtest vs `BASELINE` → log verdict → next task.

---

### Phase 0 — Baseline lock & diagnostics (no code)

**Runbook:** [Phase0-Harness.md](./Phase0-Harness.md)

| ID | Task | Output | Status |
|----|------|--------|--------|
| **P0-001** | Export and save `ORBVWAP_BASELINE_P1_*` preset with current inputs | Baseline .set file | ✅ Done |
| **P0-002** | Run baseline backtest; record PF, WR, DD, trades, avg win/loss in journal | Baseline metrics row | ✅ PASS — PF 0.91, 1659 trades, −72.01 |
| **P0-003** | Enable `InpEnableFileJournal=true`; run 1 month; tally rejection codes | Rejection histogram | ✅ PASS — see `Diagnostics/P0-003_rejection-histogram.csv` |
| **P0-004** | Strategy Tester → Report → export HTML; tag trades by hour/day/session | CSV for hour/day analysis | ✅ PASS — `Diagnostics/P0-004-temporal-summary.csv` |
| **P0-005** | Split baseline trades: London-only vs NY-only (tester filter or manual) | Session edge table | ✅ PASS — `Diagnostics/P0-005-session-split.csv` |

**Presets:** `Presets/` and `MQL5/Profiles/Tester/` · **Templates:** `Diagnostics/`

**Gate:** Baseline documented before any Phase 2 code.

---

### Phase 2A — Exit & R:R geometry (highest priority)

*Fix “we win often but lose bigger.” Hooks: `RiskEngine.mqh`, new `ExitManager.mqh`, `OnTick` open-position branch.*

| ID | Task | Params | Preset variant | Expected effect |
|----|------|--------|----------------|-----------------|
| **P2-001** | SL at range **midpoint** instead of opposite boundary | `InpSlMode`: OPPOSITE / MID_RANGE | `SLmid_TimeStop120` | **CLOSED** — REJECT; WR −7pts kills net; keep OPPOSITE (`P2-001-test-journal.csv`) |
| **P2-002** | SL = breakout level − `InpSlBufferAtr × ATR` | buffer 0.1–0.3 ATR | `SLbreakoutAtr` | Tighter invalidation |
| **P2-003** | TP = `InpTpRangeMult × range_width` (default 1.0 → test 1.25, 1.5, 2.0) | mult 1.0–2.0 | `TP125x` `TP15x` `TP20x` | **CLOSED — keep 1.0**; all extensions REJECT (`P2-003-test-journal.csv`) |
| **P2-004** | Enforce minimum R:R at entry (`InpMinRR` gate) | 0.7–1.5 | `MinRR09_SkipWedFri` | **CLOSED** — **STACK_LEADER** at 0.9 (+17.75, PF 1.32, n=186; `P2-004-test-journal.csv`) |
| **P2-005** | Time stop: close at market after `InpMaxHoldMinutes` | 60, 120, 180 | `TimeStop60` `TimeStop120` `TimeStop180` | **CLOSED** — 120 min STACK_CANDIDATE; default stays 0 (`P2-005-test-journal.csv`) |
| **P2-006** | Break-even: move SL to entry at `InpBeTrigger × range_width` profit | 0.5, 0.75 | `BE05_TimeStop120` `BE075_TimeStop120` | **CLOSED** — REJECT all; keep `InpBeTrigger=0`; stack base stays TimeStop120 (`P2-006-test-journal.csv`) |
| **P2-007** | Trailing stop: trail by `InpTrailAtr × ATR` after BE trigger | 0.5–1.0 ATR | `TrailAtr05` | **BACKLOG → Phase 4A** (runner trail, not standalone BE) |
| **P2-008** | Partial close: 50% at 1× range, runner to 1.5× | % + levels | `Partial50` | **BACKLOG → Phase 4A** (retest on PROD ref, not full TP mult) |

**Recommended order:** P2-003 → P2-005 → P2-001 → P2-006 → P2-007 → P2-004.

**Gate:** PF ≥ 1.0 on full test period OR DD reduced ≥30% with PF ≥ 0.95 before Phase 2B.

---

### Phase 2B — Session & time filters (trade quality)

*Hooks: `SessionUtils.mqh`, `SignalEngine.mqh` or `CanTrade()`.*

| ID | Task | Params | Preset variant |
|----|------|--------|----------------|
| **P2B-001** | Trade **London only** (`InpActiveSession = LONDON`) | session enum | `LondonOnly` |
| **P2B-002** | Trade **NY only** | session enum | `NyOnly` |
| **P2B-003** | Sub-window: only trade `InpTradeStartMin`–`InpTradeEndMin` after session open | e.g. 5–90 min | `WinPostOpen60` | **BACKLOG → Phase 4B** (test on PROD ref) |
| **P2B-004** | Hard cut: no entries after GMT hour `InpNoEntryAfterHour` | 16 or 17 | `NYcut1600_TimeStop120` `NYcut1700_TimeStop120` | **CLOSED** — NYcut1600 **STACK_LEADER** (−31.23, PF 0.95); 1700 no-op (`P2B-004-test-journal.csv`) |
| **P2B-005** | Skip Wednesday / Friday (`InpSkipWeekdays` bitmask) | Wed+Fri=40 | `SkipWedFri_NYcut1600_TimeStop120` | **CLOSED** — **STACK_LEADER** (−11.87, PF 0.97, DD 15.6%; `P2B-005-test-journal.csv`) |
| **P2B-006** | Breakout freshness: close must break range within N bars of lock | N = 3, 5, 10 | `FreshBreak5` |

**Gate:** Identify best session combo; PF improvement without collapsing trade count below ~200/year.

---

### Phase 2C — Entry quality filters (regime & structure)

*Hooks: `SignalEngine.mqh`, `IndicatorManager.mqh`.*

| ID | Task | Params | Preset variant | Status |
|----|------|--------|----------------|--------|
| **P2C-001** | D1 bias: long only if `Close[1] > D1 EMA(50)` | EMA period | `D1EMA50_PROD` | **CLOSED — REJECT** (+3.87, PF 1.15, n=81) |
| **P2C-002** | H4 structure: bullish/bearish swing sequence on H4 | pivot bars=3 | `H4Swing3_PROD` | **CLOSED — REJECT** (+8.35, PF 1.30, n=95) |
| **P2C-003** | M15 ADX filter: only trade if `ADX(14) < InpAdxMax` (range regime) | 20, 25, 30 | `ADX20/25/30_PROD` | **CLOSED — no stack** (best ADX30: +15.72, PF 1.41, n=137) |
| **P2C-004** | ATR expansion: block if `ATR / ATR(50) > InpAtrExpMax` | 1.5 | `AtrExp15_PROD` | **CLOSED — MARGINAL** (+16.94, PF 1.33, n=179) |
| **P2C-005** | Spread vs range: block if `spread > pct × range_width` | 20% | `SpreadRange20_PROD` | **CLOSED — STACK_CANDIDATE** (+18.54, PF 1.34, n=184) |
| **P2C-006** | Volume spike cap: block if vol > `InpVolMaxMult × MA` | 3.0 | `VolCap3x_PROD` | **CLOSED — REJECT** (+16.78, PF 1.31, n=184) |
| **P2C-007** | VWAP distance: `\|close-vwap\| <= InpMaxVwapDistAtr × ATR` | 1.0 ATR | `VwapDist1_PROD` | **CLOSED — REJECT** (+2.14, PF 1.12, n=59) |

**P2C sweep CLOSED (7/7):** **1 STACK_CANDIDATE → promoted PROD v2.**

| Filter | Trades | Net | PF | DD % | Verdict |
|--------|--------|-----|-----|------|---------|
| PROD v1 ref | 186 | +17.75 | 1.32 | 3.24 | superseded |
| D1 EMA50 | 81 | +3.87 | 1.15 | 2.82 | **REJECT** |
| H4 swing3 | 95 | +8.35 | 1.30 | 2.86 | **REJECT** |
| ADX20 / 25 / 30 | 61 / 107 / 137 | +0.07 / +11.12 / +15.72 | 1.00 / 1.37 / 1.41 | — | REJECT / MARGINAL ×2 |
| AtrExp1.5 | 179 | +16.94 | 1.33 | 3.52 | **MARGINAL** |
| **Spread20%** | **184** | **+18.54** | **1.34** | **3.24** | **→ PROD v2** ✓ |
| VolCap3x | 184 | +16.78 | 1.31 | 3.25 | **REJECT** |
| VwapDist1 | 59 | +2.14 | 1.12 | 2.63 | **REJECT** |

**P2C lesson:** MTF/ADX/VWAP gates over-filter. **Spread-vs-range** is surgical (−2 trades, +4% net). Full journal: `Diagnostics/P2C-test-journal.csv`.

---

### Phase 2D — Failure containment (circuit breakers)

*Hooks: `CircuitBreakers.mqh` → `RiskEngine::CanTrade()` · EA v1.09*

| ID | Task | Params | Preset | Status |
|----|------|--------|--------|--------|
| **P2D-001** | Daily loss: halt entries if day equity loss ≥ `InpDailyLossPct%` | 5% | `DailyLoss5_PROD_v2` | **CLOSED — NO-OP** (5% never hit) |
| **P2D-002** | Consecutive loss pause: N losses → pause M min | 3 / 120 | `LossPause3_PROD_v2` | **CLOSED — NO-OP** (pause &lt; session gap) |
| **P2D-003** | Max 1 trade per session | — | (built-in) | **VERIFIED** — n=184 unchanged |
| **P2D-004** | Equity trail: halt if equity drops ≥ `InpEqTrailPct%` from day peak | 5% | `EqTrail5_PROD_v2` | **CLOSED — NO-OP** (DD 3.24% &lt; 5%) |

**P2D sweep:** All breakers **NO-OP** at 5%/3-loss/5% trail on PROD v2 harness — thresholds above realized daily variance. **Keep PROD v2 with P2D off.** Code stays for live/larger size. Journal: `Diagnostics/P2D-test-journal.csv`.

---

## Phase map (historical vs active)

Phases **0–2D** are **closed** — do not re-run unless regression testing. New work uses **Phase 4** (post-PROD refinement) then **Phase 3** (validation). Task IDs are **unique**; Phase 4 does not reuse P2/P3 numbers.

| Phase | Era | Reference preset | Status |
|-------|-----|------------------|--------|
| **0** | Baseline lock | `BASELINE_P1` | ✅ Closed |
| **2A–2D** | Stack build | incremental → PROD | ✅ Closed |
| **4A–4C** | Post-PROD headroom | `ORBVWAP_PROD_EURUSD-M1` | **4A/4B closed** · **4C active** |
| **3** | OOS / forward / multi-symbol | final PROD | After 4 or on demand |

---

### Phase 4A — Exit payoff refinement *(CLOSED — no stack)*

*Goal: raise payoff ratio without repeating P2-003 full-TP extension failures. Reference: **`ORBVWAP_PROD_EURUSD-M1`** (+PF 1.34, n=184). Hooks: `ExecutionEngine.mqh` partial close + optional runner management.*

**Sweep result (4/4):** No variant passed **payoff + DD** gates. Best PF = **P4A-003** (1.38, MARGINAL). **Keep PROD** — partial defaults off (`InpPartialClosePct=0`).

**Not the same as P2-003:** full TP mult sweep **REJECTED**; Phase 4A tests **partial bank + runner**, preserving core SL/time-stop stack.

| ID | Task | Params | Preset variant | Notes |
|----|------|--------|----------------|-------|
| **P4A-001** | Partial close **50%** at 1× range width; runner TP **1.5×** | pct=50, runner=1.5× | `Partial50_Run15x_PROD` | **CLOSED — REJECT** (PF 1.34 tie; payoff 0.75 vs 1.12; DD 6.06%; n=274) |
| **P4A-002** | Partial close **70%** at 1×; runner TP **1.5×** | pct=70 | `Partial70_Run15x_PROD` | **CLOSED — REJECT** (PF 1.34 tie; payoff 0.74; same n/WR as P4A-001) |
| **P4A-003** | Partial **50%** at 1×; runner **trail** by `InpTrailAtr × ATR` (no fixed runner TP) | trail 0.5, 1.0 ATR | `Partial50_TrailAtr05_PROD` | **CLOSED — MARGINAL** (PF 1.38 ↑; payoff 0.62; DD 6.06%) |
| **P4A-004** | Partial **50%** at 1×; runner obeys existing **120 min** time stop only | pct=50 | `Partial50_TimeStop120_PROD` | **CLOSED — REJECT** (PF 1.19; payoff 0.88; DD 7.05%) |

**Gate vs PROD:** Beat on **PF** or **payoff ratio** (avg win / |avg loss|) without DD &gt; +30% relative or trades &lt; ~150. Journal: `Diagnostics/P4A-test-journal.csv`.

**P4A-001 (2026-06-11):** PF **1.34** tie · WR **64.2%** · payoff **0.75** (↓ vs 1.12) · DD **6.06%** · n=**274** · 458 deals. **REJECT** — partial banks winners; runner full SL inflates avg loss.

**P4A-002 (2026-06-11):** PF **1.34** tie · WR **64.2%** · payoff **0.74** · DD **21.24%** (0.10 lot). **REJECT** — same profile as P4A-001.

**P4A-003 (2026-06-11):** PF **1.38** (↑ vs 1.34) · WR **69.0%** · payoff **0.62** · DD **6.06%** · n=**274** · 458 deals. **MARGINAL** — best P4A PF; fails payoff + DD gates; do not stack.

**P4A-004 (2026-06-11):** PF **1.19** · WR **57.7%** · payoff **0.88** · DD **7.05%** · n=**274** · 458 deals · avg hold **~73 min**. **REJECT** — worst P4A PF; runner drifts to time stop without TP/trail.

**Phase 4A verdict:** **CLOSED — no stack.** Partial + runner cannot beat PROD payoff geometry on opposite-boundary SL.

---

### Phase 4B — Session micro-filters *(secondary)*

*Goal: trim noisy sub-windows on **PROD stack** without re-opening closed P2B tasks. Distinct from P2B-004/005 (already on PROD).*

| ID | Task | Params | Preset variant | Notes |
|----|------|--------|----------------|-------|
| **P4B-001** | NY: block entries before **13:30 GMT** (skip first 30 min of NY session) | NY min minute=30 | `NYstart1330_PROD` | **PROMOTED → PROD v3** (PF 1.40; payoff 1.20; DD 2.51%; n=172) |
| **P4B-002** | London: block entries before **09:00 GMT** (post-open only) | delay=120 min | `LDNstart0900_PROD` | **CLOSED — REJECT** (PF 1.50; n=129; net ↓ vs v3) |
| **P4B-003** | Breakout freshness (from P2B-006): break within **N** bars of range lock | N = 3, 5 | `FreshBreak5_PROD` | **CLOSED — REJECT** (n=5; PF 3.80 on tiny sample) |

**Gate vs PROD v3:** Beat on **net or PF**; trades ≥ ~150. Journal: `Diagnostics/P4B-test-journal.csv`.

**P4B-001 (2026-06-11):** PF **1.40** · WR **54.1%** · payoff **1.20** · DD **2.51%** · n=**172** · net **18.94**. **PROMOTED → PROD v3** (`InpNyEntryDelayMin=30`).

**P4B-002 (2026-06-11):** PF **1.50** · WR **54.3%** · payoff **1.28** · DD **2.67%** · n=**129** · net **17.33**. **REJECT** — PF up but n&lt;150 and net below v3.

**P4B-003 (2026-06-11):** PF **3.80** · WR **80%** · n=**5** · net **1.96** · DD **0.39%**. **REJECT** — freshness ≤5 bars collapses sample; do not test N=3.

**Phase 4B verdict:** **P4B-001 → PROD v3** · **P4B-002 REJECT** · **P4B-003 REJECT** — **Phase 4B CLOSED**.

**Do not re-test:** P2B-004 NYcut1600, P2B-005 SkipWedFri — already stacked on PROD.

---

### Phase 4C — Direction diagnostics *(analysis only, no stack)* — **CLOSED**

*Goal: explain short-heavy mix before any long-bias code. **No promotion** from this phase — output is a report.*

| ID | Task | Result | Verdict |
|----|------|--------|---------|
| **P4C-001** | Rejection journal (June 2026, 11,487 bars) | `VOL` 1.46× long · `MIN_RR` 1.62× long · `VWAP` 1.81× short · `SPREAD_RANGE` 0 | **PASS** — no >2× skew |
| **P4C-002** | PROD v3 closed trades (n=172) | Long **32%** WR 52.7% · Short **68%** WR 54.7% · PF 1.40 | **PASS** — frequency skew, not quality |
| **P4C-003** | Decision memo | `Diagnostics/P4C-003-decision-memo.md` | **NO-STACK** long-bias filters |

**Phase 4C verdict:** **CLOSED — NO-STACK.** Short-heavy mix is **structural** (more valid down-breaks). Do not add D1/long-only filters.

**Artifacts:** `P4C-001_reject-by-direction.csv` · `P4C-002-by-direction.csv` · `P4C-003-decision-memo.md`

---

### Phase 5 — AI intelligence layers *(offline CLOSED · MT5 partial)*

Full roadmap: [ailayers.md](./ailayers.md) · journal: `Diagnostics/AI-test-journal.csv` · **offline closed 2026-06-11**

| ID | Offline train | EA wired | MT5 validated | LIVE promote | Open tasks |
|----|---------------|----------|---------------|--------------|------------|
| **AI-0** | ✅ PASS | N/A | ✅ export | N/A | Re-export v2 when new data |
| **AI-1** | ✅ PASS · τ=0.30 · PF 1.49 | ✅ v1.19 | ✅ 342t PF 1.33 | ⬜ | Walk-forward 3 folds · PROD preset |
| **AI-2** | ✅ PASS · PF 1.47 | ✅ v1.20 | ⬜ | ⬜ | `AI12` shadow backtest |
| **AI-3** | ✅ PASS · skip 8% · PF 1.43 | ✅ v1.21 | ✅ 315t PF 1.53 | ⬜ | PROD preset with AI-1 |
| **AI-4** | ✅ PASS *(proxy paths)* | ✅ v1.22 | ✅ log only | ⬜ last | Real paths v2 · LIVE stall exit |

**Deploy candidate:** AI-1 + AI-3 LIVE — MT5 **n=315 · PF=1.53 · DD=5.89%** (`AI-1234-005`).

---

### Phase 3 — Optimisation & forward validation *(after Phase 4 or on demand)*

*Unchanged scope from original plan. Run **P3-004 forward demo** when you choose — deferred is OK if Phase 4A–4C are active.*

| ID | Task | When |
|----|------|------|
| **P3-001** | Genetic optimise **only** params from winning Phase 4 tasks (max 5 params) | After Phase 4 stack locked |
| **P3-002** | Walk-forward: 70% IS / 30% OOS | After Phase 4 stack locked |
| **P3-003** | Multi-symbol: EURUSD, GBPUSD, USDJPY per-symbol preset | After EURUSD validated |
| **P3-004** | Forward demo 4 weeks + journal + weekly preset snapshot | **User-triggered** — real slippage gate |
| **P3-005** | Promote to `ORBVWAP_PROD_{symbol}_vN.set` | After P3-004 pass |

**P3-004 gate:** 4 weeks · PF ≥ 1.2 · DD ≤ 2× backtest DD · no structural regressions vs PROD preset.

---

## Suggested roadmap (post-PROD)

Work **one Task ID at a time** vs **`ORBVWAP_PROD_EURUSD-M1`**. Do not mix Phase 4 with Phase 3 forward until stack is locked or you explicitly defer Phase 4.

```
1. P3-004                             Forward demo (when you trigger)
2. P3-001–003                         OOS / optimise / multi-symbol
```

**Phase 4C (completed — NO-STACK):**

```
P4C-001 PASS · P4C-002 PASS · P4C-003 NO-STACK → no long-bias code
```

**Phase 4A (completed — do not stack):**

```
P4A-001 REJECT · P4A-002 REJECT · P4A-003 MARGINAL · P4A-004 REJECT → keep PROD
```

**Historical sprint (completed — do not repeat):**

```
P0-001/002 → P2-003/005 → P2B-004/005 → P2-004 → P2C-005 → PROD v1.10
```

After each Phase 4 task: compare to **PROD reference**, not P0 baseline. **Keep only if PF or payoff improves without DD &gt; +30% relative or trades &lt; ~150.**

---

## Metrics to watch per test

| Metric | Baseline (P0-002) | PROD (v1.10) | Phase 4 target |
|--------|-------------------|--------------|----------------|
| Profit factor | 0.91 | **1.40** ✅ | ≥ 1.40 |
| Win rate | 62.5% | 54.1% | stable ±3 pts OK |
| Payoff (avg win / \|avg loss\|) | 0.54 | **1.20** ✅ | ≥ 1.20 |
| Max DD | ~50% | **2.51%** ✅ | ≤ 4% |
| Trades | 1,646 | 172 | ≥ ~150 |

---

## What NOT to do (post-PROD)

- Re-open **P2C MTF/ADX/VWAP** filters — sweep closed; SpreadRange20 only winner
- Re-test **P2-006 break-even** or **P2-001 SL midpoint** — rejected
- Extend **time stop** beyond 120 min — baseline leak returns
- Remove **SkipWedFri** or **NYcut1600** — proven stack layers
- Optimise 15 inputs at once (P3-001) before Phase 4 isolated tasks complete
- Add long-bias code before **P4C** diagnostics justify it

---

## Summary

| Layer | Status | Next action |
|-------|--------|-------------|
| Execution engine | ✅ Complete | Maintain |
| Exit / time / R:R | ✅ PROD stack | **Phase 4A closed** — partial off |
| Session filters | ✅ **PROD v3** | NY delay 30 min on stack |
| Regime filters (P2C) | ✅ CLOSED | SpreadRange20 on PROD |
| Circuit breakers (P2D) | ✅ CLOSED (NO-OP) | Off; revisit at live scale |
| Direction analysis | ✅ **Phase 4C** NO-STACK | No long-bias filters |
| AI layers | **AI-0/1/2/3/4 PASS** (offline) | MT5 `AI1234` shadow → LIVE |
| Forward validation | Deferred | **Phase 3** P3-004 when ready |
| Testing discipline | — | One Task ID → one preset → one journal row |

**PROD v3** (PF 1.40, n=172, DD 2.51%). Phase 4A partial sweep closed with no stack; **P4B-001** is the post-PROD winner.

---

## Post-PROD headroom (constraints)

The system is **near geometric limit** for opposite-boundary SL + MinRR 0.9 + 1× TP:

- Realised entry R:R ~**0.7–0.9 : 1** · PF **1.34** at **54% WR** is consistent with that geometry
- **P2C proved** additional entry gates cut edge; only SpreadRange20 stacked
- **P2D proved** breakers inert at test thresholds (1 trade/session/day cadence)

**Highest leverage (revised):** Phase **4C** (direction diagnostics) · **Phase 3** forward demo. Phase **4A closed** (no stack) · **4B-001 on PROD v3**.

**Frozen on PROD v3:** Time stop 120 · SkipWedFri · NYcut1600 · **NYdelay30** · MinRR 0.9 · SpreadRange20 · BE off · partial off · MTF off.