# ORBVWAP — System Design

**Document:** `System Design.md`  
**EA version:** 1.22 · **Production:** PROD v3 (frozen signal/exit geometry)  
**AI models:** Offline training **CLOSED** (AI-0…AI-4) · see [ailayers.md](./ailayers.md)  
**Infra pipeline:** **INF-0–7** ✅ · **INF-GATE PASS** · chart LIVE steps 6 & 8 unlocked (demo sign-off still required)

> **Doc ownership:** Wiring / INF / preset ladder → this file. AI models → [aidesign.md](./aidesign.md). PROD edge → [System Profile.md](./System%20Profile.md). Ops → [AGENTS.md](./AGENTS.md) · [STATUS.md](./STATUS.md).

---

## 1. Purpose

Operational system design for ORBVWAP: EA layout, AI wiring, offline → Tester → live paths, **infrastructure hardening phases (INF-*)**, and preset sign-off.

| Track | Phase prefix | Status | Unlocks |
|-------|--------------|--------|---------|
| **Edge + AI models** | AI-0…AI-4 | Offline ✅ · Tester partial | MT5 Tester SHADOW/LIVE presets |
| **Infra + pipeline** | INF-0…INF-7 | **INF-0–7** ✅ · **INF-GATE PASS** | **Chart LIVE** · forward demo |
| **Forward validation** | P3-004 | Deferred | Real-money cadence |

**Critical rule:** **Strategy Tester sign-off** and **live chart / demo sign-off** are **different gates**. Chart LIVE (preset steps 6–8) runs **only after INF-GATE PASS**. Until then, max stage = **MT5 Tester** + journal row.

---

## 2. System overview

ORBVWAP is a **two-tier system**:

| Tier | Role | Mutable? |
|------|------|----------|
| **PROD v3** | ORB + VWAP signal, session filters, SL/TP, 120m time stop | Frozen during AI phases |
| **AI overlay** | Session gate · entry score · lot scale · stall exit | Versioned via Python → `.mqh` |

```
Market (EURUSD M1)
       │
       ▼
┌──────────────────────────────────────┐
│  PROD v3 (frozen)                     │
│  Session → Range → VWAP → Signal      │
│  Filters → Risk → Execution entry     │
└──────────────────┬───────────────────┘
                   ▼
         AI-3 → AI-1 → AI-2  (new bar)
                   │
                   ▼
              Open position
                   │
                   ▼
         AI-4 + PathTracker  (every tick)
                   │
                   ▼
              Close (TP/SL/time/AI-4)
```

**Runtime order (`ORBVWAP.mq5`):**

1. **Every tick:** `ManageOpenPositions` → `PathTracker` → AI-4 → PROD exits  
2. **New bar:** `ProcessPipeline` → AI-3 → risk/setup → AI-1 → AI-2 → execute → optional export logs

**Target logging stack (post INF-1):**

| Tier | Output | Consumer |
|------|--------|----------|
| L0 | PROD reject codes (`Logger.mqh`) | Experts / optional file journal |
| L1 | AI shadow CSV (`ORBVWAP_ai_shadow.csv`) | Sign-off audit · parity |
| L2 | Train/replay JSON lines (`Diagnostics/logs/`) | CI · regression |
| L3 | Forward journal (P3-004) | Live slippage gate |

---

## 3. EA infrastructure

### 3.1 Module map

| Layer | File | Role |
|-------|------|------|
| Orchestrator | `ORBVWAP.mq5` | `OnInit` / `OnTick` / `OnTradeTransaction` |
| Session & signal | `SessionUtils`, `OpeningRange`, `SessionVwap`, `SignalEngine`, `EntryFilters` | PROD edge |
| Risk & state | `RiskEngine`, `StateTracker`, `CircuitBreakers` | Gates, one trade/session |
| Execution | `ExecutionEngine.mqh` | Entry, time stop, AI-4 stall |
| AI-0 | `DecisionExport.mqh` | Training CSV export |
| AI-1 | `AiScorer.mqh` | Score ∈ [0,1], τ=0.30 |
| AI-2 | `AiSizer.mqh` | Lot × {1.0, 1.15, 1.25} |
| AI-3 | `AiRegime.mqh` | Skip session if chop_prob ≥ 0.60 |
| AI-4 | `AiExit.mqh`, `PathTracker.mqh` | Stall @ 45m, path export |
| Logging | `Logger.mqh` | Experts tab, optional file journal |
| *(planned INF-1)* | `AiShadowExport.mqh` | Structured AI decision CSV |

