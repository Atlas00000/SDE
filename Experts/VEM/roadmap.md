# VEM Execution Engine — Roadmap (Phase 1)

This roadmap builds **only** the automated execution engine for the RSI + Bollinger Band + Volume mean-reversion concept described in `concept.md`. Anything outside that scope is deferred.

---

## Scope guardrails (non-negotiable)

**In scope for Phase 1**

- Single symbol, single timeframe (chart context).
- Signal evaluation (BB + RSI + volume spike) per `concept.md` v1 logic.
- Market orders, validation (spread, stops/freeze, filling mode where needed).
- Basic risk: fixed lot and/or risk-% sizing, SL/TP (fixed points or ATR), optional R:R TP mode, optional BB midline exit **with explicit precedence** (see `concept.md`).
- Operational limits: max trades, cooldown, magic number, slippage input, equity/balance checks, buy/sell permissions.
- Modular `.mqh` files with clear responsibilities; logging suitable for tester and live.

**Out of scope until a later phase**

- Session/time filters, news filters, multi-symbol scanning, portfolio or correlation logic.
- AI / adaptive optimization / self-tuning parameters.
- Trailing stops, partial closes, scale-in/out, complex exit trees.
- Over-abstract “plugin frameworks” or unused interfaces.

If a task does not directly serve **signal → risk gate → size → send order → track state**, it does not belong in Phase 1.

---

## Compile-once-before-test discipline

**Rule:** The EA must **compile successfully after each week’s work** before you run Strategy Tester or demo.

How:

1. **Week 1** creates the full **project skeleton**: main `.mq5` plus all `.mqh` modules as **thin stubs** (functions declared and called from `OnInit` / `OnTick`, minimal bodies). No orphaned references.
2. Later weeks **replace stubs with real logic** inside existing functions; avoid renaming public entry points mid-phase.
3. Avoid adding new translation units mid-roadmap unless necessary; prefer filling stubs first.

Result: you finish the week’s coding, hit **Compile once**, then test — no half-wired files left for the linker.

---

## Recommended folder layout (production-friendly, minimal)

Keep depth shallow.

```
MQL5/
  Experts/VEM/
    VEM.mq5                 ← includes headers, OnInit/OnDeinit/OnTick only wiring
  Include/VEM/              ← create if not present
    VEM_Config.mqh          ← inputs grouped, enums (exit mode, direction)
    VEM_Log.mqh             ← Print vs tester macros
    VEM_Indicators.mqh      ← BB, RSI, volume baseline handles & accessors
    VEM_Signal.mqh          ← Long/short signal booleans + bar indexing rules
    VEM_Risk.mqh            ← spread, equity, cooldown, max positions, sizing
    VEM_Execution.mqh       ← CTrade wrapper, validation, OrderSend
    VEM_State.mqh           ← last trade bar/time, position counts by magic
```

Adjust names to taste; **do not** add extra layers (factories, DI containers, etc.) in Phase 1.

---

## Execution workflow (what each module owns)

1. **Indicators** — Create handles in `OnInit`; copy buffers on the **signal bar** (e.g. closed bar index `1` if you decide “no intrabar signals” for v1 — align with `concept.md`).
2. **Signal** — Implements touch/pierce + RSI threshold + volume spike using **documented definitions** (penetration epsilon, spike vs MA).
3. **Risk** — Blocks trade if spread, equity, cooldown, max positions, or permissions fail.
4. **Execution** — Computes SL/TP prices from inputs; checks stops level / freeze; sends market order with magic and comment.
5. **State** — Updates cooldown anchor and prevents duplicate entries per your rules.

Exit handling for v1: evaluate SL/TP (platform) plus optional midline close or opposite-signal close **only if precedence is fixed in code** (document in `concept.md`).

---

## Weekly implementation plan

### Week 1 — Scaffolding (compiles, runs, no real trades)

**Deliverable:** `VEM.mq5` + stub headers; EA loads on chart and logs heartbeat.

