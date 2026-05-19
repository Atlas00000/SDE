# VEM production runbook

**Default preset:** **`VEM.AI_Skip`** — production rules + ~**2%** AI entry veto (validated OOS).

**Rollback / rules-only baseline:** **`VEM.Production`** — no AI; use after failed experiments or to verify 396-trade reference.

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
| `VEM.C1_Production` | Same rules + C1 CSV for retrain |
| `VEM.E13_Production` / `VEM.E14_Production` | **Discard** — do not use |

---

## Rollback procedure

After any failed experiment:

1. Load **`VEM.AI_Skip`** (default) or **`VEM.Production`** (rules-only)
2. Verify AI inputs **off** in Inputs tab
3. Re-run short sanity backtest → **396** trades · **+$16.58** · PF **~1.17**

---

## Sign-off

Phase 3 frozen per [`step-p4-0-signoff.md`](step-p4-0-signoff.md). Phase 4 changes must beat production on **avg loss R** without breaking OOS pass bar.
