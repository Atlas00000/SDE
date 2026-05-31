# VEM — Volatility Expansion Mean-reversion

<p align="center">
  <strong>EURUSD M5 · rules-first EA · optional AI entry layer</strong>
</p>

---

## At a glance

| | |
|---|---|
| **Style** | Mean-reversion fades at BB extremes + volume spike |
| **Symbol / TF** | **EURUSD M5** (production) · pilot: other pair/TF via **`VEM.Pilot.*`** |
| **Default preset** | **`VEM.AI_Skip`** — production rules + ~**2%** AI entry veto |
| **Rollback preset** | **`VEM.Production`** — rules only, **no AI** |
| **Pilot preset** | **`VEM.Pilot.Production`** → [`MULTI_SYMBOL_PILOT.md`](MULTI_SYMBOL_PILOT.md) |
| **Lot size** | **0.01** fixed (scaling deferred to Phase 4+) |

### Validated metrics (Strategy Tester · 2023–2026)

| Mode | Trades | Net $ | PF | WR | Notes |
|------|-------:|------:|---:|---:|-------|
| **Production** | 396 | +16.58 | 1.17 | ~66% | OOS 2025+: **111 · +9.08 · PF 1.30** |
| **AI skip** | 389 | +20.30 | 1.21 | ~66% | OOS: **109 · +9.83 · PF 1.34** |

**Known weakness:** avg loss (~**0.7–0.9R**) > avg win (~**0.45R**) — midline caps winners; losers hit full SL. Phase 4 targets **avg loss**, not WR/PF.

---

## Production stack (locked)

```text
Signal: BB pierce + RSI extreme + volume spike
Habitat: D1 (hours 13–15 block) + D6 (max BB width) + D7 (RSI depth 25/75)
Exit:   BB midline TP + E8c worse-structure @ bar 4
Off:    E10, E8a/E8b, D8–D11, partial/BE paths (tested null or discard)
```

| Layer | ID | Role |
|-------|-----|------|
| Habitat | **D1** | Session block (server 13–15) |
| Habitat | **D6** | Max BB width ratio **0.00165** |
| Habitat | **D7** | RSI depth gate (long ≤25, short ≥75) |
| Exit | **E8c** | Worse BB penetration @ bar **4** |
| Exit | Midline | Primary take-profit |

---

## Presets (Strategy Tester)

Load via **Inputs → Load** (files under `MQL5/Profiles/Tester/`).

| Preset | AI | C1 log | Use |
|--------|:--:|:------:|-----|
| **`VEM.AI_Skip`** | Entry skip | Off | **Default** · tester + promoted stack |
| **`VEM.Production`** | Off | Off | Rollback · rules-only baseline |
| **`VEM.C1_Production`** | Off | On | Trade archive / retrain data |
| **`VEM.AI_Shadow`** | Log only | On | Scorer parity · no order change |
| **`VEM.AI_HalfLot`** | Skip + 0.5× lot | Off | P4-1 experiment — **park** offline ([`step-ai-v2-sizing-results.md`](step-ai-v2-sizing-results.md)) |
| **`VEM.E13_Production`** | E13 bleed exit | Off | **Discard** — [`step-e13-results.md`](step-e13-results.md) |
| **`VEM.E14_Production`** | E14 soft SL −0.5R | Off | **Discard** — [`step-e14-results.md`](step-e14-results.md) |

**Important:** After loading a preset, confirm **AI v0.1** inputs — `VEM.AI_Shadow` forces `inp_ai_skip_enable=false` (MT5 otherwise keeps the last value). Half-lot defaults **off** on `VEM.Production` / `VEM.AI_Skip`.

---

## AI layer (Phase 3 · v0.1) — done in tester

```text
[Rules signal] → [AI score @ entry] → [Skip if P(bad) high] → [Rules exits]
```

| Piece | Location |
|-------|----------|
| Model | `models/ai_v1_logistic_bad_trade.json` |
| Scorer | `Include/VEM/VEM_AI.mqh` |
| Shadow log | `Include/VEM/VEM_AIShadow.mqh` → `Common/Files/VEM_ai_shadow_*.csv` |
| Train | `scripts/train_ai_v1.py` |
| Validate | `scripts/validate_ai_shadow.py` |