- Create folder layout and empty/stub modules listed above.
- `OnInit`: validate symbol, log magic and inputs.
- `OnTick`: call stub `Signal_Update()`, `Risk_AllowTrade()`, `Execution_Process()` — stubs return false / no-op.
- **Compile once →** attach to chart; confirm Experts log shows init success.

**Stop here if anything fails compile** — fix skeleton before Week 2.

---

### Week 2 — Indicators + signal definitions (still no live orders)

**Deliverable:** Reliable reads of BB, RSI, volume; signal function returns long/short intent on the chosen bar model.

- Implement `VEM_Indicators.mqh`: handles for BB (built-in or `iBands`), RSI, volume SMA for spike.
- Encode **touch/pierce** and **volume spike** exactly as inputs (penetration, multiplier, MA period).
- Implement `VEM_Signal.mqh`: long/short booleans only — **no** `OrderSend` inside.

**Compile once →** Strategy Tester visual mode or chart: log indicator values and signal true/false per bar (debug flag).

---

### Week 3 — Risk gates + position sizing (still no orders, or dry-run only)

**Deliverable:** Single function “may we enter?” combining spread, max trades, cooldown, equity, direction permission; lot calculation.

- Implement `VEM_Risk.mqh`: spread vs max, cooldown bars since last entry attempt or fill (pick one rule and document it), count positions with this magic, fixed vs risk-% sizing.
- Optionally log intended lots and SL/TP distances without sending — keeps behavior visible before execution risk.

**Compile once →** tester with signals firing; log shows blocked vs “would trade” lines.

---

### Week 4 — Execution + validation

**Deliverable:** Market orders with SL/TP; broker constraint checks; magic and comment.

- Implement `VEM_Execution.mqh` using `CTrade` (or thin wrapper): normalize volumes, validate stops vs `SYMBOL_TRADE_STOPS_LEVEL`, respect filling mode where applicable.
- Wire **long path only first** if you prefer incremental verification; then mirror short in same week (still one compile before test).

**Compile once →** demo or tester with **minimum lot**, tight max-loss inputs; verify orders match logged plan.

---

### Week 5 — Exits + state + full symmetry

**Deliverable:** Optional BB midline exit and optional opposite-signal exit per precedence in `concept.md`; cooldown and “no duplicate long” rules enforced.

- Implement `VEM_State.mqh`: persist last entry bar index / time for cooldown; helpers for “already long/short.”
- Exit logic: if midline exit enabled, detect touch/cross of middle band on signal bar rules; if opposite signal exit enabled, close before opening opposite (define order).
- Enable short setup mirror of long.

**Compile once →** full tester passes over representative symbol; inspect deals for duplicate entries and exit reasons.

---

### Week 6 — Hardening + optimization-ready inputs (completion of Phase 1)

**Deliverable:** Production-ish defaults, structured inputs (safe vs structural per `concept.md`), reduced debug spam, failure logging.

- Group inputs in `VEM_Config.mqh`; defaults sensible for tester.
- Add concise error reasons when `OrderSend` fails (retcode).
- Run forward/backtest dry checklist: compilation on release folder, reload EA, one-symbol sanity.

**Compile once →** final acceptance test in Strategy Tester; document known limitations (tick volume vs real volume, etc.) in comments or `concept.md`, not new docs unless you need them.

---

## Definition of done (Phase 1)

- [ ] EA compiles from clean MetaEditor build with no warnings you care about.
- [ ] Single-chart deployment; magic identifies EA trades.
- [ ] Entry rules match v1 checklist in `concept.md`; exits match chosen precedence.
- [ ] Risk limits enforced before every send.
- [ ] No features implemented from the “out of scope” list above.

---

## When tempted to overengineer

Ask: **Does this reduce bugs or misorders in the next four weeks?** If no, backlog it.

---

*Aligned with `concept.md`. Update this roadmap only when Phase 1 scope formally changes.*
