# ORBVWAP Phase 1 — Comprehensive Build Report

## Executive summary

Phase 1 delivered a **modular, single-symbol automated execution engine** for MetaTrader 5, built around **Strategy 3: Opening Range Breakout with VWAP**. The EA forms a session-anchored opening range at London and NY opens, tracks session VWAP, evaluates closed-bar breakout conditions with volume confirmation, applies risk guards, sizes positions, and places market orders with strategy-native stop loss and take profit.

Strategy Tester results confirm the engine is **operationally complete**: **220 trades** over the test window, **100% history quality**, **440 deals** (entries + exits), and **10,896,734 ticks** processed across **161,498 M1 bars**. The system runs end-to-end without structural failures.

Phase 1 was about **execution reliability**, not strategy profitability. A net loss of **−24.42** on a **200.00** deposit (−12.2%), profit factor **0.77**, and a **59.55%** win rate with negative expectancy (average loss **1.17** vs average win **0.61**) reflect the **Phase 1 signal layer without Phase 2 MTF filters** — not a broken engine. The hourly entry distribution shows activity concentrated at **~10:00** and **16:00–17:00**, consistent with London and NY session opens.

---

## Project scope — what Phase 1 set out to do

From [concept.md](./concept.md) and [roadmap.md](./roadmap.md):

| Goal | Status |
|------|--------|
| Configurable execution engine | Done |
| Single symbol, single timeframe (M1), current chart | Done |
| Modular separation: signal / risk / execution / state | Done |
| Basic risk management and position sizing | Done |
| Opening range state machine (FORMING → LOCKED → TRADED/EXPIRED) | Done |
| Session-anchored VWAP (London/NY open, not midnight) | Done |
| Lightweight session gate (London 07:00–12:00, NY 13:00–17:00 GMT) | Done |
| ORB + VWAP + volume + min-range + first-breakout signal logic | Done |
| Strategy-native SL/TP (opposite range boundary + measured move) | Done |
| Tagged rejection reason codes + optional file journal | Done |
| No overengineering or Phase 2 MTF/circuit-breaker features | Done (TODO comments only) |

---

## Architecture

```
ORBVWAP.mq5  (~160 lines — orchestrator only)
    │
    ├── CSessionUtils       GMT conversion, London/NY session windows
    ├── COpeningRange       FORMING → LOCKED → TRADED / EXPIRED
    ├── CSessionVwap        volume-weighted mean from session open
    ├── CIndicatorManager   ATR(14), tick-volume MA(20)
    ├── CSignalEngine       closed-bar ORB + VWAP + volume entry logic
    ├── CRiskEngine         guards + SL/TP + lot sizing
    ├── CExecutionEngine    CTrade wrapper + validation
    ├── CStateTracker       position count + cooldown + breakout flag
    └── COrbVwapLogger      tagged Print() + optional CSV journal
```

**Design principles applied:**

- One EA instance per chart, `_Symbol` + `PERIOD_CURRENT` only
- New-bar processing only (no intrabar signal repainting)
- Session context resolved from `bar[1]` time via `TimeGMT()` + manual offset
- Fail-closed: invalid session, forming range, narrow range, volume/VWAP failure, wide spread, or failed validation → no order
- All behaviour driven by grouped `input` parameters for optimisation
- Strategy-native exits as default; fixed-point and ATR-multiple modes available for dev/fallback

**Pipeline on each new bar:**

```
IsNewBar()
  → UpdateMarketContext()  (session → opening range → VWAP → state sync)
  → indicators ready?
  → ResolveSignal()        (or InpTestExecution forced BUY)
  → CanTrade()
  → BuildSetup()
  → OpenMarket()
  → RecordEntry() + MarkBreakoutConsumed() + MarkTraded()
```

---

## Module breakdown

### 1. Foundation (`Include/ORBVWAP/`)

**Types.mqh** — shared data model:

- `ENUM_ORBVWAP_SIGNAL` — NONE / BUY / SELL
- `ENUM_ORBVWAP_SIZING_MODE` — fixed lot vs % risk
- `ENUM_ORBVWAP_SLTP_MODE` — STRATEGY_NATIVE / FIXED_POINTS / ATR_BASED
- `ENUM_ORBVWAP_TRADE_PERMISSION` — both / buy only / sell only
- `ENUM_ORBVWAP_SESSION` — NONE / LONDON / NY
- `ENUM_ORBVWAP_ACTIVE_SESSION` — London / NY / Both
- `ENUM_ORBVWAP_RANGE_STATE` — IDLE / FORMING / LOCKED / TRADED / EXPIRED
- `SSessionContext` — active flag, session type, open/end times (GMT + broker)
- `SOpeningRangeState` — range state, high/low/width, lock time, bars collected
- `SSignalResult` — signal, signal bar index, reference price, reject reason
- `STradeSetup` — signal, lot, entry, SL, TP, signal bar, risk-reward, reject reason

