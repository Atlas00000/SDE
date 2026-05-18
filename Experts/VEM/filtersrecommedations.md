# VEM — Phase 2b roadmap

**Rule:** one ID per build → backtest → KEEP or DISCARD → next ID.

**ID prefix**

| Prefix | Meaning | When it runs |
|--------|---------|--------------|
| **D** | Entry filter | Blocks or allows a **new** trade at signal time |
| **E** | Exit rule | Closes or manages an **open** trade |

**Filter families**

| Family | What it is for |
|--------|----------------|
| **Habitat** | Time and volatility — *where* MR is safer |
| **Regime** | Trend and price structure — *avoid continuation / band walk* |
| **Exit — failure** | Cut trades that are not reverting |
| **Exit — payoff** | Protect or bank profit on good reversions |

**Current problem:** good/bad entries look similar at signal time; **losers use ~full SL**, winners rarely need 1R → improve PF via **trade-state exits** (cut invalid reversions), not more entry cosmetics.

**Production (default):** `vem5m_d7_session_bb_rsi.set` — D1 + D6 + D7 + **E8c** @ **0.01** · midline on · E8a/E8b/E10 **OFF**.  
**Benchmark:** `vem5m_d7_habitat_only.set` — same entries, no E8c.
**Profiles:** [`trade-profile.md`](trade-profile.md) · [`Trade_Quality.md`](Trade_Quality.md)

**Phase 2b (entry + simple exits):** **complete** — D8–D9, E7–E9, E8a–E8b discarded.  
**Phase 2c (expectancy engineering):** active — logging → adaptive failure exit → optional entry path/HTF.

---

## 1. Master task list (all IDs)

*This is the main reference. Every task is one row.*

| ID | Queue | Family | Layer | Status | What it achieves (one line) |
|----|:-----:|--------|-------|--------|-----------------------------|
| **D1** | — | Habitat | Entry | **Done** | Blocks bad **hours** (server 13–15) — less chop / continuation |
| **D6** | — | Habitat | Entry | **Done** | Blocks **wide BB** — skip volatile, unstable mean-reversion |
| **D7** | — | Habitat | Entry | **Done · base** | Requires **deeper RSI** — fewer, sharper fades only (**locked stack**) |
| **D8** | — | Regime | Entry | **Discard** | EMA slope ±5 bp — null vs D7 |
| **D8b** | — | Regime | Entry | **Discard** | ±3 bp — null vs D7 (same as D8) |
| **D9** | — | Regime | Entry | **Discard** | BB walk ≥2 closes — fired but **OOS −$4.81** vs D7 **+$6** |
| **D10** | 4 | Regime | Entry | **Discard** | Confirm bar — OOS **+$2.82** PF **1.16** vs ctrl **+$9.08** / **1.30** |
| **D11** | 5 | Regime | Entry | **Discard** | H1 slope — OOS **+$6.50** PF **1.26** vs ctrl **+$9.08** / **1.30** |
| **D12** | — | Habitat | Entry | Backlog | **BB/ATR widening** — block if bands/ATR **rising** 2–3 bars (expansion, not level only) |
| **D13** | — | Regime | Entry | Backlog | **EMA displacement** — only fade when price stretched from mean (old D10 idea) |
| **C1** | 0 | Infrastructure | Logging | Todo | **Step C CSV** — entry snapshot + per-bar MAE/MFE on **D7** closes (validate E10 buckets) |
| **E6** | — | Exit — failure | Exit | **Done** | E1–E5 analysis complete; simple exits tested → defer to **E10** |
| **E7** | — | Exit — payoff | Exit | **Discard v1** | BE +0.5R — **null vs D7** (119/270 tr, +$6 OOS unchanged) |
| **E8** | — | Exit — failure | Exit | — | Parent; E8a/E8b discarded — use **E10** (state), not time/red alone |
| **E8a** | — | Exit — failure | Exit | **Discard** | 4 bar / 0.2R / outside BB — **WR 47%**, OOS **−$4.65** |
| **E8b** | — | Exit — failure | Exit | **Discard** | Still in loss @ 4 bars — **WR 35%**, OOS **−$4.48** |
| **E8c** | 2 | Exit — failure | **KEEP** | Worse BB pen @ bar 4 — OOS **+$9.08** PF **1.30** WR **70%** |
| **E9** | — | Exit — payoff | Exit | **Discard** | Same as D7 @ 0.02 — partial adds no edge |
| **E10** | 1 | Exit — failure | **Park** | MAE/MFE @ bar 6 — WR/PF OK, net −$0.05 OOS; **prod stays D7 off** |
| **E11** | 6 | Exit — payoff | **Discard null** | Same as production IS/OOS — partial path never differs |
| **E12** | — | Exit — payoff | Backlog | **ATR trail** after +1R — rare; only if E10/E11 done |

