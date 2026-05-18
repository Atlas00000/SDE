# Step E8c — Experiment lock (Worse-structure exit)

**Status:** **KEEP — production default** (merged into `vem5m_d7_session_bb_rsi.set`)  
**Date locked:** 2026-05-18  
**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  
**Test:** `vem5m_e8c_d7_worse_structure.set` (D7 + E8c only)

---

## Prerequisites

- **E10** parked (marginal; production stays D7 off)
- **E8a / E8b** **DISCARD** — do not combine in v1
- **E8c ≠ E8a:** E8a exits if still outside band **or** low MFE; E8c exits only if penetration **deepens** vs entry

---

## References

| Item | Path / value |
|------|----------------|
| **Control** | `vem5m_d7_session_bb_rsi.set` |
| **Test** | `vem5m_e8c_d7_worse_structure.set` |
| D7 OOS control | 119 tr · **+$6.00** · PF **1.17** · WR **~69%** |
| D7 IS control | 270 tr · **−$0.38** · PF **0.99** |

---

## E8c — single hypothesis

**Name:** Cut band-walk / continuation before full SL

**Hypothesis:** Losers that **never revert** often show price closing **further outside** the entry-side BB; winners may wobble outside but rarely **deepen** penetration before midline.

**Rule v1** (each new bar, **after** midline pass):

| Condition | Action |
|-----------|--------|
| `bars_in_trade >= 4` | Start checking |
| Long: `pen_now = lower − close` **>** `pen_entry` (signal bar at entry) | **Close** |
| Short: `pen_now = close − upper` **>** `pen_entry` | **Close** |
| Must still be outside band (`pen_now > 0`) | — |

| Parameter | Value |
|-----------|--------|
| `inp_worse_struct_exit_enable` | `true` |
| `inp_worse_struct_exit_bars` | **4** |
| `inp_worse_struct_min_pen_pts` | **0** |
| E10 / E8 | **off** |
| SL / midline | Same as D7 |

**Code:** `VEM_Execution_CheckWorseStructureExits()` — entry penetration stored on open; fallback from entry bar if missing.

**Journal:** `E8c worse-struct exit` with `pen` / `entry_pen`.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (E8c)

**Keep E8c** if vs D7 on **OOS** (primary):

- [x] Net **≥ +$6.00** — **yes** (+$9.08)
- [x] PF **≥ 1.17** — **yes** (1.30)
- [x] WR **≥ ~65%** — **yes** (70.3%)
- [x] Trade count not collapsed — **yes** (111 vs 119)
- [x] IS not materially worse — **yes** (+$3.06 / PF 1.04 vs −$0.38 / 0.99)

**Discard** if WR &lt; ~65%, net/PF below control, or exits fire on most winners.

---

## Run checklist

1. Compile **VEM.mq5** (F7)
2. Load **`vem5m_e8c_d7_worse_structure.set`**
3. Run **OOS** then **IS**
4. Journal: count `E8c worse-struct exit` lines

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Max DD % |
|--------|--------|-------|-----|------|-----------|----------|
| **IS (E8c)** | 274 | **+$3.06** | **1.04** | **64.2%** | +$0.42 / −$0.72 | 7.2% |
| **OOS (E8c)** | 111 | **+$9.08** | **1.30** | **70.3%** | +$0.50 / −$0.91 | 3.2% |
| IS (D7 ctrl) | 270 | −$0.38 | 0.99 | ~64% | — | — |
| OOS (D7 ctrl) | 119 | +$6.00 | 1.17 | ~69% | — | ~3.2% |

### vs D7 (delta)

| Window | Δ trades | Δ net | Δ PF | Δ WR |
|--------|----------|-------|------|------|
| OOS | −8 | **+$3.08** | **+0.13** | **+1.3 pp** |
| IS | +4 | **+$3.44** | **+0.05** | ~flat |

**Interpretation:** Tighter than E8a — only exits when BB penetration **deepens**, not merely “still outside.” Cuts band-walk losers without E8b-style WR collapse. **IS turns positive** for the first time on D7 habitat stack.

**Verdict:** **KEEP** — **production default** merged into **`vem5m_d7_session_bb_rsi.set`**. Benchmark habitat-only: **`vem5m_d7_habitat_only.set`**.

### Full-span robustness (E8c profile, $200, 0.01 lots)

| Metric | Value |
|--------|--------|
| Trades | **915** |
| Net | **+$34.44** |
| PF | **1.15** |
| WR | **64.6%** |
| Avg win / loss | +$0.45 / −$0.72 |
| Max equity DD | **6.3%** |

vs prior D7 habitat-only long run (~880 tr · +$30 · PF 1.13): **more trades, higher net, better PF** on extensive window.
