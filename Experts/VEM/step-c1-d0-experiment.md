# Step C1 — Trade log (CSV) for E10 tuning

**Status:** Code ready — run backtest → analyze CSV  
**Date:** 2026-05-18  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (unchanged logic)  
**Test set:** `vem5m_d7_c1_trade_log.set` (D7 + `inp_trade_log_enable=true`)

---

## Output file

After backtest with logging on:

`C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_trades_EURUSD_M5.csv`

(Open via MT5: **File → Open Data Folder → MQL5 → Files** — same path when `FILE_COMMON` is used.)

---

## Recommended backtest windows

Run **both** (same as locked cell):

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

$200 · 0.01 lots · EURUSD M5 · every tick.

**Before each run:** delete or rename old `VEM_trades_EURUSD_M5.csv` so rows are not appended across runs.

---

## Analyze

```powershell
python "MQL5\Experts\VEM\scripts\analyze_vem_trade_log.py"
```

Writes `step-c1-results.md` with winner/loser medians and an **E10 threshold grid** (MFE/MAE @ bar 6).

---

## CSV columns

| Column | Meaning |
|--------|---------|
| `mae_r` / `mfe_r` | Final excursion in R at close |
| `mae_r_b5` / `mfe_r_b5` | Snapshot at **5** bars in trade |
| `mae_r_b6` / `mfe_r_b6` | Snapshot at **6** bars (E10 default) |
| `exit_type` | midline / sl / tp / fail_exit |
| `rsi`, `bb_width_ratio`, `vol_ratio` | Entry signal bar |

---

## Next step after C1

Pick E10 thresholds from grid → implement `vem5m_e10_d7_invalidation.set` → IS/OOS vs D7 (WR ≥ ~65%, PF ≥ 1.17 OOS).

---

## C1 results

| Window | Trades | Notes |
|--------|--------|--------|
| IS | *fill* | |
| OOS | *fill* | |

See `step-c1-results.md` after `analyze_vem_trade_log.py`.
