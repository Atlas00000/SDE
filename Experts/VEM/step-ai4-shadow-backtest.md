# AI-4 — Shadow backtest validation

**Policy:** Strategy Tester only until production + AI gates pass in backtest. No live/demo debugging.

- Shadow: `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_ai_shadow_EURUSD_M5.csv` · rows **4223** · **opened=396**
- C1 archive: `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\data\c1\VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` · n=**396**
- Shadow↔C1 merge_asof misses: **1** (signal vs entry bar; P/L from C1 direct)

## E2 — MT5 vs Python scorer (opened trades)

- Threshold: **0.874305** (skip top ~2% offline)
- Max |py_score − ai_score|: **0.000132**
- Mean |delta|: **0.000042**
- MT5 would_skip on opened: **7**
- Python would_skip on opened: **7**
- Agreement: **100.0%**
- C1 archive would_skip (E4 source): **7** · OOS **2**

## E4 — Hypothetical skip on realized P/L (shadow only; orders unchanged in tester)

### Full span (opened, n=396)

| Metric | Baseline | If skip would_skip=1 |
|--------|--------:|---------------------:|
| Net $ | 16.58 | 20.30 |
| PF | 1.17 | 1.21 |
| Trades | 396 | 389 |

- Skipped trades net: **$-3.72** (7 tr)

### OOS pass window (`2025-01-01` -> `2026-05-15`)

| Metric | Baseline | After shadow skip | Pass bar |
|--------|--------:|------------------:|---------|
| Net $ | 9.08 | 9.83 | >= 9.08 |
| PF | 1.30 | 1.34 | >= 1.30 |
| Trades | 111 | 109 | >= 100 |
| Skipped | — | 2 | — |

- OOS skipped P/L: **$-0.75**

- OOS skip pass bar (D5–D8): **PASS**

## Gate (backtest-only deployment)

- [x] **E3** — Tester run `VEM.AI_Shadow` · shadow CSV + **396** opened = C1
- [x] **E2** — MT5 scorer matches Python (max delta < 0.001)
- [x] **E4** — Skip sim on C1 archive (same as AI-3 offline)
- [ ] **Production backtest gate** — rules-only `VEM.Production` stable on OOS pass bar
- [ ] **AI-5** — Wire entry skip in tester only after E4 + production gate pass
- [ ] **AI-0 live** — **After** all tester gates; never parallel debugging on charts