**Globals:** `g_indicators`, `g_opening_range`, `g_session_vwap`, `g_state`, `g_breakers`, `g_executor`.

### 3.2 AI inputs and modes

| Input | Layer | OFF (0) | SHADOW (1) | LIVE (2) |
|-------|-------|---------|------------|----------|
| `InpAiRegimeMode` | AI-3 | No filter | Log ALLOW/SKIP | Skip choppy session |
| `InpAiGateMode` | AI-1 | No filter | Log score | Block score &lt; τ |
| `InpAiSizeMode` | AI-2 | 1.0× lot | Log multiplier | Scale lot |
| `InpAiExitMode` | AI-4 | PROD exits | Log STALL | Market close stall |
| `InpEnableDecisionExport` | AI-0 | — | — | Write decisions CSV |
| `InpEnablePathExport` | AI-4 train | — | — | Write paths CSV |

**Pipeline hooks:**

| Layer | Hook | Timing |
|-------|------|--------|
| AI-3 | `CAiRegime::AllowFromPipeline()` | New bar, before setup |
| AI-1 | `CAiScorer::Score()` | New bar, after setup |
| AI-2 | `CAiSizer::Multiplier()` | New bar, after AI-1 pass |
| AI-4 | `CAiExit::ShouldStallScratch()` | Every tick in manage loop |

---

## 4. How AI connects to the EA

### 4.1 v1 (current) — compile-time `.mqh`

**No runtime Python.** No HTTP. No sidecars.

```
Python train/replay  →  auto-gen .mqh + manifest.json
                              │
                              ▼
                    MetaEditor compile (F7)
                              │
                              ▼
              EA embeds rules (constants, trees)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
      Strategy Tester              Live chart (INF-GATE required)
      (Tester sign-off OK now)     (blocked until infra PASS)
```

| Stage | Who | What | Gate |
|-------|-----|------|------|
| **Offline** | Python | `build_dataset` → `train_*` → `replay_*` | AI-* journal PASS |
| **Wire** | Developer | Regenerate `.mqh` · recompile | — |
| **Tester** | MT5 Strategy Tester | SHADOW/LIVE presets · 6y backtest | `AI-test-journal.csv` |
| **Infra** | Docker/CI/schema | INF-* tasks | `INF-test-journal.csv` *(planned)* |
| **Chart LIVE** | Demo / small live | Same preset as Tester | **INF-GATE** + Tester PASS |
| **Forward** | P3-004 | 4-week real slippage | After chart LIVE stable |

### 4.2 v2 (planned) — runtime inference · **INF-8**

When ORBVWAP adds HTTP / file IPC (VWAPMRE pattern):

| Environment | Preset | Transport | Before run |
|-------------|--------|-----------|------------|
| **Strategy Tester** | Gates / LogOnly + sidecars ON | `FILE_COMMON` binary IPC | Sidecars `--mode tester` before Start |
| **Live / demo** | HTTP inference preset | `WebRequest` → local server | Inference server + URL allowlist |

