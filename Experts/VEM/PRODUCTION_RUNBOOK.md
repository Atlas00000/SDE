# VEM production runbook

## Operate

| Role | Preset | When |
|------|--------|------|
| **Default** | **`VEM.AI_Skip`** | Live, forward test, normal backtest |
| **Rollback** | **`VEM.Production`** | After any failed experiment; rules-only sanity check |

**`VEM.AI_Skip`:** D1+D6+D7+midline+E8c · ~**2%** AI entry veto · OOS **+$9.83 / PF 1.34 / 109 tr**  
**`VEM.Production`:** same rules · **no AI** · OOS **+$9.08 / PF 1.30 / 111 tr**

Do **not** use `VEM.AI_Tail_Skip`, E13/E14, or 5% `inp_risk_pct` as operating configs (experimental / not validated).

**Second chart (pilot):** [`MULTI_SYMBOL_PILOT.md`](MULTI_SYMBOL_PILOT.md) · presets **`VEM.Pilot.Production`** / **`VEM.Pilot.AI_Skip`** · magic **2600520**.

---

## What production is

| On | Off |
|----|-----|
| D1 session block (13–15) | AI shadow / skip / exit |
| D6 BB width ≤ 0.00165 | E10 invalidation |
| D7 RSI depth 25 / 75 | E8a / E8b |
| Midline TP | Extra entry filters (D8–D11) |
| E8c @ bar 4 | |

**Inputs (AI section):** both **false** — preset file sets this explicitly.

---

## Reference metrics (EURUSD M5 · 0.01 · 2023–2026)

| Window | Trades | Net $ | PF |
|--------|-------:|------:|---:|
| Full | 396 | +16.58 | 1.17 |
| OOS 2025+ | 111 | +9.08 | 1.30 |

**AI skip (`VEM.AI_Skip`):**

| Full | 389 | +20.30 | 1.21 |
| OOS 2025+ | 109 | +9.83 | 1.34 |

If your backtest differs, check: wrong preset · AI left on from prior load · CSV append · date range.

**Exit R&D (E10/E13/E14):** **closed** — all **DISCARD**; do not enable on default preset.

---

## Tester workflow

1. Delete `Terminal/Common/Files/VEM_trades_*.csv` if using C1 log.
2. Compile `VEM.mq5`.
3. **Inputs → Load → `VEM.AI_Skip`** (default) or **`VEM.Production`** (rollback)
4. Confirm: **AI skip** = true (AI_Skip) or **false** (Production) · shadow = false · E13/E14 = false
5. Run · compare to reference table.

---

## Other presets

| Preset | Use |
|--------|-----|
| `VEM.Production` | Rules only — rollback · 396 trades |
| `VEM.AI_Shadow` | Log scores only — parity check |
| `VEM.AI_Tail_Shadow` | P4-2: bad + tail scores, no live skip — delete old shadow CSV first |
| `VEM.AI_Tail_Skip` | P4-2 trial: `AI_Skip` + tail skip — **not default** until tester OOS passes |
| `VEM.C1_Production` | Same rules + C1 CSV for retrain |
| `VEM.E13_Production` / `VEM.E14_Production` | **Discard** — do not use |
| `VEM.Pilot.Production` | New symbol/TF — rules only · C2 log on |
| `VEM.Pilot.AI_Skip` | Pilot + EURUSD AI skip (after rules pass) |

---

## Rollback procedure

After any failed experiment:

1. **Inputs → Load → `VEM.AI_Skip`** (return to default) — or **`VEM.Production`** if you need rules-only baseline
2. Confirm: **`inp_ai_skip_enable`** = true (`AI_Skip`) or false (`Production`) · tail/shadow/half-lot = false · E13/E14 = false
3. Sanity backtest (EURUSD M5, 2023–2026, 0.01 lots):
   - **`VEM.AI_Skip`:** ~**389** tr · **+$20.30** · PF **~1.21**
   - **`VEM.Production`:** ~**396** tr · **+$16.58** · PF **~1.17**

---

## Sign-off

Phase 3 frozen per [`step-p4-0-signoff.md`](step-p4-0-signoff.md). Phase 4 changes must beat production on **avg loss R** without breaking OOS pass bar.
