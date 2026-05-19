# VEM trade profile — aggregate outlook (EURUSD M5)

**Purpose:** Macro-style portrait of **winning vs losing trade populations** for the VEM mean-reversion EA — not per-trade logs, but **how each side tends to behave** in market structure, time, volatility, and execution.

**Primary symbol / TF:** EURUSD · M5  
**Strategy core:** Fade outer Bollinger touch + RSI extreme + volume spike → target **BB midline**; **200 pt SL** (~1R); optional broker TP at 1.5R (rarely reached).

**Evidence used (2024–2026 discovery path):**

| Layer | Source | Trades / window |
|--------|--------|------------------|
| Raw engine | `baseline-eurusd-m5-20260516.md` · `vem5m.set` | 1,429 · 2024.01–2026.05 |
| Regime buckets | `step-b-complete-results.md` · `phase-b-guide.md` | 1,429 (B6) · 818 bar-matched (B1–B10) |
| Excursions & exits | `step-e-results.md` · D1 session OOS | 681 analyzed · ~701 OOS |
| **Production** | `vem5m_d7_session_bb_rsi.set` | D1+D6+D7 + **E8c** · OOS 111 tr · full ~915 tr |
| **Benchmark** | `vem5m_d7_habitat_only.set` | D7 entries only, E8c off |

**Production today:** session block **13–15**, max BB width, RSI depth (long ≤25, short ≥75), **midline + E8c** (worse BB penetration @ bar 4). E8a/E8b/E10 **off**.

---

## How the EA behaves (shared mechanics)

Every trade follows the same **lifecycle contract**:

1. **Signal bar** (shift 1): price at/touching outer BB, RSI past 30/70, volume ≥ 1.5× its MA.
2. **Entry:** market order; fixed **20 pip** SL; TP exists at 1.5R but **midline exit dominates**.
3. **Management:** **midline** primary; **E8c** scratches band-walk (penetration deepens @ bar 4). E8a/E8b/E10 discarded.
4. **Typical hold:** ~**30–55 minutes** on M5 (scalp / short intraday fade).

**Payoff shape (structural):** High win rate, **small average win**, **larger average loss** when SL fires — expectancy is won or lost on **context**, not on tightening RSI by 2 points alone.

| Exit path | ~Share (baseline / habitat) | Role |
|-----------|----------------------------|------|
| **BB midline** | **~80%** | Defines the “winner archetype” |
| **Full SL (200 pts)** | **~18%** | Defines the “loser archetype” |
| **TP @ 1.5R** | **~2%** | Noise — midline almost always wins first |

---

## Aggregate winner profile

*“The trade that reverts to the mean before the stop.”*

### Market structure & regime

| Dimension | Typical winner pattern |
|-----------|-------------------------|
| **Regime** | **Range / exhaustion**, not sustained trend. Price stretched to an extreme, then **stalls** — volatility climax slowing, not accelerating. |
| **BB state** | Bands **not in widest expansion**; narrow-to-mid width environments outperform wide-band entries (B4: narrow bucket **+$3.97** vs wide **−$11.92** on analyzed sample). |
| **Band touch** | Touch or pierce of outer band on signal bar; **reversion toward mid** begins within a handful of M5 bars. |
| **BB walk** | **Not** a reliable winner marker — ~**25%** of both winners and losers had ≥2 prior closes outside the same band (B9). Winners are **not** defined by “zero walk.” |
| **Trend / slope** | Mild or **against** the fade works better than fading into a clean drift; `range` and `mild_trend` buckets less toxic than blind trend-fade (B1). |
| **Structure** | **Failed push** or rejection at the extreme — not a series of strong continuation bodies in the fade direction. |

### Indicators at entry (habitat-aligned)

| Feature | Winner tendency |
|---------|-----------------|
| **RSI** | **Deep** extreme — longs: OS **≤25** (best buckets deep &lt;20, 20–25); shorts: need **≥75** (shallow 70–75 and 75–80 were net negative pre-D7). |
| **Volume** | Spike vs MA confirms **capitulation / exhaustion** at the band, not random low-volume tag. |
| **Wick** | Slight edge for **longs** only (winners +2.6 pp median wick vs losers — B10); **not** a strong global separator (~16.5% median both sides). |

