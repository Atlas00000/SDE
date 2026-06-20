# ORBVWAP — System Profile

**Instrument:** EURUSD · **Timeframe:** M1 · **EA version:** 1.17  
**Production preset:** `ORBVWAP_PROD_EURUSD-M1.set` (alias: `_v3.set`)  
**Validation:** P0–P4C in-sample sweeps on locked harness · **Forward test:** deferred (P3-004)  
**Last updated:** 2026-06-11

> **Doc ownership:** This file owns **PROD v3 edge and baseline metrics**. AI wiring / INF gates → [System Design.md](./System%20Design.md). AI models → [aidesign.md](./aidesign.md).

Reference: [Edge Discovery.md](./Edge%20Discovery.md) · [Phase0-Harness.md](./Phase0-Harness.md) · [P4C-003 decision memo](./Diagnostics/P4C-003-decision-memo.md)

> **How to read this document:** Metrics are **ratio- and behaviour-focused** (PF, WR, DD%, payoff, correlations, hold times). Dollar balance and deposit are **ignored** — they scale with lot size and are not comparable across accounts.

---

## Executive summary

ORBVWAP is a **low-frequency, session-scoped Opening Range Breakout (ORB)** system on EURUSD M1. Each London or NY session produces at most **one** trade: a volume-confirmed breakout of a 5-minute opening range, aligned with session VWAP, with exits defined by range geometry and a hard **120-minute** time stop.

After structured refinement (P0–P4C), the system moved from **negative expectancy** (PF 0.91, ~50% equity DD, 1,646 trades) to a **stable profitable profile** (PF **1.40**, equity DD **2.51%**, **172** trades) on the locked P0-002 test window — trading **~10% of baseline frequency** with **controlled tail risk**.

The edge is **not** raw win rate. It is **filtered directional accuracy** on session opens, combined with **failure containment** (time stop, session/day cuts, min R:R gate, spread filter, NY open delay). Phase **4C** confirmed the short-heavy trade mix is **structural frequency**, not filter bias — **no long-bias code** warranted.

**Characterisation:** Quality over quantity · one opportunity per active session day · positively skewed payoff at ~54% WR.

---

## 1. System profile

### 1.1 What the system is

| Attribute | Definition |
|-----------|------------|
| **Style** | Intraday ORB scalp / day trade |
| **Symbol** | EURUSD (single-symbol production) |
| **Bar type** | M1 — signal on closed bar `[1]` |
| **Sessions** | London 07:00–12:00 GMT + NY 13:00–17:00 GMT (both active) |
| **Frequency** | ≤ 1 trade per session · ≤ 1 open position |
| **Magic** | 20260611 |

### 1.2 Architecture

| Layer | Module | Role |
|-------|--------|------|
| Orchestrator | `ORBVWAP.mq5` | New-bar pipeline, tick management |
| Session | `SessionUtils.mqh` | GMT sessions, weekday skip, entry cutoff, NY/London entry delay |
| Range | `OpeningRange.mqh` | 5-min ORB lock, ATR width gate, optional freshness filter (off) |
| VWAP | `SessionVwap.mqh` | Session-anchored cumulative VWAP |
| Signal | `SignalEngine.mqh` | Breakout + VWAP + volume logic |
| Filters | `EntryFilters.mqh` | P2C regime gates (**SpreadRange20** active on PROD) |
| Risk | `RiskEngine.mqh` | Sizing, min R:R, spread points, `CanTrade()` |
| Breakers | `CircuitBreakers.mqh` | P2D daily loss / consec pause / equity trail (**off** on PROD) |
| Execution | `ExecutionEngine.mqh` | Market entry, time stop; partial/trail code present but **off** |
| State | `StateTracker.mqh` | One trade per session, open count |
| Logging | `Logger.mqh` | Tagged reject codes; optional direction journal (P4C) |

### 1.3 Production stack (v3)

| Parameter | Value | Phase | Purpose |
|-----------|-------|-------|---------|
| Opening range | 5 min | P1 | ORB window |
| Min range width | ≥ 0.8 × ATR(14) | P1 | Skip compressed ranges |
| SL mode | Opposite boundary | P1 | Native ORB invalidation |
| TP | 1.0 × range width | P2-003 | Measured move (1× — extensions rejected) |
| Time stop | **120 min** | P2-005 | Cap loser duration (baseline max hold 91h+) |
| Min R:R | **0.9** | P2-004 | Reject worst geometric setups |
| NY entry cutoff | **16:00 GMT** | P2B-004 | Block late-session entries |
| Weekday skip | **Wed + Fri** (mask 40) | P2B-005 | Remove weak weekdays |
| Spread filter | ≤ **20%** of range width | P2C-005 | Drop wide-spread entries |
| NY entry delay | **30 min** (entries from 13:30 GMT) | P4B-001 | Skip first 30 min of NY session |
| London entry delay | 0 | — | P4B-002 rejected |
| Breakout freshness | 0 (off) | P4B-003 | Rejected — collapsed sample |
| Partial TP / trail | 0 (off) | P4A | All variants rejected |
| P2D breakers | All off | P2D | NO-OP at harness thresholds |
| Fixed lot | 0.01 | P1 | Sizing mode: fixed (not % risk on PROD) |

