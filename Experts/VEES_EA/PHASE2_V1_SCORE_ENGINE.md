# Phase 2 V1 Score Engine

This document defines the first probability-weighted execution model for VEES EA.

## Purpose

Replace stacked hard filters with a weighted trade quality score.

## Score Components (0-100)

- EMA distance quality: 30
- Retest rejection quality: 20
- Breakout strength quality: 15
- Session/hour quality: 15
- Range/volatility quality: 10
- Spread quality: 10

Total max score: 100

## Default Execution Rule

- Execute trade only when `trade_score >= 60`.

## Feature Scoring

### 1) EMA Distance Score (0-30)

- `<= 10 pips`: 20
- `> 10 and <= 35 pips`: 30
- `> 35 and <= 45 pips`: 15
- `> 45 pips`: 0

### 2) Rejection Score (0-20)

Use wick/range ratio on retest candle:

- ratio `>= 0.35`: 20
- ratio `>= 0.20 and < 0.35`: 12
- ratio `< 0.20`: 0

### 3) Breakout Strength Score (0-15)

Use body/range:

- `>= 0.62`: 15
- `>= 0.52 and < 0.62`: 10
- `< 0.52`: 3

### 4) Session/Hour Score (0-15)

- hour `8`: 15
- hour `13`: 0
- London/NY session hours: 10
- other: 6

### 5) Range Score (0-10)

Use M5 candle range in pips:

- `4 to 12`: 10
- `2 to <4` or `>12 to 18`: 6
- otherwise: 2

### 6) Spread Score (0-10)

Spread in points:

- `<= 5`: 10
- `> 5 and <= 8`: 6
- `> 8`: 0

## Logging Requirements

For each score decision, log:

- total score
- threshold
- each sub-score
- decision (take/skip)

## Test Plan

Hold weights fixed and test thresholds:

- 55
- 60
- 65

Compare PF, DD, expectancy, and trade count against baseline.