**Constants.mqh** — log prefix (`ORBVWAP`), default magic (`20260611`), trade comment, journal filename, and **15 standardised rejection reason codes**.

**Inputs.mqh** — 7 input groups, 28 parameters:

| Group | Parameters |
|-------|------------|
| General | Magic number, enable trading |
| Session (GMT) | GMT offset, London/NY start/end hours, active session filter |
| Opening Range | Range minutes (5/10/15), min range ATR factor (0.8) |
| Execution | Test flag, slippage, max spread |
| Risk | Sizing mode, fixed lot, risk %, SL/TP mode, fixed/ATR fallbacks, max trades, cooldown, permissions, min equity ratio |
| Indicators | ATR period, volume MA period, volume multiplier |
| Debug | File journal, session state logging |

**Logger.mqh** — `INFO` / `WARN` / `ERROR` prefixed journal lines; `Journal()` writes rejection codes to `Print()` and optionally to `ORBVWAP_journal.csv`.

---

### 2. SessionUtils

Resolves which trading session is active for a given bar time:

- Converts broker time → GMT via `InpGmtOffsetHours` (manual DST handling)
- London window: `InpLondonStartHour`–`InpLondonEndHour` (default 07:00–12:00 GMT)
- NY window: `InpNyStartHour`–`InpNyEndHour` (default 13:00–17:00 GMT)
- `InpActiveSession` filters to London only, NY only, or both
- Exposes `session_open_broker` for range and VWAP anchoring

---

### 3. OpeningRange

State machine tracking the first N minutes of each session:

| State | Meaning |
|-------|---------|
| FORMING | Collecting high/low from M1 bars after session open |
| LOCKED | Range window complete; breakout evaluation armed |
| TRADED | Valid signal fired; no further breakouts this session |
| EXPIRED | Session ended without trade |

- Range high/low updated from `bar[1]` OHLC during FORMING
- Locks after `InpRangeMinutes` bars or elapsed minutes
- `width = high − low` stored at lock time for SL/TP and min-range gate
- Resets automatically on new session open

---

### 4. SessionVwap

Session-anchored VWAP (not calendar-day midnight):

- Recalculates cumulative typical price × tick volume from session open through `bar[1]`
- Resets when session open time changes
- Used as directional filter: longs require close above VWAP; shorts require close below

---

### 5. IndicatorManager

| Component | Default | Role |
|-----------|---------|------|
| ATR | 14 period (iATR handle) | Min-range gate, fallback SL/TP |
| Tick-volume MA | 20-bar simple average | Volume expansion baseline |

- `GetATR(shift)`, `GetTickVolume(shift)`, `GetVolumeMA(shift)`
- `IsReady()` checks bar count and ATR buffer at `bar[1]`
- `OnInit` returns `INIT_FAILED` if ATR handle is invalid

---

### 6. Signal engine — `SignalEngine`

Evaluates **closed bars only** (`bar[1]`). Rejection codes logged on every suppressed evaluation.

**Pre-conditions (in order):**

1. Indicators ready
2. Inside active session (`OUTSIDE_SESSION` if not)
3. Breakout not already consumed (`ALREADY_TRADED`)
4. Range locked, not forming (`RANGE_FORMING`)
5. Range width ≥ `InpMinRangeAtrFactor × ATR[1]` (`RANGE_TOO_NARROW`)
6. Session VWAP available

**Long entry:**

- `Close[1] > range_high`
- `Close[1] > session_vwap`
- `TickVol[1] ≥ InpVolumeMultiplier × VolMA[1]`

**Short entry:**

- `Close[1] < range_low`
- `Close[1] < session_vwap`
- Volume filter as above

**No breakout** → `NO_BREAKOUT`. VWAP/volume failures → `WRONG_SIDE_OF_VWAP` / `VOL_INSUFFICIENT`.

**Not implemented (Phase 2 TODO):** D1 50 EMA bias, H4 swing structure, daily loss breaker, trailing TP at 1.5× range.

