# ORBVWAP — AI Intelligence Layers & Roadmap

**Status:** Phase **5 (AI)** — **offline training CLOSED** (AI-0…AI-4 PASS) · **MT5 validation partial** · **LIVE promotion pending**  
**Prerequisite:** Edge Discovery **closed** · PROD v3 execution stack locked · Phase 4C **NO-STACK**  
**Reference:** [System Profile.md](./System%20Profile.md) · [Edge Discovery.md](./Edge%20Discovery.md)

**Deploy path:** MT5 Tester sign-off → **INF-0…INF-7 pipeline** → chart LIVE (preset steps 6–8). See [System Design.md](./System%20Design.md).

**Offline training closed:** 2026-06-11 · all layer gates PASS in `Diagnostics/AI-test-journal.csv`. No further Python train/replay until retrain trigger (below).

**Chart LIVE blocked** until **INF-GATE PASS** (`Diagnostics/INF-test-journal.csv`).

---

## Executive summary

AI sits **above** the existing signal and execution engine as a **meta-filter and adaptive controller**. It does **not** replace ORB logic, VWAP, volume, MinRR, session filters, or SL/TP geometry.

**Workflow:** Export decisions from backtest → train versioned models in Python → **policy replay** on held-out time → gate vs PROD → shadow log in EA → live gate only after pass → **retrain** as data grows (6y history, candidate-setup logging, later forward logs).

**Training data (current):** 6-year PROD backtest ≈ **358 trades** — sufficient for **AI-0 + AI-1 v1** (simple models, time-split CV). Not sufficient to “finish” AI or run complex ensembles without **candidate-setup export** (3–5× more labelled rows) and periodic retraining.

| Reference run | Window | Trades | PF | WR | Max equity DD |
|---------------|--------|--------|-----|-----|---------------|
| PROD v3 (harness) | P0-002 | 172 | **1.40** | 54.1% | **2.51%** |
| PROD v3 (6-year) | ~6y | **358** | **1.29** | 53.9% | **8.56%** |

*Compare every AI phase to the **same backtest window** used to train/evaluate that model version.*

---

## Core principles

1. **Frozen execution** — `SignalEngine`, `RiskEngine`, PROD exits unchanged until an AI phase **passes** its gate.
2. **One Task ID → one experiment → one journal row** — same discipline as P2/P4.
3. **Time-based splits only** — never random train/test shuffle on serial market data.
4. **Optimize PF and DD on holdout** — not headline win rate alone (geometry caps WR ~55%).
5. **Models are versioned artifacts** — `models/ai1_v3.lgb` + manifest; retrain without rewriting the EA.
6. **No wire until holdout pass** — offline policy replay is shadow mode for backtest; live shadow comes later.

---

## Architecture

```
Market Data (M1)
       ↓
┌──────────────────────────────────────┐
│  PROD v3 — UNCHANGED BELOW AI WIRE   │
│  SessionUtils → OpeningRange → VWAP  │
│  SignalEngine → EntryFilters → MinRR │
└──────────────────────────────────────┘
       ↓  (approved setup)
┌──────────────────────────────────────┐
│  AI-3  Layer 3: Regime gate          │  session on/off
└──────────────────────────────────────┘
       ↓  (regime OK)
┌──────────────────────────────────────┐
│  AI-1  Layer 1: Signal scorer        │  score ∈ [0,1]
└──────────────────────────────────────┘
       ↓  (score ≥ τ)
┌──────────────────────────────────────┐
│  AI-2  Layer 2: Dynamic sizer        │  lot multiplier
└──────────────────────────────────────┘
       ↓
┌──────────────────────────────────────┐
│  ExecutionEngine — entry unchanged   │
└──────────────────────────────────────┘
       ↓  (position open)
┌──────────────────────────────────────┐
│  AI-4  Layer 4: Exit manager         │  optional overlay
└──────────────────────────────────────┘
       ↓
   Trade close (TP / SL / 120m time stop)
```

