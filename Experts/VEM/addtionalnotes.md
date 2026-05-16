# Additional notes (edge discovery)

> **Canonical doc:** These ideas are integrated into [`edge-discovery.md`](edge-discovery.md) (trade quality profiles, market structure, first filters, filter design, expanded checklists). Use that file for day-to-day work; keep this file as a short scratchpad if needed.

---

## Trade quality profile (explicit)

**GOOD LONG** — BB width expanding but slowing; RSI &lt; 22; long lower wick; volume spike &gt; 1.8×; ATR elevated but not exploding; weak EMA slope; stretched from mean; rejection close.

**BAD LONG** — strong EMA slope down; multiple closes outside BB; ATR expanding rapidly; small/no rejection wick; momentum continuation candles.

→ Future filters, AI labels, and scoring come from refining these profiles with CSV data.

---

## Missing piece: market structure

Not just indicator state — also structure: HTF distance from mean, local slope, compression vs expansion, impulse vs exhaustion, directional persistence. BB + RSI alone do not separate exhaustion from acceleration.

---

## First filters to try (before ADX stacks)

1. **BB walk** — no entry if 2–3 consecutive closes already outside same band  
2. **Min wick rejection** — lower/upper wick &gt; X% of candle range  

Each = one hypothesis, not a condition tree.

---

## Filter rule

**Bad:** `RSI<22 AND ATR<... AND ADX<...`  
**Good:** Hypothesis + one mechanism (e.g. “persistence kills MR” → block after 3 same-side closes outside BB).
