# Step E8a — Experiment lock (Failure-to-revert exit)

**Status:** **DISCARD** — WR collapse; OOS net/PF worse than D7 (early exit cuts winners)  
**Date locked:** 2026-05-16  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  
**Test:** `vem5m_e8a_d7_fail_exit.set` (D7 + E8a only)

---

## Prerequisites

- D7 habitat locked; D8/D9 **discarded**
- **No** new entry filters in this run
- Step E MAE/MFE: losers median MFE **0.15R** — failures start small then hit SL

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_e8a_d7_fail_exit.set` |
| Step E | [`step-e-results.md`](step-e-results.md) |
| D7 OOS control | 119 tr · **+$6.00** · PF **1.17** · avg loss **−$0.97** |
| D7 IS control | 270 tr · −$0.38 · PF 0.99 |

---

## E8a — single hypothesis

**Name:** Close dead trades before full SL

**Hypothesis:** Good MR shows early favorable excursion; if after **N** bars MFE is still tiny (and/or price still outside band), continuation risk dominates — exit early.

**Rule v1** (checked each new bar, after midline exit pass):

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 4` | Start checking |
| `MFE < 0.2R` **OR** close still outside band (long: below lower; short: above upper) | **Close position** |

| Parameter | Value |
|-----------|--------|
| `inp_fail_exit_enable` | `true` in E8a set |
| `inp_fail_exit_bars` | **4** |
| `inp_fail_exit_min_mfe_r` | **0.2** |
| `inp_fail_exit_outside_bb` | **true** |
| SL / midline / entries | Same as D7 |

**Code:** `VEM_Execution_CheckFailureExits()` in `VEM_Execution.mqh`

**Not in v1:** E8b time-in-loss only; E7 breakeven combined in same run.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · 0.01 lots.

---

## Pass / fail (E8a)

**Keep E8a** if vs D7 on **OOS** (primary):

- [x] **Avg loss** smaller — **yes** (~−$0.50 vs −$0.97) but **not enough**
- [ ] Net **≥ +$6.00** — **no** (**−$4.65**)
- [ ] PF **≥ 1.17** — **no** (**0.86**)
- [ ] WR preserved — **no** (**46.7%** vs **~69%**)
- [ ] Full SL exits down — unclear; midline winners lost to early close

**Verdict (2026-05-16):** **DISCARD** — rule fires too often on valid fades (still outside band + low early MFE is normal). Habitat stays **D7 exits only** (midline). **Next:** **E7** breakeven or **E9** partial TP — not E8b without redesign.

---

## E8a results (tester screenshots 2026-05-16)

`vem5m_e8a_d7_fail_exit.set` · bars **4** · MFE **&lt; 0.2R** or outside BB.

### OOS 2025.01.01 → 2026.05.15

| Metric | D7 | E8a | Δ |
|--------|-----|-----|---|
| Trades | 119 | **122** | +3 |
| Net $ | **+6.00** | **−4.65** | **−$10.65** |
| PF | **1.17** | **0.86** | −0.31 |
| Win rate | **68.9%** | **46.72%** | **−22 pp** |
| Max equity DD | 3.2% | **4.59%** | worse |
| Avg win / loss | 0.51 / **−0.97** | 0.49 / **−0.50** | loss smaller |
| Sharpe | 4.20 | **−5.00** | collapsed |

### IS 2024.01.01 → 2026.05.15

| Metric | D7 | E8a | Δ |
|--------|-----|-----|---|
| Trades | 270 | **293** | +23 |
| Net $ | −0.38 | **−6.66** | worse |
| PF | 0.99 | **0.89** | −0.10 |
| Win rate | 65.2% | **46.42%** | −19 pp |
| Max equity DD | 7.75% | **5.08%** | lower DD only win |
| Avg win / loss | 0.42 / −0.79 | 0.41 / **−0.40** | symmetric R |

**Interpretation:** “Still outside BB” + low MFE at bar 4 is **normal** for good MR before snapback — E8a exits **before** midline (~80% of D7 wins). Shrinking avg loss did not help because **win rate** destroyed expectancy.

---

## Deliverables

- [x] E8a D0 — this file
- [x] `inp_fail_exit_*` + `VEM_Execution_CheckFailureExits`
- [x] `vem5m_e8a_d7_fail_exit.set`
- [x] F7 + IS/OOS
- [x] **DISCARD** + baseline row

---

## Tester checklist

1. **F7** compile `VEM.mq5`
2. Load **`vem5m_e8a_d7_fail_exit.set`**
3. Confirm: failure exit **on**, bars **4**, min MFE **0.2**, outside BB **on**
4. OOS then IS (dates above)
5. Compare to D7 — focus on **avg loss**, **PF**, **% SL exits**