**Build order (dependencies):** `AI-0` → `AI-1` → `AI-3` → `AI-2` → `AI-4`  
*(Regime before sizing — skip bad sessions before scoring trades.)*

---

## Phase map (IDs)

| Phase ID | Layer | Name | Offline train | EA wired | MT5 validated | LIVE promote |
|----------|-------|------|---------------|----------|---------------|--------------|
| **AI-0** | — | Pipeline & dataset | ✅ CLOSED | N/A | ✅ export replay | N/A |
| **AI-1** | **L1** | Signal scorer | ✅ CLOSED | ✅ v1.19 | ✅ `AI-123-005` | ⬜ when AI-1+3 stack signed off |
| **AI-2** | **L2** | Dynamic sizing | ✅ CLOSED | ✅ v1.20 | ⬜ dedicated `AI12` run | ⬜ after AI-2 MT5 PASS |
| **AI-3** | **L3** | Regime gate | ✅ CLOSED | ✅ v1.21 | ✅ `AI-1234-005` | ⬜ when AI-1+3 stack signed off |
| **AI-4** | **L4** | Exit overlay | ✅ CLOSED *(proxy paths)* | ✅ v1.22 | ✅ log only `AI-1234-005` | ⬜ last · after AI-4 LIVE MT5 + optional v2 paths |

**Retrain trigger (all layers):** new 6y export · `ORBVWAP_paths.csv` merge (AI-4) · +N live trades · manifest bump → re-run train → holdout gate → shadow → LIVE.

**Best deploy candidate (so far):** **AI-1 + AI-3 LIVE** — MT5 n=315 · PF=1.53 · DD=5.89% (`AI-1234-005`).

---

## AI-0 — Pipeline & dataset infra

**Goal:** Reproducible decision-level dataset from backtest; policy replay without re-running MT5 for every model iteration.

| Task ID | Task | Output |
|---------|------|--------|
| **AI-0-001** | Feature export preset on PROD v3 (`InpEnableDecisionExport`) | `ORBVWAP_decisions.csv` / `.parquet` |
| **AI-0-002** | `Diagnostics/ai/build_dataset.py` — clean, validate, document schema | `ORBVWAP_ai_dataset_vN.parquet` |
| **AI-0-003** | `Diagnostics/ai/replay_policy.py` — apply threshold/rules on holdout | Metrics row in `AI-test-journal.csv` |
| **AI-0-004** | `Diagnostics/ai/train_eval.py` — shared time-split, metrics, plots | Reusable training harness |
| **AI-0-005** | Model manifest (`model_id`, features, train window, τ, git hash) | `models/manifest.json` |

**Row definition (decision point):** One row per **candidate setup** where `SignalEngine` would emit BUY/SELL **before** AI (include rows blocked by MinRR for richer negatives if logged at pre-MinRR stage — document which).

**Required columns (minimum):**

| Column | Description |
|--------|-------------|
| `bar_time` | Signal bar GMT |
| `direction` | BUY / SELL |
| `session` | LONDON / NY |
| `range_width_atr` | Range / ATR(14) |
| `vol_ratio` | Tick vol / vol MA |
| `vwap_dist_atr` | \|close − vwap\| / ATR |
| `spread_pct_range` | Spread / range width |
| `min_rr_at_entry` | Computed R:R |
| `hour_gmt`, `weekday` | Temporal |
| `ny_min_since_open` | Minutes since NY open |
| `prod_taken` | 1 if PROD actually traded |
| `label_win` | 1 if fixed PROD exit would win (replay) |
| `label_pnl_r` | P/L in R multiples (optional) |

**AI-0 gate:** Dataset builds from full 6y backtest with **no duplicate decision_id**; train/holdout split reproducible; policy replay holdout PF ≈ full on `prod_executed` rows.

**Implemented (v1.18):**

