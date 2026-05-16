# Step D0 — Experiment lock (Filter #1: session)

**Status:** Filter #1 **complete** (D3–D5) — proceed to **Step E** (`edge-discovery.md`). D6 deferred until after E.  
**Date locked:** 2026-05-16

---

## References (do not change mid-test)

| Item | Path / value |
|------|----------------|
| Baseline metrics | [`baseline-eurusd-m5-20260516.md`](baseline-eurusd-m5-20260516.md) |
| Baseline inputs | `MQL5/Profiles/Tester/vem5m.set` |
| Step B evidence | [`step-b-complete-results.md`](step-b-complete-results.md) · B6 from `ReportTester-23489.xlsx` |
| EA build | `Experts/VEM/VEM.ex5` |
| Symbol / TF | EURUSD, M5 |
| Tester model | Every tick |
| Deposit / leverage | $200, 1:500 |

---

## Filter #1 — single hypothesis

**Name:** Session block (NY overlap / hour 13)

**Hypothesis:** Mean reversion on EURUSD M5 fails when entries occur during **NY overlap momentum** (server hours 13–15). Fading band touches in that window adds trades that are net negative despite high win rate.

**Mechanism (one rule only):** If the **signal bar** open time (bar at `inp_signal_shift`, default 1 = last closed bar) falls in blocked hours → **no new entry**.

**Rule v1:**

| Parameter | Value |
|-----------|--------|
| `inp_session_filter_enable` | `true` (D1 `.set` only; baseline `.set` stays `false`) |
| Blocked hours (inclusive) | **13, 14, 15** |
| Time basis | **Server / tester time** (same as Strategy Tester report & B6 hour pivot) |
| Applies to | Long and short |

**Not in v1:** hour 21–22, full NY 13–21 block, weekends, ADX, BB walk, wick %.

**Fallback if D3/D4 fail:** Rule v1b = block **hour 13 only** (worst single hour, −$18.55). Decide only after OOS — do not pre-code v1b.

---

## Evaluation windows

| Window | From | To | Use |
|--------|------|-----|-----|
| **In-sample (IS)** | 2024.01.01 00:00 | 2026.05.15 00:00 | Same as Step A — primary pass/fail |
| **Out-of-sample (OOS)** | 2025.07.01 00:00 | 2026.05.15 00:00 | Validation only — **no retuning** hours on OOS |

---

## Baseline (control) — copy for comparison

| Metric | Value |
|--------|-------|
| Trades | 1,429 |
| Net profit | −$47.63 |
| Profit factor | 0.93 |
| Win rate | 61.09% |
| Max equity DD | 31.42% ($67.21) |

---

## Step B — why this filter (D1 confirm)

From **full 1,429 trades** (Excel deals, entry hour):

| Hour (server) | Net P/L | Trades | Notes |
|---------------|---------|--------|--------|
| **13** | **−$18.55** | 182 | Worst single hour |
| **15** | **−$15.35** | 58 | |
| **14** | +$3.87 | 43 | Mildly positive |
| **NY 13–21 block** | **−$34.30** | 416 | Broader than v1 |

**v1 blocks ~283 entries** (hours 13+14+15: 182+43+58) ≈ **20%** of all trades — expect material trade-count drop.

**Evidence NOT used for v1:** BB walk / wick (B9/B10 weak on bar sample).

---

## Pass / fail criteria (D3 IS)

Record in comparison table. **Keep filter** if most are true:

- [x] Profit factor **>** 0.93 (0.96)  
- [x] Net profit **>** −$47.63 (−$17.08)  
- [x] Max equity DD **≤** 31.42% (15.4%)  
- [x] Removed trades plausibly from bad hours (not random)  
- [x] Trade count **> 800** on IS (1161)

**Discard or narrow (v1b)** if IS improves but **D4 OOS** does not.

---

## Pass / fail criteria (D4 OOS)

On **same OOS window** as session run (ran **2025.01.01 → 2026.05.15**; charter optional window **2025.07.01 → 2026.05.15**):

- [x] PF and net $ better than baseline on **same OOS window** (session −$13.69 / 15.2% DD vs baseline −$16.58 / 20.6%)

---

## Deliverables checklist (D0)

- [x] Hypothesis + single rule written (this file)  
- [x] IS / OOS dates fixed  
- [x] Baseline reference linked  
- [x] Comparison table row added (placeholder) in `baseline-eurusd-m5-20260516.md`  
- [x] D1 — code + `vem5m_d1_session.set` (`VEM_Risk_CheckSession`, default off in baseline `.set`)  
- [x] D3 — IS backtest (`ReportTester-23489.xlsx`, `inp_session_filter_enable=true`)  
- [x] D4 — OOS backtest (`ReportTesterB-23489.xlsx`; ran **2025.01.01–2026.05.15**, not Jul start)  
- [x] D5 — **keep** filter (OOS 2025.01–2026.05: session −$13.69 / 15.2% DD vs baseline −$16.58 / 20.6%)  

---

## Comparison row (fill after D3/D4)

| Run | Date | Change | Trades | PF | Net $ | Max DD % | Verdict |
|-----|------|--------|--------|-----|-------|----------|---------|
| Baseline | 20260516 | — | 1429 | 0.93 | −47.63 | 31.4 | Step A |
| D1 session IS | 20260516 | block hrs 13–15 | 1161 | 0.96 | −17.08 | 15.4 | IS pass |
| Baseline OOS | 20260516 | 2025.01–2026.05 · filter off | 841 | 0.96 | −16.58 | 20.6 | control |
| D1 session OOS | 20260516 | 2025.01–2026.05 · ReportTesterB | 701 | 0.96 | −13.69 | 15.2 | **keep** |