### Time & session

| Dimension | Winner tendency |
|-----------|-----------------|
| **Best hours (baseline, server time)** | **09, 12, 17** — positive P/L buckets; **London 8–12** block **+$13.94** aggregate. |
| **Avoid (removed in production)** | Entries **13:00–15:00** — NY overlap / hour-13 expansion; production blocks this window. |
| **Weekday / month** | Activity spread Mon–Fri; no single month dominates edge — **summer (Jun–Aug)** somewhat weaker in baseline heatmaps. |

### Excursion & hold (Step E — session habitat, n≈406 winners)

| Metric | Winners (typical) |
|--------|-------------------|
| **Median MAE** | **0.18R** — drawdown before win is **shallow** |
| **75th %ile MAE** | **0.34R** — rarely needs full 1R room |
| **% MAE &gt; 0.8R** | **2.7%** — almost never “near stop then win” |
| **Median MFE** | **0.45R** — often **does not reach** 1.5R TP; midline caps the win |
| **Median hold** | **9 M5 bars** (~45 min) |
| **75th %ile hold** | **12 bars** |

### Economic signature

- **Win rate (raw):** ~**61%** baseline → **~65–69%** under D7 habitat (fewer, sharper trades).
- **Avg win (money):** ~**$0.46–0.73** depending on run — **small, frequent**.
- **Psychology of outcome:** Price **reaches BB mid** while trade is still structurally valid; floating P/L may still be **negative at bar 4** (E8b lesson) before snapback — **early “still red” is normal** for eventual winners.

### Winner in one sentence

> A **compressed-to-normal volatility** stretch into a **deep RSI extreme** during **non-NY-overlap** hours, with **shallow adverse excursion**, closed at **BB midline** in under ~12 bars.

---

## Aggregate loser profile

*“The fade that was actually continuation — or never snapped back before full stop.”*

### Market structure & regime

| Dimension | Typical loser pattern |
|-----------|-------------------------|
| **Regime** | **Directional persistence** — mean reversion thesis wrong. NY **momentum expansion**, not exhaustion. |
| **BB state** | **Wide bands** at entry (expansion / trend noise); wide tercile worst in B4. |
| **BB walk** | Theoretically “bad” — empirically **weak** discriminator (~**26%** losers vs ~**25%** winners with ≥2 walk bars). **46%** of losers had **zero** walk — loss is **not** only band-walk. |
| **Trend / slope** | Fading into **active drift** (`against` bucket −$138 on losers-only P/L in B1 subset); hour **13** losses cluster with **momentum**, not range chop. |
| **Structure** | **Continuation** — price holds outside band or grinds through the fade; no meaningful rejection / stall. |

### Indicators at entry (anti-habitat)

| Feature | Loser tendency |
|---------|----------------|
| **RSI** | **Shallow** OB/OS — shorts **70–75**, **75–80**; longs **25–30** zone net negative (B5). |
| **Volume** | Spike can still fire on **wrong context** (news / impulse bar) — volume alone does not save the trade. |
| **Wick** | Median wick **~16%** — essentially same as winners; **no rejection** is not cleanly measurable by wick % alone on M5. |

### Time & session

| Dimension | Loser tendency |
|-----------|-----------------|
| **Worst hour** | **13:00** — **−$18.55** / 182 trades (baseline 1,429). |
| **Worst block** | **NY 13–21** — **−$34.30** / 416 trades. |
| **Other toxic hours** | **15, 21–22, 00, 07, 11** — mixed WR but negative $ contribution. |
| **Production** | Losers disproportionately came from **13–15** before D1 — that window is **removed** in D7. |

### Excursion & hold (Step E — session habitat, n≈275 losers)

| Metric | Losers (typical) |
|--------|------------------|
| **Median MFE** | **0.15R** — price **barely** moved in favor |
| **% MFE &gt; 0.5R** | **10.9%** — rarely “was winning, gave back” |
| **% MFE &gt; 0.8R** | **4.4%** |
| **Median MAE** | **0.87R** — adverse move consumes most of **1R** |
| **Median hold** | **14 M5 bars** — **longer** than winners before resolution |
| **75th %ile hold** | **18 bars** |

### Economic signature