| Task ID | Status | Artifact |
|---------|--------|----------|
| **AI-0-001** | ✅ PASS | 6y export · 16,565 rows · 358 executed |
| **AI-0-002** | ✅ PASS | `Diagnostics/datasets/ORBVWAP_ai_dataset_v1.parquet` |
| **AI-0-003** | ✅ PASS | Full PF 1.29 · holdout PF 1.43 · delta 0.135 |
| **AI-0-004** | ✅ PASS | `Diagnostics/ai/train_eval.py` |
| **AI-0-005** | ✅ PASS | `models/manifest.json` |

**Validated 2026-06-12:** Backtest n=358 · WR 53.91% · net 31.71 — matches PROD baseline. Journal row `AI-0-003` **PASS**.

**Offline training:** ✅ **CLOSED** — no open AI-0 tasks.

| Task ID | Task | Status | When / trigger |
|---------|------|--------|----------------|
| **AI-0-001** | Feature export preset | ✅ DONE | — |
| **AI-0-002** | `build_dataset.py` | ✅ DONE | — |
| **AI-0-003** | `replay_policy.py` gate | ✅ PASS | — |
| **AI-0-004** | `train_eval.py` harness | ✅ DONE | — |
| **AI-0-005** | `models/manifest.json` | ✅ DONE | — |
| **AI-0-R1** | Re-export decisions (v2 dataset) | ⬜ UNDONE | When candidate-setup logging or new PROD window |

**Artifacts:** `Diagnostics/ai/` · `Diagnostics/datasets/` · `Diagnostics/AI-test-journal.csv`

---

## AI-1 — Layer 1: Signal quality scorer

**Phase ID:** `AI-1` · **Layer:** L1 · **Highest impact on WR / trade quality**

**What it does:** Scores each approved setup ∈ [0, 1]. **Protection mode** — block only the worst tail (~10–15% lowest scores); PROD engine keeps its edge, AI skips bad conditions.

**Model (v1):** Logistic regression or LightGBM (max depth 4–5). **Not** deep nets on 358 trades.

**Features:**

| Feature | Notes |
|---------|--------|
| `range_width_atr` | Compressed vs expanded range |
| `vol_ratio` | Breakout volume expansion |
| `vwap_dist_atr` | VWAP alignment strength |
| `spread_pct_range` | Already on PROD — still useful in ML |
| `min_rr_at_entry` | Geometry quality |
| `hour_gmt`, `weekday` | Temporal (no long-bias — P4C NO-STACK) |
| `session`, `direction` | Categorical |
| `ny_min_since_open` | NY delay interaction |
| H1 body/wick ratio | Volatility proxy (optional) |
| Distance to D1 high/low | Optional; ablation required |

**Training protocol:**

- Split: earliest **70%** of time → train; latest **30%** → holdout (or walk-forward 3 folds).
- Tune τ on train; report on holdout only once (or nested CV).
- Metrics: **precision @ τ**, holdout **PF**, **DD**, **n** (not accuracy).

**AI-1 gate vs PROD (holdout) — protection mode:**

| Metric | Pass |
|--------|------|
| Retention | ≥ **85%** of PROD holdout trades |
| Profit factor | ≥ PROD × **0.95** (no collapse) |
| Max equity DD | ≤ PROD (tail-risk cut) |

**Expected range:** n ↓ **10–15%** only · PF flat-to-up · DD down.

**Wire:** `InpAiGateMode=OFF|SHADOW|LIVE` · `InpAiMinScore` · export rules tree to MQL5 (v1) — no Python socket until v2.

| Task ID | Task | Preset variant |
|---------|------|----------------|
| **AI-1-001** | Train v1 scorer on 6y dataset | `AI1_Scorer_train` |
| **AI-1-002** | Threshold sweep τ ∈ [0.25, 0.55] · keep ≥85% trades | journal only |
| **AI-1-003** | Holdout evaluation + policy replay | `AI-test-journal.csv` |
| **AI-1-004** | Export decision rules / lookup for MQL5 | `Include/ORBVWAP/AiScorer.mqh` |
| **AI-1-005** | EA shadow mode (log score, do not block) | `ORBVWAP_AI1_SHADOW_PROD` |

