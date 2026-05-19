# Step E13 — Experiment lock (MFE-gated bleed exit)

**Status:** **DISCARD** — see [`step-e13-results.md`](step-e13-results.md)  
**Date:** 2026-05-19  
**Control:** `VEM.Production` (E8c on, E10 off)  
**Test:** `VEM.E13_Production`

---

## Hypothesis

**Type C losers** (sideways bleed → SL) hold **longer** (median ~14 bars) with **low MFE** (~0.15R). After enough time, if MFE never proves reversion, scratch before full 1R SL — **without** E8b-style “red @ N bars” alone.

---

## Rule v1

Each bar, **after** midline and E8c passes:

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 12` | Start checking |
| `MFE <= 0.20R` (excursions vs entry SL distance) | Required |
| `POSITION_PROFIT < 0` | Required (default) |
| All true | **Close position** (`e13` in trade log) |

| Parameter | Value |
|-----------|--------|
| `inp_e13_bleed_exit_enable` | `true` |
| `inp_e13_bleed_min_bars` | **12** |
| `inp_e13_mfe_max_r` | **0.20** |
| `inp_e13_require_loss` | **true** |
| E8c / midline / entries | Same as production |
| E10 | **OFF** |

**Code:** `VEM_Execution_CheckBleedExits()` in `VEM_Execution.mqh`

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **OOS (pass bar)** | 2025-01-01 | 2026-05-15 |
| **IS** | 2024-01-01 | 2024-12-31 |
| **Full** | 2023-01-01 | 2026-05-15 |

**Pass vs control:** OOS net **≥ +$9.08**, PF **≥ 1.30**, WR **≥ 65%**, trades **≥ 100**; IS not materially worse than prod (+$3.06 / PF 1.04).

**Focus metrics:** ↓ avg loss $ / R · ↓ SL % · exit mix (`e13` count).

---

## Presets (ready before compile)

| Run | File | `inp_e13_bleed_exit_enable` |
|-----|------|------------------------------|
| **T-CTRL** | `MQL5/Profiles/Tester/VEM.Production` | **false** |
| **T-E13** | `MQL5/Profiles/Tester/VEM.E13_Production` | **true** |

Alias: `vem5m_e13_prod_bleed.set` (same as `VEM.E13_Production`).

**After Load:** confirm in Inputs → **Bleed exit (E13)** group — enable must match table. Also confirm **E10** and **AI skip/half** are **off** (presets set these explicitly).

---

## Tester protocol

1. Compile **VEM** in MetaEditor (required once for new E13 inputs).  
2. **T-CTRL:** `VEM.Production` — record OOS + full span (expect ~111 / +$9.08 OOS).  
3. **T-E13:** `VEM.E13_Production` — same symbol, dates, deposit, spread model.  
4. Optional: `inp_trade_log_enable=true` on both → C1 compare exit mix (delete CSV before run).  
5. Post results → KEEP / DISCARD in `filtersrecommedations.md`.

---

## Notes

- C1b: **51** production losers held **13+** bars — primary target cohort.  
- Do **not** combine with E10 in v1 (E10 failed on production stack).  
- If marginal, try `inp_e13_bleed_min_bars=10` or `inp_e13_require_loss=false` as **E13-v2** only after v1 result.
