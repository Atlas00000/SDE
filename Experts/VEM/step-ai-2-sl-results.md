# AI-2 — Offline model v0

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_trades_EURUSD_M5.csv` (production-path, no `e10`)
**Target:** `label_sl`
**Model:** logistic regression + standard scaler

## Splits (time-based)

| Split | End | n | SL | loss |
|-------|-----|---:|---:|-----:|
| Train | — | 163 | 6 | 67 |
| Val | — | 20 | 2 | 5 |
| Test (holdout) | — | 91 | 6 | 28 |

### Train (n=163)

- ROC-AUC: **0.899**
- Brier: **0.1385**
- Positive rate: **3.7%**

```
              precision    recall  f1-score   support

           0       1.00      0.80      0.89       157
           1       0.16      1.00      0.28         6

    accuracy                           0.81       163
   macro avg       0.58      0.90      0.58       163
weighted avg       0.97      0.81      0.87       163

```

### Validation (n=20)

- ROC-AUC: **0.278**
- Brier: **0.2442**
- Positive rate: **10.0%**

```
              precision    recall  f1-score   support

           0       0.87      0.72      0.79        18
           1       0.00      0.00      0.00         2

    accuracy                           0.65        20
   macro avg       0.43      0.36      0.39        20
weighted avg       0.78      0.65      0.71        20

```

### Test / holdout (n=91)

- ROC-AUC: **0.651**
- Brier: **0.1601**
- Positive rate: **6.6%**

```
              precision    recall  f1-score   support

           0       0.96      0.80      0.87        85
           1       0.15      0.50      0.23         6

    accuracy                           0.78        91
   macro avg       0.55      0.65      0.55        91
weighted avg       0.90      0.78      0.83        91

```

## AI-3 — Skip simulation (holdout)

Pass bar (production OOS): net **≥ $9.08**, PF **≥ 1.30**

| Skip frac | Skipped | Kept n | Net kept | PF kept | WR kept | vs pass |
|----------:|--------:|-------:|---------:|--------:|--------:|---------|
| 10% | 9 | 82 | $8.96 | 1.51 | 69.5% | ✗ |
| 15% | 13 | 78 | $8.02 | 1.47 | 69.2% | ✗ |
| 20% | 18 | 73 | $6.36 | 1.37 | 67.1% | ✗ |

- Holdout baseline (no skip): **$7.40**, PF **1.31**, n=91

## Feature coefficients (standardized)

- `spread_pts`: -2.1246
- `rsi_depth`: -1.7339
- `entry_dow`: +1.6023
- `bb_width_ratio`: +0.7485
- `entry_hour`: +0.7260
- `side_sell`: +0.2231
- `vol_ratio`: +0.0991
- `rsi`: +0.0391

## Verdict (AI-2 / AI-3)

- **Val ROC-AUC** must be stable before **AI-4/AI-5** — weak val = do not wire.
- Holdout skip sim is **exploratory** on a **mixed CSV**; re-run on **clean** `vem5m_d7_c1_trade_log.set` export before promotion.
- **label_loss** v0: use for research / shadow design only unless val improves on clean data.
- **label_sl** v0: too few SL events; prefer loss-quality gate over raw SL classifier.

**Exported:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\models\ai_v0_logistic_label_sl.json`