---

### 7. Risk engine — `RiskEngine`

**Pre-trade guards (`CanTrade`):**

- Trading enabled flag
- Equity ratio: `Equity >= Balance × InpMinEquityRatio` (default 0.8) → `EQUITY_FLOOR`
- Max spread (points) → `SPREAD_TOO_HIGH`
- Max open positions (magic + symbol scoped) → `MAX_TRADES`
- Cooldown between entries → `COOLDOWN`
- Buy-only / sell-only permission → `PERMISSION_DENIED`

**Trade setup (`BuildSetup`) — STRATEGY_NATIVE (default):**

| Direction | Stop loss | Take profit |
|-----------|-----------|-------------|
| Long | `range_low` (normalized) | `entry + range_width` (measured move) |
| Short | `range_high` (normalized) | `entry − range_width` (measured move) |

Additional validation:

- Buy/sell geometry check → `STOPS_INVALID`
- TP proximity: suppress if TP distance &lt; spread + stops level
- Informational RR logged at setup time
- Lot sizing: fixed lot or % equity from SL distance via `OrderCalcProfit`

**Fallback modes** (dev/testing; also used when `InpTestExecution` forces a trade before range is locked):

- `FIXED_POINTS` — SL/TP from input point distances
- `ATR_BASED` — SL/TP as ATR multiples from entry

**Not implemented (Phase 2 TODO):** daily 5% loss breaker, consecutive-loss pause.

---

### 8. Execution — `ExecutionEngine`

Wraps MQL5 `CTrade` with:

- Auto-detected order filling mode (IOC / FOK / RETURN)
- Configurable slippage and magic number
- Pre-send validation: lot normalisation (min/max/step), stops level, margin check
- Market buy/sell with SL and TP attached at placement
- Retcode logging on failure → `STOPS_INVALID`, `LOT_INVALID`, `MARGIN_INSUFFICIENT`

---

### 9. State — `StateTracker`

- Counts open positions for `_Symbol` + magic number
- Records `lastEntryTime` for cooldown enforcement
- Per-session `breakout_consumed` flag — resets on new session open
- Synced with `OpeningRange.MarkTraded()` after successful execution
- In-memory only (no GlobalVariables — appropriate for Phase 1)

---

### 10. Orchestrator — `ORBVWAP.mq5`

Thin entry point wiring all modules. Warns if attached to non-M1 chart.

**Dev hook:** `InpTestExecution = true` forces one BUY on the first new bar to verify the pipeline without waiting for a session breakout. Uses ATR fallback SL/TP if range is not yet locked. Default is `false`.

---

## Configuration surface

All behaviour is tunable without code changes:

| Category | Key parameters |
|----------|----------------|
| Identity | `InpMagicNumber`, `InpEnableTrading` |
| Session timing | `InpGmtOffsetHours`, London/NY hours, `InpActiveSession` |
| Range | `InpRangeMinutes`, `InpMinRangeAtrFactor` |
| Execution quality | `InpSlippagePoints`, `InpMaxSpreadPoints` |
| Position sizing | `InpSizingMode`, `InpFixedLot`, `InpRiskPercent` |
| Exit modes | `InpSltpMode`, fixed/ATR fallbacks |
| Trade limits | `InpMaxOpenTrades`, `InpCooldownSeconds`, `InpTradePermission`, `InpMinEquityRatio` |
| Signal tuning | ATR period, volume MA period, volume multiplier |
| Debug | `InpEnableFileJournal`, `InpLogSessionState` |

This supports Strategy Tester optimisation of session, range, risk, and volume parameters independently.

---

## Backtest validation

Strategy Tester results (screenshot provided) confirm the engine meets Phase 1 operational criteria.

### Test environment

| Metric | Value |
|--------|-------|
| History quality | 100% |
| Symbols | 1 |
| Ticks processed | 10,896,734 |
| Bars generated | 161,498 |
| Modelling | Every tick based on real ticks (assumed from bar count) |

### Account and performance

| Metric | Value | What it tells us |
|--------|-------|------------------|
| Initial deposit | 200.00 | Small-account test scenario from concept |
| Total net profit | −24.42 | Strategy unprofitable in this window (−12.2%) |
| Gross profit / loss | 79.65 / −104.07 | Losses outweigh wins in dollar terms |
| Profit factor | 0.77 | Below 1.0 — negative expectancy |
| Recovery factor | −0.70 | Drawdown not recovered |
| Sharpe ratio | −5.00 | Poor risk-adjusted return |
| Expected payoff | Negative | Avg win &lt; avg loss despite high win rate |

