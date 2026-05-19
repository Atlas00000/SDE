# AI v0.3 — bar-6 exit model (P4-3/P4-4)

**Matrix:** `ai_v3_bar_matrix.csv` (290 rows, bar-6 path) · **usd/R:** 2.395

## Model (train on b6 cohort)

- Val ROC-AUC: **0.713** · Test b6 AUC: **0.883**
- `exit_prob_threshold`: **1.000000** (val pct **100**)

### Train classification (0.5)

```
precision    recall  f1-score   support

           0       0.95      0.81      0.87        77
           1       0.50      0.83      0.62        18

    accuracy                           0.81        95
   macro avg       0.73      0.82      0.75        95
weighted avg       0.87      0.81      0.83        95
```

## Val (b6 subset only)

- Baseline net: **$-16.01** · tuned early-exit net: **$-16.01**

## Test OOS — full **111** trade window

| Policy | n | Net $ | PF | WR % | early@b6 | avg loss $ |
|--------|--:|------:|---:|-----:|---------:|-----------:|
| Production (hold) | 111 | 9.08 | 1.30 | 70.3 | 0 | -0.91 |
| AI exit @ bar 6 | 111 | 9.08 | 1.30 | 70.3 | 0 | -0.91 |

- OOS pass bar @ tuned thr: **PASS** (net≥9.08, PF≥1.3, WR≥65%, n≥100)
- Improved vs hold on exited trades: **0** / 0
- Exit mix (early-closed): `{}`
- **Offline verdict:** **PARK** — no val-tuned thr beats production OOS; export thr=1.0 (no exit)

## OOS threshold sweep (val percentiles → full 111 window)

| val pct | thr | Net $ | PF | early@b6 |
|--------:|----:|------:|---:|---------:|
| 50 | 0.4323 | -7.09 | 0.84 | 42 |
| 52 | 0.4351 | -7.09 | 0.84 | 42 |
| 54 | 0.4456 | -7.09 | 0.84 | 42 |
| 56 | 0.4632 | -7.11 | 0.84 | 40 |
| 58 | 0.4742 | -7.11 | 0.84 | 40 |
| 60 | 0.4926 | -5.99 | 0.86 | 38 |
| 62 | 0.5040 | -6.11 | 0.86 | 37 |
| 64 | 0.5350 | -3.98 | 0.90 | 35 |
| 66 | 0.5410 | -3.98 | 0.90 | 35 |
| 68 | 0.5493 | -3.98 | 0.90 | 35 |
| 70 | 0.6034 | -5.63 | 0.86 | 33 |
| 72 | 0.6343 | -5.48 | 0.87 | 32 |
| 74 | 0.6507 | -5.28 | 0.87 | 29 |
| 76 | 0.6834 | -4.16 | 0.90 | 27 |
| 78 | 0.7066 | -1.61 | 0.96 | 25 |
| 80 | 0.7653 | -1.81 | 0.95 | 24 |
| 82 | 0.7896 | -0.14 | 1.00 | 22 |
| 84 | 0.8099 | 0.68 | 1.02 | 20 |
| 86 | 0.8438 | 2.04 | 1.06 | 18 |
| 88 | 0.8862 | 2.40 | 1.07 | 15 |
| 90 | 0.9204 | 5.51 | 1.16 | 9 |
| 92 | 0.9326 | 5.51 | 1.16 | 9 |
| 94 | 0.9385 | 5.51 | 1.16 | 9 |
| 96 | 0.9630 | 4.11 | 1.12 | 7 |
| 98 | 0.9966 | 6.94 | 1.22 | 2 |

- Best sweep net: **$9.08** @ pct **100** (still vs prod **$9.08**)

## Test OOS — b6-path cohort only (84 trades)

| Policy | n | Net $ | PF | exited |
|--------|--:|------:|---:|-------:|
| Hold | 84 | 5.16 | 1.27 | 0 |
| AI exit | 84 | 5.16 | 1.27 | 0 |

Export: `ai_v3_exit_logistic.json` · wire in EA: **P4-5**