**Implemented (v1.19):**

| Task ID | Task | Offline | MT5 / LIVE | When / trigger |
|---------|------|---------|------------|----------------|
| **AI-1-001** | Train scorer · `ai1_v1.json` | ✅ DONE | — | — |
| **AI-1-002** | τ sweep · **τ=0.30** cap | ✅ DONE | — | — |
| **AI-1-003** | Holdout gate | ✅ PASS · n=98 PF=1.49 | — | — |
| **AI-1-004** | `AiScorer.mqh` export | ✅ DONE | — | — |
| **AI-1-005** | EA SHADOW/LIVE wiring | ✅ DONE | ✅ `AI-123-005` · 342t PF=1.33 | — |
| **AI-1-006** | Walk-forward 3 folds | ⬜ UNDONE | — | Before standalone LIVE sign-off (harness rule) |
| **AI-1-007** | Promote `InpAiGateMode=LIVE` in PROD preset | ⬜ UNDONE | — | With AI-3 · after stack MT5 sign-off |

**Offline training:** ✅ **CLOSED**.

**v1 philosophy:** PROD engine keeps edge; AI blocks ~9% worst-scored setups (bad conditions). τ=0.30 cap prevents score-drift over-filtering.

**Retrain command:** `python Diagnostics/ai/train_l1.py` *(retrain loop only)*

---

## AI-2 — Layer 2: Dynamic position sizing

**Phase ID:** `AI-2` · **Layer:** L2 · **Payoff / net lever** (protection-oriented)

**What it does:** On AI-1 passing trades, scale lot by **score percentile** (calibrated on train). PROD base lot = 1.0×.

| Score vs train percentiles | Multiplier |
|----------------------------|------------|
| &lt; p50 | **1.0×** |
| p50 – p80 | **1.15×** |
| ≥ p80 | **1.25×** |

*v1 calibrated: p50=0.549 · p80=0.635 · max 1.25× (not 1.5× — scores rarely exceed 0.75).*

**Hard constraints:** Max **1.25×** base lot · never bypass `InpMinEquityRatio` · circuit breakers unchanged.

**Prerequisite:** **AI-1 PASS** on holdout.

**AI-2 gate (protection):** PF ≥ AI-1 × 0.98 · payoff ≥ PROD × 0.99 · net ≥ AI-1 · DD ≤ AI-1 × 1.15.

| Task ID | Task | Offline | MT5 / LIVE | When / trigger |
|---------|------|---------|------------|----------------|
| **AI-2-001** | `replay_sizing.py` bucket replay | ✅ PASS | — | — |
| **AI-2-002** | Ablation AI-1 vs AI-1+AI-2 | ✅ PASS · PF 1.47 net 12.79 | — | — |
| **AI-2-003** | `InpAiSizeMode` · `AiSizer.mqh` | ✅ DONE · v1.20 | — | — |
| **AI-2-004** | MT5 shadow `ORBVWAP_AI12_SHADOW` | ⬜ UNDONE | — | Before AI-2 LIVE · confirm lot mult logs |
| **AI-2-005** | Promote `InpAiSizeMode=LIVE` | ⬜ UNDONE | — | After AI-2-004 PASS · AI-1+3 stable |

**Offline training:** ✅ **CLOSED**.

**MT5 backtest preset:** `ORBVWAP_AI12_SHADOW_PROD_EURUSD-M1.set` (AI-1 LIVE + AI-2 SHADOW log).

**Retrain:** `python Diagnostics/ai/replay_sizing.py` *(retrain loop only)*

---

## AI-3 — Layer 3: Regime detection

**Phase ID:** `AI-3` · **Layer:** L3 · **DD and streak reduction**