**Queue** = Phase **2c** build order (0 = first). Blank = done or not in active queue.

**E10 pass bar (vs D7):** OOS net **≥ +$6**, PF **≥ 1.17**, WR **≥ ~65%** — same as E8b charter.

---

## 2. Recommended queue

Work **top to bottom**. Each line = **one** build → IS/OOS → KEEP/DISCARD.

| Step | ID | Family | What you are testing |
|:----:|-----|--------|----------------------|
| 0 | **D7** | Habitat (base) | **Done** — production `vem5m_d7_session_bb_rsi.set` @ 0.01 |
| **0** | **C1** | Logging | Step C CSV on D7 — confirm winner/loser **evolution** split before tuning E10 |
| **1** | **E10** | Exit — failure | Invalidation: low MFE + high MAE after **5–6** bars (not time/red alone) |
| **2** | **E8c** | Exit — failure | Worse structure (further outside BB) — only if E10 partial or discard |
| **3** | — | Analysis | Re-bucket from C1 CSV; update `trade-profile.md` medians on D7-only |
| **4** | **D10** | Regime entry | Confirmation bar — fewer trades, less continuation at entry |
| **5** | **D11** | Regime entry | HTF gate — trend vs exhaustion |
| **6** | **E11** | Exit — payoff | Let winners breathe **after** MFE proof (not before midline) |
| — | D12, D13, E12 | — | Backlog — only if 2c queue stalls |

---

## 3. Pick by goal

| Your goal | Use this ID | Family |
|-----------|-------------|--------|
| Avoid worst time of day | **D1** | Habitat |
| Avoid wide / crazy volatility at entry | **D6** | Habitat |
| Trade only extreme RSI | **D7** | Habitat |
| Avoid fading a strong trend | **D8** | Regime |
| Avoid entering during band walk | **D9** | Regime |
| Require stretch from mean before fade | **D10** | Regime |
| Block volatility explosion (if D6 not enough) | **D11** | Habitat |
| Cut invalid reversions early (keep winners) | **E10** | Exit — failure (MAE/MFE state) |
| Cut losers getting worse structurally | **E8c** | Exit — failure (after E10) |
| Separate good/bad when entry looks the same | **D10** / **D11** | Entry path + HTF |
| Log trades for bucket proof | **C1** | Infrastructure |
| Stop good trades giving back profit | ~~E7~~ **E11** | Exit — payoff (after MFE proof) |
| Take profit at mean, keep a runner | ~~E9 discarded~~ | — |
| Trail only after trade already won | **E12** | Exit — payoff (backlog) |
| More trades, milder filters | Base **D6** | Habitat stack |
| Fewer trades, stricter entries | Base **D7** | Habitat stack |

---

## 4. Which loss type each ID targets

| Loss type | What happens | IDs that address it |
|-----------|--------------|---------------------|
| **A** | Price never reverts; hits full SL fast | D10, D11, **E10**, E8c |
| **B** | Reached mean then gave back | E11 (rare on D7 — midline dominates) |
| **C** | Sideways bleed then SL | ~~E8a, E8b~~ → **E10** (high MAE + low MFE) |

---

## 5. Done items (reference only)

| ID | Code / set | One-line rule |
|----|------------|---------------|
| D1 | `VEM_Risk_CheckSession()`, `vem5m_d1_session.set` | Block hours 13–15 on signal bar |
| D6 | `VEM_Risk_CheckBBWidth()`, `vem5m_d6_session_bbwidth.set` | Block if BB width ratio > max |
| D7 | `VEM_Risk_CheckRSIDepth()`, `vem5m_d7_session_bb_rsi.set` | Long RSI ≤ 25, short RSI ≥ 75 |

---

## 6. Implementation checklist (per ID)

Copy the block for the ID you are building. **Do not tick the next ID until current one is KEEP or DISCARD.**

### D8 / D8b — Regime: EMA slope — **DISCARD**

- [x] D8 ±5 bp and D8b ±3 bp — null vs D7; keep **EMA slope OFF**

### D9 — Regime: BB walk — **DISCARD**

- [x] Tested min closes **2** — 44 OOS / 115 IS vs D7 119 / 270
- [x] **DISCARD** — keep **BB walk OFF** on D7 habitat

### E8a — Exit: failure-to-revert — **DISCARD**

- [x] Tested bars **4**, MFE **0.2R**, outside BB **on**
- [x] **DISCARD** — keep **failure exit OFF**; avg loss fell but WR destroyed edge

