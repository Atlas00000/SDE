# VEM — filter & exit roadmap

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

**Default preset:** **`VEM.AI_Skip`** — D1+D6+D7+E8c + ~**2%** entry skip. **Rollback:** **`VEM.Production`** (rules only). Exit R&D **E10/E13/E14 closed (discard)**.  
**Code defaults:** `VEM_Config.mqh` matches production (no `.set` required).  
**Benchmark:** `vem5m_d7_habitat_only.set` — same entries, E8c off.  
**Raw baseline:** `vem5m.set` — habitat + E8c off for Step A comparisons.
**Profiles:** [`trade-profile.md`](trade-profile.md) · [`Trade_Quality.md`](Trade_Quality.md)

**Phase 2b (entry + simple exits):** **complete** — D8–D9, E7–E9, E8a–E8b discarded.  
**Phase 2c (expectancy engineering):** **complete** — C1, E8c **KEEP** (production); E10 **park**; D10/D11/E11 **discard**.  
**Phase 2d (EURUSD loss containment):** **complete** — exit queue **E13/E14 discard**. **Phase 3 AI (v0.1):** **signed off** · default **`VEM.AI_Skip`**. **Phase 4:** **stalled** on exits/sizing — next: **multi-symbol** or deploy [§10](#10-phase-4--ai-expectancy--avg-loss).

**Deployment policy:** **Strategy Tester only** until production + AI gates pass on predetermined metrics. **No live/demo chart debugging** (time constraint). **AI-0 live** runs only after backtest gate clears.

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
| **D10** | — | Regime | Entry | **Discard** | Confirm bar — OOS **+$2.82** PF **1.16** vs ctrl **+$9.08** / **1.30** |
| **D11** | — | Regime | Entry | **Discard** | H1 slope — OOS **+$6.50** PF **1.26** vs ctrl **+$9.08** / **1.30** |
| **D12** | — | Habitat | Entry | Backlog | **BB/ATR widening** — block if bands/ATR **rising** 2–3 bars (expansion, not level only) |
| **D13** | — | Regime | Entry | Backlog | **EMA displacement** — only fade when price stretched from mean (old D10 idea) |
| **C1** | — | Infrastructure | Logging | **Done** | Step C CSV + `analyze_vem_trade_log.py` — thresholds for E10; **re-run on production set** in 2d step 0 |
| **C1b** | — | Infrastructure | Analysis | **Done** | Re-bucket production path — [`step-c1b-results.md`](step-c1b-results.md) · E13/E14 paused |
| **E6** | — | Exit — failure | Exit | **Done** | E1–E5 analysis complete; simple exits tested → defer to **E10** |
| **E7** | — | Exit — payoff | Exit | **Discard v1** | BE +0.5R — **null vs D7** (119/270 tr, +$6 OOS unchanged) |
| **E8** | — | Exit — failure | Exit | — | Parent; E8a/E8b discarded — use **E10** (state), not time/red alone |
| **E8a** | — | Exit — failure | Exit | **Discard** | 4 bar / 0.2R / outside BB — **WR 47%**, OOS **−$4.65** |
| **E8b** | — | Exit — failure | Exit | **Discard** | Still in loss @ 4 bars — **WR 35%**, OOS **−$4.48** |
| **E8c** | — | Exit — failure | **KEEP · prod** | Worse BB pen @ bar 4 — OOS **+$9.08** PF **1.30** WR **70%** |
| **E8c-v2** | — | Exit — failure | **Park** | min_pen **5 pts** — OOS +$9.44/PF 1.32 vs ctrl +$9.08/1.30; IS +$2.58 vs +$3.06 — prod stays **0** |
| **E8c-bar** | — | Exit — failure | **Closed** | bar **5** discard OOS −$0.43 · bar **3** optional — prod bar **4** |
| **E9** | — | Exit — payoff | Exit | **Discard** | Same as D7 @ 0.02 — partial adds no edge |
| **E10** | — | Exit — failure | **Park** | MAE/MFE @ bar 6 — WR/PF OK, net −$0.05 OOS; **prod off** |
| **E10-v2** | — | Exit — failure | **Discard** | v1 OOS +$5.54 PF 1.16 vs prod +$9.08 / 1.30 — E10 stays **off** |
| **D1b** | — | Habitat | Entry | **Discard null** | Block2 hour **7** — **identical** to prod OOS/IS (111/274 tr) |
| **D6b** | — | Habitat | Entry | **Discard** | width **0.0015** — IS 238 tr **−$1.35** PF 0.98 vs prod +$3.06 / 1.04 |
| **D7b** | — | Habitat | Entry | **Discard** | RSI **22/78** — IS 124 tr **−$1.57** PF 0.95 vs prod +$3.06 / 1.04 |
| **E13** | 7 | Exit — failure | **Discard** | T-E13: 289 tr · **−$1.10** · PF **0.99** · WR **60%** · [`step-e13-results.md`](step-e13-results.md) |
| **E14** | 8 | Exit — failure | **Discard** | T-E14: 289 tr · **−$2.46** · PF **0.97** · [`step-e14-results.md`](step-e14-results.md) |
| **E11** | — | Exit — payoff | **Discard null** | Same as production IS/OOS — partial path never differs |
| **E12** | — | Exit — payoff | Backlog | **ATR trail** after +1R — rare; only if E10/E11 done |
| **DEV-G** | — | Gate | Dev | **Done** | C1b + 2d paused — [`step-phase3-dev-g.md`](step-phase3-dev-g.md) |
| **AI-0** | P3 | Validation | Live | **Deferred** | Forward/demo when scheduled — tester C1 substitute for AI-1 |
| **AI-1** | P3 | Infrastructure | Data | **Done** | Clean C1 — 274 tr · OOS 111 / +$9.08 · `VEM.C1_Production` · no `e10` |
| **AI-2** | P3 | Intelligence | Offline | **Done · v0.1** | bad_trade + entry · [`step-ai-v1-results.md`](step-ai-v1-results.md) |
| **AI-3** | P3 | Intelligence | Offline | **KEEP offline** | 2% skip OOS · $9.83 / PF 1.34 / 109 tr |
| **AI-PASS** | P3 | Gate | Offline | **Done** | Tester T1/T3/T4/T5 · E2–E7 |
| **AI-4** | P3 | Intelligence | Tester | **Done** | `VEM.AI_Shadow` · [`step-ai4-shadow-backtest.md`](step-ai4-shadow-backtest.md) |
| **AI-5** | P3 | Intelligence | Tester | **Done** | `VEM.AI_Skip` · 389 tr · OOS +$9.83 / PF 1.34 |
| **P4-0** | P4 | Gate | — | **Done** | [`step-p4-0-signoff.md`](step-p4-0-signoff.md) · [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md) |
| **P4-1** | P4 | Intelligence | Entry | **Park offline** | v0.2 wired · [`step-ai-v2-sizing-results.md`](step-ai-v2-sizing-results.md) |
| **P4-3** | P4 | Intelligence | Exit | **Done** | bar matrix · [`step-ai-v3-bar-matrix.md`](step-ai-v3-bar-matrix.md) |
| **P4-4** | P4 | Intelligence | Exit | **Park** | v0.3 train · [`step-ai-v3-exit-results.md`](step-ai-v3-exit-results.md) |
| **P4-2** | P4 | Intelligence | Entry | Backlog | **v0.2** — loss-magnitude / tail-risk score |
| **P4-5** | P4 | Intelligence | Exit | Backlog | Wire AI exit · midline + E8c unchanged |
| **P4-6** | P4 | Ops | — | Backlog | Retrain + drift on C1 / shadow CSV |
| **P4-7** | P4 | Scale | — | **Blocked** | Lot scaling / multi-symbol — after avg loss |

**Queue** = Phase **2d** build order (0 = first). **P3** = Phase 3 entry AI. **P4** = Phase 4 expectancy AI (avg loss). Blank = done or not in active queue.

**Pass bar (vs production `vem5m_d7_session_bb_rsi.set`):** OOS net **≥ +$9.08**, PF **≥ 1.30**, WR **≥ ~65%**, trade count not collapsed; IS not materially worse than control (+$3.06 / PF 1.04).

**Do not optimize for:** avg win / partial / BE (E7/E9/E11 null) · PF 2.0 · new entry indicators (D8–D11 discarded) · multi-symbol until 2d stalls.

---

## 2. Recommended queue (Phase 2d — EURUSD backtest)

**Scope:** EURUSD M5 only · backtest before live · **one variable per build**.

**Primary levers:** ↓ **avg loss** · ↓ **SL %** · ↑ **PF** — via **structural failure** and **excursion state**, not bigger TP or more entry indicators.

**Stretch targets (OOS):** PF **1.35–1.45** · WR **≥ 65%** · avg loss **0.55–0.65R** (from ~0.72–0.91) · avg win **~0.45R** (midline-capped — do not chase).

Work **top to bottom**. Each row = one build → IS 2024–2026 + OOS 2025–2026 → KEEP/DISCARD vs **production** control.

| Step | ID | Family | What you are testing | Metric focus |
|:----:|-----|--------|----------------------|--------------|
| — | **D7 + E8c** | Base | **Done** — `vem5m_d7_session_bb_rsi.set` @ 0.01 | OOS +$9.08 · PF 1.30 · WR 70% |
| **0** | **C1b** | Analysis | Re-run C1 on **production** set; bucket **losers** (hour, BB width, RSI, exit, bars held); update `trade-profile.md` | Pick **one** ID for step 1 |
| **1** | **E8c-v2** | Exit — failure | **Done (park)** — min_pen 5: OOS +$0.36 only; prod **0** | — |
| **2** | **E8c-bar** | Exit — failure | **Closed** — bar 5 discard; bar 3 optional skip | — |
| **3** | **E10-v2** | Exit — failure | **DISCARD** — E10 off on prod | — |
| **4** | **D1b** | Habitat | **DISCARD null** — no change vs prod · next **D6b** | — |
| **5** | **D6b** | Habitat | **DISCARD** — prod **0.00165** kept · next **D7b** | — |
| **6** | **D7b** | Habitat | **DISCARD** — Phase **2d habitat sweep complete** | — |
| **7** | **E13** | Exit — failure | **DISCARD** — T-E13 FAIL vs pass bar | — |
| **8** | **E14** | Exit — failure | **DISCARD** — exit R&D **closed** | — |
| — | D12, D13, E12 | Backlog | BB/ATR **widening** entry, EMA displacement, ATR trail after +1R | Only if steps 0–8 stall |
| — | Multi-symbol | — | **Deferred** — need habitat data per pair before parameter transfer | — |
| — | **DEV-G** → **AI-0…AI-5** | Phase 3 | **Deferred** until dev gate — see §9 (forward/demo is **AI-0**, not “next” during dev) | — |

**Every new exit must answer:** *Does this cut the high-MAE / low-MFE continuation loser before full SL?* If not, skip.

**Analysis-only (no code) between builds:** exit mix (% midline / E8c / SL) · avg win/loss in **R** · walk-forward 2024 / 2025 / 2026 · optional +1–2 pt spread stress on OOS.

---

## 3. Pick by goal

| Your goal | Use this ID | Family |
|-----------|-------------|--------|
| **Improve PF (primary)** | **E8c-v2** → **E10-v2** | Exit — failure |
| **Reduce avg loss / SL %** | **E8c-v2**, **E10-v2**, **E13**, **E14** | Exit — failure |
| **Raise avg win** | **Low priority** — midline caps ~0.45R; E7/E9/E11 null | — |
| Prove where losers still live | **C1b** | Analysis |
| Avoid worst time of day | **D1** (done) · tighten **D1b** | Habitat |
| Avoid wide volatility at entry | **D6** (done) · tighten **D6b** | Habitat |
| Trade only extreme RSI | **D7** (done) · tighten **D7b** | Habitat |
| Cut band-walk / deepening penetration | **E8c** (prod) · **E8c-v2** | Exit — failure |
| Cut low-MFE + high-MAE continuation | **E10-v2** (parked base **E10**) | Exit — failure |
| Avoid fading a strong trend | ~~D8/D8b~~ **discard** | — |
| Avoid band walk at entry | ~~D9~~ **discard** | — |
| Confirmation bar / HTF gate | ~~D10/D11~~ **discard** | — |
| Log trades for bucket proof | **C1** (done) · **C1b** on production | Infrastructure |
| Partial / BE / bigger TP | ~~E7/E9/E11~~ **discard** | — |
| Block volatility **expansion** (rising ATR/BB) | **D12** | Habitat (backlog) |
| Trail after big winner | **E12** | Exit — payoff (backlog) |
| More trades, milder filters | Relax **D6b/D7b** vs production | Habitat |
| Fewer trades, stricter habitat | **D1b**, **D6b**, **D7b** | Habitat |
| Finish dev before live/AI | **DEV-G** | Gate |
| Prove prod without AI | **AI-0** | Validation (post DEV-G) |
| Build training dataset | **AI-1** | Infrastructure |
| Retry ML (v0.1+) | **AI-PASS** checklist §9 | Intelligence |
| Offline skip/score model | **AI-2** → **AI-3** | Intelligence |
| AI skip in tester | **AI-5** wire (tester) → then live | Intelligence |

---

## 4. Which loss type each ID targets

| Loss type | What happens | IDs that address it |
|-----------|--------------|---------------------|
| **A** | Price never reverts; hits full SL fast | **E8c** (prod), **E8c-v2**, **E10-v2** |
| **B** | Reached mean then gave back | Rare on D7 — ~~E11~~ discard |
| **C** | Sideways bleed then SL | **E10-v2**, **E13**, **E14** (not E8a/E8b time/red) |
| **Entry wrong regime** | NY expansion, wide BB, shallow RSI | **D1b**, **D6b**, **D7b** |

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

### C1 — Step C feature logging — **Done**

- [x] `VEM_TradeLog.mqh` + `OnTradeTransaction` + `inp_trade_log_enable`
- [x] `vem5m_d7_c1_trade_log.set` · `step-c1-d0-experiment.md`
- [x] `scripts/analyze_vem_trade_log.py`
- [x] CSV backtest + `step-c1-results.md` thresholds

### C1b — Production re-bucket (Phase 2d step 0) — **Next**

- [ ] Run C1 on `vem5m_d7_session_bb_rsi.set` (IS + OOS windows clean)
- [ ] Group losers: hour, BB width tercile, RSI bucket, exit reason, bars held
- [ ] Promote **one** follow-up ID only if bucket has **≥30 trades** and PF &lt; 1
- [ ] Update `trade-profile.md` medians from production CSV

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

### E8c-v2 — min pen delta 5 pts — **PARK**

- [x] OOS 111 tr · **+$9.44** · PF **1.32** · WR **70.27%** (ctrl +$9.08 / 1.30 / 70.3%)
- [x] IS 268 tr · **+$2.58** · PF **1.04** (ctrl 274 / +$3.06 / 1.04) — IS net **−$0.48**
- [x] **Production stays `min_pen_pts=0`** — see [`step-e8c-v2-d0-experiment.md`](step-e8c-v2-d0-experiment.md)

### E8c-bar — start bar sweep — **closed (prod bar 4)**

- [x] **v1 bar 5 DISCARD** — OOS −$0.43 / PF 0.99 vs prod +$9.08 / 1.30
- [ ] **v2 bar 3** optional skip — move to E10-v2 first

### E10-v2 — invalidation on production stack — **DISCARD v1**

- [x] OOS 113 tr · **+$5.54** · PF **1.16** · WR **69.0%** (prod +$9.08 / 1.30 / 70.3%)
- [x] **E10 stays OFF** on `vem5m_d7_session_bb_rsi.set` — [`step-e10-v2-d0-experiment.md`](step-e10-v2-d0-experiment.md)
- [x] **E10 line closed** on production stack

### E13 — Exit: MFE-gated bleed — **DISCARD**

- [x] Rule: bar **12+**, **MFE ≤ 0.20R**, **profit &lt; 0** · `VEM_Execution_CheckBleedExits()`
- [x] Preset **`VEM.E13_Production`** · charter [`step-e13-d0-experiment.md`](step-e13-d0-experiment.md)
- [x] **T-E13:** **289** tr · **−$1.10** · PF **0.99** · WR **60.2%** · avg win **$0.44** / loss **$0.68** — [`step-e13-results.md`](step-e13-results.md)
- [x] **Production:** E13 **OFF** (no promote)

### E14 — Exit: soft SL tighten — **DISCARD**

- [x] Rule: bar **6+**, **MFE ≤ 0.15R**, **MAE ≥ 0.40R** → SL at **−0.5R** · `VEM_Execution_ManageSoftSlTighten()`
- [x] Presets **`VEM.E14_Production`** · [`step-e14-d0-experiment.md`](step-e14-d0-experiment.md)
- [x] **T-E14:** **289** tr · **−$2.46** · PF **0.97** · WR **62.6%** — [`step-e14-results.md`](step-e14-results.md)
- [x] **Exit R&D closed** — default **`VEM.AI_Skip`** · E13/E14/E10 **OFF**

### D1b — block hour 7 — **DISCARD (null)**

- [x] OOS/IS **identical** to production (111 / +$9.08 / PF 1.30 · 274 / +$3.06 / 1.04)
- [x] **block2 stays off** on prod set
### D6b — tighter BB width 0.0015 — **DISCARD**

- [x] IS **238** tr · **−$1.35** · PF **0.98** (prod **274** / **+$3.06** / **1.04**)
- [x] Prod stays **`inp_bb_max_width_ratio=0.00165`**
### D7b — tighter RSI 22/78 — **DISCARD**

- [x] IS **124** tr · **−$1.57** · PF **0.95** · WR **60.5%** (prod IS **274** / **+$3.06** / **1.04**)
- [x] **Phase 2d closed** — production unchanged

### Phase 2d complete — locked production

- **Set:** `vem5m_d7_session_bb_rsi.set` · OOS ref **111 tr / +$9.08 / PF 1.30 / WR 70%**
- **Stack:** D1 (13–15) · D6 (0.00165) · D7 (RSI ≤25 / ≥75) · midline · **E8c @ bar 4** · E10 **off**
- **Next (dev):** **C1b** · optional **E13/E14** with C1 thesis — **not** forward/demo until **DEV-G** (§9)

### DEV-G — Dev parameter gate (before live / AI data) — **Done**

- [x] Production locked: `vem5m_d7_session_bb_rsi.set` · D1+D6+D7+E8c · pass bar documented
- [x] **C1b** complete — [`step-c1b-results.md`](step-c1b-results.md) · `trade-profile.md` updated
- [x] Phase 2d rule queue **done or paused** (E13/E14 paused — no bucket promotion)
- [x] Sign-off: [`step-phase3-dev-g.md`](step-phase3-dev-g.md)

### Phase 3 (AI) — see **§9**

All AI todos (**AI-0** … **AI-5**) and the **AI pass checklist** live in [§9 Phase 3](#9-phase-3--ai-intelligence-layer-sequenced-todos). §6 keeps experiment IDs (D/E) only.

### E8c-bar / E10-v2 / D1b / D6b / D7b / E13 / E14 — Phase 2d

- [ ] One hypothesis per `step-*-d0-experiment.md` · control = production set
- [ ] E10-v2: only after E8c-v2 KEEP/DISCARD; do not stack with E8c in v1 without charter

### D12 / D13 / E12 — Backlog

- [ ] Same pattern when Phase 2d queue stalls

---

## 7. Do not do yet

- Multiple IDs in one build  
- Global tighter SL (200→100) for all trades — winners need ~0.2–0.5R breathing room  
- E8b-style exit: **profit &lt; 0** or **time alone** after N bars  
- E8a-style exit: **low MFE OR outside BB** (OR kills winners)  
- E7 / E9 / E11 partial or BE — **null** on production  
- D10 / D11 confirmation or HTF entry — **discard**  
- Chasing **avg win** or PF 2.0 — midline caps payoff  
- Multi-symbol parameter copy — **deferred**  
- Large parameter optimization grids  
- Martingale, **AI train/deploy before DEV-G**, random new indicators  
- More M5 cosmetic filters (walk, wick, ±3 bp slope) — proven weak on D7  
- **Forward/demo (AI-0)** while still running Phase 2d backtest sweeps — time-consuming; only after **DEV-G**  
- **Live AI veto (AI-5)** before **AI-PASS** checklist §9 complete  

---

## 8. Target end state (reminder)

**Production today:** **D1 + D6 + D7 + midline + E8c** @ 0.01.

**Phase 2d goal:** same habitat · **smarter failure recognition** (E8c-v2, E10-v2, optional E13/E14) · optional **micro habitat** (D1b/D6b/D7b) → WR **≥ ~65%**, **avg loss 0.55–0.65R**, OOS PF **≥ 1.35** without collapsing trade count. Winners stay on **midline**; losers exit on **structure worsen** or **MFE/MAE invalidation**, not time-in-red alone.

**After 2d stalls (dev):** finish **DEV-G** → then **AI-0** forward/demo — not more backtest micro-filters unless C1b opens E13/E14.

---

## 9. Phase 3 — AI intelligence layer (sequenced todos)

**Role:** trade-quality / regime scoring **on top of** locked D1+D6+D7+E8c — not replacement habitat or exit grids.

**Production today:** rules-only · preset **`VEM.Production`**. **Model tried:** logistic regression v0 (`scripts/train_ai_v0.py`) — **parked**.

**Architecture:** `[Rules: signal]` → `[AI: score]` → `[Enter/skip/size]` → `[Rules: midline + E8c]`

### Status overview

| Order | ID | Status | One line |
|:-----:|-----|--------|----------|
| 0 | **DEV-G** | **Done** | Dev gate — [`step-phase3-dev-g.md`](step-phase3-dev-g.md) |
| 1 | **AI-1** | **Done** | Clean C1 · `VEM.C1_Production` · 274 tr · OOS 111 / +$9.08 |
| 2 | **AI-2** | **Done · v0.1** | [`step-ai-v1-results.md`](step-ai-v1-results.md) |
| 3 | **AI-3** | **KEEP offline** | 2% skip · $9.83 / 109 tr |
| — | **AI-PASS** | **Next** | **B2** onward (**A1–A5** done) |
| 4 | **AI-0** | **Deferred** | Demo/forward optional |
| 5 | **AI-4** | **Done** | Tester shadow — [`step-ai4-shadow-backtest.md`](step-ai4-shadow-backtest.md) |
| 6 | **AI-5** | **Done** | `VEM.AI_Skip` validated in tester |

---

### AI pass checklist — unlock **AI-4 / AI-5** (`AI-PASS`)

*v0 failed. Work **A1 → E3** in order. **D6–D10** = pass bar (production control).*

| Block | Tasks | Status |
|-------|-------|--------|
| **A** Data | A1–A5 | **Done** · 396 tr 2023–2026 (deduped) |
| **B** Labels & features | B1–B6 | **Done** (B6 skip) |
| **C** Train & metrics | C1–C7 | **Done** (logistic v0.1) |
| **D** Skip simulation | D1–D10 | **Done** (v0.1 pass · v0 fail D10) |
| **E** Tester gates | E1–E7 | **E2–E4 done** · E5–E7 = AI-5 |

---

#### A) Data (A1–A5)

- [x] **A1** — Clean C1 CSV (no `e10`) · [`step-ai-pass-a-data.md`](step-ai-pass-a-data.md)
- [x] **A2** — **396** tr · 2023.01–2026.05 · +$16.58 full · PF 1.17 (matches tester)
- [x] **A3** — Archive: `data/c1/VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` (deduped)
- [x] **A4** — Splits: train **2023** · val **2024** · test **2025+** · `manifest.json`
- [x] **A5** — Val **163** trades (2024 slice)

#### B) Labels & features (B1–B6)

- [x] **B1** — v0 baseline logged: entry-only + `label_loss` / `label_sl` — insufficient
- [x] **B2** — Rule: [`data/c1/bad_trade_rule.json`](data/c1/bad_trade_rule.json)
- [x] **B3** — `scripts/train_ai_v1.py` → `label_bad_trade`
- [x] **B4** — **N/A at entry** — path cols are post-trade; use for future bar-4 model only
- [x] **B5** — Entry features in `train_ai_v1.py`
- [x] **B6** — Skipped (v0.1 logistic sufficient)

#### C) Model quality — offline (C1–C7)

- [x] **C1** — [`step-ai-v1-results.md`](step-ai-v1-results.md) on 396-tr archive
- [x] **C2** — Logistic + scaler · `train_ai_v1.py`
- [x] **C3** — Val AUC **0.600** (pass)
- [x] **C4** — Test AUC **0.609** (pass)
- [x] **C5** — Top decile bad_trade **27%** · mix sl/e8c/midline
- [x] **C6** — HGB tested — **worse** than logistic ([`step-ai-v1-hgb-results.md`](step-ai-v1-hgb-results.md))
- [x] **C7** — Export: `models/ai_v1_logistic_bad_trade.json`

#### D) AI-3 skip simulation — pass bar (D1–D10)

*Control: `vem5m_d7_session_bb_rsi.set` · OOS **111 tr / +$9.08 / PF 1.30 / WR ~70%***

- [x] **D1** — OOS window 2025–2026 · n=111
- [x] **D2** — Val tune (2024) · pass-bar policy separate on OOS
- [x] **D3** — Optimize net $ · smallest skip that **beats** baseline
- [x] **D4** — **2% skip** · 2 trades removed · see v1 results
- [x] **D5** — Net **$9.83** >= $9.08
- [x] **D6** — PF **1.34** >= 1.30
- [x] **D7** — WR **70.6%** >= 65%
- [x] **D8** — **109** trades >= 100
- [ ] **D9** — Full-span IS not re-checked on 396-tr (2023–26 mix) — optional
- [x] **D10** — v0 fail retained for history

#### E) Gates after D5–D9 pass (E1–E7)

- [x] **E1** — **AI-3 KEEP (offline)** in master table
- [x] **E2** — Shadow CSV `VEM_ai_shadow_*.csv` · MT5 score = Python (max Δ **0.0001**)
- [x] **E3** — Tester `VEM.AI_Shadow` · **396** opened = C1 · **4223** signal rows
- [x] **E4** — [`scripts/validate_ai_shadow.py`](scripts/validate_ai_shadow.py) · OOS skip **2** tr · net **$9.83** (matches AI-3)
- [x] **E5** — Charter: **entry skip** chosen (0.5× lot → **P4-1**)
- [x] **E6** — **AI-5** wired · preset `VEM.AI_Skip`
- [x] **E7** — Rollback: `VEM.Production` = **396** / +$16.58 / PF 1.17

---

### AI-0 — Live validation — **Blocked until backtest gate**

*Not used during dev — tester substitutes AI-1 / AI-4.*

- [ ] **Only after:** production OOS pass bar stable + **AI-5** pass in tester
- [ ] Deploy **`VEM.AI_Skip`** on live (default) · or **`VEM.Production`** rollback · journal only
- [ ] Rolling metrics vs OOS ref (111 tr / +$9.08 / PF 1.30)

### AI-1 — Accumulate C1 — **Done**

- [x] **`VEM.C1_Production`** backtest · 274 tr · OOS 111 / +$9.08 / PF 1.30
- [x] Clean CSV — no `e10`
- [x] `c1b_production_buckets.py` + `train_ai_v0.py` run

### AI-2 — Offline model — **Done (v0.1)**

- [x] v0 entry-only — parked
- [x] v0.1 `scripts/train_ai_v1.py` · `label_bad_trade` · [`step-ai-v1-results.md`](step-ai-v1-results.md)
- [x] Model: `models/ai_v1_logistic_bad_trade.json` · skip **2%** on OOS

### AI-3 — Skip simulation — **KEEP (offline)**

- [x] v0 discard · v0.1 **pass** D5–D8 with minimal skip
- [x] Tester shadow before **AI-5** (not live)

### AI-4 — Shadow mode — **Done (tester)**

- [x] `VEM_AI.mqh` + `VEM_AIShadow.mqh` · `scripts/export_ai_model_mqh.py` · `scripts/validate_ai_shadow.py`
- [x] Preset **`VEM.AI_Shadow`** · **T3 PASS** · **396** tr · **+$16.58** · PF **1.17** · `ai_skip=0`
- [x] Scorer parity · [`step-ai4-shadow-backtest.md`](step-ai4-shadow-backtest.md) · E4 OOS hypothetical **2** skips · **$9.83**

### AI-5 — Wire into MT5 — **Ready for tester run**

- [x] `inp_ai_skip_enable` blocks entry after habitat pass · midline + E8c unchanged
- [x] Preset **`VEM.AI_Skip`** · rollback = **`VEM.Production`** (both AI inputs off)
- [x] **You:** `VEM.AI_Skip` — **389** tr · **+$20.30** · PF **1.21** · OOS **109 / +$9.83 / PF 1.34** (C1 block 3)
- [x] **E7:** `VEM.Production` ×2 — **396** tr · **+$16.58** · PF **1.17** (C1 blocks 1–2 identical)

---

## 10. Phase 4 — AI expectancy (↓ avg loss)

**When:** After Phase 3 tester gate (**AI-5** + production rollback). **Before:** lot scaling, multi-symbol, live AI promote.

**Problem (unchanged):** WR and PF are acceptable (~**65–70%**, PF **~1.2–1.3**, DD **~6–10%**). **Avg loss (~0.72–0.9R)** exceeds **avg win (~0.45R)** because losers often reach **full SL**; midline caps winners. Entry skip (v0.1) removes a few bad trades — it does **not** shrink loss depth on trades kept.

**Do not optimize:** PF 2.0 · bigger TP / avg win · heavy new entry filters · live without tester pass.

**Pass bar (vs `VEM.Production` control):** OOS net **≥ +$9.08** · PF **≥ 1.30** · WR **≥ 65%** · trades **≥ 100** · **avg loss in R** materially lower (target **0.55–0.65R**) · IS not worse than control.

**Architecture (target):**

```text
[Rules: D1+D6+D7 signal] → [AI entry: skip / half lot] → [Rules: midline + E8c]
                              ↓
                    [AI bar-state: early invalidation exit]
```

### Phase 4 status overview

| Order | ID | Status | One line |
|:-----:|-----|--------|----------|
| 0 | **P4-0** | **Done** | [`step-p4-0-signoff.md`](step-p4-0-signoff.md) |
| 1 | **P4-1** | **Park** | v0.2 wired · OOS sim **FAIL** vs skip-only |
| 2 | **P4-2** | Backlog | v0.2 — tail-loss / SL probability at entry |
| 3 | **P4-3** | **Next** | v0.3 — C1 labels @ bar 4–6 (path features) |
| 4 | **P4-4** | **Park** | v0.3 trained · offline **FAIL** vs prod OOS |
| 5 | **P4-5** | Backlog | Tester wire — one early-exit hook (E10/E14 bridge) |
| 6 | **P4-6** | Backlog | Retrain + drift (`validate_ai_shadow.py` pattern) |
| 7 | **P4-7** | Blocked | Scaling / symbols — after P4 pass |

---

### P4-0 — Phase 3 sign-off — **Done**

- [x] `VEM.Production` — **396** / +$16.58 / PF 1.17
- [x] `VEM.AI_Shadow` — scorer parity · no `ai_skip`
- [x] `VEM.AI_Skip` — **389** / +$20.30 · OOS **109** / +$9.83 / PF 1.34
- [x] Runbook: [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md) · sign-off: [`step-p4-0-signoff.md`](step-p4-0-signoff.md)

### P4-1 — AI v0.2 graduated sizing — **Park (offline FAIL)**

*Charter: high → skip; medium → **0.5× lot**; low → full.*

- [x] Medium band: score ∈ **[0.501, 0.874)** · val pct **57** · [`models/ai_v2_sizing.json`](models/ai_v2_sizing.json)
- [x] `scripts/train_ai_v2_sizing.py` · [`step-ai-v2-sizing-results.md`](step-ai-v2-sizing-results.md)
- [x] `inp_ai_half_lot_enable` + `inp_ai_half_lot_prob_min` in `VEM_Config.mqh`
- [x] Preset **`VEM.AI_HalfLot`** (skip + half)
- [x] Offline OOS: skip+half **$7.81** PF **1.46** vs skip-only **$9.83** / prod **$9.08** → **DISCARD** for promote
- [ ] Optional tester **`T-HALF`** confirm (not required for P4-3)

### P4-2 — AI v0.2 tail-risk at entry — **Backlog**

- [ ] Label: `label_sl` or `mae_r_b6 >= 0.5` (C1 archive)
- [ ] Train regressor/classifier on entry + optional context
- [ ] Skip or 0.5× only when predicted tail loss high
- [ ] Compare to P4-1 — pick one sizing/skip policy for wire

### P4-3 — AI v0.3 bar-state data — **Next**

*Uses C1 path cols — **not** available at signal time (see B4).*

- [x] Export bar-5/6 matrix — `scripts/export_ai_v3_bar_matrix.py` → [`data/c1/ai_v3_bar_matrix.csv`](data/c1/ai_v3_bar_matrix.csv) · [`step-ai-v3-bar-matrix.md`](step-ai-v3-bar-matrix.md)
- [x] Labels: `label_invalid` (SL / deep loss / bad e8c) in export + train script
- [ ] Train/val/test same splits as `manifest.json`
- [ ] No leakage: features only from bars ≤ 6 after entry

### P4-4 — AI v0.3 offline exit model — **Park (offline FAIL)**

- [x] `scripts/train_ai_v3_exit.py` — logistic · [`step-ai-v3-exit-results.md`](step-ai-v3-exit-results.md)
- [x] Val AUC **0.71** · test b6 AUC **0.88** — but **no thr** beats prod OOS **$9.08** on sweep
- [x] Export **`models/ai_v3_exit_logistic.json`** · `offline_recommendation: no_wire`
- [ ] MQL5 include + tester — **P4-5** only if new hypothesis (narrower band / bar-4 features)

### P4-5 — Wire in-trade AI exit — **Backlog**

*Bridges parked **E10** / backlog **E13/E14** — one rule only.*

- [ ] Shadow mode: log `ai_exit_score` @ bar 4/6 · no close (mirror AI-4)
- [ ] `inp_ai_exit_enable` — close or tighten when score &gt; threshold
- [ ] Preset `VEM.AI_Exit` · midline + E8c precedence unchanged
- [ ] Tester rollback: AI exit off = `VEM.Production` identical

### P4-6 — Retrain & drift — **Backlog**

- [ ] Quarterly C1 refresh → `ai_data_setup.py` + retrain v1/v3
- [ ] `validate_ai_shadow.py` extended for exit scores
- [ ] Alert if shadow feature distribution drifts vs train

### P4-7 — Scale & deploy — **Blocked**

- [ ] Live **AI-0** with **`VEM.AI_Skip`** (default) · rollback `VEM.Production`
- [ ] Exit AI (`VEM.AI_Exit`) — **not pursued** (P4 exit R&D closed)
- [ ] Lot scaling · multi-symbol — **out of scope** until P4 stall or pass