- **Label:** SL, or e8c + MAE≥0.5R, or loss + MAE≥0.5R  
- **Skip:** ~**2%** of entries (7 full-span, 2 OOS)  
- **Not in production preset** — enable only via `VEM.AI_Skip` or inputs

Results: [`step-ai-v1-results.md`](step-ai-v1-results.md) · [`step-ai4-shadow-backtest.md`](step-ai4-shadow-backtest.md)

**Phase 4 (v0.3 exit):** `python scripts/export_ai_v3_bar_matrix.py` then `python scripts/train_ai_v3_exit.py` — see [`step-ai-v3-exit-results.md`](step-ai-v3-exit-results.md) (**park**, no EA wire).

---

## Phase 3 — signed off · Phase 4 — active

**P4-0 done:** [`step-p4-0-signoff.md`](step-p4-0-signoff.md) · [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md)

**Next:** **P4-1** (half-lot) — see **[`filtersrecommedations.md` §10](filtersrecommedations.md#10-phase-4--ai-expectancy--avg-loss)**.

| ID | Focus |
|----|--------|
| **P4-1** | 0.5× lot on medium P(bad) |
| **P4-2** | Tail-loss score at entry |
| **P4-3–P4-5** | Bar-4/6 **exit** model (MAE/MFE from C1) — main lever for avg loss |
| **P4-7** | Scaling / live promote — blocked until P4 pass |

---

## Repository layout

```text
Experts/VEM/
├── VEM.mq5                 # Expert entry
├── README.md               # This file
├── filtersrecommedations.md  # Master roadmap (Phases 2–4)
├── data/c1/                # Archives, manifest, labels
├── models/                 # Exported JSON weights
├── scripts/                # Train, validate, C1 tools
└── step-*.md               # Experiment write-ups

Include/VEM/
├── VEM_Config.mqh          # Inputs (incl. AI flags)
├── VEM_Signal.mqh / VEM_Risk.mqh / VEM_Execution.mqh
├── VEM_TradeLog.mqh        # C1 CSV
├── VEM_AI.mqh / VEM_AIShadow.mqh
└── VEM_AI_Model.inc.mqh    # Auto-generated coefficients

Profiles/Tester/
├── VEM.Production.set
├── VEM.C1_Production.set
├── VEM.AI_Shadow.set
└── VEM.AI_Skip.set
```

---

## Quick start (backtest)

1. Compile **`VEM.mq5`** in MetaEditor.  
2. Strategy Tester: **EURUSD M5** · deposit **200** · dates **2023.01.01 → 2026.05.15**.  
3. Load **`VEM.Production`**.  
4. Before a new C1/shadow run: **delete** `Terminal/Common/Files/VEM_trades_*.csv` and `VEM_ai_shadow_*.csv` (no append/dedupe surprises).

### Tester gate checklist

| ID | Preset | Pass |
|----|--------|:----:|
| T1 | `VEM.Production` | 396 · +$16.58 · PF 1.17 |
| T3 | `VEM.AI_Shadow` | Same trades + shadow log · `ai_skip=0` |
| T4 | `VEM.AI_Skip` | 389 · +$20.30 · OOS +$9.83 |

---

## Deployment policy

- **Tester first** — predetermined pass bars before live.  
- **Live default:** `VEM.Production` (rules only).  
- **Do not** enable `inp_ai_skip_enable` on live until explicitly promoted.

---

## Key documents

| Doc | Purpose |
|-----|---------|
| [`filtersrecommedations.md`](filtersrecommedations.md) | Full task IDs, phases, pass bars |
| [`trade-profile.md`](trade-profile.md) | Winner/loser buckets |
| [`step-phase3-dev-g.md`](step-phase3-dev-g.md) | Dev gate before AI |
| [`data/c1/manifest.json`](data/c1/manifest.json) | Train/val/test splits |

---

## Retrain AI v0.1

```bash
cd Experts/VEM
python scripts/train_ai_v1.py
python scripts/export_ai_model_mqh.py
# Recompile VEM.mq5
```

---

<p align="center">
  <sub>VEM · Production frozen · Phase 3 closed · Phase 4 open (P4-1 next)</sub>
</p>
