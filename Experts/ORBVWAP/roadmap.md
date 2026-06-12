# ORBVWAP Phase 1 Roadmap — Execution Engine

Build a reliable, configurable **automated execution engine** for **Opening Range Breakout + session VWAP** on a **single symbol** attached to an **M1 chart**. The focus of this phase is session/range state, signal evaluation, execution, risk, and logging — not strategy perfection or advanced filters.

Reference: [concept.md](./concept.md)

**Canonical setup:** attach to **EURUSD M1** (or one pair from concept.md). One EA instance per chart. `_Symbol` only — no scanning.

**You own testing** (Strategy Tester, demo, parameter tuning). This roadmap defines *what to build*, not *how to test it*.

---

## Phase 1 completion criteria

Phase 1 is **done** when all of the following are true:

- EA compiles with zero errors from `ORBVWAP.mqproj`
- Attaches to M1 and initialises/deinitialises without journal errors
- On each **new closed bar**, the pipeline runs: **session/range update → signal → risk → execute**
- Opening range forms at session open, locks after N minutes, and arms breakouts only when width ≥ 0.8×ATR(14)
- Long/short entries require: close beyond range + correct VWAP side + volume ≥ 1.5× 20-bar tick-volume MA + **first breakout only** per session
- SL/TP use strategy-native prices: opposite range boundary + measured-move TP
- Lot sizing works in fixed-lot or %‑risk mode (back-calculated from SL distance)
- Spread, slippage, max open trades, cooldown, permissions, equity floor, and broker validation block invalid sends
- Positions tracked by magic number on `_Symbol` only
- Every signal rejection and order failure logs a tagged reason code
- No Phase 2 features implemented beyond `// TODO Phase 2:` comments

---

## Scope guardrails

### In scope

| Area | What to build |
|------|----------------|
| Foundation | `Include/ORBVWAP/` tree, types, grouped inputs, logger, thin orchestrator |
| Session (lightweight) | London 07:00–12:00 GMT, NY 13:00–17:00 GMT as inputs; `TimeGMT()` + `InpGmtOffsetHours`; range starts at session open |
| Opening range | State machine: FORMING → LOCKED → TRADED / EXPIRED; configurable 5/10/15 min window |
| VWAP | Session-anchored from London/NY open (not calendar midnight) |
| Indicators | ATR(14), tick-volume 20-bar MA on chart TF (M1) |
| Signal | Breakout + VWAP + volume + min-range + first-breakout flag (Week 4) |
| Risk | Strategy-native SL/TP (default), optional fixed/ATR dev modes, lot sizing, guards |
| Execution | `CTrade` wrapper, pre-order validation, market orders |
| Logging | Tagged `Print()` + optional `FileWrite()` journal with rejection reason codes |
| State | Open position count, last entry time, per-session breakout consumed |

### Out of scope — do not build

| Item | Notes |
|------|-------|
| D1 50 EMA bias | Phase 2 — MTF cascade |
| H4 swing structure | Phase 2 |
| H1 / M15 zone confirmation | Phase 2 |
| Daily 5% drawdown circuit breaker | Phase 2 |
| 3-loss / 2-hour consecutive-loss pause | Phase 2 |
| Trailing stop at 1.5× range | Phase 2 |
| Auto DST detection | Phase 2 — use `InpGmtOffsetHours` manual offset only |
| Multi-symbol scanning or portfolio logic | Never in Phase 1 |
| AI, adaptive optimisation, custom DLLs | Never in Phase 1 |
| Abstract interfaces, plugin registries, factory patterns | Never in Phase 1 |
| Unit test frameworks or mock layers | Never in Phase 1 |
| Chart objects / horizontal line drawing | Optional debug only — not required for execution |
| Pending/limit orders | Phase 2 — market orders only in Phase 1 |

### Stub rule

