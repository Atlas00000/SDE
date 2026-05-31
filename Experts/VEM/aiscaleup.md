# VEM — AI scale-up roadmap

**Purpose:** Scale the AI layer from v0.1 logistic skip → richer data, labels, models, and (later) regime / risk / execution intelligence.

**Rule:** Same as [`filtersrecommedations.md`](filtersrecommedations.md) — **one ID per build** → backtest or offline gate → KEEP or DISCARD → next ID.

**Production baseline (unchanged):** **D1 + D6 + D7 + midline + E8c** · preset **`VEM.AI_Skip`** (v0.1 logistic ~2% entry veto) · rollback **`VEM.Production`**.

**Pass bar (promote anything to default):** OOS net **≥ +$9.08** · PF **≥ 1.30** · WR **≥ 65%** · trades **≥ 100** · avg loss in R **↓** vs control (target **0.55–0.65R**) · IS not worse than `VEM.Production` / `VEM.AI_Skip`.

**Related docs:** [`filtersrecommedations.md`](filtersrecommedations.md) · [`README.md`](README.md) · [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md) · [`addtionalnotes.md`](addtionalnotes.md) · Phase 4 §10 in filters doc.

---

## ID prefix (this roadmap)

| Prefix | Meaning |
|--------|---------|
| **C** | Trade logging / data infrastructure |
| **B** | Labels & feature definitions (offline) |
| **AI-** | Intelligence (offline train → tester shadow → wire) |
| **P5-** | Phase 5 scale-up gate (optional rollup) |

**Phase map**

| Phase | Name | Focus |
|:-----:|------|--------|
| **P3** | AI entry v0.1 | **Done** — C1, logistic, `VEM.AI_Skip` |
| **P4** | AI expectancy | **Active / stalled** — ↓ avg loss (bar-4/6 exit, tail-risk) |
| **P5** | AI scale-up | **This doc** — data → labels → XGB → skip promote → later regime/risk/SL |
| **P5-L** | Build later | Regime, dynamic risk, delay, dynamic SL/TP — **blocked on P5 foundation** |

---

## Architecture (target end state)

```text
[Rules: D1+D6+D7 signal]
        ↓
[C2 log @ signal + bar 4/6/close]
        ↓
[AI entry: skip (XGB) / optional half-lot / optional regime gate]
        ↓
[Rules: midline + E8c]
        ↓
[Optional: AI bar-state exit — P4-5 / v0.3 revival]
        ↓
[Build later: dynamic risk · delay · dynamic SL/TP — only if P5+P4 pass]
```

---

## 1. Master task list (P5 scale-up)

