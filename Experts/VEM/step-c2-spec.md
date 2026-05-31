# C2 — Trade Logger v2 spec (P5 · Step 1)

**ID:** C2 · **Preset:** `VEM.C2_Production` · **Output file:** `Terminal/Common/Files/VEM_trades_v2_EURUSD_M5.csv`

---

## EA inputs

| Input | Value | Notes |
|-------|-------|-------|
| `inp_trade_log_enable` | `true` | Required |
| `inp_trade_log_schema` | `2` | `1` = legacy C1 file/columns |
| `inp_trade_log_snap_bar` | `6` | Snapshots at bars **4**, **5**, and **6** |

Stack: same as `VEM.C1_Production` (D1+D6+D7+E8c, E10 off, AI off).

---

## CSV schema (log_schema = 2)

| Column | Type | When | Notes |
|--------|------|------|-------|
| `log_schema` | int | close | Always `2` |
| `trade_id` | ulong | close | `DEAL_POSITION_ID` |
| `entry_time` / `exit_time` | datetime | close | |
| `symbol` / `timeframe` / `side` | str | close | |
| `entry_px` / `exit_px` / `profit` | | close | |
| `exit_type` | str | close | `midline`, `sl`, `e8c`, `e14`, … |
| `bars_held` | int | close | |
| `rsi` / `bb_width_ratio` / `vol_ratio` | | signal bar | |
| `spread_pts` / `entry_hour` / `entry_dow` | | signal bar | |
| `rsi_depth` | float | signal | D7-style depth |
| `bb_walk_count` | int | signal | consecutive closes outside band |
| `wick_pct` | float | signal | rejection wick % of range |
| `ema_slope_bp` | float | signal | M5 EMA slope (bp) |
| `atr_ratio` | float | signal | ATR / close |
| `bb_pen_pts` | float | signal | penetration beyond band (pts) |
| `htf_slope_bp` | float | signal | HTF EMA slope (logging handle; not D11 gate) |
| `mae_r` / `mfe_r` | float | close | Final excursion in R |
| `mae_r_b4` … `mfe_r_b6` | float | in-trade | Empty if trade closed before bar N |
| `sl_pts` | float | close | SL distance in points |

**No post-trade leakage** for entry labels: use only signal-time columns for entry models.

---

## Scripts

```powershell
# After Strategy Tester run (delete old v2 CSV first)
python scripts/c2_trade_log.py validate
python scripts/c2_trade_log.py archive --tag 20260529
python scripts/c2_trade_log.py report
python scripts/c2_trade_log.py labels
```

Archive → `data/c2/` + `data/c2/manifest.json`.

---

## Gate (C2 done)

- [x] Backtest + v2 CSV in `Terminal/Common/Files/`
- [x] Archive **408** trades (2023+) → `data/c2/VEM_trades_v2_EURUSD_M5_prod_20260529.csv`
- [x] Labeled → `data/c2/VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv`
- [x] [`step-c2-report.md`](step-c2-report.md) · `data/c2/manifest.json`

**Next:** **AI-6** XGB on `data/c2/VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv` (B7 done — [`step-b7-results.md`](step-b7-results.md)).

---

## Code

| Piece | Path |
|-------|------|
| Logger | `Include/VEM/VEM_TradeLog.mqh` |
| Config | `inp_trade_log_schema` in `VEM_Config.mqh` |
| CLI | `scripts/c2_trade_log.py` |
