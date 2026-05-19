# AI-2 — Offline model v0

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_trades_EURUSD_M5.csv` (production-path, no `e10`)
**Target:** `label_loss`
**Model:** logistic regression + standard scaler

## Splits (time-based)

| Split | End | n | SL | loss |
|-------|-----|---:|---:|-----:|
| Train | — | 163 | 6 | 67 |
| Val | — | 20 | 2 | 5 |
| Test (holdout) | — | 91 | 6 | 28 |

### Train (n=163)

- ROC-AUC: **0.583**
- Brier: **0.2390**
- Positive rate: **41.1%**

```
              precision    recall  f1-score   support

           0       0.61      0.61      0.61        96
           1       0.44      0.43      0.44        67

    accuracy                           0.54       163
   macro avg       0.52      0.52      0.52       163
weighted avg       0.54      0.54      0.54       163

```

### Validation (n=20)

- ROC-AUC: **0.440**
- Brier: **0.3455**
- Positive rate: **25.0%**

```
              precision    recall  f1-score   support

           0       1.00      0.07      0.12        15
           1       0.26      1.00      0.42         5

    accuracy                           0.30        20
   macro avg       0.63      0.53      0.27        20
weighted avg       0.82      0.30      0.20        20

```

### Test / holdout (n=91)

- ROC-AUC: **0.552**
- Brier: **0.2659**
- Positive rate: **30.8%**

```
              precision    recall  f1-score   support

           0       0.70      0.37      0.48        63
           1       0.31      0.64      0.42        28

    accuracy                           0.45        91
   macro avg       0.50      0.50      0.45        91
weighted avg       0.58      0.45      0.46        91

```

## AI-3 — Skip simulation (holdout)

Pass bar (production OOS): net **≥ $9.08**, PF **≥ 1.30**

| Skip frac | Skipped | Kept n | Net kept | PF kept | WR kept | vs pass |
|----------:|--------:|-------:|---------:|--------:|--------:|---------|
| 10% | 9 | 82 | $8.41 | 1.44 | 69.5% | ✗ |
| 15% | 13 | 78 | $8.33 | 1.45 | 69.2% | ✗ |
| 20% | 18 | 73 | $8.56 | 1.50 | 71.2% | ✗ |

- Holdout baseline (no skip): **$7.40**, PF **1.31**, n=91

## Feature coefficients (standardized)

- `spread_pts`: +0.4621
- `entry_dow`: +0.2029
- `entry_hour`: +0.1518
- `side_sell`: +0.1256
- `vol_ratio`: -0.0573
- `rsi`: -0.0523
- `bb_width_ratio`: +0.0436
- `rsi_depth`: -0.0037

## Verdict (AI-2 / AI-3)

- **Val ROC-AUC** must be stable before **AI-4/AI-5** — weak val = do not wire.
- Holdout skip sim is **exploratory** on a **mixed CSV**; re-run on **clean** `vem5m_d7_c1_trade_log.set` export before promotion.
- **label_loss** v0: use for research / shadow design only unless val improves on clean data.
- **label_sl** v0: too few SL events; prefer loss-quality gate over raw SL classifier.

**Exported:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\models\ai_v0_logistic_label_loss.json`
