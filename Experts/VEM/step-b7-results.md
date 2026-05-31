# B7 — Quality labels results

**Source:** `data/c2/VEM_trades_v2_EURUSD_M5_prod_20260529.csv`
**Rules:** `data/c2/label_rules.json`
**Trades:** 408

## Label prevalence (all)

| Label | % positive | n |
|-------|------------|---|
| label_bad_entry | 16.9% | 69 |
| label_tail_loss | 10.3% | 42 |
| label_early_cut | 10.0% | 41 |
| label_early_cut_b4 | 8.1% | 33 |
| label_early_cut_b6 | 6.6% | 27 |
| label_profile_good | 91.4% | 373 |
| label_profile_bad | 18.9% | 77 |
| label_loss | 35.3% | 144 |
| label_sl | 4.9% | 20 |

## By split

| Split | n | bad_entry% | early_cut% | profile_bad% | net $ |
|-------|---|------------|--------------|--------------|-------|
| train | 122 | 17.2% | 10.7% | 19.7% | $13.61 |
| val | 163 | 12.9% | 9.2% | 23.3% | $-6.11 |
| test | 123 | 22.0% | 10.6% | 12.2% | $7.43 |

## Regime mix

```
{'range': 276, 'trend': 86, 'chop': 46}
```

## Outcome vs profile (entry-only proxies)

| | bad_entry rate | n |
|--|----------------|---|
| profile_good=1 | 16.9% | 373 |
| profile_good=0 | 17.1% | 35 |
| profile_bad=1 | 19.5% | 77 |
| profile_bad=0 | 16.3% | 331 |

## Leakage checklist (B9)

- Entry skip (**AI-6**): use **entry columns only** — see `label_rules.json` → `leakage.entry_models_may_use`
- Exit model (**P4-5**): may use `mae_r_b4/b6`, `mfe_r_b4/b6`, `label_early_cut`
- `label_bad_entry` / `label_tail_loss` use **post-trade** outcome — **do not** feed into entry features

## Exit cross-tab (bad_entry)

```
label_bad_entry    0   1
exit_type               
e8c               23  15
midline          315  34
sl                 0  20
tp                 1   0
```

---

*Next: **AI-6** train XGB on entry features → `label_bad_entry`*