| ID | Phase | Layer | Status | What it achieves (one line) |
|----|:-----:|-------|--------|-----------------------------|
| **C1** | P3 | Logging | **Done** | v1 CSV · `VEM_TradeLog.mqh` · `analyze_vem_trade_log.py` |
| **C2** | P5 | Logging | **Done** | Archive 408 tr (2023+) — [`step-c2-report.md`](step-c2-report.md) |
| **C2a** | P5 | Logging | **Done** | Preset `VEM.C2_Production` · `data/c2/manifest.json` |
| **C2b** | P5 | Logging | **Done** | Bar 4/5/6 + structure cols in `VEM_TradeLog.mqh` |
| **B7** | P5 | Labels | **Done** | [`step-b7-results.md`](step-b7-results.md) · `data/c2/label_rules.json` |
| **B7a** | P5 | Labels | **Done** | `label_bad_entry` · `label_tail_loss` |
| **B7b** | P5 | Labels | **Done** | `label_early_cut` (+ b4/b6) |
| **B7c** | P5 | Labels | **Done** | `label_regime` — trend/volatile/chop/range |
| **B8** | P5 | Labels | **Done** | `label_profile_good` / `label_profile_bad` |
| **B9** | P5 | Labels | **Done** | QA in `step-b7-results.md` · split balance |
| **AI-2** | P3 | Scorer | **Done · v0.1** | Logistic `label_bad_trade` · [`step-ai-v1-results.md`](step-ai-v1-results.md) |
| **AI-5** | P3 | Skip | **Done** | `VEM.AI_Skip` · ~2% veto · OOS +$9.83 / PF 1.34 |
| **AI-6** | P5 | Scorer | **Park** | XGB offline **FAIL** pass bar — [`step-ai-v6-results.md`](step-ai-v6-results.md) |
| **AI-6a** | P5 | Scorer | **Done** | `scripts/train_ai_v6_xgb.py` |
| **AI-6b** | P5 | Scorer | **Done** | Walk-forward splits from `data/c2/manifest.json` |
| **AI-7** | P5 | Scorer | Backlog | Shadow parity — only if AI-6 re-run passes |
| **AI-8** | P5 | Skip | **Keep v0.1** | `VEM.AI_Skip` logistic — XGB does not beat pass bar on C2 |
| **P5-0** | P5 | Gate | Backlog | Sign-off: C2 + B7 + AI-6/7/8 vs `VEM.AI_Skip` control |
| **P4-3** | P4 | Data | **Done** | Bar matrix export · [`step-ai-v3-bar-matrix.md`](step-ai-v3-bar-matrix.md) |
| **P4-4** | P4 | Exit model | **Park** | v0.3 logistic exit — offline FAIL · [`step-ai-v3-exit-results.md`](step-ai-v3-exit-results.md) |
| **P4-5** | P4 | Exit wire | **Park** | `label_early_cut` — no OOS lift · [`step-p45-exit-results.md`](step-p45-exit-results.md) |
| **P4-2** | P4 | Entry | **Shadow ready** | Tail-loss skip — [`step-p4-2-tail-results.md`](step-p4-2-tail-results.md) · presets `VEM.AI_Tail_Shadow` / `VEM.AI_Tail_Skip` |
| **AI-9** | P5-L | Regime | **Build later** | **Regime classification** — filter or gate, not new signal |
| **AI-10** | P5-L | Risk | **Build later** | **Dynamic risk allocation** — size from score/regime |
| **AI-11** | P5-L | Entry | **Build later** | **Entry delay** — wait N bars; high live risk for MR |
| **AI-12** | P5-L | Execution | **Build later** | **Dynamic SL/TP** — last; prefer bar-state exit over ATR grids |

**Queue** = work **top to bottom** within P5 before opening **P5-L**.

---

## 2. Recommended build queue (now)

Work in order. Do **not** start **P5-L** until **P5-0** passes or explicitly stalls.

| Step | ID | Item | Depends on | Gate |
|:----:|-----|------|------------|------|
| — | C1, AI-5 | Already shipped | — | v0.1 skip in tester |
| **1** | **C2** | Trade Logger v2 | C1 schema | New CSV columns frozen · doc `step-c2-spec.md` |
| **2** | **C2b** | Bar 4/6/close snapshots | C2 | Rows joinable to trade_id |
| **3** | **B7** | Quality labels v2 spec | C2 | B7a–c defined · no leakage |
| **4** | **B9** | Label QA + splits | B7 | Same `manifest.json` windows as AI-1 |
| **5** | **AI-6** | XGBoost trade scorer | B7a, C2 archive | Beat logistic AUC **and** skip sim on OOS |
| **6** | **AI-7** | XGB shadow | AI-6 | MT5 Δ vs Python ≤ v0.1 tolerance |
| **7** | **AI-8** | AI skip layer (XGB) | AI-7 | Pass bar vs `VEM.AI_Skip` · preset `VEM.AI_Skip_XGB` |
| **8** | **P5-0** | Phase 5 sign-off | AI-8 | Rollback path documented |
| **9** | **P4-5** | Optional exit wire | C2b, B7b, P4-4 lessons | Only if new OOS $ beats prod |

---

## 3. Workstream detail

### C2 — Trade Logger v2

**Status:** Code shipped 2026-05-29 — run tester to complete gate.

**Goal:** One production-grade dataset for entry models, exit models, and regime tags.

**Minimum columns (v2):**

| Group | Examples |
|-------|----------|
| Identity | `trade_id`, `signal_time`, `direction`, `exit_reason` |
| Habitat @ signal | hour, spread, `bb_width_ratio`, RSI, vol spike, session flags |
| Structure | BB walk count, wick %, HTF EMA distance/slope, ATR level vs prior bars |
| Path | `mfe_r`, `mae_r` @ bar 4, 6, close; bars held |
| Labels (filled offline) | `label_bad_entry`, `label_early_cut`, `label_regime` |