- **~35–39%** of trades lose (baseline / habitat).
- **Avg loss:** ~**$0.33–1.17** — when SL hits, often **near full 20 pip** (MAE ~0.87R).
- **Dominant exit:** **Stop loss** — not midline failure after deep profit.
- **Failure mode (data):** **Type C** — *sideways bleed then SL* or **fast wrong-way** with **low MFE** — **not** “reached mean then gave back” (that would be Type B; only ~11% of losers had MFE &gt;0.5R).

### Loser in one sentence

> A **wide-band, shallow-RSI** fade during **NY-style expansion** (or other momentum context), with **high MAE / low MFE**, held **longer**, terminated at **full SL** — the market never mean-reverted before the stop.

---

## Winners vs losers — structural contrast

| Axis | Winners (aggregate) | Losers (aggregate) |
|------|---------------------|---------------------|
| **Thesis** | Exhaustion at extreme | Continuation disguised as extreme |
| **Volatility** | Narrow–mid BB; stabilizing ATR | Wide BB; expanding / noisy |
| **RSI** | Deep OS/OB (D7: ≤25 / ≥75) | Shallow touch of 30/70 |
| **Session** | London-friendly; not 13–15 | Hour **13**, NY block, late NY |
| **MFE / MAE** | Low MAE (0.18R), moderate MFE (0.45R) | High MAE (0.87R), low MFE (0.15R) |
| **Hold time** | Shorter (~9 bars median) | Longer (~14 bars median) |
| **Exit** | **Midline ~80%** | **SL ~18%+** of all trades |
| **“Still red @ bar 4”** | **Common** before snapback | Also common — **cannot** separate (E8b) |
| **BB walk ≥2** | ~25% | ~26% — **no separation** |

**Core insight:** Winners and losers look **similar at entry** on weak features (walk, wick, EMA slope on D7 subset). Edge comes from **stacking habitat filters** (session, width, RSI depth) and **letting midline exit work** — not from early scratch exits.

---

## Temporal fingerprint (when edge lives)

**Server / tester clock** (MetaTrader — confirm vs your broker).

```
        Asia 0–7          London 8–12        NY 13–21        Late 22–23
P/L     mixed (−12)       BEST (+14)         WORST (−34)     weak (−15)
Role    high volume       habitat core       anti-habitat    tail risk
```

**Production D7** blocks **13–15** only (not full NY 13–21) — keeps London afternoon and some NY hours while removing the worst overlap pocket.

**Intraday rhythm (baseline entries):** peaks **08:00** (London) and pre-block **13–14**; after D1, the **13–15 loss cluster** is largely removed from the entry set.

---

## Regime map (where each population lives)

| Regime | Winners | Losers |
|--------|---------|--------|
| **Range / chop** | Primary habitat | Less dominant — still some SL in chop |
| **Mild trend** | Survivable if deep RSI + filters | Losers pile in `against` + `mild_trend` buckets |
| **Strong trend / band walk** | Rare — midline may still save some | Theoretical anti-habitat; walk count **weak** in data |
| **Volatility expansion (wide BB)** | Suppressed by D6 | Enriched in loser set |
| **Volatility compression (narrow BB)** | Best B4 bucket | Under-represented in losers |

**ATR terciles (B3):** All slightly negative on raw baseline — **no clean ATR-only gate**; BB width and session did more work than ATR bucket alone.

---

## Direction: long vs short

| Side | Baseline | Notes |
|------|----------|--------|
| **Long** | 705 trades | Deep OS (≤25) **kept**; shallow 25–30 **blocked** by D7 |
| **Short** | 724 trades | Shallow 70–80 **worst** buckets; **≥75** required |
| **WR asymmetry (E8b discard runs)** | Long WR ~31% / Short ~38% when failure exit on — habitat path: both profitable only with **midline + filters** |

Shorts were **more sensitive to shallow overbought** than longs to shallow oversold — D7 RSI depth rule is **especially** a short-side hygiene filter.

---

## Production (D7 + E8c) — who is allowed to trade

After filters, the **aggregate entry** resembles:

| Trait | Profile |
|-------|---------|
| **Session** | Signal bar **not** hour 13, 14, or 15 |
| **BB width** | `(upper−lower)/mid ≤ 0.00165` on signal bar |
| **RSI** | Long **≤25** · Short **≥75** |
| **Still required** | Outer BB touch + volume spike + spread/cooldown gates |

