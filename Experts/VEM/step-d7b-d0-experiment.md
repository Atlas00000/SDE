# Step D7b — Experiment lock (Tighter RSI depth on production)

**Status:** **DISCARD** — IS negative; prod RSI **25/75** locked  
**Date:** 2026-05-19  
**Control:** `vem5m_d7_session_bb_rsi.set` — long RSI **≤25**, short RSI **≥75**  
**Test:** `vem5m_d7b_prod_rsi228.set` — long **≤22**, short **≥78**

---

## Prerequisites

- **D6b** discard (width 0.0015) — prod width stays **0.00165**  
- **D1b** null · exit sweeps closed — **E8c @ 4**, E10 **off**  
- Step B5: shallow RSI buckets (25–30 long, 70–75 short) were net negative pre-D7

---

## Hypothesis

Production D7 already requires deep extremes. **D7b** tightens one step to drop shallow-but-passing signals:

| Side | Control (D7) | D7b test |
|------|--------------|----------|
| Long | RSI **≤ 25** | RSI **≤ 22** |
| Short | RSI **≥ 75** | RSI **≥ 78** |

Both sides enabled. Same D1 + D6 + E8c stack.

**Code:** `VEM_Risk_CheckRSIDepth()` — parameters only.

**Note:** Legacy `vem5m_d7b_short80.set` is **short-only** min 80 (old D7 sweep) — not this build.

---

## Evaluation windows

| Window | From | To |
|--------|------|-----|
| **IS** | 2024.01.01 | 2026.05.15 |
| **OOS** | 2025.01.01 | 2026.05.15 |

**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots.

---

## Pass / fail (vs production)

**Keep D7b** if on **OOS** (primary):

- [ ] Net **≥ +$9.08**
- [ ] PF **≥ 1.30**
- [ ] WR **≥ ~65%**
- [ ] Trades **≥ ~95**
- [ ] IS net **≥ +$3.06**, PF **≥ 1.04**

**Discard** if below control on OOS net/PF.

---

## Run checklist

1. Load **`vem5m_d7b_prod_rsi228.set`** (not `vem5m_d7b_short80.set`)
2. **OOS** then **IS**
3. Expect **fewer** trades than 111 / 274

---

## Results

| Window | Trades | Net $ | PF | WR % | Avg W / L | Notes |
|--------|--------|-------|-----|------|-----------|--------|
| **OOS (D7b)** | — | — | — | — | — | _not in screenshot — run if needed_ |
| **IS (D7b)** | **124** | **−$1.57** | **0.95** | **60.48%** | +$0.44 / −$0.71 | tester 2026-05-19 |
| OOS (prod) | 111 | +9.08 | 1.30 | 70.3% | +0.50 / −0.91 | |
| IS (prod) | 274 | +3.06 | 1.04 | 64.2% | +0.42 / −0.72 | |

### vs production (IS)

| Δ trades | Δ net | Δ PF | Δ WR |
|----------|-------|------|------|
| **−150** | **−$4.63** | **−0.09** | **−3.7 pp** |

**Interpretation:** Tighter RSI cut **~55%** of IS trades and flipped IS negative. WR fell; avg loss unchanged. Shallow-band trades removed were not the toxic subset on this stack.

### Verdict

- [ ] **KEEP** — merge RSI **22 / 78** into production
- [x] **DISCARD** — prod stays **25 / 75**

---

## Phase 2d — habitat micro-sweep **complete**

| ID | Result |
|----|--------|
| E8c-v2 min_pen 5 | Park |
| E8c-bar 5 | Discard |
| E10-v2 MAE 0.45 | Discard |
| D1b hour 7 | Null |
| D6b width 0.0015 | Discard |
| **D7b RSI 22/78** | **Discard** |

**Next:** forward/demo on **`vem5m_d7_session_bb_rsi.set`** — no further entry/exit micro-filters without new C1 evidence.