### E7 — Exit: breakeven — **DISCARD v1**

- [x] Tested +0.5R trigger — **identical** to D7 IS/OOS
- [x] **DISCARD** — keep **breakeven OFF** on `vem5m_d7_session_bb_rsi.set`

### E8b — Exit: time-in-loss — **DISCARD**

- [x] Tested mode **2**, bars **4** — 122 OOS / 293 IS vs D7 119 / 270
- [x] **DISCARD** — WR **~35%** (worse than E8a); keep **failure exit OFF** (mode **0**)

### E9 — Exit: partial midline TP — **DISCARD**

- [x] `inp_partial_midline_*` + `VEM_Execution_MidlineExits()`
- [x] `vem5m_e9_d7_partial_midline.set` (pct **0.6**)
- [x] `step-e9-d0-experiment.md`
- [x] **DISCARD** — matches D7 @ 0.02; no partial edge
- [x] **Production:** `vem5m_d7_session_bb_rsi.set` @ **0.01** (best risk/WR) unless you accept 0.02 IS/DD for more OOS $

### C1 — Step C feature logging — **code ready**

- [x] `VEM_TradeLog.mqh` + `OnTradeTransaction` + `inp_trade_log_enable`
- [x] `vem5m_d7_c1_trade_log.set` · `step-c1-d0-experiment.md`
- [x] `scripts/analyze_vem_trade_log.py`
- [x] CSV backtest + `step-c1-results.md` thresholds

### E10 — Exit: MAE/MFE invalidation — **MARGINAL KEEP (park)**

- [x] IS/OOS vs D7 — [`step-e10-d0-experiment.md`](step-e10-d0-experiment.md)
- [x] OOS: 113 tr · **+$5.95** · PF **1.18** · WR **69%** (ctrl +$6 / 1.17 / 69%)
- [x] IS: 269 tr · **−$0.06** · PF **1.00** (ctrl −$0.38 / 0.99)
- [x] **Parked** — E10 off; E8c is production exit

### E8c — Exit: worse structure — **KEEP**

- [x] OOS: 111 tr · **+$9.08** · PF **1.30** · WR **70%** (ctrl +$6 / 1.17 / 69%)
- [x] IS: 274 tr · **+$3.06** · PF **1.04** (ctrl −$0.38 / 0.99)
- [x] **Production:** merged into `vem5m_d7_session_bb_rsi.set` · full span **915 tr / +$34.44 / PF 1.15**

### D10 — Entry: confirmation bar — **DISCARD**

- [x] OOS: 80 tr · **+$2.82** · PF **1.16** · WR **65%** (ctrl 111 / +$9.08 / 1.30 / 70%)
- [x] IS: 200 tr · **−$0.33** · PF **0.99** (ctrl +$3.06 / 1.04)
- [x] **Production:** `inp_confirm_bar_enable` **off** on default set

### D11 — Entry: HTF regime gate — **DISCARD**

- [x] OOS: 95 tr · **+$6.50** · PF **1.26** · WR **69%** (ctrl 111 / +$9.08 / 1.30 / 70%)
- [x] IS: 239 tr · **+$0.76** · PF **1.01** (ctrl +$3.06 / 1.04)
- [x] **Production:** `inp_htf_regime_enable` **off**

### E11 — Payoff after MFE proof — **DISCARD (null)**

- [x] IS/OOS **identical** to production (274 / +$3.06 / 111 / +$9.08)
- [x] Same class as E7/E9 — midline dominates before runner logic matters
- [x] **`inp_e11_payoff_enable` off** on `vem5m_d7_session_bb_rsi.set`

### D12 / D13 / E12 — Backlog

- [ ] Same pattern when queue reaches them

---

## 7. Do not do yet

- Multiple IDs in one build  
- Global tighter SL (200→100) for all trades — winners need ~0.2–0.5R breathing room  
- E8b-style exit: **profit &lt; 0** or **time alone** after N bars  
- E8a-style exit: **low MFE OR outside BB** (OR kills winners)  
- Large parameter optimization grids  
- Martingale, ML, random new indicators  
- More M5 cosmetic filters (walk, wick, ±3 bp slope) — proven weak on D7  

---

## 8. Target end state (reminder)

**Habitat** (D7) + **trade-state failure exit** (E10 soft scratch + hard 1R backup) + optional **confirmation/HTF** entries → WR stays **~65%+**, **smaller avg loss**, PF **≥ 1.1** OOS. Winners keep midline path; losers cut at ~0.5R when MFE/MAE say “continuation.”