**Defaults in code:** `Inputs.mqh` matches this stack — attaching the EA without a preset loads PROD v3.

### 1.4 Entry pipeline (all must pass)

1. Active London or NY session (signal bar in GMT)
2. Weekday allowed — **Mon, Tue, Thu** only on PROD
3. Entry before **16:00 GMT**
4. NY session: at least **30 min** after NY open (13:30+ GMT)
5. Opening range **locked**; width ≥ 0.8 × ATR(14)
6. **Breakout:** `Close[1]` beyond range high (long) or low (short)
7. **VWAP side:** long above / short below session VWAP
8. **Volume:** tick vol ≥ 1.5 × 20-bar tick-volume MA
9. **Spread:** spread ≤ 20% × range width (P2C)
10. **Min R:R** ≥ 0.9 at computed entry / SL / TP
11. Risk gates: max spread points, equity floor, cooldown, max open trades
12. **Not already traded** this session (`ALREADY_TRADED`)

### 1.5 Exit pipeline

| Exit type | Trigger | Status |
|-----------|---------|--------|
| Take profit | Entry ± 1× range width | Active |
| Stop loss | Opposite range boundary | Active |
| Time stop | 120 minutes in trade → market close | Active |
| Break-even | — | Off (P2-006 rejected) |
| Partial TP / runner trail | — | Off (P4A rejected) |
| Trailing stop | — | Not on PROD |

### 1.6 Intentionally excluded (tested & closed)

| Feature | Sweep result |
|---------|--------------|
| SL at range midpoint | P2-001 **REJECT** |
| Break-even move | P2-006 **REJECT** |
| TP > 1× range | P2-003 **REJECT** |
| D1 EMA / H4 swing / ADX / vol cap / VWAP distance | P2C **REJECT** or marginal |
| P2D circuit breakers on PROD cadence | **NO-OP** |
| Partial TP + runner (4 variants) | P4A **REJECT** / marginal |
| London 120 min delay | P4B-002 **REJECT** |
| Breakout freshness ≤ 5 bars | P4B-003 **REJECT** (n=5) |
| Long-bias / direction filters | P4C **NO-STACK** |

### 1.7 Operational reference

| Item | Location |
|------|----------|
| Production preset | `Presets/ORBVWAP_PROD_EURUSD-M1.set` |
| Tester presets | `MQL5/Profiles/Tester/` |
| Diagnostic journals | `Diagnostics/*.csv` |
| Compile | MetaEditor · `ORBVWAP.mq5` v1.17 |

---

## 2. Edge profile

### 2.1 Core hypothesis

**Validated (in-sample):** Short-horizon directional breakouts from a session opening range, confirmed by **session VWAP** and **volume expansion**, carry **positive directional bias** on EURUSD during London and NY — *when* failures are time-boxed and low-quality regimes (days, hours, geometry, spread) are removed.

**What was wrong at baseline (P0):** ~63% win rate but **payoff inverted** — average loss magnitude ~**1.85×** average win. Full-boundary stop, uncapped hold (91h+), no min R:R, no session/day filters, no spread gate. High WR masked negative expectancy.

**What PROD v3 fixes:** Trade **fewer, better** setups (~54% WR) with **payoff ~1.20:1** (avg win / |avg loss|) → PF **1.40**.

### 2.2 Structural R:R geometry (inherent ORB constraint)

Entry fires **after** the breakout close; stop sits at the **opposite** range edge. Risk distance typically **exceeds** reward (1× range width):

```
Long example:
  range_low  = 1.0990    range_high = 1.1000  → width = 10 pips
  entry      = 1.1002    (post-breakout)
  SL         = 1.0990    → risk   ≈ 12 pips
  TP         = 1.1012    → reward = 10 pips
  Structural R:R ≈ 0.83 : 1
```

At structural R:R ~0.83, breakeven WR ≈ **55%**. PROD v3 WR **54.07%** sits near geometric breakeven — **PF > 1** comes from filtering worst setups, time-stop tail truncation, and session selection — not from expanding TP or moving SL.

