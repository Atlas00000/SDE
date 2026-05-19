# AI v0.2 — tiered sizing (P4-1)

**Archive:** `VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` · skip **2%** fixed

## Thresholds (val-tuned half band)

| Param | Value |
|-------|------:|
| `skip_prob_threshold` | **0.874305** |
| `half_lot_prob_min` | **0.501002** (val pct **57**) |

## Val

- Net sim: **$-1.24** · n=159 · half=66 · skipped=4

## Test OOS

| Policy | n | Net $ | PF | WR % | half | skip |
|--------|--:|------:|---:|-----:|-----:|-----:|
| Production (1x) | 111 | 9.08 | 1.30 | 70.3 | 0 | 0 |
| Skip only (v0.1) | 109 | 9.83 | 1.34 | 70.6 | 0 | 2 |
| Skip + half (v0.2) | 109 | 7.81 | 1.46 | 70.6 | 78 | 2 |

- OOS pass bar: **FAIL** (net>=9.08, PF>=1.3)

Export: `ai_v2_sizing.json`