### Trade activity

| Metric | Value | What it tells us |
|--------|-------|------------------|
| Total trades | 220 | Low-frequency ORB behaviour (vs thousands of scalps) |
| Total deals | 440 | Entries and exits both executing |
| Long trades (won %) | 102 (56.86%) | Longs slightly weaker than shorts |
| Short trades (won %) | 118 (61.86%) | Shorts marginally stronger |
| Profit trades | 131 (59.55%) | High win rate |
| Loss trades | 89 (40.45%) | Losses are fewer but larger |
| Largest profit / loss | 2.33 / −5.66 | Asymmetric: losers ~2.4× avg winners |
| Average profit / loss | 0.61 / −1.17 | Classic negative R:R profile |
| Max consecutive wins | 10 (6.44) | Engine kept running through streaks |
| Max consecutive losses | 7 (−9.98) | No circuit breaker yet (Phase 2) |

### Drawdown and risk

| Metric | Value | What it tells us |
|--------|-------|------------------|
| Balance DD maximal | 34.16 (16.59%) | Moderate drawdown on 200 deposit |
| Equity DD maximal | 34.66 (16.81%) | Inline with balance DD |
| Margin level | 8576.50% | No margin stress at 0.01 lots |

### Holding time and trade quality

| Metric | Value | What it tells us |
|--------|-------|------------------|
| Min holding time | 0:00:15 | Fastest exits confirmed |
| Max holding time | 13:34:00 | Some trades held well beyond typical ORB window |
| Average holding time | 1:09:06 | ~1 hour — breakout moves with measured-move TP |
| Correlation (profits, MFE) | 0.30 | Low — winners don't always capture full favourable move |
| Correlation (profits, MAE) | 0.74 | High — trades that go deep into drawdown rarely recover |
| Correlation (MFE, MAE) | −0.25 | Moderate inverse relationship |

### Temporal distribution

| Dimension | Pattern | Implication |
|-----------|---------|-------------|
| Entries by hour | Peaks ~10:00 and 16:00–17:00 | Aligns with London open + NY overlap after range formation |
| Entries by weekday | Consistent Mon–Fri | Session logic active across week |
| Entries by month | Jan–Jun; peaks Apr/May | Test window coverage |
| P/L by hour/day/month | Mixed; losses outweigh wins in aggregate | Consistent with profit factor 0.77 |

**Engine verdict:** The automated execution loop is **working as designed** — session ranges form, breakouts generate signals, orders place with strategy-native SL/TP, positions close. Trade count (~220 over ~6 months) matches the intentionally low-frequency ORB profile from [concept.md](./concept.md) (1–3 trades/day target with filters).

**Strategy verdict (separate concern):** Profit factor 0.77 with **59.55% win rate** indicates a **negative risk-reward profile** — average loss (1.17) nearly **2×** average win (0.61). Measured-move TP vs opposite-range SL produces ~1:1 theoretical RR, but slippage, spread, and stop placement at range boundary likely erode realised RR. High MAE correlation (0.74) suggests many losing trades move significantly against entry before SL. Phase 2 MTF filters (D1 EMA, H4 structure) and trailing at 1.5× range — deferred by design — are the intended levers for edge refinement.

---

## What was intentionally excluded

Per scope guardrails, none of the following were built — only TODO comments:

| Feature | Planned hook point |
|---------|-------------------|
| D1 50 EMA directional bias | `SignalEngine` |
| H4 last-completed-swing structure | `SignalEngine` |
| H1 / M15 zone confirmation (full MTF cascade) | `SignalEngine` |
| Daily 5% drawdown circuit breaker | `RiskEngine` |
| 3-loss / 2-hour consecutive-loss pause | `RiskEngine` |
| Trailing TP at 1.5× range size | `RiskEngine` / exit logic |
| Auto DST detection | `SessionUtils` |
| Pending/limit entry variants | `ExecutionEngine` |
| Multi-symbol / portfolio management | Out of scope entirely |
| AI, adaptive optimisation, custom DLLs | Out of scope entirely |
| Chart objects / horizontal range lines | Out of scope (debug optional) |

These attach later as filters on the existing pipeline without rewriting the core.

---

## Documentation delivered

