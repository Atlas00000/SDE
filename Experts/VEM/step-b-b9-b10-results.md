# Step B — B9 & B10 results (EURUSD M5 baseline)

> **Superseded by:** [`step-b-complete-results.md`](step-b-complete-results.md) (includes B1, B3–B5, B8, full B9/B10).

**Source report:** `MQL5/Profiles/Tester/ReportTester-23489.xlsx`  
**Analysis date:** 2026-05-16  
**Script:** `scripts/b9_b10_analyze.py` (re-runnable with MT5 open)

---

## Important limitations

| Topic | Detail |
|--------|--------|
| Excel content | Deals sheet has **times, profit, SL/TP comment** — **no** BB, wick, or OHLC |
| Price data | Pulled **EURUSD M5** from MT5 terminal (`copy_rates_from_pos`, 100k bars) |
| Coverage | **818 / 1,429** trades (57%) — entries from **2025-01-10 → 2026-05-15** |
| Missing | **611 trades** in **2024** (no M5 history loaded in terminal for that period) |
| Method | Signal bar = entry time − 5 min (`inp_signal_shift=1`); BB 20/2 on **close**; walk = consecutive **prior** closes outside same band |

To analyze **all** 1,429 trades: in MT5 → EURUSD M5 chart → **Home → History Center → Download** full 2024–2026, then re-run script.

---

## B9 — BB walk (consecutive closes outside band before signal)

**Question:** Do losers enter during band **walk** (persistence) more than winners?

### All analyzed trades

| Group | N | Mean walk | Median walk | **≥ 2 prior closes outside band** |
|-------|---|-----------|-------------|-----------------------------------|
| **Losers** | 329 | 1.04 | 1 | **85 (25.8%)** |
| **Winners** | 484 | 1.07 | 1 | **119 (24.6%)** |

### Worst 40 losers (largest $ loss)

| Metric | Value |
|--------|--------|
| ≥ 2 walk closes | **11 / 40 (27.5%)** |

### SL-only losers (full stop)

| Metric | Value |
|--------|--------|
| N | 166 |
| ≥ 2 walk closes | **47 (28.3%)** |

### Losers — walk count distribution

| Prior walk closes | Count | % of losers |
|-------------------|-------|-------------|
| 0 | 151 | 45.9% |
| 1 | 93 | 28.3% |
| 2 | 49 | 14.9% |
| 3 | 12 | 3.6% |
| 4 | 12 | 3.6% |
| 5+ | 12 | 3.6% |

### B9 verdict

**Weak discriminator** on this sample: winners and losers show almost the same rate of **≥ 2** walk bars (~25%). Many losers (46%) had **zero** prior closes outside the band — failures are not dominated by classic “BB walk” alone.

**Step D:** Implement **B6 session filter first** (Step D1 in `edge-discovery.md`). BB walk is an **optional later trial** (D filter #4), not the first code change.

---

## B10 — Wick rejection (% of signal-bar range)

**Question:** Do winners show larger rejection wicks at the signal bar?

| Group | Mean wick % | **Median wick %** | p25 | p75 |
|-------|-------------|-------------------|-----|-----|
| Losers | 21.5 | **16.2** | 7.1 | 31.1 |
| Winners | 22.3 | **16.7** | 7.7 | 31.9 |

### By side (median wick % on signal bar)

| Side | Losers | Winners | Δ (winners − losers) |
|------|--------|---------|----------------------|
| **Long** | 15.2% | 17.7% | **+2.6 pp** |
| **Short** | 17.3% | 16.0% | **−1.3 pp** |

### B10 verdict

**Very small edge** in the data: overall medians differ by **0.5 pp**; only **longs** show winners with slightly larger lower wicks (+2.6 pp). **Not strong enough** to prioritize `min_wick_pct` before session / exit work.

---

## Updated Step D priority (after B6 + B9 + B10)

Use **`edge-discovery.md` → Step D checklist** (D0–D6). Filter #1 = **session**, not BB walk.

| Phase | Item | Status |
|-------|------|--------|
| **D filter #1** | Session / hour (B6) | **Done** — keep; see `baseline-eurusd-m5-20260516.md` |
| **Step E** | Exit / payoff (E1–E6) | **Next** — `vem5m_d1_session.set`; see `edge-discovery.md` |
| **D6 filter #2** | Min BB width (B4) | After Step E |
| **D6 filter #3** | RSI depth (B5) | After BB width D0–D5 |
| **Optional** | BB walk (B9) | Weak — trial only |
| **Defer** | Min wick % (B10) | Weak |

---

## Step B findings block (copy into baseline)

```markdown
### B9 BB walk (818 trades, 2025–2026)
- Losers ≥2 walk: 25.8% | Winners ≥2 walk: 24.6% → **no clear separation**
- Worst 40: 11/40 (28%) ≥2 walk

### B10 Wick % (signal bar)
- Losers median 16.2% | Winners median 16.7% → **minimal separation**
- Longs only: winners +2.6 pp wick vs losers

### B7 — Filters for Step D
1. **Hypothesis:** NY overlap / hour 13 momentum kills mean reversion.  
   **Rule:** Block entry hours 13–15 (and/or 13–21) — validate OOS.  
2. **Optional trial:** BB walk ≥2 closes — B9 weak; test if session filter insufficient.
```

---

## Re-run instructions

1. Open **MetaTrader 5** (YWO-Trade) and download EURUSD M5 history for 2024–2026.  
2. `pip install MetaTrader5 openpyxl numpy`  
3. `python MQL5/Experts/VEM/scripts/b9_b10_analyze.py`
