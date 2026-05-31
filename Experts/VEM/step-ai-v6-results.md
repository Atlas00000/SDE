# AI-6 — XGBoost trade scorer (C2 entry features)

**Source:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VEM\data\c2\VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv` · n=408
**Target:** `label_bad_entry` · rate **16.9%**
**OOS window:** `2025-01-01` → `2026-05-15` · n=119

## Model comparison

| Model | Feats | Val AUC | Test AUC | Skip% | OOS net | PF | WR | n | Pass D5-D8 |
|-------|------:|--------:|---------:|------:|--------:|---:|---:|--:|:----------:|
| logistic_v01_feats | 8 | 0.600 | 0.613 | 0% | $6.83 | 1.19 | 68.9 | 119 | N |
| logistic_c2_feats | 14 | 0.466 | 0.507 | 0% | $6.83 | 1.19 | 68.9 | 119 | N |
| xgb_c2_feats | 14 | 0.510 | 0.565 | 0% | $6.83 | 1.19 | 68.9 | 119 | N |

- Baseline OOS (no skip): **$6.83**, PF **1.19**

## Reference (v0.1 on 396-tr C1 archive)

- Logistic 8 feats · test AUC ~0.61 · pass-bar skip ~2% · OOS ~$9.83 / PF 1.34

## AI-6 verdict

- **FAIL** — no model meets D5–D8 skip pass bar on this C2 archive.
- Test AUC: XGB **0.565** vs logistic C2 **0.507** (XGB +0.01)

**Next:** AI-7 shadow log in tester · AI-8 promote skip if shadow matches Python.

## XGB feature importance (gain)

- `ema_slope_bp`: 0.1264
- `entry_hour`: 0.0923
- `atr_ratio`: 0.0908
- `vol_ratio`: 0.0813
- `htf_slope_bp`: 0.0766
- `wick_pct`: 0.0759
- `bb_width_ratio`: 0.0749
- `spread_pts`: 0.0734
- `bb_walk_count`: 0.0687
- `rsi_depth`: 0.0620
- `rsi`: 0.0597
- `bb_pen_pts`: 0.0591
- `entry_dow`: 0.0588
- `side_sell`: 0.0000
