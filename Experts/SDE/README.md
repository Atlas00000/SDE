# SDE — Phase 1 execution engine (MT5)

This repository contains the **SDE** Expert Advisor only. It lives under your terminal’s Experts tree at:

`C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SDE`

It is **not** the VEES EA. If you see documentation for VEES, that refers to a different project (`Experts/VEES_EA/`) elsewhere under the same MetaQuotes `MQL5` folder.

## What this project is

Phase 1: a modular **automated execution engine** for a volatility squeeze style setup (Bollinger + Keltner-style channel + ADX), with basic risk gates and market orders. See `concept.md` and `roadmap.md` in this folder.

## Layout

- `SDE.mq5` — EA entrypoint
- `Include/SDE/` — modules (config, state, indicators, signal, risk, execution, logger)
- `concept.md` — strategy and scope
- `roadmap.md` — build phases

## Install / compile

1. Copy or sync the `SDE` folder into `MQL5\Experts\SDE` (path above).
2. Open `SDE.mq5` in MetaEditor and compile.
3. Attach to **one** chart (single symbol, chart timeframe).

Remote: [Atlas00000/SDE](https://github.com/Atlas00000/SDE.git)