**Deliverables:** `VEM_TradeLog.mqh` v2 · `inp_trade_log_version=2` · `scripts/analyze_vem_trade_log.py` update · preset `VEM.C2_Production`.

**Status:** C1 **done** → C2 **next**.

---

### B7 — Quality labels

**Goal:** Separate questions — *bad at entry?* · *should have cut early?* · *what regime?*

| Sub-ID | Label | Use |
|--------|-------|-----|
| **B7a** | `label_bad_entry` | Entry skip (**AI-6**, **AI-8**) — extends v0.1 `label_bad_trade` |
| **B7b** | `label_early_cut` | Exit model (**P4-5**) — SL, deep MAE @ b6, failed reversion |
| **B7c** | `label_regime` | Offline buckets for **AI-9** — train only until C2 has HTF features |

**Reference profiles:** [`addtionalnotes.md`](addtionalnotes.md) · [`edge-discovery.md`](edge-discovery.md) · [`Trade_Quality.md`](Trade_Quality.md).

**Status:** B1–B6 (v0.1) **done** → B7 **next** with C2.

---

### AI-6 — XGBoost trade scorer

**Goal:** Beat logistic v0.1 on **OOS 2025+** with controlled complexity (~400–800 trades).

| Task | ID | Notes |
|------|-----|-------|
| Feature set from C2 | AI-6a | Small, interpretable set; no post-trade leakage for entry model |
| Train / tune | AI-6 | Prefer shallow XGB + strong reg; compare HGB history (v0.1 HGB **worse**) |
| Skip simulation | AI-6b | Same policy as AI-3 D1–D10 pass bar |
| Export | AI-6 | JSON + `export_ai_model_mqh.py` or parallel scorer path |

**Do not:** Optimize on full 2020–2026 span only · add 50+ features · promote without shadow (**AI-7**).

---

### AI-8 — AI skip layer (promote)

**Goal:** Production entry veto — either keep **v0.1 logistic** or promote **XGB** if strictly better on OOS.

| Mode | Preset | Behavior |
|------|--------|----------|
| Current | `VEM.AI_Skip` | Logistic P(bad) ≥ threshold (~2% skip) |
| Candidate | `VEM.AI_Skip_XGB` | XGB P(bad) ≥ tuned threshold |
| Rollback | `VEM.Production` | No AI |

**Already wired:** `inp_ai_skip_enable`, `VEM_AI.mqh`, `VEM_AIShadow.mqh` — **AI-8** is model swap + threshold retune, not greenfield.

**Status:** AI-5 **done** → AI-8 after **AI-6/7**.

---

## 4. Build later (P5-L) — do not start until P5-0

These refine the EA but **multiply overfit and live risk**. Each needs **C2** features and its own ID gate.

| ID | Item | Role | Prerequisite | Risk |
|----|------|------|--------------|------|
| **AI-9** | Regime classification | Block or down-weight trades in trend/continuation | C2 HTF + B7c labels | False regime → missed MR |
| **AI-10** | Dynamic risk allocation | Scale lots by score/regime | Stable **AI-8** + forward stats | Thin PF → sizing amplifies noise |
| **AI-11** | Entry delay | Enter after confirmation bar(s) | C2 path study | Breaks MR timing · overlaps parked **D10** |
| **AI-12** | Dynamic SL/TP | ATR/structure-based SL/TP | Exit thesis exhausted | Overlaps failed **E13/E14** grids |

**Prefer instead of AI-12:** **P4-5** bar-state early exit (midline + E8c unchanged) — attacks **avg loss**, not TP fantasy.

---

## 5. Mapping: your list → IDs

| Your name | Phase | ID(s) | Notes |
|-----------|-------|-------|-------|
| Trade Logger v2 | P5 | **C2**, C2a, C2b | Extends **C1** |
| Quality Labels | P5 | **B7**, B7a–c, B8, B9 | Extends **B1–B6** |
| XGBoost Trade Scorer | P5 | **AI-6**, AI-6a, AI-6b | Offline vs **AI-2** |
| AI Skip Layer | P3 + P5 | **AI-5** (done), **AI-8** (promote) | Already in EA |
| Regime Classification | P5-L | **AI-9** | Build later |
| Dynamic Risk Allocation | P5-L | **AI-10** | Build later |
| Delay | P5-L | **AI-11** | Build later |
| Dynamic SL/TP | P5-L | **AI-12** | Build later; prefer **P4-5** first |

