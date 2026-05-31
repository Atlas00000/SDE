# P4-5 — Early-cut exit summary (`label_early_cut`)

**Script:** `scripts/train_ai_p45_exit.py` · **Data:** C2 labeled archive (408 tr)

## Verdict: **PARK — do not wire**

| Bar | Val AUC | Test AUC | OOS baseline | ML exit | B7 rule oracle | Wire |
|-----|--------:|---------:|-------------:|--------:|---------------:|------|
| **4** | 0.936 | 0.945 | **$6.83** | $6.83 | $2.18 (9 exits) | no |
| **6** | 0.958 | 0.986 | **$6.83** | $6.83 | −$0.94 | no |

- Tuned threshold = **1.0** (no early exits) — any lower skip % **destroys** OOS net on sweep (best sub-baseline ≈ −$0.03 @ 97th pct).
- **High AUC is misleading:** model ranks “bad path” trades well, but closing at **bar MTM** cuts winners that later reach midline / E8c.
- **B7 rule oracle** also loses vs hold — confirms problem is **exit timing**, not ML vs rules.

## Keep in production

**D1+D6+D7 + midline + E8c** · optional **`VEM.AI_Skip`** (entry v0.1). No bar-4/6 AI exit.

## Detail reports

- [`step-p45-exit-b4-results.md`](step-p45-exit-b4-results.md)
- [`step-p45-exit-b6-results.md`](step-p45-exit-b6-results.md)

## Models (safe no-op export)

- `models/ai_p45_exit_b4_logistic.json` — `exit_prob_threshold: 1.0`
- `models/ai_p45_exit_b6_logistic.json` — `exit_prob_threshold: 1.0`

## If revisiting P4-5

1. Simulate **partial** cut or **tighter SL** instead of full close @ bar MTM.
2. Target **tail_loss** only (SL trades), not generic `early_cut`.
3. Require **profit < 0** at bar before cut (avoid scratching midline-bound winners).