**What it does:** Classify **session** at signal time. Skip worst ~8% chop-probability sessions (protection mode).

**Regime classes (v1):**

| Class | Action |
|-------|--------|
| `TRENDING` | Trade allowed (chop_prob &lt; 0.60) |
| `CHOPPY` | Skip session |

**Features:** `range_width_atr` · `vol_ratio` · `spread_pct_range` · `vwap_dist_atr` · `weekday` · `session_ny` · `prior_session_loss`.

**Model (v1):** Decision tree (depth 3) · skip if chop_prob ≥ **0.60**.

**Prerequisite:** **AI-0 PASS**.

**AI-3 gate (protection):** maxCL ↓ or DD ↓ · win-profit removed ≤ **30%** · PF ≥ PROD × 0.95.

| Task ID | Task | Offline | MT5 / LIVE | When / trigger |
|---------|------|---------|------------|----------------|
| **AI-3-001** | `sessions.py` session labels | ✅ DONE | — | — |
| **AI-3-002** | `train_regime.py` · `AiRegime.mqh` | ✅ DONE | — | — |
| **AI-3-003** | `replay_regime.py` gate | ✅ PASS · n=97 PF=1.43 | — | — |
| **AI-3-004** | `InpAiRegimeMode` SHADOW/LIVE | ✅ DONE · v1.21 | ✅ `AI-1234-005` · 315t PF=1.53 DD=5.89% | — |
| **AI-3-005** | Promote in PROD preset (with AI-1) | ⬜ UNDONE | — | After stack sign-off · best candidate pair |

**Offline training:** ✅ **CLOSED**.

**Holdout:** AI-3 n=97 PF=1.43 maxCL **5→4** · AI-3+AI-1 n=88 PF=**1.52** DD=3.20.

**MT5 preset:** `ORBVWAP_AI123_SHADOW_PROD_EURUSD-M1.set` (AI-3 SHADOW) · full stack: `ORBVWAP_AI1234_SHADOW_PROD_EURUSD-M1.set`

**Retrain:** `python Diagnostics/ai/train_regime.py` → `replay_regime.py` *(retrain loop only)*

---

## AI-4 — Layer 4: Stall-scratch exit overlay

**Phase ID:** `AI-4` · **Layer:** L4 · **Tail loss / payoff** (protection, not partial TP)

**What it does:** After **45 min**, if MFE &lt; **0.25× range** → close at market (stall scratch). Cuts bleeders; winners that moved stay on PROD TP/time-stop.

**Not partial TP:** No runner geometry — single full close on stall only (Phase 4A lesson).

**Path data:** `PathTracker.mqh` samples MFE@15/30/45 · `ORBVWAP_paths.csv` on close. v1 offline used proxy paths; re-export improves v2.

**AI-4 gate (protection):** PF ↑ · payoff ↑ · max_dd ↓ on AI-3+AI-1 stack holdout.

| Task ID | Task | Offline | MT5 / LIVE | When / trigger |
|---------|------|---------|------------|----------------|
| **AI-4-001** | `build_paths.py` + `PathTracker` | ✅ DONE *(proxy MFE)* | — | — |
| **AI-4-002** | `train_exit.py` · stall 45m / 0.25× | ✅ DONE | — | — |
| **AI-4-003** | `replay_exit.py` gate | ✅ PASS · stack PF 1.52→2.51 | — | — |
| **AI-4-004** | `InpAiExitMode` · `ManageAiStallScratch` | ✅ DONE · v1.22 | ✅ SHADOW log `AI-1234-005` | — |
| **AI-4-005** | Real path export + v2 retrain | ⬜ UNDONE | — | `InpEnablePathExport=true` 6y backtest → merge CSV |
| **AI-4-006** | MT5 with `InpAiExitMode=LIVE` | ⬜ UNDONE | — | After AI-4-005 optional · confirm tail −5.19 cut |
| **AI-4-007** | Promote stall scratch LIVE | ⬜ UNDONE | — | **Last layer** · after AI-4-006 PASS |