**MinRR 0.9** removes the bottom of the geometry distribution. **SpreadRange20** removes marginal wide-spread entries. Neither fixes geometry; they **curate** which breakouts are worth taking.

### 2.3 Refinement map (what moved the needle)

| Change | Primary effect | Phase |
|--------|----------------|-------|
| **Time stop 120 min** | Max hold 91h → 2h; stops cross-session bleed | P2-005 |
| **NY cut 16:00** | Removes late/chop entries | P2B-004 |
| **Skip Wed + Fri** | Removes two weak weekdays | P2B-005 |
| **MinRR 0.9** | ~80% trade reduction; quality knee | P2-004 |
| **SpreadRange 20%** | Surgical −2 trades; PF tick up | P2C-005 |
| **NY delay 30 min** | PF 1.34 → 1.40; DD 3.24% → 2.51% | P4B-001 |
| SL midpoint, BE, TP extend, MTF, partial TP | No durable improvement | P2/P4A |

### 2.4 Temporal edge

| Window (GMT) | Role on PROD v3 |
|--------------|-----------------|
| **09:00–11:00** | Core — London post-range breakouts |
| **10:00** | Peak entry hour (report charts) |
| **13:30–16:00** | NY window (30 min delay + 16:00 cutoff) |
| **Mon, Tue, Thu** | Only active weekdays |
| **Wed, Fri** | Zero entries (skip mask) |
| **17:00+** | Gated out (session end + cutoff) |
| Asian / late US | Outside session — no edge harvested |

Seasonal month patterns from baseline (Mar, Jul, Sep weaker) remain **hypothesis** until OOS validation (P3).

### 2.5 Directional structure (P4C closed)

| Side | Share | Win rate | Interpretation |
|------|-------|----------|----------------|
| Short | **68.0%** (117/172) | 54.70% | More valid down-break setups |
| Long | **32.0%** (55/172) | 52.73% | Healthy quality; lower frequency |

**P4C-001 rejection skew** (June journal, 11,487 bars): no focus code exceeds **2×** directional bias (`VOL` 1.46× long, `MIN_RR` 1.62× long, `VWAP` 1.81× short). **Verdict: NO-STACK** long-bias filters.

Short-heavy mix is **structural** (EURUSD session flow, VWAP-aligned down-breaks more frequent) — not evidence that longs are systematically filtered out or under-performing.

### 2.6 Filter sensitivity summary

| Filter class | On PROD stack |
|--------------|---------------|
| **Spread vs range (20%)** | **STACK** — only P2C winner |
| **Min R:R (0.9)** | **STACK** — primary frequency reducer |
| **Time stop (120)** | **STACK** — tail containment |
| **Session / day / NY delay** | **STACK** — regime selection |
| MTF (D1, H4), ADX, ATR expansion, vol cap, VWAP dist | **REJECT** or marginal |
| P2D breakers | **NO-OP** at test thresholds |
| Partial TP (4 variants) | **REJECT** / marginal |

### 2.7 Excursion behaviour (edge quality signal)

| Correlation | P0 baseline | PROD v3 | Meaning |
|-------------|-------------|---------|---------|
| Profit ↔ **MFE** | 0.42 | **0.80** | Winners track favourable excursion — exits align with move |
| Profit ↔ **MAE** | 0.68 | **0.57** | Losers still go adverse, but less catastrophically |
| MFE ↔ MAE | — | 0.12 | Low — winners and losers are distinguishable early |

Rising MFE correlation is a strong sign the **exit stack captures edge** that baseline left on the table.

---

## 3. Trade profile — winners vs losers

*Per-trade magnitude units below are at 0.01 lot — use **ratios and percentages**, not dollar scaling.*

### 3.1 Aggregate split (PROD v3)

| Cohort | Count | Share | Win rate |
|--------|-------|-------|----------|
| **Winners** | 93 | 54.07% | — |
| **Losers** | 79 | 45.93% | — |
| **Long** | 55 | 32.0% | 52.73% |
| **Short** | 117 | 68.0% | 54.70% |

| Metric | Winners | Losers | Ratio |
|--------|---------|--------|-------|
| Avg magnitude | 0.71 | 0.59 | **Payoff 1.20 : 1** |
| Largest magnitude | 2.35 | 1.89 | Tail loss / tail win ≈ **0.80 : 1** (improved vs baseline ~1.9 : 1) |
| Max consecutive | 7 wins | 5 losses | Moderate streaks |
| Avg consecutive | ~2 | ~2 | No runaway clustering |

### 3.2 Winner archetype

