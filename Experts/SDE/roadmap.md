# SDE Phase 1 Roadmap (Execution Engine Only)

## Objective

Build a reliable, configurable MT5 automated execution engine for the Volatility Breakout Stack in Phase 1:
- BB/KC squeeze detection
- Squeeze fire detection
- ADX confirmation
- Market order execution
- Basic risk controls and trade safety

This phase is complete when the EA compiles, runs on one chart (one symbol, one timeframe), executes valid trades, and enforces safety/risk constraints.

---

## Scope Lock (No Overengineering)

### In Scope (Phase 1)
- Single EA instance per chart
- Single symbol and current chart timeframe only
- Signal flow: `SQUEEZE_ON -> SQUEEZE_FIRED -> ADX_CONFIRM -> ENTRY`
- Market orders only
- Fixed lot and optional risk-percent lot sizing
- SL/TP configuration (fixed points; ATR option only if already defined in current concept)
- Max spread, slippage/deviation, max open trades
- Cooldown after trade exit
- Magic-number-based trade ownership and restart recovery
- Basic logging (`INFO`, `WARN`, `ERROR`, optional `DEBUG`)

### Out of Scope (Must Not Be Added)
- Multi-symbol scanning or portfolio engine
- Session filters, news filters, AI/ML layers
- Adaptive optimization logic
- Advanced trade management (pyramiding, scaling, partial exits, trailing complexity)
- Cross-chart communication
- Multi-strategy routing
- External service dependencies

If a request appears during implementation that is not listed in scope, add it to backlog and defer.

---

## Architecture Blueprint (Minimal and Modular)

Use a simple module split to keep responsibilities clear:

- `SDE.mq5`  
  Thin orchestrator: `OnInit`, `OnTick`, `OnDeinit`, new-bar gating, module wiring.

- `Include/SDE/Config.mqh`  
  All inputs and enums grouped by domain (signal, risk, execution, debug).

- `Include/SDE/State.mqh`  
  Runtime state machine and timestamps:
  - state enum: `FLAT`, `SQUEEZE_ON`, `SQUEEZE_FIRED`, `ADX_CONFIRM`, `IN_TRADE`, `COOLDOWN`
  - setup/trade timing fields
  - direction and expiration tracking

- `Include/SDE/Indicators.mqh`  
  Indicator handle lifecycle and value reads:
  - BB handle
  - ADX handle
  - internal KC computation (EMA basis + ATR envelope)
  - warmup checks (`BarsCalculated`, `CopyBuffer` validation)
  - shift policy: signal reads on closed bar (`shift = 1`)

- `Include/SDE/SignalEngine.mqh`  
  Pure signal evaluation and state transitions only (no order sending).

- `Include/SDE/RiskEngine.mqh`  
  Lot sizing, spread filter, max trades, cooldown, equity safety checks, permission gates.

- `Include/SDE/ExecutionEngine.mqh`  
  Order validation and `CTrade` execution with broker mode checks and normalized prices.

- `Include/SDE/Logger.mqh`  
  Lightweight log wrapper with log levels.

Keep classes/structs small and explicit. Avoid inheritance trees or generic frameworks.

---

## Delivery Criteria (Definition of Done)

Phase 1 is done only when all are true:
- EA compiles without errors/warnings that affect behavior.
- Deterministic signal path on closed bars.
- No duplicate entries from same squeeze cycle.
- One-position policy enforced (if configured).
- Trade ownership isolated by magic number.
- Restart recovery re-syncs existing EA-owned positions.
- Safety gates block invalid execution (spread/stops/trade mode/filling checks).
- Config inputs are grouped, readable, and optimization-ready.

---

## Weekly Implementation Plan (Scaffolding -> Completion)

## Week 1 - Scaffolding and Contracts

Goal: establish structure and frozen interfaces (no execution yet).

Tasks:
- Create folder/module skeleton and file stubs.
- Define all input parameters in `Config.mqh`.
- Define state enum, transition contract, and runtime fields in `State.mqh`.
- Define indicator data contracts and signal result structs.
- Define public method signatures for `SignalEngine`, `RiskEngine`, and `ExecutionEngine`.
- Document fixed rules:
  - closed-bar signal policy (`shift = 1`)
  - one-position behavior
  - setup expiration and invalidation flags

