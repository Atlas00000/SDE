# Step C1 — Trade log analysis

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_trades_EURUSD_M5.csv`
**Trades:** 111

### Winners (n=78)

| Metric | Median | 75th % |
|--------|--------|--------|
| MAE (R) final | 0.175 | 0.295 |
| MFE (R) final | 0.305 | 0.443 |
| MAE @ bar 5 | 0.155 | 0.290 |
| MFE @ bar 5 | 0.205 | 0.280 |
| MAE @ bar 6 | 0.160 | 0.295 |
| MFE @ bar 6 | 0.220 | 0.300 |

- Net P/L sum: **$39.17**
- Win rate: **100.0%**
- Exit mix: `{'midline': 77, 'tp': 1}`

### Losers (n=33)

| Metric | Median | 75th % |
|--------|--------|--------|
| MAE (R) final | 0.645 | 0.805 |
| MFE (R) final | 0.085 | 0.175 |
| MAE @ bar 5 | 0.300 | 0.470 |
| MFE @ bar 5 | 0.085 | 0.198 |
| MAE @ bar 6 | 0.310 | 0.510 |
| MFE @ bar 6 | 0.085 | 0.198 |

- Net P/L sum: **$-30.09**
- Win rate: **0.0%**
- Exit mix: `{'midline': 22, 'sl': 8, 'e8c': 3}`

## E10 rule sweep (in-sample on this CSV)

| MFE max | MAE min | Would cut | Cut WR | Cut avg $ | Kept WR | Kept n |
|--------|---------|-----------|--------|-----------|---------|--------|
| 0.15 | 0.45 | 9 | 11% | -0.81 | 75% | 75 |
| 0.15 | 0.50 | 7 | 14% | -0.91 | 73% | 77 |
| 0.15 | 0.55 | 6 | 17% | -1.06 | 72% | 78 |
| 0.20 | 0.45 | 10 | 10% | -0.93 | 76% | 74 |
| 0.20 | 0.50 | 8 | 12% | -1.04 | 74% | 76 |
| 0.20 | 0.55 | 6 | 17% | -1.06 | 72% | 78 |
| 0.25 | 0.45 | 11 | 18% | -0.84 | 75% | 73 |
| 0.25 | 0.50 | 8 | 12% | -1.04 | 74% | 76 |
| 0.25 | 0.55 | 6 | 17% | -1.06 | 72% | 78 |

_Goal: high cut count among losers, cut WR low, kept WR ≥ ~65%._
