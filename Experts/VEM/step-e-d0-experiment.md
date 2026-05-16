# Step E0 — Exit experiment lock (session habitat)

**Status:** E1–E5 **complete** (analysis) · E6 **deferred** (no code change) · **Next: Step D6** (BB width)  
**Date:** 2026-05-16

---

## Control run (do not change mid-test)

| Item | Value |
|------|--------|
| Set file | `MQL5/Profiles/Tester/vem5m_d1_session.set` |
| Session filter | on · block hours **13–15** |
| SL | 200 pts (1R = 0.00200) |
| Exits | midline on · `inp_tp_rr=1.5` |
| OOS control | 701 trades · −$13.69 · PF 0.96 · DD 15.2% · 2025.01.01–2026.05.15 |

**Analysis:** [`step-e-results.md`](step-e-results.md) · script `scripts/step_e_mae_mfe_analyze.py`

---

## E1 — Winner MAE (OOS, n=406 winners)

| Stat | Value |
|------|-------|
| Median MAE | **0.18R** |
| 75th %ile | **0.34R** |
| % MAE > 0.8R | **2.7%** |

**E3 decision:** Do **not** widen SL — winners rarely use full 1R room.

---

## E2 — Loser MFE (OOS, n=275 losers)

| Stat | Value |
|------|-------|
| Median MFE | **0.15R** |
| % MFE > 0.5R | **10.9%** |
| % MFE > 0.8R | **4.4%** |
| Median loser MAE | **0.87R** (price goes adverse toward SL) |

**E4 decision:** Losers **fail fast** with **low MFE** — not “gave back a winning trade.” Midline + session filter are correct tools; **lower `inp_tp_rr` / faster TP is not supported** by data.

---

## E5 — Hold time (M5 bars)

| | Winners | Losers |
|--|---------|--------|
| Median | 9 | 14 |
| 75th %ile | 12 | 18 |

Losers linger longer before SL; no max-bars rule in v1 (insufficient evidence).

---

## Exit mix (OOS deals)

| Type | Share |
|------|-------|
| Midline | **80.2%** |
| SL | **17.9%** |
| TP | **1.9%** |

Payoff problem = **many small midline wins** (winner median MFE **0.45R**) vs **near-full SL** on losers (median MAE **0.87R**).

---

## E6 — Retest

**Deferred (documented skip):** No single exit-parameter change met the evidence bar. Wider SL, lower `inp_tp_rr`, and time-stop are **not** first tests.

**Eligible next:** Step **D6** filter #2 — **min BB width** (B4) on top of `vem5m_d1_session.set`.

Optional later E6 trials (only if new data contradicts):

- Tighter SL (e.g. 160 pts) — high risk of more SL tags; needs hypothesis
- Midline-only vs R:R mode compare — structural test, not parameter tweak

---

## Checklist sync

- [x] E1 · [x] E2 · [x] E3 · [x] E4 · [x] E5 · [x] E6 deferred → see `edge-discovery.md`