For every out-of-scope item, at most **one `// TODO Phase 2:` comment** where it would attach later (typically `SignalEngine.mqh` or `RiskEngine.mqh`). No partial implementations, no empty classes “for later.”

---

## Architecture (minimal)

```
ORBVWAP.mq5              ← orchestrator only (~100 lines)
    │
    ├─ SessionUtils         GMT conversion, active session window check
    ├─ OpeningRange         FORMING → LOCKED → TRADED/EXPIRED state machine
    ├─ SessionVwap          volume-weighted mean from session open
    ├─ IndicatorManager     ATR(14), tick-volume MA(20)
    ├─ SignalEngine         returns SSignalResult (Week 4 logic; Weeks 2–3 stub)
    ├─ RiskEngine           guards + SL/TP + lot size
    ├─ ExecutionEngine      CTrade + validation
    ├─ StateTracker           cooldown + position count + session breakout flag
    └─ Logger                 tagged Print() + optional file journal
```

**Tick flow (new bar only for signals):**

1. New closed bar? If no → return
2. Update session context — which session (London/NY/none), session open time, reset state on new session
3. Update opening range — form high/low during window, lock after N minutes, expire outside session
4. Update session VWAP — cumulative from session open through `bar[1]`
5. Indicators ready? If no → log and return
6. Signal evaluation — `NONE` until Week 4 (stub in Weeks 2–3)
7. Risk guards — spread, max trades, cooldown, permissions, equity floor, enable flag
8. Risk sizing — strategy-native SL/TP in **price**, lot from SL distance
9. Execute — validate lot/stops/margin/freeze → market order
10. Update state — last entry time, mark range TRADED, log result

---

## Folder structure

Create once in Week 1; do not reorganise later.

