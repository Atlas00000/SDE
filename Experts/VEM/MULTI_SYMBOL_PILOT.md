# Multi-symbol pilot (second profile)

**Production (unchanged):** EURUSD M5 · **`VEM.AI_Skip`** · magic **2600511** · comment **`VEM`**

**Pilot (new chart):** any symbol/TF you choose · **`VEM.Pilot.*`** · magic **2600520** · comment **`VEM-PILOT`**

Same edge hypothesis (BB fade + vol spike + D1/D6/D7 + midline + E8c). Goal: test whether **habitat is universal** before promoting a second live line.

---

## Presets

| Preset | AI | Trade log | Use |
|--------|----|-----------|-----|
| **`VEM.Pilot.Production`** | Off | C2 **on** (tester) | **Start here** — rules-only on new symbol |
| **`VEM.Pilot.AI_Skip`** | On (EURUSD model) | Off (demo) | After rules pass bar; optional transfer skip |

Production presets **`VEM.AI_Skip`** / **`VEM.Production`** stay on the **EURUSD** chart only.

---

## Setup (demo or second tester)

1. **New chart** — e.g. **GBPUSD M5** (or USDJPY M5, EURUSD M15).
2. Attach **VEM** · **Inputs → Load → `VEM.Pilot.Production`**.
3. Confirm:
   - `inp_magic` = **2600520**
   - `inp_trade_comment` = **VEM-PILOT**
   - `inp_ai_skip_enable` = **false** (first phase)
4. Enable Algo trading.

**Same account, two charts:** OK — magic differs per chart; position cap is **per symbol + magic**.

---

## Suggested pilot queue

| Priority | Symbol | TF | Notes |
|----------|--------|-----|--------|
| 1 | **GBPUSD** | M5 | Closest to EUR behavior |
| 2 | **USDJPY** | M5 | JPY pip scale — watch D6 width |
| 3 | **EURUSD** | M15 | Same pair, slower bar |
| 4 | XAUUSD / NAS100 | — | Higher spread — tune gates first |

---

## Per-symbol tweaks (only if backtest fails habitat)

| Input | EURUSD prod | Pilot starting point |
|-------|-------------|----------------------|
| `inp_max_spread_pts` | 50 | GBPUSD **60** · USDJPY **40** · XAU **80+** |
| `inp_bb_max_width_ratio` | 0.00165 | Same first; retune if too few/many trades |
| D1 hours 13–15 block | On | Same server-time test first |

Do **not** change BB/RSI periods until rules-only run completes.

---

## Tester workflow (pilot)

1. Symbol = pilot pair · TF = pilot TF · 2023–2026 · 0.01 lots.
2. **`VEM.Pilot.Production`** → record trades, net, PF, WR, DD.
3. **Pass bar (rules-only):** same shape as EURUSD — PF **≥ 1.15**, WR **≥ 60%**, DD **≤ ~10%**, **≥ 200** trades (scale with years).
4. Optional: enable C2 log → archive `data/pilot/<SYMBOL>_<TF>_*.csv`.
5. **`VEM.Pilot.AI_Skip`** — compare vs pilot Production; AI model is **EURUSD-trained** until you retrain on pilot CSV.
6. **Promote pilot to “second production”** only if OOS on **that** symbol beats its own Production baseline (not EURUSD numbers).

---

## Demo feedback checklist

Log weekly:

- Trades / week vs EURUSD chart
- Spread blocks (`Skip: spread` in journal if verbose)
- Session block still sensible (server hour)
- Any repeated SL clusters (symbol-specific news?)

---

## Data paths

| Item | Path |
|------|------|
| C2 pilot CSV | `Terminal/Common/Files/VEM_trades_v2_<SYMBOL>_<TF>.csv` |
| Future pilot manifest | `data/pilot/manifest.json` (create after first archive) |

---

## What not to do

- Do not use **`VEM.AI_Tail_Skip`** on pilot (parked).
- Do not copy EURUSD **OOS $9.83** as the pilot target — use **relative** lift vs pilot rules-only.
- Do not share magic **2600511** on two charts (production collision risk on same symbol).

---

*Pilot does not change EURUSD production. See [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md).*
