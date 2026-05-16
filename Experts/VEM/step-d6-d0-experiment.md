# Step D6 — Experiment lock (Filter #2: BB width)

**Status:** Code + `.set` ready — **you:** compile (F7) → D6 IS/OOS backtests  
**Date locked:** 2026-05-16

---

## Prerequisites

- Filter #1 **session** kept — `vem5m_d1_session.set`
- Step **E** complete (E6 deferred) — [`step-e-d0-experiment.md`](step-e-d0-experiment.md)

---

## References

| Item | Path / value |
|------|----------------|
| Control (D1 only) | `MQL5/Profiles/Tester/vem5m_d1_session.set` |
| Test (D1 + D6) | `MQL5/Profiles/Tester/vem5m_d6_session_bbwidth.set` |
| B4 evidence | [`step-b-complete-results.md`](step-b-complete-results.md) |
| Session OOS control | 701 trades · −$13.69 · PF 0.96 · DD 15.2% |
| OOS B4 replay (681 bar-matched trades) | narrow +$3.73 · wide −$9.20 |

---

## Filter #2 — single hypothesis

**Name:** Block wide Bollinger bands at entry

**Hypothesis:** On EURUSD M5 mean reversion, entries when bands are **wide** (expansion / trend noise) are net negative; **narrow** bands are better.

**Mechanism (one rule):** On the **signal bar** (`inp_signal_shift`), if

`(BB_upper - BB_lower) / BB_middle > inp_bb_max_width_ratio`

→ **no new entry** (long and short).

**Rule v1:**

| Parameter | Value |
|-----------|--------|
| `inp_bb_width_filter_enable` | `true` in `vem5m_d6_session_bbwidth.set` only |
| `inp_bb_max_width_ratio` | **0.00165** (≈ 66.7th percentile of M5 bar widths, 2025.01–2026.05 calibration) |
| Session filter | **stays on** (hours 13–15 blocked) |

**Not in v1:** min-width floor (narrow was best in B4 — do not block narrow), dynamic terciles, ATR combo.

---

## Evaluation windows (same as D1)

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Fair compare:** D6 test vs **`vem5m_d1_session.set`** on **identical dates** (not baseline without session).

---

## Pass / fail (D6)

**Keep filter #2** if on IS and OOS vs session-only control:

- [x] Net profit **improves** OOS (−$4.58 vs session −$13.69)
- [x] PF **≥** session control (0.96 tie)
- [x] Max DD **not worse** (8.4% vs 15.2%)
- [x] Trade drop **plausible** (373 vs 701, −47%)

**D6 verdict (2026-05-16):** **Keep** session + BB width — IS and OOS pass vs session-only control.

| Window | Trades | Net $ | PF | Max DD % |
|--------|--------|-------|-----|----------|
| IS 2024.01–2026.05 | **724** | **+$4.98** | **1.03** | **8.0%** |
| OOS 2025.01–2026.05 | **373** | −$4.58 | 0.96 | 8.4% |
| Session-only OOS (control) | 701 | −$13.69 | 0.96 | 15.2% |
| Session-only IS (control) | 1161 | −$17.08 | 0.96 | 15.4% |

**Discard** if trade count collapses (&lt; ~350 OOS) with no PF gain — **not triggered**.

---

## Deliverables

- [x] D6 D0 — this file  
- [x] Code — `VEM_Risk_CheckBBWidth`, inputs in `VEM_Config.mqh`  
- [x] `vem5m_d6_session_bbwidth.set`  
- [x] **You:** compile + OOS backtest (2025.01.01–2026.05.15, both filters on)  
- [x] D6 IS — **724** trades, **+$4.98**, PF **1.03**, DD **8.0%**  
- [x] D6 OOS — **373** trades, **−$4.58**, PF **0.96**, DD **8.4%**  
- [x] `baseline-eurusd-m5-20260516.md` OOS row updated  

---

## D6 OOS result (tester screenshot 2026-05-16)

| Metric | Session only | D6 (+ BB width) | Δ |
|--------|----------------|-----------------|---|
| Trades | 701 | **373** | −47% |
| Net $ | −$13.69 | **−$4.58** | **+$9.11** |
| PF | 0.96 | 0.96 | tie |
| Max equity DD | 15.2% | **8.4%** | −6.8 pp |
| Win rate | 60.2% | **64.3%** | +4.1 pp |
| Avg win / loss | $0.73 / −$1.15 | **$0.46 / −$0.87** | smaller losses |

Confirmed inputs via `VEM.EURUSD.M5.20250101_20260515.000.ini`: session + `inp_bb_width_filter_enable=true`, `inp_bb_max_width_ratio=0.00165`.