```
Experts/ORBVWAP/
├── ORBVWAP.mq5
├── ORBVWAP.mqproj
├── concept.md
├── roadmap.md
└── Include/
    └── ORBVWAP/
        ├── Types.mqh
        ├── Inputs.mqh
        ├── Constants.mqh
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

Register every new `.mqh` in `ORBVWAP.mqproj` as it is added.

---

## Strategy → engine mapping (Phase 1 contract)

These rules are fixed for Phase 1. Do not reinterpret during build.

| Rule | Definition |
|------|------------|
| Chart TF | **M1 only** — attach EA to M1; use `PERIOD_CURRENT` |
| Signal bar | Always `bar[1]` (last completed bar). Never evaluate on `bar[0]`. |
| Session gate | Trade logic active only inside London (07:00–12:00 GMT) or NY (13:00–17:00 GMT) windows |
| Range window | High/low of first `InpRangeMinutes` (5/10/15) M1 bars from session open |
| Min range | `(range_high - range_low) >= 0.8 * ATR[1]` — else reject with `RANGE_TOO_NARROW` |
| Long entry | `Close[1] > range_high` AND `Close[1] > session_vwap` AND `TickVol[1] >= 1.5 * VolMA[1]` |
| Short entry | `Close[1] < range_low` AND `Close[1] < session_vwap` AND `TickVol[1] >= 1.5 * VolMA[1]` |
| First breakout | One trade direction consumed per session/range — reject re-tests with `ALREADY_TRADED` |
| Long SL | `range_low` (normalized, stops-level adjusted) |
| Short SL | `range_high` (normalized, stops-level adjusted) |
| Take profit | Measured move: long `entry + range_width`, short `entry - range_width` |
| Range width | `range_high - range_low` at lock time |
| Volume MA | Simple 20-bar tick-volume average ending at `bar[1]` |
| Equity check | Block if `Equity < Balance * InpMinEquityRatio` (default 0.8) |

**Rejection reason codes** (log on every suppressed signal):

`OUTSIDE_SESSION`, `RANGE_FORMING`, `RANGE_TOO_NARROW`, `VOL_INSUFFICIENT`, `WRONG_SIDE_OF_VWAP`, `NO_BREAKOUT`, `ALREADY_TRADED`, `SPREAD_TOO_HIGH`, `MAX_TRADES`, `COOLDOWN`, `PERMISSION_DENIED`, `EQUITY_FLOOR`, `STOPS_INVALID`, `LOT_INVALID`, `MARGIN_INSUFFICIENT`

**SL/TP mode enum** (`InpSltpMode`, default `STRATEGY_NATIVE`):

- `STRATEGY_NATIVE` — opposite range boundary + measured move (Phase 1 default)
- `FIXED_POINTS` — dev/fallback only; fixed SL/TP in points from entry
- `ATR_BASED` — dev/fallback only; SL/TP as ATR multiples from entry

---

## Compile-once workflow (every week)

Each week is designed so you **implement all tasks first**, then **compile once**, then **run your tests**.

| Step | Action |
|------|--------|
| 1. Build | Complete every task listed for that week before opening MetaEditor compile |
| 2. Compile | Single compile from `ORBVWAP.mqproj` — fix all errors in one pass |
| 3. Test | Run the end-of-week verification checklist (you own test design and execution) |
| 4. Gate | Do not start the next week until the current week's gate passes |

**Rule:** Every week's deliverable must be syntactically complete before compile. Use `return NONE` / log-and-skip stubs inside unfinished modules — never leave broken syntax or half-written function bodies mid-week.

---

## Weekly implementation

### Week 1 — Scaffolding & configuration

**Goal:** Compilable EA shell with all module files present. Initialises cleanly on M1. No trading logic.

| Task | Module |
|------|--------|
| Create `Include/ORBVWAP/` tree and register all files in `ORBVWAP.mqproj` | project |
| Define enums: signal direction, sizing mode, SL/TP mode, trade permission, session type, range state | `Types.mqh` |
| Define structs: `SSignalResult`, `STradeSetup`, `SOpeningRangeState`, `SSessionContext` | `Types.mqh` |
| Magic number prefix, log tag, rejection reason string constants | `Constants.mqh` |
| Grouped inputs: General, Session, Range, Execution, Risk, Indicators, Debug | `Inputs.mqh` |
| Logger: `Info`, `Warn`, `Error`, optional `Journal()` to file | `Logger.mqh` |
| Stub classes with valid syntax: `Init`/`Release` no-ops, `Evaluate` returns empty signal, `CanTrade` returns false | all modules |
| Wire `OnInit` / `OnDeinit` / `OnTick` — log init, `IsNewBar()` gate, empty pipeline call | `ORBVWAP.mq5` |

**Key inputs to declare in Week 1** (defaults only; wired in later weeks):

- General: `InpMagicNumber`, `InpEnableTrading`
- Session: `InpGmtOffsetHours`, London/NY start/end hours (GMT), `InpActiveSession` (London / NY / Both)
- Range: `InpRangeMinutes` (5), `InpMinRangeAtrFactor` (0.8)
- Execution: `InpTestExecution` (default `false`), `InpSlippagePoints`, `InpMaxSpreadPoints`
- Risk: sizing mode, fixed lot, risk %, SL/TP mode, max open trades, cooldown seconds, trade permission, `InpMinEquityRatio` (0.8)
- Indicators: ATR period (14), volume MA period (20), volume multiplier (1.5)
- Debug: `InpEnableFileJournal` (default `false`)

**End-of-week gate**

- [ ] Compiles with 0 errors from `ORBVWAP.mqproj`
- [ ] Attaches to EURUSD M1 — journal shows init success
- [ ] Removing EA shows clean deinit, no errors
- [ ] All `.mqh` files registered in `.mqproj`

---

### Week 2 — Session, opening range, VWAP & indicators

**Goal:** Session clock, range state machine, session VWAP, and indicator buffers all update on new bars. Signal module exists but always returns `NONE`. **No orders sent.**

| Task | Module |
|------|--------|
| `BrokerToGmt()` / `IsInsideSessionWindow()` using `TimeGMT()` + offset input | `SessionUtils.mqh` |
| Detect active session (London/NY/none); expose session open datetime | `SessionUtils.mqh` |
| State machine: FORMING during range window → LOCKED → TRADED or EXPIRED at session end | `OpeningRange.mqh` |
| Track `range_high`, `range_low`, `range_width`, lock time; reset on new session open | `OpeningRange.mqh` |
| Session VWAP from session open through current bar (typical price × tick volume) | `SessionVwap.mqh` |
| ATR(14) handle + buffer read at `[1]` | `IndicatorManager.mqh` |
| Tick-volume simple MA(20) at `[1]` | `IndicatorManager.mqh` |
| `Init(symbol, period)` / `Release()` — fail `OnInit` if ATR handle invalid | `IndicatorManager.mqh` |
| `SignalEngine::Evaluate()` — stub returning `NONE` with `// TODO Phase 2:` for D1/H4 MTF | `SignalEngine.mqh` |
| On new bar: update session → range → VWAP → indicators; log state transitions (optional) | `ORBVWAP.mq5` |