| Dimension | Typical behaviour |
|-----------|-------------------|
| **Setup** | Clean breakout beyond 5-min range with VWAP alignment |
| **Volume** | Expansion bar (≥ 1.5× vol MA) on signal candle |
| **MFE** | Strong profit–MFE correlation (**r ≈ 0.80**) — price moves favourably early |
| **Hold time** | Often **< 120 min**; many hit TP or close green before time stop |
| **Session** | London morning (~10 GMT) and NY 13:30–16:00 |
| **Exit path** | TP at 1× range width, or time stop with small gain |
| **Geometry** | Passed MinRR 0.9 — not the worst R:R bucket |

**Summary:** Impulsive range break with institutional-flow confirmation (VWAP + volume). Follow-through sufficient to reach measured-move target or retain edge before time cap.

### 3.3 Loser archetype

| Dimension | Typical behaviour |
|-----------|-------------------|
| **Setup** | False breakout — price reverses through range |
| **Failure mode** | Full SL at opposite boundary (widest structural risk) |
| **MAE** | Moderate profit–MAE correlation (**r ≈ 0.57**, down from 0.68 baseline) |
| **Hold time** | Cluster at **120 min** time stop — hard cap prevents multi-hour bleed |
| **Historical weak zones** | NY open chop, Wed/Fri, late session — **now filtered on PROD** |
| **Tail** | Largest loss magnitude ~**0.80×** largest win (vs ~1.9× at baseline) |

**Summary:** Breakout lacks follow-through; price mean-reverts to opposite range edge. Time stop converts what were **slow bleeds** (91h+ holds) into **bounded, timed failures**.

### 3.4 Hold-time morphology

| Stat | P0 baseline | PROD v3 |
|------|-------------|---------|
| Min hold | ~5 sec | ~4 sec |
| Avg hold | ~1h 57m | **~38 min** |
| Max hold | **91h+** | **2h 00m** (hard cap) |

PROD v3 trades behave like **ORB scalps** again — not overnight drift positions.

### 3.5 Baseline → PROD v3 morphology shift

| Dimension | P0 baseline | PROD v3 | Shift |
|-----------|-------------|---------|-------|
| Win rate | 62.5% | 54.1% | ↓ quality over quantity |
| Payoff (avg win / \|avg loss\|) | **0.54 : 1** | **1.20 : 1** | **Primary fix** |
| Profit factor | 0.91 | **1.40** | Positive expectancy |
| Max equity DD | ~50% | **2.51%** | Risk profile transformed |
| Trade count | 1,646 | **172** | ~10% of baseline frequency |
| MFE correlation | 0.42 | **0.80** | Winners more linear |
| MAE correlation | 0.68 | **0.57** | Losers less catastrophic |
| Max hold | 91h+ | **2h** | Time containment |

---

## 4. Current performance (PROD v3)

**Test harness:** P0-002 window · EURUSD M1 · every tick · history quality **100%**  
**Sample:** 172 trades (344 deals) · validation in-sample · forward test not yet run

### 4.1 Key metrics (ratio-focused)

| Metric | PROD v3 | PROD v2 | P0 baseline |
|--------|---------|---------|-------------|
| **Profit factor** | **1.40** | 1.34 | 0.91 |
| **Win rate** | **54.07%** | 54.35% | 62.52% |
| **Payoff ratio** | **1.20** | 1.12 | 0.54 |
| **Gross profit / \|gross loss\|** | 1.40 : 1 | ~1.34 : 1 | < 1 : 1 |
| **Max equity DD** | **2.51%** | 3.24% | ~50% |
| **Max balance DD** | 2.05% | — | ~50% |
| **Trade count** | **172** | 184 | 1,646 |
| **Sharpe ratio** | **14.61** | 11.97 | negative |
| **Recovery factor** | **3.52** | 2.72 | — |
| **Expected payoff / trade** | +0.11 | +0.10 | negative |
| **Z-score** | 0.78 (56.5%) | — | — |

### 4.2 Risk & consistency

| Metric | Value |
|--------|-------|
| Max consecutive losses | **5** |
| Max consecutive wins | **7** |
| Avg hold | **37 min 41 sec** |
| Max hold | **120 min** (time stop) |
| LR correlation (equity curve) | **0.91** |
| Active weekdays | Mon, Tue, Thu |
| Peak entry hours (GMT) | 10, 12–16 |
| Trades per active day | ~0.7 (≤ 1 session slot) |

### 4.3 Direction & activity (from tester report)

| Metric | Value |
|--------|-------|
| Short / long split | **68% / 32%** |
| Short win rate | 54.70% |
| Long win rate | 52.73% |
| Wed / Fri entries | **0** (skip confirmed) |
| Entry window (GMT) | ~10:00–17:00 (session + filters) |

