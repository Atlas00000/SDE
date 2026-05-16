# Phase B Guide — Hypothesis buckets (manual first)

Step B turns your Step A baseline into **1–2 named filter hypotheses** for Step D. No EA code changes in this phase.

**Baseline:** [`baseline-eurusd-m5-20260516.md`](baseline-eurusd-m5-20260516.md)  
**Tester report (this run):** `MQL5/Profiles/Tester/ReportTester-23489.xlsx`  
**Set file:** `MQL5/Profiles/Tester/vem5m.set`

---

## What Step B delivers

Written output (add to baseline file or below **Step B findings**):

```markdown
## Step B findings

### Filter candidates for Step D
1. **Hypothesis:** …  **Rule:** …  **Evidence:** …
2. (optional) …
```

**Exit criteria:** 1–2 filters with a **hypothesis name**, not a laundry list of optimized inputs.

---

## Your report file structure

`ReportTester-23489.xlsx` is one sheet (~5,815 rows):

| Section | Starts around row | Use for |
|---------|-------------------|---------|
| Summary / settings | 1–94 | Confirm test matches baseline |
| **Orders** | ~95 (header row 96) | Open times, types |
| **Deals** | ~2955 (header row 2956) | **Primary data for Step B** |

**Deals columns (row 2956 header):**

| Col | Field |
|-----|--------|
| A | Time |
| B | Deal |
| C | Symbol |
| D | Type (buy/sell) |
| E | Direction (`in` = entry, `out` = exit) |
| F | Volume |
| G | Price |
| H | Order |
| K | **Profit** (on `out` rows) |
| M | Comment (`sl …`, `tp …`, or empty = midline/manual close) |

**Pairing entry → exit:** For each `out` deal `#N`, the entry is the previous `in` deal `#N-1` (same EURUSD position).

---

## Phase 0 — Setup (once)

- [ ] Open `ReportTester-23489.xlsx` in Excel / LibreOffice / Google Sheets
- [ ] Confirm report matches baseline: VEM, EURUSD M5, 2024.01.01–2026.05.15, `vem5m` inputs
- [ ] Optional: copy the **Deals** block (row 2956 onward) to a sheet named `Deals` for easier formulas
- [ ] Chart ready: EURUSD **M5**, BB(20,2), RSI(14), Volume — for B8–B10 chart review

---

## Phase 1 — Do these first (highest signal)

Recommended order: **B6 → B9 → B10 → B8 → B7**, then optional B1–B5.

---

### B6 — Session / hour (spreadsheet)

**Goal:** Find hours or sessions that destroy P/L.

#### Excel method

1. On **Deals** rows where `Direction = out` and `Symbol = EURUSD`:
   - **Profit** = column K  
   - **Exit comment** = column M (`sl`, `tp`, or blank)  