**Offline training:** ✅ **CLOSED** *(v1 proxy paths — treat holdout PF 2.51 as optimistic until AI-4-005)*.

**Holdout (AI-3+AI-1 stack):** PF 1.52→**2.51** · payoff 1.21→**2.00** · max_dd 3.20→**1.42** *(proxy paths)*.

**MT5 preset:** `ORBVWAP_AI1234_SHADOW_PROD_EURUSD-M1.set`

**Retrain:** `python Diagnostics/ai/build_paths.py` → `train_exit.py` → `replay_exit.py` *(retrain loop only)*

---

## Evaluation harness (all phases)

**Policy replay** (`replay_policy.py`) recomputes on held-out rows:

| Metric | PROD ref | AI policy | Notes |
|--------|----------|-----------|-------|
| Profit factor | ✓ | target | Primary |
| Payoff (avg win /\|avg loss\|) | ✓ | target | Primary for AI-2/4 |
| Max equity DD | ✓ | ≤ ref × 1.2 | Primary for AI-3 |
| Win rate | ✓ | informational | Can drop if PF up |
| Trades (n) | ✓ | ≥ 80 holdout | Anti-overfit |
| Sharpe / Recovery | ✓ | informational | |

**Walk-forward (AI-1+):** Minimum **3** rolling windows (mini offline P3-002) before any LIVE wire — ⬜ **UNDONE** (harness rule; defer until pre-LIVE sign-off).

**Ablation matrix:**

```
PROD
PROD + AI-3
PROD + AI-3 + AI-1
PROD + AI-3 + AI-1 + AI-2
PROD + AI-3 + AI-1 + AI-2 + AI-4
```

---

## MT5 integration & sign-off presets

| Mode | Value | Behaviour |
|------|-------|-----------|
| OFF | 0 | Layer inactive — PROD only for that lever |
| SHADOW | 1 | Log decision; **do not** block / scale / close |
| LIVE | 2 | Apply policy |

**v1 wiring:** Hardcoded rules in auto-generated `.mqh` — **no HTTP, no sidecars**. Recompile after train.

### Sign-off preset map

| Preset | AI-1 | AI-2 | AI-3 | AI-4 | Use |
|--------|------|------|------|------|-----|
| `ORBVWAP_PROD_EURUSD-M1` | OFF | OFF | OFF | OFF | Baseline |
| `ORBVWAP_AI0_Export_*` | OFF | OFF | OFF | OFF | Export CSV |
| `ORBVWAP_AI1_SHADOW_*` | SHADOW | OFF | OFF | OFF | Score log only |
| `ORBVWAP_AI12_SHADOW_*` | LIVE | SHADOW | OFF | OFF | Sizing log ⬜ |
| `ORBVWAP_AI123_SHADOW_*` | LIVE | SHADOW | SHADOW | OFF | ✅ journal |
| `ORBVWAP_AI1234_SHADOW_*` | LIVE | SHADOW | LIVE | SHADOW | ✅ journal |
| **`ORBVWAP_AI123_LIVE_*`** | LIVE | OFF | LIVE | OFF | **Deploy sign-off** ⬜ |
| `ORBVWAP_AI1234_SIZING_LIVE_*` | LIVE | LIVE | LIVE | SHADOW | Sizing sign-off ⬜ |
| **`ORBVWAP_AI1234_LIVE_*`** | LIVE | LIVE | LIVE | LIVE | Full stack ⬜ last |

All presets in `Presets/` · copies in `MQL5/Profiles/Tester/`.

### v2 connection rules (when runtime inference added)

**Tester can't use HTTP.** Use `Terminal\Common\Files\Logs\` + **`FILE_COMMON`**. Sidecars accept `req != last_req`. Fail-open = scores stuck at neutral · IPC looks alive but AI inactive.

