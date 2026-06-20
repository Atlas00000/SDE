# ORBVWAP — Multi-Symbol Portfolio Guide

**Purpose:** Candidate assets and portfolio construction for scaling ORBVWAP beyond EURUSD without breaking the validated edge.  
**Prerequisite:** EURUSD chart demo sign-off complete (steps 6 & 8 or `AI1234_HTTP_LIVE`).  
**Roadmap ref:** P3-003 in [Edge Discovery.md](./Edge%20Discovery.md) · wiring in [System Design.md](./System%20Design.md)

> Each symbol requires its **own** AI-0 export → train → Tester sign-off. **Do not** reuse EURUSD `models/*.json` on other pairs.

---

## EURUSD demo sign-off (first)

1. Load **`AI1234_LIVE`** (compiled) or **`AI1234_HTTP_LIVE`** (+ `python Scripts/ai_inference_server.py`).
2. Attach to **EURUSD M1** · enable Algo Trading · `InpEnableAiShadowLog=true`.
3. After 1–2 sessions: check Experts tab (no HTTP fail-open spam).
4. Audit shadow CSV:

   ```powershell
   python Diagnostics/ai/audit_shadow.py "%APPDATA%\MetaQuotes\Terminal\Common\Files\Logs\ORBVWAP_ai_shadow.csv"
   ```

5. Append result to `AI-test-journal.csv` when PASS.

---

## What makes a good ORBVWAP symbol

| Requirement | Why |
|-------------|-----|
| Liquid **London / NY** session | ORB + session VWAP are session-scoped |
| Tight spread vs range width | PROD uses `MaxSpreadPctRange=20` |
| Enough M1 volatility for 5-min ORB | Min range ≥ 0.8× ATR |
| Stable broker symbol | Same tick/point rules across backtest and live |

---

## Tier 1 — First adds (best ORB + session fit)

| Symbol | Why | Correlation vs EURUSD | Portfolio role |
|--------|-----|------------------------|----------------|
| **GBPUSD** | Strong London open, ORB-friendly, tight on most brokers | **High (~0.7–0.85)** | More London exposure — **not** diversification alone |
| **USDJPY** | Clean NY/London moves, different USD leg | **Low–moderate (~0.2–0.5)** | **Best 2nd FX** for diversification |
| **AUDUSD** | Asia→London handoff, liquid major | **Moderate (~0.5–0.65)** | Pacific / commodity-FX tilt |
| **USDCAD** | NY session active, oil-linked | **Moderate (~0.4–0.6)** | North America block |

**Suggested FX core (after EURUSD signed):** **EURUSD + USDJPY + AUDUSD** — three different drivers (EUR bloc, JPY risk, commodity AUD).

---

## Tier 2 — Expand frequency (overlap risk)

| Symbol | Why | Correlation note |
|--------|-----|------------------|
| **EURGBP** | Pure London ORB; no USD | Redundant if EURUSD + GBPUSD already live |
| **EURJPY** | Volatile London open | Bridges EUR + JPY |
| **GBPJPY** | Large ranges | High vol; correlates with GBPUSD + USDJPY |
| **NZDUSD** | Similar to AUD | **~0.85+ vs AUDUSD** — pick one, not both |
| **USDCHF** | Often inverse EURUSD | **~−0.8 vs EURUSD** — hedge, but double EUR exposure |

Use Tier 2 only after Tier 1 passes gates. Cap total **GBP/EUR-linked** exposure.

---

## Tier 3 — Cross-asset (strongest diversification, more work)

| Symbol | Why | vs FX majors | Caveats |
|--------|-----|--------------|---------|
| **XAUUSD** | Sharp NY/London breaks | Low–moderate (~0.1–0.4) | Wider spread — re-tune spread/range filters |
| **US500 / US30** | NY cash open ORB | Moderate vs USDJPY | Session hours differ; check broker symbol |
| **GER40 / UK100** | London cash open | Low vs USD pairs | Equity-linked, not FX |
| **BTCUSD** | Volatile NY | Historically low vs FX | Spread/slippage — experimental only |

Requires separate PROD geometry review before AI layers.

---

## Tier 4 — Generally skip

| Symbol | Why |
|--------|-----|
| Exotic FX (USDTRY, USDZAR, …) | Spreads too wide for range filter |
| **AUDUSD + NZDUSD** together | Near-duplicate exposure |
| **EURUSD + USDCHF** together | Same EUR view twice |
| **EURUSD + GBPUSD + EURGBP** | Three-way redundancy |
| Illiquid crosses | Too few clean ORB sessions/month |

---

## Portfolio templates

**Goal:** ~**4–5 trades/month per symbol** × **N uncorrelated symbols** → smoother combined equity.

| Portfolio | Symbols | Diversification logic |
|-----------|---------|------------------------|
| **Minimal (3)** | EURUSD · USDJPY · AUDUSD | EUR bloc + JPY + commodity |
| **Balanced (4)** | + USDCAD | Adds NA / oil-linked leg |
| **Balanced + alt (5)** | + XAUUSD | Cross-asset; lower FX correlation |
| **London-heavy (avoid)** | EURUSD · GBPUSD · EURGBP | High correlation — not diversified |

### Risk bucketing

- Treat **EURUSD + GBPUSD** as **~1.5× EUR exposure**, not 2× independent edges.
- Size each chart so **combined bucket risk** stays within portfolio DD budget.
- Use **separate magic numbers** per symbol/chart.

---

## Per-symbol workflow (same discipline as EURUSD)

```
PROD 6y backtest → PASS
  ↓
AI-0 export → build_dataset → train ai*_v1 (symbol-specific)
  ↓
AI1234_SHADOW Tester → journal PASS
  ↓
Demo shadow audit → chart sign-off
  ↓
Add to portfolio
```

---

## Portfolio metrics to track

| Metric | Use |
|--------|-----|
| Combined PF / max DD | Portfolio health |
| Trades/month per symbol | Capacity planning |
| **Pairwise correlation of weekly P&L** | True diversification check |
| Max simultaneous drawdown | Risk stacking |
| Shadow audit per symbol | Fail-open detection |

---

## Recommended rollout

| Phase | Action |
|-------|--------|
| **1 (now)** | Sign off **EURUSD** on demo |
| **2** | Add **USDJPY** — best uncorrelated FX major |
| **3** | Add **AUDUSD** or **XAUUSD** (FX-only vs cross-asset) |
| **Defer** | GBPUSD unless you accept correlation with EURUSD for more London frequency |

---

## Related docs

- [README.md](./README.md) — run modes and presets
- [System Profile.md](./System%20Profile.md) — PROD v3 geometry (frozen)
- [aidesign.md](./aidesign.md) — AI training gates per symbol
- [Edge Discovery.md](./Edge%20Discovery.md) — P3-003 multi-symbol plan