**Shared path:** `%APPDATA%\MetaQuotes\Terminal\Common\Files\Logs\`

---

## 5. Connection rules (v2 IPC · INF-8)

> **Tester can't use HTTP.** EA and Python must share `Terminal\Common\Files\Logs\` via **`FILE_COMMON`**, and sidecars must accept any new `req` (**`!= last_req`**, not `>`) — otherwise IPC looks connected but every score times out to **fail-open** (neutral scores · AI inactive).

### 5.1 Fail-open symptom

| Signal | Meaning |
|--------|---------|
| Scores stuck at neutral (e.g. 1.0 / 50) | Timeout → AI inactive |
| Experts: sidecar / HTTP timeout spam | Inference never applied |
| Trades still execute | PROD only — **AI did not score** |

### 5.2 Prevent checklist

| Do | Don't |
|----|-------|
| **Live** = HTTP preset + inference server | HTTP preset in Tester without sidecars |
| **Tester** = LogOnly/Gates + sidecars `--mode tester` | Health probe **mid-backtest** |
| **`FILE_COMMON`** → `Common\Files\Logs\` | Agent `MQL5/Files\` for IPC |
| Handshake: **`req != last_req`** | `req > last_req` only |
| Recompile after IPC changes | Start test before sidecars `listening` |

---

## 6. Infrastructure phases (INF-*)

Industry-aligned hardening **before chart LIVE**. One Task ID → one experiment → one journal row (same discipline as P2/AI).

### 6.1 Phase map

| Phase | Name | Primary lever | Unlocks |
|-------|------|---------------|---------|
| **INF-0** | Schema & data contract | Reproducible datasets | CI validation |
| **INF-1** | Structured AI shadow log | Observable sign-off | Prove SHADOW ≠ fail-open |
| **INF-2** | Reproducible Python env | Docker / locked deps | Same metrics on any machine |
| **INF-3** | Golden replay CI | Regression detection | Safe `.mqh` export merges |
| **INF-4** | Feature parity (Py ↔ MQL5) | Silent drift prevention | Trust Tester vs offline n |
| **INF-5** | Walk-forward automation | Pre-LIVE statistics | Replace manual 3-fold rule |
| **INF-6** | Deployment manifest bundle | Traceability | `bundle_id` = deploy unit |
| **INF-7** | Agent / ops ergonomics | `AGENTS.md`, `STATUS.md` | Faster human + AI handoff |
| **INF-8** | v2 runtime IPC *(optional)* | HTTP live + sidecar Tester | Dynamic models without recompile |

### 6.2 INF-GATE (blocks chart LIVE)

All must PASS before preset steps **6–8** on a **live/demo chart**:

| Check | Source |
|-------|--------|
| INF-0 schema validates export + parquet | `build_dataset.py --validate` |
| INF-1 shadow CSV: mixed scores, not 100% neutral | Tester run + CSV audit |
| INF-2 `make replay-all` exits 0 in Docker | CI green |
| INF-3 golden metrics within ε of committed snapshots | CI |
| INF-4 parity: max feature delta &lt; ε on N rows | `parity_check.py` PASS |
| INF-5 walk-forward 3 windows documented | `INF-test-journal.csv` |
| INF-6 manifest `bundle_id` matches EA + presets | Manual review |
| AI Tester sign-off | `AI-test-journal.csv` steps 3–5 minimum |

**INF-8** not required for v1 `.mqh` chart LIVE — only for runtime inference track.

---

### 6.3 INF-0 — Schema & data contract

**Goal:** Single versioned schema; fail fast on bad exports.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-0-001** | `schemas/decisions.v1.json` column spec | Schema file | ✅ |
| **INF-0-002** | `Diagnostics/ai/schema.py` (Pydantic or dataclass) | Validators | ✅ |
| **INF-0-003** | `build_dataset.py --validate` | Exit non-zero on schema fail | ✅ |
| **INF-0-004** | Unique `decision_id` · no dup executed rows | Validation rule | ✅ |
| **INF-0-005** | Schema bump procedure doc in schema file | `v1` → `v2` policy | ✅ |

**Gate:** Full 6y export builds parquet with zero validation errors. ✅ PASS on `ORBVWAP_ai_dataset_v1.parquet` (journal `INF-0-006`).

---

### 6.4 INF-1 — Structured AI shadow log

**Goal:** Replace Experts-only SHADOW audit with joinable CSV.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-1-001** | `AiShadowExport.mqh` · `InpEnableAiShadowLog` | EA module | ✅ |
| **INF-1-002** | `ORBVWAP_ai_shadow.csv` columns (see below) | File spec | ✅ |
| **INF-1-003** | Log on every signal evaluation (SHADOW + LIVE) | Pipeline hook | ✅ |
| **INF-1-004** | Preset `ORBVWAP_AI1234_SHADOW` + export ON | Tester preset | ✅ |
| **INF-1-005** | Audit script `audit_shadow.py` — fail if all neutral | CI/local gate | ✅ |

**Minimum columns:** `bar_time_gmt`, `sess_key`, `decision_id`, `ai1_score`, `ai1_pass`, `ai2_mult`, `ai3_allow`, `ai4_would_scratch`, `mode_ai1`, `mode_ai2`, `mode_ai3`, `mode_ai4`, `ea_version`, `bundle_id`.

**Gate:** Tester backtest produces ≥2 distinct score buckets · 0% all-neutral rows. ✅ PASS `INF-1-006` (v1.23 · 55 buckets · 16965 rows).

---

### 6.5 INF-2 — Reproducible Python environment

**Goal:** Identical replay results on any host.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-2-001** | `pyproject.toml` + locked deps | Root package | ✅ |
| **INF-2-002** | `Dockerfile` · Python 3.11+ slim | `docker/` | ✅ |
| **INF-2-003** | `Makefile` targets: `replay-all`, `train-all`, `simulate-ai2` | `Makefile` | ✅ |
| **INF-2-004** | `.env.example` — Tester Files path, terminal ID | Config template | ✅ |
| **INF-2-005** | Document `docker compose run replay-all` | README | ✅ |

**Gate:** Fresh container runs all AI replay gates · metrics match local journal within ε. ✅ PASS local `replay_all.py` (`INF-2-006`); Docker: `make docker-replay` or `docker compose run replay-all`.

---

### 6.6 INF-3 — Golden replay CI

**Goal:** Block merges that break holdout metrics.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-3-001** | `tests/golden/ai0_v1.json` — AI-0 baseline holdout metrics | Snapshot | ✅ |
| **INF-3-002** | Golden files `ai2_v1.json`, `ai3_v1.json`, `ai4_v1.json` | Snapshots | ✅ |
| **INF-3-003** | `tests/test_replay_golden.py` · ε tolerances (PF ±0.05) | Pytest | ✅ |
| **INF-3-004** | `.github/workflows/orbvwap-ai-replay.yml` on ORBVWAP push | Workflow | ✅ |
| **INF-3-005** | `golden_replay.py --update-golden` only | Safety flag | ✅ |

**Gate:** CI PASS on main · intentional metric change requires `--update-golden` + `INF-test-journal.csv` note. ✅ PASS local `make test-golden` (`INF-3-006`); GitHub Actions: `orbvwap-ai-replay.yml`.

---

### 6.7 INF-4 — Feature parity (Python ↔ MQL5)

**Goal:** EA features match training features.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-4-001** | `export_feature_sample.py` — N rows dual columns | Sample parquet | ✅ |
| **INF-4-002** | `AiFeatures.mqh` shared by export + `AiScorer` · optional `feat_*` CSV cols | MQL5 side | ✅ |
| **INF-4-003** | `parity_check.py` · max abs delta per feature | Report | ✅ |
| **INF-4-004** | INF-GATE requires parity PASS | Gate rule | ✅ |

**Gate:** All FEATURE_ORDER columns · max Δ &lt; 1e-4 on executed rows. ✅ PASS `parity_check.py --all-rows` (`INF-4-006`); CI step in `orbvwap-ai-replay.yml`.

---

### 6.8 INF-5 — Walk-forward automation

**Goal:** Automate the harness rule currently marked UNDONE in [ailayers.md](./ailayers.md).

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-5-001** | `walkforward.py` — 3 rolling cuts | Metrics table | ✅ |
| **INF-5-002** | Run on AI-3 + AI-1 + AI-2 stack | Journal rows | ✅ |
| **INF-5-003** | Pass rule: stack PF ≥ PROD×0.95 per window | Gate | ✅ |

**Gate:** 3 windows PASS · row per window in `INF-test-journal.csv`. ✅ PASS `walkforward.py` (`INF-5-006`); WF-1..3 stack PF 1.18 / 2.25 / 1.33 vs prod 0.83 / 1.66 / 1.28.

---

### 6.9 INF-6 — Deployment manifest bundle

**Goal:** One deployable unit — not loose `.mqh` + preset.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-6-001** | Extend `models/manifest.json` → `bundle_id`, `git_sha`, `presets[]` | Bundle schema | ✅ |
| **INF-6-002** | `scripts/build_bundle.py` — stamp EA version + models | Artifact | ✅ |
| **INF-6-003** | EA logs `bundle_id` at `OnInit` | Traceability | ✅ |
| **INF-6-004** | Chart LIVE uses pinned bundle only | Ops rule | ✅ |

**Gate:** Tester + chart run share same `bundle_id` in logs/CSV. ✅ PASS `build_bundle.py --verify` (`INF-6-006`); `orbvwap-v1.23-ai1234` · git `b9f3328` · 9 presets pinned.

---

### 6.10 INF-7 — Agent & ops ergonomics

**Goal:** Faster onboarding for you and coding agents.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-7-001** | `AGENTS.md` — repo map, commands, gates | Root doc | ✅ |
| **INF-7-002** | `Scripts/status.py` → `STATUS.md` from journals | Live dashboard | ✅ |
| **INF-7-003** | `Diagnostics/INF-test-journal.csv` | Infra audit trail | ✅ |
| **INF-7-004** | Doc ownership: Design=wiring · aidesign=models · Profile=edge | Reduce duplication | ✅ |

**Gate:** `python Scripts/status.py` prints AI + INF gate summary in one table. ✅ PASS `make status` (`INF-7-006`); **INF-GATE PASS** declared in [STATUS.md](./STATUS.md).

---

### 6.11 INF-8 — v2 runtime IPC *(optional · after v1 chart LIVE)*

**Goal:** Dynamic inference without recompile per retrain.

| Task ID | Task | Output | Status |
|---------|------|--------|--------|
| **INF-8-001** | Port VWAPMRE `FILE_COMMON` sidecar pattern | `Ai*Sidecar.mqh` | ⬜ |
| **INF-8-002** | HTTP inference server + live preset | Python server | ⬜ |
| **INF-8-003** | Tester LogOnly preset + sidecar startup doc | Runbook | ⬜ |
| **INF-8-004** | Fail-open audit same as INF-1 | Shadow/neutral check | ⬜ |

**Gate:** Tester mixed scores via sidecars · live mixed scores via HTTP · no neutral-only runs.

---

### 6.12 Suggested implementation order

```
INF-0  Schema          (foundation — do first)
  ↓
