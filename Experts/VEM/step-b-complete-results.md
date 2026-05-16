# Step B — Complete results (EURUSD M5)

Generated: 2026-05-16 14:28

- Trades total: **1429**
- Analyzed: **818** | Skipped (no bar): **611**
- Bar source: `c:\Users\emili\OneDrive\Documents\EURUSD_M5_202501092220_202605152055.csv`
- Bar range: 2025-01-09 22:20:00+00:00 to 2026-05-15 20:55:00+00:00

> **Note:** **611** trades are before the CSV/bar range (likely **2024.01–2025.01.09**). Export a second M5 CSV from **2024.01.01** or use History Center Download.

## B9 — BB walk

| Group | N | ≥2 walk |
|-------|---|---------|
| Losers | 329 | 85 (25.8%) |
| Winners | 484 | 119 (24.6%) |
| Worst 40 | 40 | 11 |

## B10 — Wick % (median)

| Group | Median wick % |
|-------|----------------|
| Losers | 16.2 |
| Winners | 16.7 |

## B1 — Trend vs range (EMA slope proxy)

Buckets: `range` | `mild_trend` | `with` (with drift) | `against`

### All analyzed — P/L by trend bucket

| Trend | N | Net P/L | Win % |
|-------|---|---------|-------|
| range | 427 | -20.77 | 61.4% |
| against | 173 | -5.36 | 53.8% |
| mild_trend | 218 | 4.34 | 59.2% |

### Losers only

| Trend | N | Net P/L |
|-------|---|---------|
| range | 160 | -157.97 |
| against | 80 | -138.45 |
| mild_trend | 89 | -106.13 |

## B3 — ATR regime (terciles)

| Bucket | N | Net P/L | Win % |
|--------|---|---------|-------|
| mid | 251 | -8.30 | 61.8% |
| high | 307 | -7.61 | 54.4% |
| low | 260 | -5.88 | 62.3% |

## B4 — BB width (terciles)

| Bucket | N | Net P/L | Win % |
|--------|---|---------|-------|
| mid | 282 | -13.84 | 62.1% |
| wide | 431 | -11.92 | 55.7% |
| narrow | 105 | 3.97 | 65.7% |

## B5 — RSI depth at signal

| Bucket | N | Net P/L | Win % |
|--------|---|---------|-------|
| 70- | 72 | -16.46 | 50.0% |
| 75-80 | 96 | -12.95 | 56.2% |
| 25-30 | 86 | -10.05 | 62.8% |
| deep_>80 | 177 | -3.68 | 59.9% |
| 70-75 | 94 | -1.77 | 57.4% |
| 20-25 | 101 | 7.38 | 59.4% |
| 30+ | 44 | 7.79 | 68.2% |
| deep_<20 | 148 | 7.95 | 60.8% |

## B8 — Trade quality profiles (rule-based on signal bar)

Automated proxy for good/bad tables in `edge-discovery.md`.

| Profile flag | Losers % | Winners % | Worst40 % |
|--------------|----------|-----------|-----------|
| good_long | 0.0 | 0.0 | 0.0 |
| bad_long | 55.6 | 55.1 | 58.8 |
| good_short | 0.0 | 0.0 | 0.0 |
| bad_short | 47.6 | 49.2 | 52.2 |

**Interpretation:** `bad_*` should be **higher on losers** than winners; `good_*` **higher on winners**. Large gap = useful filter idea.

### Worst 10 losers — profile snapshot

| Entry | Side | P/L | walk | wick% | RSI | trend | bad |
|-------|------|-----|------|-------|-----|-------|-----|
| 2026-01-23 20:00 | sell | -5.31 | 1 | 32 | 76 | range | False |
| 2026-04-17 18:55 | buy | -4.12 | 1 | 16 | 33 | mild_trend | False |
| 2025-01-13 21:45 | sell | -2.48 | 0 | 22 | 80 | mild_trend | False |
| 2025-08-01 20:40 | sell | -2.26 | 1 | 9 | 71 | against | True |
| 2026-03-24 07:05 | sell | -2.06 | 2 | 18 | 67 | range | True |
| 2025-01-30 13:55 | sell | -2.05 | 1 | 70 | 79 | against | True |
| 2025-04-02 21:15 | sell | -2.05 | 0 | 19 | 78 | range | False |
| 2025-07-28 07:20 | buy | -2.04 | 0 | 0 | 21 | mild_trend | False |
| 2026-01-27 14:35 | sell | -2.04 | 0 | 0 | 66 | mild_trend | False |
| 2025-07-10 15:05 | buy | -2.03 | 0 | 59 | 34 | mild_trend | False |

## B7 — Step D priorities (updated)

1. **Session filter (B6)** — hour 13 / NY 13–21 (strongest).
2. **BB width** — avoid `wide` band entries (B4: wide −$11.92 vs narrow +$3.97).
3. **RSI** — shorts: avoid shallow `70-` / `75-80`; longs: `deep_<20` / `20-25` best (B5).
4. **Trend** — `range` entries still net negative; combine with session, not alone.
5. **BB walk / wick** — weak (B9/B10); optional trial only.

## Full sample (1429 trades)

- **818/1429** analyzed.
- For **1429/1429**: add M5 bars from **2024.01.01** (History Center download or second CSV export).

- Re-run: `python scripts/step_b_complete_analyze.py --csv "c:\Users\emili\OneDrive\Documents\EURUSD_M5_202501092220_202605152055.csv"`
