# Step C1 — Trade log analysis

**Source:** `Terminal\Common\Files\VEM_trades_EURUSD_M5.csv`  
**Analyzed:** 2026-05-18  
**Trades logged:** **373** (2024.01.04 → 2026.04.29)

**Sanity vs D7:** Full IS = **270** tr · OOS = **119** tr. **373** rows ≈ **D6 OOS trade count** or a **longer/custom window** — confirm tester dates + `vem5m_d7_c1_trade_log.set`. Data quality for E10 tuning is still valid.

| Check | Value |
|-------|--------|
| Net P/L (CSV sum) | **+$10.86** |
| Win rate | **66.5%** (248 W / 125 L) |
| Exit mix | midline **342** · sl **29** · tp **2** |
| Logging | **OK** — MAE/MFE + bar 5/6 populated |

---

## Winners vs losers (medians)

| Metric | Winners (n=248) | Losers (n=125) |
|--------|-----------------|----------------|
| **MAE final (R)** | **0.15** | **0.56** |
| **MFE final (R)** | **0.26** | **0.08** |
| **MAE @ bar 6** | **0.16** | **0.31** |
| **MFE @ bar 6** | **0.18** | **0.08** |

**Matches Step E / full-run story:** winners stay shallow; losers show **low MFE + higher MAE** by close, with separation already visible **@ bar 6**.

---

## E10 rule preview (at bar 6: `MFE ≤ X` **and** `MAE ≥ Y`)

| Rule | Would cut | Cut WR | Kept n | Kept WR |
|------|-----------|--------|--------|---------|
| MFE ≤ 0.20 & MAE ≥ 0.50 | 34 | 15% | 339 | **72%** |
| MFE ≤ 0.15 & MAE ≥ 0.45 | ~55 | ~15% | ~318 | **~70%** |
| MFE ≤ 0.20 & MAE ≥ 0.45 | ~48 | ~15% | ~325 | **~71%** |

**Interpretation:** E10 **can** work on this CSV — cuts are mostly losers, kept WR stays **~70%+**. Trade count cut is **small** (34–55 of 373) with strict thresholds; may need slightly looser bar-6 gate or bar **5** combo in E10 v1.

**Do not use** time-in-loss or MFE-only (E8b/E8a lesson).

---

## Recommended E10 v1 (for coding)

| Parameter | Value |
|-----------|--------|
| `inp_inv_exit_bars` | **6** |
| `inp_inv_mfe_max_r` | **0.20** |
| `inp_inv_mae_min_r` | **0.50** |
| Hard SL | **unchanged** 200 pts |

Re-validate on **D7 IS (270)** + **OOS (119)** after E10 code — pass bar: OOS WR **≥ 65%**, PF **≥ 1.17**, net **≥ +$6**.

---

## Optional: cleaner CSV

Delete CSV → run **only** `2024.01.01–2026.05.15` (IS) or `2025.01.01–2026.05.15` (OOS) once each for exact D7 trade counts.