---

## 6. Overlap with Phase 4 (expectancy)

| P5 item | P4 item | Relationship |
|---------|---------|----------------|
| C2b bar snapshots | **P4-3** | P4-3 matrix is v1 — **C2** supersedes for new trains |
| B7b early-cut label | **P4-4**, **P4-5** | Revive exit model only with v2 data |
| AI-6 entry XGB | **P4-2** tail-risk | Can be one model with multi-head labels later |
| AI-12 dynamic SL/TP | E13, E14 | **Discard** path — do not repeat without C2 proof |

**Priority:** **↓ avg loss** = **B7b + P4-5** before **AI-12**.

---

## 7. Checklists (copy per build)

### C2 — Logger v2

- [ ] Schema doc + version field in CSV header
- [ ] `VEM_TradeLog.mqh` writes v2 rows on `VEM.C2_Production` backtest
- [ ] `analyze_vem_trade_log.py` reads v2
- [ ] One production-length backtest archive committed under `data/c1/`

### B7 — Labels

- [ ] `bad_trade_rule.json` v2 or separate label rules per B7a–c
- [ ] Leakage check: entry labels use ≤ signal bar only
- [ ] Class counts logged per split (train/val/test)

### AI-6 — XGB

- [ ] Train/val/test AUC or PR-AUC reported
- [ ] Skip sim beats **AI-3** on OOS ($, PF, WR, n)
- [ ] Model artifact + export path documented

### AI-8 — Skip promote

- [ ] `VEM.AI_Shadow` parity for XGB
- [ ] `VEM.AI_Skip_XGB` tester run vs `VEM.AI_Skip` + `VEM.Production`
- [ ] README + runbook updated if default changes

### P5-0 — Sign-off

- [ ] `step-p5-0-signoff.md` written
- [ ] Default preset decision: keep logistic or XGB
- [ ] P5-L items explicitly **not** started

---

## 8. Status log

| Date | ID | Result |
|------|-----|--------|
| — | C1, AI-1–AI-5 | Phase 3 complete — see filters §9 |
| — | P4-0 | Sign-off complete |
| — | P4-1, P4-4, E13, E14 | Park / discard — see filters §10 |
| 2026-05-29 | C2 | Archived 408 tr · labeled CSV in `data/c2/` |
| 2026-05-29 | B7 | Multi-label + QA — [`step-b7-results.md`](step-b7-results.md) |
| 2026-05-29 | AI-6 | **Park** — no OOS skip pass; keep **v0.1** [`step-ai-v6-results.md`](step-ai-v6-results.md) |
| 2026-05-29 | P4-2 | Tail logistic wired — offline tail-only FAIL · combo sim optimistic · **tester gate** |
| 2026-05-31 | P4-2 | **Tail_Shadow** parity PASS · v1 thr 0.742 rejected (n=74 OOS) |
| 2026-05-31 | P4-2 | **Retune** thr **0.9415** — shadow sim OOS **$10.32 / n=107** [`step-p4-2-tail-retune.md`](step-p4-2-tail-retune.md) |
| 2026-05-31 | P4-2 | **PARK** — OOS tester $8.33 / PF 1.24 / n=123 · below `AI_Skip` $9.83 / 1.34 |
| 2026-05-31 | Pilot | Presets **`VEM.Pilot.Production`** / **`VEM.Pilot.AI_Skip`** · [`MULTI_SYMBOL_PILOT.md`](MULTI_SYMBOL_PILOT.md) |
| *Next* | Pilot | Demo/tester on **GBPUSD M5** (or queue) · rules pass → optional pilot AI |
| *TBD* | B7 | — |
| *TBD* | AI-6 | — |
| *TBD* | AI-8 | — |
| *TBD* | P5-0 | — |

---

*Last updated: 2026-05-29 · canonical queue remains [`filtersrecommedations.md`](filtersrecommedations.md); this file owns **P5 scale-up** IDs only.*