Outputs:
- Complete code scaffolding with compile-intended interfaces.
- No strategy logic or order logic finalized yet.

Guardrail:
- Do not add functionality outside interface definitions and core constraints.

---

## Week 2 - Core Signal Engine (No Orders Yet)

Goal: implement deterministic signal evaluation and state transitions.

Tasks:
- Implement BB and ADX handle initialization and reads.
- Implement KC internal calculation (EMA + ATR * multiplier).
- Add warmup/history checks and fail-closed behavior.
- Implement squeeze detection, squeeze fire, and ADX confirm logic.
- Implement state transitions and invalidation:
  - squeeze cancel
  - ADX timeout
  - opposite breakout invalidation
- Add concise structured logging for each state transition.

Outputs:
- Signal engine produces stable `BUY/SELL/NONE` intent with reason codes.
- No order placement yet.

Guardrail:
- No optimization logic, no additional filters, no session/news logic.

---

## Week 3 - Execution and Risk Integration

Goal: convert valid signal intent into safe market execution.

Tasks:
- Implement risk engine checks:
  - lot calculation (fixed + risk-percent option)
  - spread filter
  - max open trades
  - cooldown logic
  - permission mode (`BUY_ONLY`, `SELL_ONLY`, `BOTH`, `DISABLED`)
- Implement SL/TP price normalization and stop-distance validation.
- Implement execution engine checks:
  - trade mode and filling mode compatibility
  - deviation/slippage input handling
  - order send wrapper with return-code logging
- Enforce one-position-per-signal-cycle policy.
- Implement restart recovery in `OnInit` using symbol + magic number.

Outputs:
- End-to-end workflow complete from signal to order send.
- Still no testing yet, by plan.

Guardrail:
- Keep retries minimal and bounded; do not build complex recovery framework.

---

## Week 4 - Stabilization, Final Wiring, Single Compile Gate

Goal: finalize and prepare for testing with one compile event.

Tasks:
- Wire all modules in `SDE.mq5` final orchestrator path.
- Finalize input grouping, defaults, and comments.
- Remove dead code/placeholders and keep only active Phase 1 logic.
- Verify logs are useful but minimal.
- Run static code pass for consistency:
  - naming consistency
  - state transition completeness
  - all risk gates connected
  - all `CopyBuffer`/handle checks fail-closed
- Perform **single compile** at end of week (first compile event in this roadmap flow).

Outputs:
- Compile-ready EA binary for Strategy Tester.
- No additional feature work after compile unless defect blocks testing.

Guardrail:
- Freeze scope. Only blocker fixes allowed after compile.

---

## Single-Compile Strategy (Before Testing)

To ensure you only need one compile before testing:

- Build with strict interface contracts first, then fill implementations in place (no API churn late).
- Avoid partial local compile cycles in roadmap workflow; rely on checklist-based integration discipline.
- Use one final integration pass in Week 4, then compile once.
- After that compile, only fix defects that prevent test execution; no enhancements.

Note: If a blocker is discovered in testing, patch only the blocker and recompile as exception.

---

## Anti-Overengineering Checklist (Use Weekly)

Before adding any code, verify:
- Is this required for immediate Phase 1 execution reliability?
- Is this already in scope?
- Can this be implemented in a simpler way?
- Does this add new state complexity not required now?
- Can this be deferred to backlog without harming core functionality?

If any answer indicates extra complexity, do not implement now.

---

## Backlog (Deferred by Design)

Track but do not implement in Phase 1:
- Session/news filters
- Multi-symbol engine
- Advanced position management
- Strategy variants and adaptive logic
- AI/optimization layers
- Portfolio-level risk controls

---

## Handoff and Next Step

When Week 4 compile is complete, move directly to your testing process:
- functional validation
- edge-case validation
- broker constraint validation
- backtest repeatability checks

Any failure should map back to one module (signal, risk, execution, state) for minimal targeted fixes.