### 4.4 Promotion path (evolution)

| Stage | PF | Max DD | Trades | Notes |
|-------|-----|--------|--------|-------|
| P0 baseline | 0.91 | ~50% | 1,646 | Raw ORB |
| + TimeStop + NYcut + SkipWedFri | 0.97 | 15.6% | 967 | Still sub-1 PF |
| + MinRR 0.9 (PROD v1) | 1.32 | 3.24% | 186 | First profitable |
| + SpreadRange20 (PROD v2) | 1.34 | 3.24% | 184 | Spread gate |
| + NYdelay30 (PROD v3) | **1.40** | **2.51%** | **172** | **Current production** |

### 4.5 Validation status (phase gate summary)

| Phase | Outcome |
|-------|---------|
| P0 harness | Baseline locked · reproducible |
| P2 exits / R:R / time | TimeStop120 + MinRR 0.9 — stable |
| P2B session | NYcut1600 + SkipWedFri — stable |
| P2C filters (7) | Only SpreadRange20 stacked |
| P2D breakers (3) | NO-OP — no regression |
| P4A partial TP (4) | All REJECT — partial off |
| P4B session micro (3) | Only NYdelay30 → v3 |
| **P4C direction (3)** | **NO-STACK** — closed |
| **P3 forward / OOS** | **Not yet run** |

---

## 5. Key metrics dashboard

```
┌──────────────────────────────────────────────────────────┐
│  ORBVWAP PROD v3 — KEY METRICS (ratio-focused)           │
├──────────────────────────────────────────────────────────┤
│  Profit factor      1.40          Win rate      54.1%    │
│  Payoff ratio       1.20          Max equity DD 2.51%    │
│  Sharpe             14.61         Recovery      3.52     │
│  Trades             172           Avg hold      ~38m      │
│  Time stop cap      120m          Max hold      2h        │
│  Short / long       68% / 32%    Sessions/day  ≤1       │
│  NY entry delay     30m (13:30+)  Partial TP    off      │
│  MFE correlation    0.80          MAE corr      0.57     │
│  Max consec L       5             Max consec W  7         │
└──────────────────────────────────────────────────────────┘
```

---

## 6. Stability assessment

### 6.1 What looks stable

- **PF 1.40** and **DD 2.51%** held across PROD v2 → v3 promotion (P4B-001)
- **Payoff ~1.20** consistent — not dependent on a handful of outlier wins
- **Direction mix** stable v2 → v3 (68% short)
- **Filter stack** individually tested; no rejected variant re-stacked
- **User re-runs** on full harness reproduce headline metrics
- **P4C** confirms no hidden directional filter bias

### 6.2 Known limitations

1. **Sample size:** 172 trades over full test window — adequate for ratio stability; thin for rare tails.
2. **Single symbol / in-sample:** EURUSD M1 only; no walk-forward or OOS split (P3-002 pending).
3. **Geometry ceiling:** Opposite-boundary SL + 1× TP caps WR expansion; TP/SL alternatives failed sweeps.
4. **P2D breakers:** Untested at live scale; may matter with larger size or faster cadence.
5. **Forward demo:** Not run — real slippage, spread spikes, and news gaps unverified (P3-004).
6. **Optimisation:** No genetic or multi-symbol validation yet (P3-001, P3-003).

### 6.3 What would invalidate the profile

- Forward PF **< 1.2** over 4 weeks with structural regressions (P3-004 gate)
- Walk-forward OOS PF collapse vs in-sample (P3-002)
- Material change in broker spread / session times without preset retest

---

## 7. Next steps

| Priority | Task | Trigger |
|----------|------|---------|
| 1 | **P3-004** forward demo (4 weeks) | User-initiated |
| 2 | **P3-002** walk-forward 70/30 OOS | After forward pass or on demand |
| 3 | **P3-001** genetic optimise (≤ 5 params) | After stack locked |
| 4 | **P3-003** multi-symbol presets | After EURUSD validated |

**Do not:** Re-open P4A partial TP, P4B-002/003, P2C MTF filters, or long-bias code (P4C NO-STACK).

---

## 8. One-line characterisation

**ORBVWAP PROD v3** is a **low-frequency, session-scoped EURUSD ORB system** that converts a high win-rate but negatively skewed baseline into a **positively skewed, low-drawdown profile** through **time containment, session/day selection, NY open delay, minimum R:R filtering, and spread-quality gating** — harvesting **~one quality breakout per active session day** at PF **1.40** and **2.5%** max equity drawdown.
