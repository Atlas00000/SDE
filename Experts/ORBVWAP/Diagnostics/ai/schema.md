# AI-0 dataset schema

**INF-0 contract (machine-readable):** `schemas/decisions.v1.json` · `schemas/outcomes.v1.json` · `schemas/dataset.v1.json`  
**Validator:** `Diagnostics/ai/schema.py` · `build_dataset.py --validate`

## Source files (Strategy Tester `MQL5/Files/`)
| File | One row per |
|------|-------------|
| `ORBVWAP_decisions.csv` | SignalEngine BUY/SELL candidate (pipeline attempt) |
| `ORBVWAP_outcomes.csv` | Closed position (deal exit) |

## `ORBVWAP_decisions.csv`

| Column | Type | Description |
|--------|------|-------------|
| `decision_id` | int | Monotonic export id |
| `bar_time_gmt` | datetime | Signal bar (GMT) |
| `direction` | BUY / SELL | |
| `session` | LONDON / NY | |
| `hour_gmt` | int | 0–23 |
| `weekday` | int | 0=Sun … 6=Sat |
| `ny_min_since_open` | int | Minutes since NY session open |
| `range_width` | float | Opening range width (price) |
| `range_width_atr` | float | range_width / ATR(14) |
| `atr` | float | ATR(14) at signal bar |
| `vol_ratio` | float | tick_vol / vol_MA |
| `vwap_dist_atr` | float | \|close − vwap\| / ATR |
| `spread_pct_range` | float | spread / range_width × 100 |
| `spread_points` | int | |
| `min_rr` | float | Setup R:R (0 if setup failed) |
| `entry`, `sl`, `tp` | float | Setup geometry |
| `can_trade_ok` | 0/1 | Risk `CanTrade` passed |
| `setup_ok` | 0/1 | `BuildSetup` passed |
| `prod_executed` | 0/1 | Market order placed |
| `reject_stage` | str | CAN_TRADE / SETUP / empty |
| `reject_code` | str | Rejection detail |
| `position_id` | ulong | Filled when `prod_executed=1` |

## `ORBVWAP_outcomes.csv`

| Column | Type | Description |
|--------|------|-------------|
| `position_id` | ulong | Join key to decisions |
| `close_time_gmt` | datetime | Exit deal time (GMT) |
| `profit` | float | Net P/L incl. swap/commission |
| `label_win` | 0/1 | 1 if profit > 0 |

## Built dataset (`ORBVWAP_ai_dataset_vN.parquet`)

Join: `decisions.position_id = outcomes.position_id` (left join).

Training rows for AI-1: `setup_ok == 1` and `label_win` not null (executed trades).

Candidate rows (incl. MinRR rejects): `setup_ok == 0` with `reject_stage == SETUP` — optional negatives if geometry exported.