| Environment | Preset | Sidecars / server |
|-------------|--------|-------------------|
| Tester | LogOnly / Gates | Both sidecars `--mode tester` before Start |
| Live chart | HTTP | Inference server + WebRequest URL allowed |

**Prevent:** HTTP in Tester · health probe mid-backtest · `req > last_req` handshake · agent Files folder instead of Common.

**Integration v2:** ONNX or Python bridge — only after v1 LIVE sign-off.

---

## Realistic targets (conservative · holdout)

| Stack | WR | PF | Max DD | Trades (6y scale) |
|-------|-----|-----|--------|-------------------|
| PROD v3 (baseline) | 54% | 1.29–1.40 | 2.5–8.5%* | 172–358 |
| + AI-1 | 57–61% | 1.45–1.65 | ~flat | −20–35% |
| + AI-1 + AI-3 | 56–60% | 1.45–1.70 | **↓** | fewer |
| + AI-1 + AI-3 + AI-2 | 56–60% | 1.55–1.80 | ~flat | fewer |
| + full (+ AI-4) | mixed | 1.6–2.0† | ↓† | payoff ↑† |

\*DD depends on test window (P0-002 vs 6y).  
†Only if AI-4 passes gate; do not assume.

**Do not target 65% WR on holdout** without collapsing n — easy to overfit 358 trades.

---

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Overfitting | Time split · simple models · min n · ablation |
| WR chasing | Gate on PF + payoff, not WR |
| AI replaces edge discovery | Frozen signal engine; AI only gates/sizes/exits |
| Stale model | Versioned retrain pipeline |
| P4A repeat | AI-4 must beat rule-based partials on holdout |
| Direction bias | P4C NO-STACK — no long-only features without new diagnostics |

---

## Suggested roadmap

```
✅ OFFLINE CLOSED (2026-06-11)
   AI-0 → AI-1 → AI-3 → AI-2 → AI-4  train + holdout gates PASS

⬜ MT5 VALIDATION (partial — journal AI-123-005, AI-1234-005)
   1. AI-12 shadow          AI-2 lot mult log          [UNDONE]
   2. Stack sign-off        AI-1 + AI-3 LIVE preset    [candidate ready]
   3. AI-4 LIVE backtest    stall scratch closes       [UNDONE · last]

⬜ OPTIONAL before AI-4 LIVE
   AI-4-005                 real ORBVWAP_paths.csv     [UNDONE]

⬜ LIVE PROMOTION (one layer at a time)
   AI-1+3 → AI-2 → AI-4

⬜ RETRAIN LOOP (ongoing)
   new export → train → gate → shadow → LIVE

⬜ DEFER
   P3-004 forward demo      user-triggered
```

**Do not:**

- Retrain and wire in one step
- Use random train/test split
- Add D1 long-bias (P4C closed)
- Change PROD SL/TP geometry in AI phases
- Deploy socket/ONNX before rules-based v1 passes

---

## Artifact inventory (target)

| Path | Purpose |
|------|---------|
| `ailayers.md` | This document |
| `Diagnostics/AI-test-journal.csv` | One row per AI task run |
| `Diagnostics/ai/build_dataset.py` | Dataset builder |
| `Diagnostics/ai/train_l1.py` | AI-1 training |
| `Diagnostics/ai/replay_policy.py` | Offline policy evaluation |
| `models/manifest.json` | Model versions + features + τ |
| `Presets/ORBVWAP_AI0_Export_PROD_*` | Feature export preset |
| `Presets/ORBVWAP_AI1_SHADOW_PROD_*` | Shadow mode preset |

---

## One-line characterisation

**ORBVWAP AI** is a **versioned policy layer** on top of PROD v3 that uses offline-trained models to **skip low-quality setups, bad sessions, and poor exits** — improving **PF and DD** while the proven execution engine stays frozen, with **retrain** as the long-term compounding mechanism.
