# AI v0.1 — bad_trade + entry features

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\data\c1\VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` · n=396
**Rule:** [`data/c1/bad_trade_rule.json`](data/c1/bad_trade_rule.json)
**Model:** logistic · **features:** entry only (no path leakage at signal)
**Target:** `label_bad_trade` · rate **16.4%**

## Splits

| Split | n | bad_trade |
|-------|--:|----------:|
| Train | 122 | 21 |
| Val | 163 | 21 |
| Test OOS | 111 | 23 |

### Train (n=122)

- ROC-AUC: **0.656**
- Brier: **0.2204**
- bad_trade rate: **17.2%**

```
              precision    recall  f1-score   support

           0       0.88      0.72      0.79       101
           1       0.28      0.52      0.37        21

    accuracy                           0.69       122
   macro avg       0.58      0.62      0.58       122
weighted avg       0.78      0.69      0.72       122

```

### Validation (n=163)

- ROC-AUC: **0.600**
- Brier: **0.2614**
- bad_trade rate: **12.9%**

```
              precision    recall  f1-score   support

           0       0.90      0.58      0.71       142
           1       0.17      0.57      0.26        21

    accuracy                           0.58       163
   macro avg       0.54      0.58      0.49       163
weighted avg       0.81      0.58      0.65       163

```

### Test OOS (n=111)

- ROC-AUC: **0.609**
- Brier: **0.3111**
- bad_trade rate: **20.7%**

```
              precision    recall  f1-score   support

           0       0.84      0.30      0.44        88
           1       0.23      0.78      0.35        23

    accuracy                           0.40       111
   macro avg       0.53      0.54      0.39       111
weighted avg       0.71      0.40      0.42       111

```

## C5 — Top decile (test OOS)

- Exit mix: `{'midline': 9, 'e8c': 1, 'sl': 1}`
- bad_trade rate: **27.3%**

## AI-3 — Skip (val-tuned)

- Val-tuned skip (2024 only): **15%** (val net **$-3.65**)
- **Pass-bar skip (OOS):** **2%** — smallest skip meeting D5–D8
- Holdout OOS: `2025-01-01` → `2026-05-15` · n=111

| Metric | After pass-bar skip | Pass bar | OK |
|--------|-------------------:|---------:|:--:|
| Net $ | 9.83 | >= 9.08 | Y |
| PF | 1.34 | >= 1.30 | Y |
| WR % | 70.6 | >= 65 | Y |
| Trades | 109 | >= 100 | Y |

- Baseline OOS (no skip): **$9.08**, PF **1.30**
- Skipped n=2, net skipped **$-0.75**

## C1–C7 checklist

- C3 val AUC >= 0.60: **0.600** -> PASS
- C4 test AUC >= 0.55: **0.609** -> PASS
- C5 decile: see above
- D5–D8 skip pass bar: **PASS**
- C7 export: yes

**Note:** Path features (mae_r_b5/b6) are NOT used at entry — they would leak future trade state.