**End-of-week gate**

- [ ] Compile once — 0 errors
- [ ] Attaches to M1 — session/range/VWAP modules run without crash
- [ ] Journal shows range FORMING → LOCKED at expected session open (spot-check one London or NY window)
- [ ] VWAP resets on new session open (not at calendar midnight)
- [ ] ATR and volume MA readable at `[1]`
- [ ] No orders placed

---

### Week 3 — Risk engine, execution, state & full pipeline

**Goal:** Real market orders with strategy-native SL/TP via full pipeline. Signal still `NONE` unless `InpTestExecution` is used.

| Task | Module |
|------|--------|
| `CanTrade()` — spread, max open trades, cooldown, permissions, equity floor, enable flag | `RiskEngine.mqh` |
| `BuildSetup()` — `STRATEGY_NATIVE`: opposite range SL + measured-move TP in price | `RiskEngine.mqh` |
| Normalize SL/TP against `SYMBOL_TRADE_STOPS_LEVEL` and freeze level | `RiskEngine.mqh` |
| Fallback modes: `FIXED_POINTS`, `ATR_BASED` (pipeline testing only) | `RiskEngine.mqh` |
| Fixed lot vs % risk sizing from SL distance | `RiskEngine.mqh` |
| Count open positions for `_Symbol` + magic | `StateTracker.mqh` |
| Track `lastEntryTime`, per-session `breakout_consumed` flag | `StateTracker.mqh` |
| Wrap `CTrade`: magic, slippage, filling mode | `ExecutionEngine.mqh` |
| Pre-send checks: lot min/max/step, stops level, free margin | `ExecutionEngine.mqh` |
| `OpenMarket(STradeSetup)` — buy/sell with SL/TP, log retcode + context on failure | `ExecutionEngine.mqh` |
| Wire pipeline: new bar → session/range/VWAP update → signal → guards → setup → execute → state | `ORBVWAP.mq5` |
| `InpTestExecution` — one controlled test order on first new bar (default off) | `Inputs.mqh` |

**End-of-week gate**

- [ ] Compile once — 0 errors
- [ ] With `InpTestExecution = true`: exactly one market order with SL/TP on first new bar
- [ ] With `InpTestExecution = false`: no orders, no errors across multiple bars
- [ ] Max open trades blocks a second test order
- [ ] Cooldown blocks re-entry within configured seconds
- [ ] Spread above max → logged block (`SPREAD_TOO_HIGH`), no crash
- [ ] Equity below ratio → logged block (`EQUITY_FLOOR`), no new trades
- [ ] Invalid lot/stops/margin → logged error with reason code, no silent failure

---

### Week 4 — Signal engine & phase completion

**Goal:** ORB + VWAP + volume rules drive entries through the existing pipeline. Phase 1 complete.

