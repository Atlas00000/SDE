# Step E14 — Experiment lock (soft SL tighten)

**Status:** **DISCARD** — see [`step-e14-results.md`](step-e14-results.md)  
**Date:** 2026-05-19  
**Control:** `VEM.Production` (E8c on, E10/E13/E14 off)  
**Test:** `VEM.E14_Production`

---

## Hypothesis

After **bar 6**, trades with **low MFE** (&lt;0.15R) and **high MAE** (&gt;0.4R) are failing reversions. **Tighten SL to −0.5R** (not market scratch) to cut avg loss vs full **−1R** SL — without E13/E10-style force closes.

---

## Rule v1

Each bar, **after** E7 BE (off on prod), **before** midline:

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 6` | Start checking |
| `MFE <= 0.15R` **and** `MAE >= 0.40R` | Eligible |
| Current SL wider than **−0.5R** | `PositionModify` SL → **entry ∓ 0.5 × sl_dist** |

| Parameter | Value |
|-----------|--------|
| `inp_e14_soft_sl_enable` | `true` |
| `inp_e14_min_bars` | **6** |
| `inp_e14_mfe_max_r` | **0.15** |
| `inp_e14_mae_min_r` | **0.40** |
| `inp_e14_sl_loss_r` | **0.50** |
| E8c / midline / entries | Same as production |
| E10 / E13 | **OFF** |

**Code:** `VEM_Execution_ManageSoftSlTighten()` in `VEM_Execution.mqh`

---

## Presets (before compile)

| Run | File | `inp_e14_soft_sl_enable` |
|-----|------|---------------------------|
| **T-CTRL** | `VEM.Production` | **false** |
| **T-E14** | `VEM.E14_Production` | **true** |

Alias: `vem5m_e14_prod_soft_sl.set`

**After Load:** confirm **Soft SL tighten (E14)** — E13/E10/AI **off**.

---

## Pass bar

OOS net **≥ +$9.08**, PF **≥ 1.30**, WR **≥ 65%**, n **≥ 100**; **↓ avg loss** vs control; IS not worse than prod (+$3.06 / PF 1.04).

Same tester window as E13: full **2023–2026**, OOS **2025-01-01 → 2026-05-15**.

---

## Tester protocol

1. Compile **VEM** in MetaEditor.  
2. **T-CTRL:** `VEM.Production`.  
3. **T-E14:** `VEM.E14_Production` (same dates / symbol / model).  
4. Post report → [`step-e14-results.md`](step-e14-results.md) when run.

---

## Notes

- Exits at tightened SL count as **`sl`** in C1 (not a separate exit tag).  
- **E14-v2** only after v1: e.g. `sl_loss_r=0.4` or `mae_min=0.5`.
