# Step E7 — Experiment lock (Breakeven)

**Status:** **DISCARD v1** — null vs D7 (identical IS + OOS; BE did not change outcomes)  
**Date locked:** 2026-05-16  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  
**Test:** `vem5m_e7_d7_breakeven.set` (D7 + E7 only)

---

## Prerequisites

- D7 locked; D8/D9/E8a **discarded**
- Midline exit **stays on** (E7 only moves SL, does not replace midline close)
- **No** E8a / E9 in same run

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_e7_d7_breakeven.set` |
| D7 OOS | 119 tr · **+$6.00** · PF **1.17** · WR **~69%** |
| D7 IS | 270 tr · −$0.38 · PF 0.99 |

---

## E7 — single hypothesis

**Name:** Move SL to breakeven after trade shows progress

**Hypothesis:** Trades that reach **+0.5R** MFE should not return to full SL loss — BE stops winner→loser reversals (Type B losses).

**Rule v1:**

| Trigger | Action |
|---------|--------|
| `MFE >= 0.5R` (closed bars since entry) | `PositionModify` SL → **entry** (broker stop level validated) |
| Midline touch | **Off** in v1 (`inp_be_on_midline=false`) — midline still **closes** via existing exit |

| Parameter | Value |
|-----------|--------|
| `inp_be_enable` | `true` in E7 set |
| `inp_be_trigger_r` | **0.5** |
| `inp_be_on_midline` | **false** |

**Code:** `VEM_Execution_ManageBreakeven()` — runs **before** midline close each bar.

**Optional E7b:** `inp_be_on_midline=true` or trigger **0.3R** — only if v1 inconclusive.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · 0.01 lots.

---

## Pass / fail (E7)

**Keep E7** if vs D7 on **OOS** (primary):

- [x] Net **≥ +$6.00** — **tie** (+$6.00)
- [x] PF **≥ 1.17** — **tie** (1.17)
- [x] WR preserved — **tie** (68.91%)
- [ ] Avg loss / SL mix improved — **no change** (0.51 / −0.97)
- [x] Not worse — **yes**, but **no benefit**

**Verdict (2026-05-16):** **DISCARD v1** — identical to D7; +0.5R BE either rarely applied on closed-bar MFE or matched midline path. Keep **breakeven OFF** on habitat set. **Next:** **E9** partial TP.

---

## E7 results (tester screenshots 2026-05-16)

`vem5m_e7_d7_breakeven.set` · trigger **0.5R** · midline BE **off**.

### OOS 2025.01.01 → 2026.05.15

| Metric | D7 | E7 | Δ |
|--------|-----|-----|---|
| Trades | 119 | **119** | 0 |
| Net $ | +6.00 | **+6.00** | 0 |
| PF | 1.17 | **1.17** | 0 |
| Win rate | 68.9% | **68.91%** | 0 |
| Max equity DD | 3.2% | **3.19%** | 0 |
| Avg win / loss | 0.51 / −0.97 | **0.51 / −0.97** | 0 |
| Sharpe | 4.20 | **4.20** | 0 |

### IS 2024.01.01 → 2026.05.15

| Metric | D7 | E7 | Δ |
|--------|-----|-----|---|
| Trades | 270 | **270** | 0 |
| Net $ | −0.38 | **−0.38** | 0 |
| PF | 0.99 | **0.99** | 0 |
| Win rate | 65.2% | **65.19%** | 0 |
| Max equity DD | 7.75% | **7.75%** | 0 |
| Avg win / loss | 0.42 / −0.79 | **0.42 / −0.79** | 0 |

**Interpretation:** Same as D8 null — on D7 trades, closed-bar MFE ≥ 0.5R likely coincides with midline exit same/next bar, or BE never differs from original SL path in tester. Optional **E7b:** lower trigger (0.3R) or `inp_be_on_midline` without midline close — not default.

---

## Deliverables

- [x] E7 D0 — this file
- [x] `inp_be_*` + `VEM_Execution_ManageBreakeven`
- [x] `vem5m_e7_d7_breakeven.set`
- [x] F7 + IS/OOS
- [x] **DISCARD** + baseline row

---

## Tester checklist

1. **F7** compile
2. Load **`vem5m_e7_d7_breakeven.set`**
3. Confirm: breakeven **on**, trigger **0.5**, midline BE **off**, failure exit **off**
4. OOS then IS vs D7