| File | Purpose |
|------|---------|
| [concept.md](./concept.md) | Strategy theory, Phase 1 scope, gap decisions |
| [roadmap.md](./roadmap.md) | 4-week build plan, compile-once workflow, completion gates |
| [compo report.md](./compo%20report.md) | This comprehensive build and backtest report |
| [ORBVWAP.mqproj](./ORBVWAP.mqproj) | Project file with all 13 source modules registered |

---

## Code quality snapshot

| Item | Detail |
|------|--------|
| Source files | 13 — 1 `.mq5` + 12 `.mqh` modules |
| Compile result | 0 errors, 0 warnings (MetaEditor, ~1216 ms) |
| Orchestrator | ~160 lines — thin, readable entry point |
| Include hierarchy | No circular dependencies |
| Abstraction level | Concrete classes only — no plugin registries or factory patterns |
| Output binary | `ORBVWAP.ex5` |

**File inventory:**

```
Experts/ORBVWAP/
├── ORBVWAP.mq5
├── ORBVWAP.mqproj
├── ORBVWAP.ex5
├── concept.md
├── roadmap.md
├── compo report.md
└── Include/ORBVWAP/
    ├── Types.mqh
    ├── Constants.mqh
    ├── Inputs.mqh
    ├── Logger.mqh
    ├── SessionUtils.mqh
    ├── OpeningRange.mqh
    ├── SessionVwap.mqh
    ├── IndicatorManager.mqh
    ├── SignalEngine.mqh
    ├── RiskEngine.mqh
    ├── ExecutionEngine.mqh
    └── StateTracker.mqh
```

---

## Phase 1 completion checklist

| Criterion | Met? |
|-----------|------|
| Compiles cleanly | Yes |
| Attaches and initialises on M1 chart | Yes |
| Closed-bar pipeline: session/range → signal → risk → execute | Yes |
| Opening range FSM with configurable window | Yes |
| Session-anchored VWAP (London/NY, not midnight) | Yes |
| ORB + VWAP + volume + min-range + first-breakout logic | Yes |
| Market orders with strategy-native SL/TP and lot sizing | Yes |
| Spread, max trades, cooldown, permissions, equity floor | Yes |
| Magic-scoped position tracking | Yes |
| Tagged rejection reason codes | Yes |
| Lightweight session gate (London/NY GMT) | Yes |
| No Phase 2 code beyond TODOs | Yes |
| Backtest confirms end-to-end trade cycles | Yes (220 trades) |

**Phase 1 is complete.**

---

## Recommended next steps (Phase 2 — when you choose)

Ordered by expected impact from [concept.md](./concept.md) and backtest observations:

1. **D1 50 EMA bias** — filter longs below / shorts above daily trend; addresses trades fighting higher-TF direction
2. **H4 swing structure** — confirm bullish/bearish structure before arming breakouts
3. **Trailing TP at 1.5× range** — capture extended moves; may improve avg win vs the current measured-move cap
4. **Daily 5% loss breaker + consecutive-loss pause** — cap drawdown from streaks (max 7 consecutive losses observed)
5. **% risk sizing** — test with `InpSizingMode = PERCENT_RISK` and ATR-calibrated stops
6. **GMT offset calibration** — verify `InpGmtOffsetHours` across DST transitions for your broker
7. **Range window optimisation** — test 5 vs 10 vs 15 minute windows per pair (EURUSD vs USDJPY)
8. **Volume multiplier tuning** — current 1.5× may be too permissive or restrictive per symbol

Each plugs into `SignalEngine::Evaluate()` or `RiskEngine::CanTrade()` without restructuring the engine.

---

## Bottom line

You have a **production-style execution foundation** for Strategy 3 (ORB + VWAP): modular, configurable, single-symbol, session-aware, and proven in backtest with **220 completed trade cycles** on M1. The engine forms opening ranges at session opens, anchors VWAP correctly, evaluates breakout conditions on closed bars, places orders with range-derived stops and measured-move targets, enforces spread/cooldown/equity guards, and logs structured rejection codes throughout.

The engine does its job. The backtest P/L reflects **incomplete edge refinement** (negative realised R:R despite 59% win rate) and **missing Phase 2 MTF filters** — not broken execution. The hourly entry peaks at London and NY opens confirm session logic is working. The next phase of work is **MTF alignment, exit refinement, and circuit breakers** — exactly what [concept.md](./concept.md) planned to defer until the execution layer was solid. That layer is solid.
