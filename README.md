# VEES EA

Breakout-retest Expert Advisor for MT5 focused on asymmetric payoff:

- Losses are frequent but controlled.
- Winners are fewer but materially larger.
- Strategy edge is managed through structure quality and disciplined risk.

---

## Strategy Overview

The EA trades a simple, explicit sequence on `EURUSD M5`:

1. Detect a close-based breakout from a rolling range.
2. Wait for a retest of the broken level (up to N bars).
3. Validate optional quality gates (momentum, rejection, trend).
4. Execute with risk-based sizing and fixed R:R targets.
5. Optionally manage open trade lifecycle (time stop / break-even).

Core source:

- `Experts/VEES_EA/VEES_EA.mq5`
- `Experts/VEES_EA/core/breakout.mqh`
- `Experts/VEES_EA/filters/session.mqh`
- `Experts/VEES_EA/filters/trend.mqh`
- `Experts/VEES_EA/risk/risk_manager.mqh`

---

## Entry Logic (Current)

### Breakout

- Lookback range on M5 uses historical bars, excluding the active signal bar.
- Breakout requires `Close(1)` to clear range high/low with buffer.

### Retest

- Retest must occur within `3` bars after breakout arm.
- Retest is a touch check (wick/body) around the broken level using tolerance.

### Quality Gates

- `UseMomentumFilter`: directional candle check (`close > open` for buy, inverse for sell).
- `UseRejectionFilter`: soft wick-vs-range rejection on retest candle.
- H1 trend alignment: buy only above H1 EMA, sell only below H1 EMA.

---

## Risk and Execution

- Position size is computed from `RiskPercent` and actual stop distance.
- Default stop/target profile: `20 / 50` pips.
- One open position per symbol.
- Spread and session filters are enforced before new setup arm.

---

## Management Modes

Two management modules are implemented and can be toggled independently:

### A) Time Stop

Purpose: close "dead" trades that never progress enough.

- `UseTimeStop`
- `TimeStopBars`
- `MinProgressR`

Rule:

- If bars since entry exceed threshold and max favorable excursion is below `MinProgressR`, close position.

### B) Smart Break-even

Purpose: reduce left-tail risk after meaningful favorable move.

- `UseBreakEven`
- `BreakEvenTriggerR`
- `BreakEvenOffsetR`

Rule:

- Once max favorable excursion reaches trigger, shift SL to entry +/- offset in R.

---

## Config Profiles

Use these profiles as reproducible test presets.

### Profile A: Control

- `UseMomentumFilter=false`
- `UseRejectionFilter=false`
- `UseTimeStop=false`
- `UseBreakEven=false`

### Profile B: Light Momentum

- `UseMomentumFilter=true`
- `UseRejectionFilter=false`
- `UseTimeStop=false`
- `UseBreakEven=false`

### Profile C: Rejection Quality (Recommended Candidate)

- `UseMomentumFilter=false`
- `UseRejectionFilter=true`
- `RejectionStrength=0.2`
- `UseTimeStop=false`
- `UseBreakEven=false`

### Profile D: Management A/B Layer

- Start from Profile C and test:
  - D1: `UseTimeStop=true`, `TimeStopBars=12`, `MinProgressR=0.3`
  - D2: `UseBreakEven=true`, `BreakEvenTriggerR=1.0`, `BreakEvenOffsetR=0.1`
  - D3: both enabled

---

## Industry Best-Practice Testing Protocol

### 1) Reproducibility

- Fix symbol, timeframe, test period, spread assumptions, and modeling mode.
- Change only one variable set per run.
- Track full input set alongside each report.

### 2) Walk-Forward Discipline

- In-sample tuning window.
- Out-of-sample validation window.
- Reject configs that degrade sharply OOS.

### 3) Stress Testing

- Re-test with worse spread/slippage assumptions.
- Verify PF and DD remain acceptable under friction.

### 4) Decision Metrics

Prioritize this order:

1. Profit Factor
2. Max Equity Drawdown %
3. Expected Payoff
4. Trade Count robustness

### 5) Acceptance Rule

Promote a profile only if it improves at least two of:

- PF
- Max DD%
- Expected Payoff

Without collapsing trade count.

---

## Current Candidate and Rationale

At this stage, the strategy has shown that:

- Over-filtering destroys opportunity.
- The edge is primarily driven by payoff asymmetry.
- Soft rejection filtering can materially improve trade quality.

Current practical candidate to validate further:

- Profile C (Rejection Quality) as the baseline for OOS checks.
- Then evaluate management modules (D1/D2/D3) one-by-one.

---

## How to Run

1. Compile `Experts/VEES_EA/VEES_EA.mq5` in MetaEditor.
2. Open MT5 Strategy Tester with fixed symbol/timeframe/modeling assumptions.
3. Load one profile at a time.
4. Export report and compare against previous baseline using the same protocol.

---

## Notes

- This repository documents a research workflow, not investment advice.
- Always validate on out-of-sample data before considering live deployment.

# MQL5

MQL5 Algo Forge / [40511693](https://www.mql5.com/en/users/40511693)