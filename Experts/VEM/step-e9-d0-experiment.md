# Step E9 — Experiment lock (Partial TP at BB midline)

**Status:** **DISCARD** — E9 metrics match D7 @ 0.02 (partial adds no edge over full midline at same size)  
**Date locked:** 2026-05-16  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  
**Test:** `vem5m_e9_d7_partial_midline.set` (D7 + E9 only)

---

## Prerequisites

- D7 locked; D8/D9/E8a/E7 **discarded**
- Midline exit **on**; partial replaces **full** close on first touch
- E7 / E8a **off** in this run

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` (full midline close) |
| **Test** | `vem5m_e9_d7_partial_midline.set` |
| D7 OOS | 119 tr · **+$6.00** · PF **1.17** · ~80% midline exits |
| D7 IS | 270 tr · −$0.38 · PF 0.99 |

---

## E9 — single hypothesis

**Name:** Bank partial profit at mean; runner for extension

**Hypothesis:** Lock **60%** at BB midline; let **40%** ride to fixed TP (1.5R) or SL — improves realized R without E8a-style early kills.

**Rule v1:**

| Event | Action |
|-------|--------|
| Signal bar touches midline (same as D7) | `PositionClosePartial` **60%** of volume |
| After partial | Runner only — **no** second midline close; SL/TP on remainder |
| Remainder too small to split | Full close (min lot) |

| Parameter | Value |
|-----------|--------|
| `inp_partial_midline_enable` | `true` |
| `inp_partial_midline_pct` | **0.6** |
| `inp_exit_bb_midline` | `true` |

**Code:** `VEM_Execution_MidlineExits()` — ticket list tracks partial-done runners.

**Optional E9b:** `inp_partial_midline_pct=0.5` — separate set if v1 inconclusive.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200**.

**Lots:** E9 set uses **0.02** so `PositionClosePartial(60%)` can split (at **0.01** min lot, partial = full close = D7). For strict compare, optional D7 control rerun at **0.02** lots.

---

## Pass / fail (E9)

**Keep E9** if vs D7 on **OOS** (primary):

- [x] Net **> +$6.00** — **yes** (+$19.53 at 0.02 lots)
- [ ] PF **> 1.17** — **no** (1.12)
- [x] WR may dip — **yes** (58% vs 69%; runners hit SL)
- [ ] Trade count ~same — **no** (202 vs 119; 0.02 lots + partial deals)
- [ ] IS not worse — **no** (−$13.64 vs −$0.38)

**Verdict (2026-05-16):** **DISCARD E9** — follow-up run at **0.02** lots matches E9 (OOS **+19.53** / 202 tr / PF **1.12**; IS **−13.64** / 418 tr). Gain vs D7 @ 0.01 is **lot size + more trades**, not partial TP. **Production:** keep **`vem5m_d7_session_bb_rsi.set` @ 0.01** (best PF/WR/DD) **or** D7 @ 0.02 only if you accept worse IS/DD for higher OOS $.

---

## E9 results (tester screenshots 2026-05-16)

`vem5m_e9_d7_partial_midline.set` · partial **60%** · **0.02** lots.

**Compare note:** D7 control = **0.01** lots. E9 = **0.02** lots (required for partial split).

### OOS 2025.01.01 → 2026.05.15

| Metric | D7 (0.01) | E9 (0.02) | Δ |
|--------|-----------|-----------|---|
| Trades | 119 | **202** | +70% |
| Net $ | +6.00 | **+19.53** | **+$13.53** |
| PF | **1.17** | 1.12 | −0.05 |
| Win rate | **68.9%** | 58.42% | −10 pp |
| Max equity DD | **3.2%** | 10.28% | higher |
| Avg win / loss | 0.51 / −0.97 | 1.50 / −1.88 | ~2× (lot size) |
| Sharpe | 4.20 | 1.54 | lower |

### IS 2024.01.01 → 2026.05.15

| Metric | D7 (0.01) | E9 (0.02) | Δ |
|--------|-----------|-----------|---|
| Trades | 270 | **418** | +55% |
| Net $ | −0.38 | **−13.64** | worse |
| PF | 0.99 | **0.96** | worse |
| Win rate | 65.2% | 54.31% | −11 pp |
| Max equity DD | 7.75% | **27.20%** | much higher |

**Interpretation:** Partial + runners **bank midline sooner** but **more runners stop out** (lower WR). OOS net gain may scale with **0.02** sizing as much as E9 logic — confirm with D7 @ 0.02 control.

### D7 @ 0.02 lots (control — same screenshots as E9 check)

If your latest run is **`vem5m_d7_session_bb_rsi.set`** with **0.02** lots only:

| Window | D7 @ 0.01 | D7 @ 0.02 / E9 @ 0.02 |
|--------|-----------|------------------------|
| OOS net | +$6.00 | **+$19.53** |
| OOS PF | **1.17** | 1.12 |
| OOS WR | **69%** | 58% |
| IS net | **−$0.38** | −$13.64 |

→ **E9 discarded.** Optional habitat: D7 full midline @ **0.02** (not E9).

---

## Deliverables

- [x] E9 D0 — this file
- [x] `inp_partial_midline_*` + `VEM_Execution_MidlineExits`
- [x] `vem5m_e9_d7_partial_midline.set`
- [x] F7 + IS/OOS
- [x] Conditional KEEP (OOS) + baseline row
- [ ] Optional: D7 control @ 0.02 lots same windows

---

## Tester checklist

1. **F7** compile
2. Load **`vem5m_e9_d7_partial_midline.set`**
3. Confirm: partial midline **on**, pct **0.6**, BE/failure **off**
4. OOS then IS vs D7
5. Check journal for `E9 partial midline` lines