| Task | Module |
|------|--------|
| Reject with reason codes when outside session, range forming, or already traded | `SignalEngine.mqh` |
| Min-range gate: width vs 0.8×ATR before arming breakouts | `SignalEngine.mqh` |
| Long: close above range high + above session VWAP + volume filter on `[1]` | `SignalEngine.mqh` |
| Short: close below range low + below session VWAP + volume filter on `[1]` | `SignalEngine.mqh` |
| First-breakout only — set `TRADED` state and session flag after valid signal | `SignalEngine.mqh`, `StateTracker.mqh` |
| Populate `SSignalResult` with direction, bar index (1), entry reference price | `SignalEngine.mqh` |
| Replace test-only path with real `SignalEngine::Evaluate()` in orchestrator | `ORBVWAP.mq5` |
| Log every rejection with reason code via `Logger` | `SignalEngine.mqh`, `RiskEngine.mqh` |
| Keep `InpTestExecution` for emergency pipeline checks (default `false`) | `Inputs.mqh` |
| Add `// TODO Phase 2:` stubs only where D1/H4/circuit-breaker/trailing would attach | `SignalEngine.mqh`, `RiskEngine.mqh` |

**End-of-week gate — Phase 1 complete**

- [ ] Compile once — 0 errors
- [ ] `InpTestExecution = false` — EA trades only on valid closed-bar ORB signals inside session
- [ ] No repainting: all conditions use `bar[1]` (and `[2]` only if needed for cross logic — not required here)
- [ ] SL at opposite range boundary; TP at measured move from entry
- [ ] Narrow range suppressed with `RANGE_TOO_NARROW`
- [ ] Second breakout attempt in same session suppressed with `ALREADY_TRADED`
- [ ] Journal trail: signal (or rejection reason) → risk pass → order sent, or blocked with reason
- [ ] All completion criteria at top of this document met
- [ ] No Phase 2 code present beyond TODO comments

**Your testing starts here** — backtest, session-window checks, broker spread validation, forward demo. That work is outside this roadmap.

---

## Anti-overengineering checklist

Before adding any file, function, or input, ask:

1. **Does Phase 1 require it to place a validated market order?** If no → skip.
2. **Is there already an MQL5 standard library for it?** Use `CTrade`, `CopyBuffer`, `SymbolInfoDouble` — do not wrap them twice.
3. **Am I building for multi-symbol or Phase 2?** Stop. One `// TODO Phase 2:` comment is enough.
4. **Will this force mid-week compiles?** Keep the week's code syntactically complete from day one.
5. **Is this a third way to configure the same thing?** One mode enum beats overlapping booleans.
6. **Am I drawing on chart or building a UI?** Execution does not need visual objects in Phase 1.
7. **Am I auto-detecting DST?** Manual `InpGmtOffsetHours` is enough for Phase 1.

---

## What comes after Phase 1 (not now)

Documented in [concept.md](./concept.md) — attach to existing pipeline as guards or signal pre-filters:

- D1 50 EMA directional bias
- H4 last-completed-swing structure
- H1 / M15 zone confirmation (full MTF cascade)
- Daily 5% drawdown circuit breaker
- 3-consecutive-loss / 2-hour pause
- Trailing TP at 1.5× range size
- Auto DST handling
- Pending/limit entry variants

The execution engine should not need rewriting — each item hooks into `CanTrade()` or the top of `SignalEngine::Evaluate()`.

---

## Quick reference — build order

```
Week 1  Types → Inputs → Constants → Logger → module stubs → ORBVWAP.mq5 shell
Week 2  SessionUtils → OpeningRange → SessionVwap → IndicatorManager → SignalEngine stub (NONE)
Week 3  RiskEngine → StateTracker → ExecutionEngine → pipeline wire
Week 4  SignalEngine (ORB + VWAP + volume) → integration → done
```

One compile. One test pass. Next week.
