# AI v0.1 — bad_trade + entry features

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\data\c1\VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` · n=396
**Rule:** [`data/c1/bad_trade_rule.json`](data/c1/bad_trade_rule.json)
**Model:** hgb · **features:** entry only (no path leakage at signal)
**Target:** `label_bad_trade` · rate **16.4%**

## Splits

| Split | n | bad_trade |
|-------|--:|----------:|
| Train | 122 | 21 |
| Val | 163 | 21 |
| Test OOS | 111 | 23 |

### Train (n=122)

- ROC-AUC: **1.000**
- Brier: **0.0341**
- bad_trade rate: **17.2%**

```
              precision    recall  f1-score   support

           0       0.97      1.00      0.99       101
           1       1.00      0.86      0.92        21

    accuracy                           0.98       122
   macro avg       0.99      0.93      0.95       122
weighted avg       0.98      0.98      0.97       122

```

### Validation (n=163)

- ROC-AUC: **0.529**
- Brier: **0.1302**
- bad_trade rate: **12.9%**

```
              precision    recall  f1-score   support

           0       0.87      0.97      0.92       142
           1       0.00      0.00      0.00        21

    accuracy                           0.85       163
   macro avg       0.43      0.49      0.46       163
weighted avg       0.76      0.85      0.80       163

```

### Test OOS (n=111)

- ROC-AUC: **0.525**
- Brier: **0.2057**
- bad_trade rate: **20.7%**

```
              precision    recall  f1-score   support

           0       0.78      0.88      0.82        88
           1       0.08      0.04      0.06        23

    accuracy                           0.70       111
   macro avg       0.43      0.46      0.44       111
weighted avg       0.63      0.70      0.66       111

```

## C5 — Top decile (test OOS)

- Exit mix: `{'midline': 10, 'sl': 1}`
- bad_trade rate: **9.1%**

## AI-3 — Skip (val-tuned)

- Val-tuned skip frac: **0%** (val net **$-6.11**)
- Holdout OOS: `2025-01-01` → `2026-05-15` · n=111

| Metric | After skip | Pass bar | OK |
|--------|----------:|---------:|:--:|
| Net $ | 9.08 | >= 9.08 | Y |
| PF | 1.30 | >= 1.30 | Y |
| WR % | 70.3 | >= 65 | Y |
| Trades | 111 | >= 100 | Y |

- Baseline OOS (no skip): **$9.08**, PF **1.30**
- Skipped n=0, net skipped **$0.00**

## C1–C7 checklist

- C3 val AUC >= 0.60: **0.529** -> FAIL
- C4 test AUC >= 0.55: **0.525** -> FAIL
- C5 decile: see above
- D5–D8 skip pass bar: **PASS**
- C7 export: no — park