2. For each `out` row, get **entry time** from the matching `in` row (deal # = current deal − 1).
3. **Entry hour** = `HOUR(entry_time)` — use **tester/server time** (same as report).
4. Pivot: **Sum of Profit** by **Entry hour**; count trades; count SL (`Comment` contains `sl`).

#### Pre-computed from `ReportTester-23489.xlsx` (B6 starter)

Total paired trades: **1,429** · Total P/L: **−$47.63**  
Exit tags on `out` rows: **SL 263** · **TP 26** · **Midline/other ~1,140**

**Worst entry hours (server time):**

| Hour | P/L ($) | Trades | Win % | SL count |
|------|---------|--------|-------|----------|
| 13 | −18.55 | 182 | 56.6% | 58 |
| 15 | −15.35 | 58 | 51.7% | 20 |
| 22 | −10.46 | 17 | 35.3% | 5 |
| 21 | −10.22 | 14 | 14.3% | 4 |
| 00 | −7.66 | 112 | 62.5% | 16 |
| 11 | −6.83 | 27 | 40.7% | 11 |
| 07 | −6.61 | 208 | 63.5% | 31 |
| 23 | −4.49 | 72 | 56.9% | 13 |

**Best entry hours:**

| Hour | P/L ($) | Trades | Win % | SL count |
|------|---------|--------|-------|----------|
| 09 | +10.27 | 36 | 75.0% | 6 |
| 12 | +9.63 | 57 | 64.9% | 10 |
| 17 | +7.33 | 13 | 76.9% | 0 |
| 14 | +3.87 | 43 | 58.1% | 10 |

**Session blocks (entry hour):**

| Block | Hours | P/L ($) | Trades | Win % |
|-------|-------|---------|--------|-------|
| Asia | 0–7 | −12.32 | 679 | 64.4% |
| London | 8–12 | **+13.94** | 245 | 60.0% |
| NY | 13–21 | **−34.30** | 416 | 56.5% |
| Late | 22–23 | −14.95 | 89 | 52.8% |

**Note:** Hour **08** is only −$1.54 (107 trades) — the NY **13:00** hour and block **13–21** are far worse than “London open” alone.

#### B6 checklist

- [ ] Reproduce hour pivot in Excel (sanity-check above)
- [ ] Decide: block **single hours** (13, 15, 21–22) vs whole **NY block** vs custom allowlist (e.g. only 8–12)
- [ ] Write hypothesis for Step D, e.g. *“Mean reversion fails during NY overlap expansion; exclude entry hours 13–15 and 21–22.”*

---

### B9 — BB walk on losers (chart)

**Goal:** See if losses happen during **band walk** (persistence).

1. In Excel: filter `out` deals with **Profit < 0**; sort ascending; take **top 30–40** losses.
2. Map each to **entry time** (via `in` deal #N−1).
3. On EURUSD M5 chart, go to **signal bar** = last closed bar before entry (`inp_signal_shift = 1`).
4. Count consecutive prior bars with **close** outside the band:
   - **Long entry:** close below lower BB  
   - **Short entry:** close above upper BB  

| Result on sample | Action |
|----------------|--------|
| ≥ 60% of losers have **≥ 2** prior closes outside same band | Was theory; B9 showed **weak** — defer to Step D filter #4 optional |
| < 40% | BB walk low priority after session filter |

#### B9 checklist

- [x] **Automated** — see [`step-b-b9-b10-results.md`](step-b-b9-b10-results.md) (818 trades, MT5 bars)  
- [ ] Optional: re-run after downloading 2024 history for full 1,429 trades  

**Preliminary result:** Losers **25.8%** vs winners **24.6%** with ≥2 walk closes → **weak** BB-walk signal on analyzed subset.

---

### B10 — Wick rejection (chart)

**Goal:** Losers enter without rejection wick (continuation close).

On the **signal bar** (same as B9):

- Range = High − Low  
- Lower wick (longs) = `min(Open, Close) − Low`  
- Wick % = lower wick / range × 100 (shorts: upper wick)

Compare **10 winning longs** vs **10 losing longs** (median wick %).

| Result | Action |
|--------|--------|
| Losers clearly lower wick % | Defer — B10 weak; session filter is Step D1 |
| Similar | Deprioritize wick filter |

#### B10 checklist

- [x] **Automated** — [`step-b-b9-b10-results.md`](step-b-b9-b10-results.md)  
- [ ] Optional: manual chart check on 10 trades if you want visual confirmation  

**Preliminary result:** Median wick **16.2%** losers vs **16.7%** winners — **minimal** separation; longs +2.6 pp only.

---

### B8 — Trade quality profiles

Compare samples to the good/bad profile table in [`edge-discovery.md`](edge-discovery.md).

- [ ] 10 largest **winners** — tick profile rows that match  
- [ ] 10 largest **losers** — tick anti-habitat rows  
- [ ] Update profile notes in `baseline-eurusd-m5-20260516.md`  

---

### B7 — Prioritize filters

| Bucket | Est. damage | Evidence (B6/B9/B10) | Filter for Step D |
|--------|-------------|----------------------|-------------------|
| BB walk | | B9: __/40 | `max_closes_outside_bb` |
| NY hours / hour 13 | | B6: NY −$34 | Session / hour block |
| Wick % | | B10: medians | `min_wick_pct` |
| … | | | |

**Pick top 1–2.** Suggested from pre-computed B6 + baseline:

1. **Session** — Step **D1**: block **13:00–15:00** (B6 full sample)  
2. **BB width** — Step D2 after session passes OOS  
3. **BB walk / wick** — optional later (B9/B10 weak)

Do **not** code session + BB walk + wick in one pass. See `edge-discovery.md` Step D checklist.

#### B7 checklist

- [ ] Filter 1 hypothesis + rule written  
- [ ] Filter 2 (optional) written  
- [ ] Mark Step B complete in `edge-discovery.md`  

---

## Phase 2 — Optional buckets

Use if Phase 1 is ambiguous.

### B1 — Trend vs range (visual)

- [ ] 10 best winners + 10 worst losers on chart  
- [ ] Note: trend vs chop, distance from BB mid, momentum candles  

### B2 — BB walk (aggregate)

Same as B9; optional: tag all 263 SL rows in Excel.

### B3 — Volatility (ATR terciles)

- [ ] Mark high/medium/low ATR weeks on 20-loss sample  

### B4 — BB width

- [ ] Narrow vs wide bands at entry on same sample  

### B5 — RSI depth

In Excel (needs entry-bar RSI from chart or Step C CSV):

| RSI at entry (long) | Bucket |
|-------------------|--------|
| −30 to −35 | Shallow |
| −25 to −30 | Medium |
| < −25 | Deep |

- [ ] Sum P/L per bucket on 30+ manual rows OR defer until Step C  

---

## Excel formulas (Deals sheet)

Assume row 2 = first data row after header. Adjust row numbers if you copied the Deals block to row 1.

**Helper columns on `out` rows only:**

```excel
' Is exit row
=IF(E2="out",1,0)

' Entry time (TEXT) — match deal N to in row with deal N-1
' (Easier: sort deals; for each out, entry time is cell A on row above if that row is "in")

' Entry hour
=IF(E2="in", HOUR(A2), "")

' Is SL exit
=IF(AND(E2="out", ISNUMBER(SEARCH("sl", M2))), 1, 0)
```

**Pivot table:** Rows = Entry hour · Values = Sum Profit, Count, Sum SL flag.

**Filter worst losses:** `Direction=out` · `Profit` < 0 · Sort Profit ascending.

---

## MT5 tools (chart review)

| Task | Where |
|------|--------|
| Visual replay | Strategy Tester → Visual mode |
| Jump to trade | From deal time in Excel → chart crosshair |
| Indicators | BB 20,2 · RSI 14 · Volume |

---

## Step B vs Step C

| Phase B | Step C |
|---------|--------|
| Spreadsheet + ~40 chart reviews | EA CSV on every trade |
| Enough to pick first filter | Proves buckets on all 1,429 trades |

Proceed to **Step D** (`edge-discovery.md` checklist): session filter first; Tester validation when MT5 works. Step C optional in parallel.

---

## Step B findings — COMPLETE

> All buckets: [`step-b-complete-results.md`](step-b-complete-results.md) · **818/1429** trades (download 2024 M5 history for full set)

### B6 Hour / session

- Worst hours: **13, 15, 21–22**; NY 13–21 **−$34.30**

### B1 Trend

- **range** −$20.77 (427 trades); **mild_trend** +$4.34; **against** −$5.36

### B3–B5

- **B4:** narrow bands **+$3.97**; wide **−$11.92**
- **B5:** longs `deep_<20` / `20-25` positive; shorts `70-` / `75-80` worst

### B8–B10

- **B9/B10:** weak separators (~26% walk both sides; wick medians ~16%)
- **B8:** worst-10 table in complete results; strict `good_*` rules rare on M5

### B7 — Filters for Step D

1. **Session** — block 13–15 / NY 13–21 (B6).  
2. **Min BB width** — avoid wide band entries (B4).  
3. **RSI** — tighten short OB / prefer deep OS longs (B5).  
4. **BB walk** — optional trial only (B9 weak).

---

## References

- [`edge-discovery.md`](edge-discovery.md) — full B1–B10 checklist  
- [`baseline-eurusd-m5-20260516.md`](baseline-eurusd-m5-20260516.md) — Step A metrics  
- `ReportTester-23489.xlsx` — Orders ~row 96, Deals ~row 2956  
