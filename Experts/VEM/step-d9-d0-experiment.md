# Step D9 — Experiment lock (Regime: BB walk)

**Status:** **DISCARD** — filter fires but **hurts** net/PF vs D7 (IS and OOS)  
**Date locked:** 2026-05-16  
**Habitat base:** `vem5m_d7_session_bb_rsi.set` (D1 + D6 + D7)  
**Prior:** D8 / D8b EMA slope **discarded** (null vs D7)

---

## Prerequisites

- D7 habitat locked
- D8 / D8b not in stack (EMA slope **off**)
- **Do not** combine other new filters in this run

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `MQL5/Profiles/Tester/vem5m_d7_session_bb_rsi.set` |
| **Test** | `MQL5/Profiles/Tester/vem5m_d9_d7_bb_walk.set` |
| B9 evidence | [`step-b-complete-results.md`](step-b-complete-results.md) — walk weak on full sample; still on-strategy |
| D7 OOS control | 119 tr · **+$6.00** · PF **1.17** · DD **3.2%** |
| D7 IS control | 270 tr · −$0.38 · PF 0.99 |

---

## Filter #5 — single hypothesis

**Name:** No entry during Bollinger band walk

**Hypothesis:** If price has closed **outside the same band** for N bars in a row, continuation risk is high — skip the fade.

**Mechanism** from **signal bar** (`inp_signal_shift`) backward:

| Side | Walk = consecutive closes… |
|------|----------------------------|
| Long | `close < BB lower` |
| Short | `close > BB upper` |

**Block** new entry if `walk_count >= inp_bb_walk_min_closes`.

**Rule v1:**

| Parameter | Value |
|-----------|--------|
| `inp_bb_walk_filter_enable` | `true` in D9 set only |
| `inp_bb_walk_min_closes` | **2** |
| D1 / D6 / D7 | unchanged from D7 set |

**Code:** `VEM_Indicators_BBWalkCount()`, `VEM_Risk_CheckBBWalk()`

**Optional v9b:** `inp_bb_walk_min_closes = 3` (stricter) — separate `.set` only if v1 inconclusive.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · 0.01 lots.

**Fair compare:** D9 vs **`vem5m_d7_session_bb_rsi.set`** on identical dates.

---

## Pass / fail (D9)

**Keep filter #5** if vs D7 on **OOS** (primary):

- [x] Trades **< 119** — **yes** (44 OOS, 115 IS; filter firing)
- [ ] Net $ **≥ +$6.00** — **no** (OOS **−$4.81**)
- [ ] PF **≥ 1.17** — **no** (OOS **0.72**)
- [ ] IS not worse — **no** (−$15.17 vs −$0.38)

**Verdict (2026-05-16):** **DISCARD** — removes too many good fades; habitat stays **D7 only**. Optional **D9b** (min closes = 3) not recommended unless you want one more null test.

---

## D9 results (tester screenshots 2026-05-16)

`vem5m_d9_d7_bb_walk.set` · min closes **2** · vs D7 control.

### OOS 2025.01.01 → 2026.05.15

| Metric | D7 | D9 | Δ |
|--------|-----|-----|---|
| Trades | 119 | **44** | **−63%** |
| Net $ | **+6.00** | **−4.81** | **−$10.81** |
| PF | **1.17** | **0.72** | −0.45 |
| Max equity DD | 3.2% | **3.97%** | worse |
| Win rate | 68.9% | **68.18%** | ~flat |
| Avg win / loss | 0.51 / −0.97 | **0.42 / −1.23** | loss larger |

### IS 2024.01.01 → 2026.05.15

| Metric | D7 | D9 | Δ |
|--------|-----|-----|---|
| Trades | 270 | **115** | **−57%** |
| Net $ | −0.38 | **−15.17** | **much worse** |
| PF | 0.99 | **0.63** | −0.36 |
| Max equity DD | 7.75% | **7.59%** | ~flat |
| Win rate | 65.2% | **62.61%** | −2.6 pp |
| Sharpe | — | **−5.00** | poor |

**Interpretation:** Band-walk gate blocks many valid mean-reversion entries (price often closes outside the band on the signal bar). B9 was weak on the full baseline for the same reason. **Regime entry filters after D7 are exhausted for now** — next lever: **E8a** (failure exit) on D7 base.

---

## Deliverables

- [x] D9 D0 — this file
- [x] `VEM_Risk_CheckBBWalk` + inputs
- [x] `vem5m_d9_d7_bb_walk.set`
- [x] F7 compile + IS + OOS
- [x] **DISCARD** + baseline row

---

## Tester checklist

1. **F7** compile `VEM.mq5`
2. Load **`vem5m_d9_d7_bb_walk.set`** — BB walk **on**, min closes **2**, EMA slope **off**
3. OOS then IS (dates above)
4. Compare to D7 control metrics