INF-2  Docker/Makefile (repro env)
  ↓
INF-3  Golden CI       (protect replay)
  ↓
INF-1  Shadow CSV      (Tester audit)
  ↓
INF-4  Parity check     (trust EA ↔ Python)
  ↓
INF-5  Walk-forward     (pre-LIVE stats)
  ↓
INF-6  Manifest bundle  (deploy unit)
  ↓
INF-7  AGENTS/STATUS    (ops)
  ↓
INF-GATE PASS  →  chart LIVE allowed (AI preset steps 6–8)
  ↓
INF-8  (optional) v2 IPC when retrain cadence needs runtime models
```

**Parallel OK:** INF-7 docs anytime · MT5 Tester AI steps 3–5 while INF-0…3 in progress.

---

## 7. Sign-off wiring chart (AI presets)

### 7.1 Validation tracks (separate gates)

| Track | Environment | Preset steps | Gate file | Blocks chart LIVE? |
|-------|-------------|--------------|-----------|-------------------|
| **A — AI Tester** | Strategy Tester only | 0–5 (SHADOW/LIVE in tester) | `AI-test-journal.csv` | No |
| **B — Infra** | Docker / CI / scripts | INF-0…INF-7 | `INF-test-journal.csv` | **Yes** until INF-GATE |
| **C — AI chart LIVE** | Demo / small live | 6–8 | Both journals | Requires A + B |
| **D — Forward** | Real slippage | P3-004 | Forward journal | After C stable |

### 7.2 Layer wiring per preset

| Layer | EA input | OFF | SHADOW | LIVE |
|-------|----------|-----|--------|------|
| **AI-3** | `InpAiRegimeMode` | — | Log | Skip session |
| **AI-1** | `InpAiGateMode` | — | Log score | Block |
| **AI-2** | `InpAiSizeMode` | 1.0× | Log mult | Scale |
| **AI-4** | `InpAiExitMode` | PROD exit | Log STALL | Close |

### 7.3 Preset ladder

| Step | Preset | AI-1 | AI-2 | AI-3 | AI-4 | Track | Status |
|------|--------|:----:|:----:|:----:|:----:|-------|--------|
| 0 | `PROD_EURUSD-M1` | — | — | — | — | A | ✅ |
| 1 | `AI0_Export_*` | export | — | — | — | A | ✅ |
| 2 | `AI1_SHADOW_*` | log | — | — | — | A | optional |
| 3 | `AI123_SHADOW_*` | **L** | log | log | — | A | ✅ |
| 4 | `AI1234_SHADOW_*` | **L** | log | **L** | log | A | ✅ |
| 5 | `AI12_SHADOW_*` | **L** | log | — | — | A | ✅ |
| 6 | **`AI123_LIVE_*`** | **L** | — | **L** | — | **C** | ⬜ · **INF-GATE PASS** |
| 7 | `AI1234_SIZING_LIVE_*` | **L** | **L** | **L** | log | **C** | ✅ Tester |
| 8 | **`AI1234_LIVE_*`** | **L** | **L** | **L** | **L** | **C** | ⬜ last |

**Legend:** **L** = LIVE (2) · **log** = SHADOW (1) · **—** = OFF (0)

**Preset paths:** `Presets/ORBVWAP_*.set` · `MQL5/Profiles/Tester/`.

### 7.4 Rollback

| Action | Effect |
|--------|--------|
| Load `ORBVWAP_PROD_EURUSD-M1` | All AI OFF |
| Set single `InpAi*Mode=0` | Disable one layer |
| Revert preset step | Step back one promotion |

---

## 8. Sign-off procedures

### 8.1 Track A — MT5 Tester (allowed now)

1. Compile ORBVWAP v1.22 (F7) after `.mqh` change.  
2. Load preset for target step · EURUSD M1 · 6y.  
3. Verify trade band · Experts log.  
4. Append `AI-test-journal.csv`.  
5. *(When INF-1 done)* run `audit_shadow.py` on `ORBVWAP_ai_shadow.csv`.

**Does not authorize chart LIVE.**

### 8.2 Track B — Infra pipeline

1. Complete INF-0…INF-7 tasks in suggested order (parallel where noted).  
2. One row per task in `Diagnostics/INF-test-journal.csv`.  
3. CI green · parity PASS · walk-forward PASS.  
4. Declare **INF-GATE PASS** in `STATUS.md` (`make status`).

### 8.3 Track C — Chart LIVE (after INF-GATE)

1. Confirm INF-GATE + AI Tester step PASS for target preset.  
2. Confirm preset is listed in `models/manifest.json` · `bundle_id` matches compiled EA (`build_bundle.py --verify`).  
3. Attach **same preset** on demo chart · minimum size.  
4. Run ≥2 weeks or P3-004 protocol · journal slippage vs Tester.  
5. Promote next preset step only after stable.

### 8.4 Reference metrics

| Run | n | PF | DD | Notes |
|-----|---|-----|-----|-------|
| PROD | 358 | 1.29 | 8.6% | Baseline |
| AI1234 SHADOW (Tester) | 315 | 1.53 | 5.9% | `AI-1234-005` |
| AI-2 sim (offline stack) | 304 | 1.66 | 10.6% | `simulate_ai2.py` +18% net |

---

## 9. Artifact paths (current + planned)

| Path | Purpose | Phase |
|------|---------|-------|
| `Include/ORBVWAP/Ai*.mqh` | Compiled AI rules | AI-* |
| `models/manifest.json` | Deployment bundle registry | INF-6 |
| `scripts/build_bundle.py` | Build / verify bundle | INF-6 |
| `schemas/bundle.v1.json` | Bundle contract | INF-6 |
| `schemas/decisions.v1.json` | Data contract | INF-0 |
| `Diagnostics/ai/*.py` | Train, replay, simulate | AI-* |
| `Diagnostics/ai/simulate_ai2.py` | Sizing stack sim | AI-2 |
| `Diagnostics/AI-test-journal.csv` | AI Tester sign-off | AI-* |
| `Diagnostics/INF-test-journal.csv` | Infra sign-off | INF-* |
| `Diagnostics/logs/*.jsonl` | Structured replay logs | INF-2 |
| `tests/golden/*.json` | CI snapshots | INF-3 |
| `Include/ORBVWAP/AiFeatures.mqh` | Shared AI-1 feature vector | INF-4 |
| `Diagnostics/ai/features.py` · `parity_check.py` | Py ↔ export parity | INF-4 |
| `Diagnostics/datasets/feature_parity_sample.parquet` | Dual-column audit sample | INF-4 |
| `Diagnostics/ai/walkforward.py` | 3-fold walk-forward gate | INF-5 |
| `ORBVWAP_ai_shadow.csv` | AI decision audit | INF-1 |
| `AGENTS.md` · `STATUS.md` | Ops / agent handoff | INF-7 |
| `Presets/` · `Profiles/Tester/` | Wiring | AI-* |

---

## 10. Related documents

| Document | Content |
|----------|---------|
| [System Profile.md](./System%20Profile.md) | PROD edge, metrics |
| [aidesign.md](./aidesign.md) | AI models, trade profiles |
| [ailayers.md](./ailayers.md) | AI phase tasks AI-0…AI-4 |
| [Diagnostics/ai/README.md](./Diagnostics/ai/README.md) | Python commands |

---

## 11. One-line summary

**ORBVWAP system design** = frozen PROD v3 + versioned AI (`.mqh` v1) with **Tester sign-off now**, **infra phases INF-0…INF-7 before chart LIVE**, and optional **INF-8 IPC** later — all traced through journal files and a deployment bundle.