**OOS (2025–2026, $200, 0.01):** 111 tr · **+$9.08** · PF **1.30** · WR **70%** · DD **~3.2%**  
**IS (2024–2026, $200, 0.01):** 274 tr · **+$3.06** · PF **1.04** · WR **64%**  
**Full span ($200, 0.01):** **915 tr** · **+$34.44** · PF **1.15** · WR **64.6%** · DD **6.3%**  

*Prior D7 habitat-only OOS: 119 tr · +$6 · PF 1.17 · benchmark `vem5m_d7_habitat_only.set`.*

**What D7 removed:** ~80% of baseline trade count — mostly **shallow RSI**, **wide band**, and **NY overlap** entries that fed the loser profile.

---

## What failed experiments teach (aggregate, not per trade)

| Test | Implication for profiles |
|------|---------------------------|
| **E8a / E8b** | “Still outside band” or “still red @ 4 bars” = **normal winner path** — discarded |
| **E8c** | **KEEP** — exit only when BB penetration **deepens** vs entry; production default |
| **E7 BE** | Winners already exit at midline before BE matters |
| **E9 partial** | Payoff already capped at midline; splitting does not change population economics |
| **D8 EMA slope** | No separation on D7 set — slope not the active loser discriminator |
| **D9 BB walk** | Walk rate **equal** on wins/losses — walk is not the main loser story |

---

## Habitat card (use before adding any filter)

**Trade if the market looks like:**

- EURUSD M5 **range / exhaustion**, not NY open momentum  
- **Narrow–normal** Bollinger width, not blow-out expansion  
- **Deep** RSI extreme with volume spike at the band  
- **London / off-peak** hours (production: not 13–15 server)  
- Willingness to hold through **small floating loss** until midline — **do not** early-exit “red @ 4 bars”

**Do not trade (or expect loser profile) if:**

- **13–15** (blocked in production) or broader **NY impulse** without extra rules  
- **Wide** bands / volatility expansion entry  
- **Shallow** RSI tag of 30/70 without depth  
- Fading what is actually a **one-way grind** (low MFE, rising MAE — visible only in hindsight or forward MAE/MFE logging)

---

## C1 production-path medians (2026-05-19)

**Source:** `VEM_trades_EURUSD_M5.csv` · 459 trades (excl. `e10`) · [`step-c1b-results.md`](step-c1b-results.md)

| Slice | n | WR% | PF | SL |
|-------|--:|----:|---:|---:|
| All | 459 | 66.2 | 1.16 | 25 |
| OOS 2025–26 | 228 | 72.8 | 1.52 | 16 |

**Loser hotspots (not promoted — D1b null):** hour **7** (37 losers, 12 SL); mid/high BB width terciles among losers. **E13/E14 paused** — no full-population bucket ≥30 with PF&lt;1.

**AI v0:** [`step-ai-2-results.md`](step-ai-2-results.md) — loss classifier holdout skip sim **passes** pass bar on mixed CSV but **val AUC weak** → research only until clean C1 re-run.

---

## Gaps & next precision (optional)

- **Canonical C1:** re-run single backtest `vem5m_d7_c1_trade_log.set` and archive CSV by date (current file mixes runs).  
- **611 trades** (2024 H1) missing from bar-matched B9–B10 — session hour stats use **full 1,429** deal export.  
- **Per-side MAE/MFE on D7** — assumed similar shape to D1 session E-results; verify after feature logging.

---

## Related files

| Doc | Content |
|-----|---------|
| `baseline-eurusd-m5-20260516.md` | Raw baseline metrics & diagnosis |
| `step-e-results.md` | MAE/MFE medians, exit mix |
| `step-b-complete-results.md` | Regime buckets B1–B5, B8 profiles |
| `phase-b-guide.md` | Hour & session P/L tables |
| `edge-discovery.md` | Good/bad trade templates & filter philosophy |
| `filtersrecommedations.md` | Locked D7 habitat & discarded experiments |

*Last updated: 2026-05-18 — production = `vem5m_d7_session_bb_rsi.set` (D7 + E8c) @ 0.01.*
