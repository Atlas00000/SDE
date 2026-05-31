# P4-2 — Tail threshold retune (shadow combo)

**Shadow:** `C:\Users\emili\AppData\Roaming\MetaQuotes\Terminal\Common\Files\VEM_ai_shadow_EURUSD_M5.csv`
**Matched opened:** 395 · OOS **111**
**Old threshold:** 0.704700
**Selection:** OOS pass bar + combo skip ≤ 8%

**New threshold:** `0.9415000000000000`
- Val combo: net $9.99 · n=279 · skip 1.8% (tail-only 0.4%)
- OOS combo: net **$10.32** · PF **1.37** · n **107** · skip 3.6%

## Top OOS candidates (pass bar)

| thr | OOS net | PF | n | skip% | tail-only% |
|----:|--------:|---:|--:|------:|-------------:|
| 0.9415 | 10.32 | 1.37 | 107 | 3.6 | 1.8 |
| 0.9962 | 9.83 | 1.34 | 109 | 1.8 | 0.0 |
| 0.9908 | 9.83 | 1.34 | 109 | 1.8 | 0.0 |

## Next

1. **Recompile** EA
2. Run **`VEM.AI_Tail_Skip`** vs **`VEM.AI_Skip`**
