# AI-PASS A1–A5 inventory

**Source:** `data\c1\VEM_trades_EURUSD_M5_prod_2023_2026_396.csv`
**Rows (production-path):** 396
**Net $ (all):** 16.58
**e10 present:** no — OK

## Splits (from `data/c1/manifest.json`)

- train <= `2023-12-31` -> **122** trades
- val through `2024-12-31` -> **163** trades
- test after val_end -> **111** trades
- OOS pass window `2025-01-01` -> `2026-05-15` -> **111** tr / $9.08

## A1-A5 status

- **A1** clean CSV: PASS
- **A2** size 400-600: **DONE** (396 / 400)
- **A3** archive: `data/c1/VEM_trades_EURUSD_M5_prod_2023_2026_396.csv`
- **A4** splits: `data/c1/manifest.json`
- **A5** val >= 50: PASS (163 trades)
