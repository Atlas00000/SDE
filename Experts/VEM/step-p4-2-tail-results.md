# P4-2 — Tail-loss entry skip

**Source:** `data/c2/VEM_trades_v2_EURUSD_M5_prod_20260529_labeled.csv` · n=408  
**Target:** `label_tail_loss` (SL or MAE≥0.75R) · rate **10.3%**  
**Model:** `models/ai_tail_logistic.json` → `Include/VEM/VEM_AI_Tail_Model.inc.mqh`

## Offline model

| Item | Value |
|------|------:|
| Val AUC | 0.619 |
| Test OOS AUC | 0.706 |
| Export skip rate | 9% |
| `skip_prob_threshold` | 0.741683 |

## OOS tail-only skip (C2 manifest window)

| Metric | Value | Pass bar |
|--------|------:|:--------:|
| Net $ | 6.81 | ≥ 9.08 **N** |
| PF | 1.22 | ≥ 1.30 **N** |
| WR % | 69.7 | ≥ 65 **Y** |
| Trades | 109 | ≥ 100 **Y** |
| Skipped | 10 | |

Baseline OOS (no tail skip): **$6.83** — tail-only does **not** promote on C2 OOS alone.

## Combined skip sim (bad + tail, matched C1 OOS n=111)

See [`step-p4-2-tail-combo-sim.md`](step-p4-2-tail-combo-sim.md).

| Policy | Net $ | PF | n | skipped |
|--------|------:|---:|--:|--------:|
| `VEM.AI_Skip` control | 9.08 | 1.30 | 111 | 0 |
| Bad + tail (OR) | 12.53 | 1.76 | 74 | 37 |

Offline combo is **optimistic** (high skip overlap) — **tester sign-off required** before replacing default.

## Promotion gate (tester)

Control: **`VEM.AI_Skip`** · candidate: **`VEM.AI_Tail_Skip`**

| Metric | Control | Pass |
|--------|--------:|:----:|
| OOS net $ | 9.08 | ≥ control |
| OOS PF | 1.30 | ≥ control |
| OOS WR % | 65 | ≥ 65 |
| OOS trades | 100 | ≥ 100 |
| Full-sample net | +$20.30 ref | improve vs +$16.58 prod |

**Do not promote** if combined skip rate ≫ ~12% or OOS trades &lt; 100.

## Workflow

1. Recompile EA (pulls `VEM_AI_Tail_Model.inc.mqh`).
2. Delete old `Common/Files/VEM_ai_shadow_EURUSD_M5.csv` (new header has tail columns).
3. Strategy Tester · EURUSD M5 · 2023–2026 · preset **`VEM.AI_Tail_Shadow`**.
4. `python scripts/validate_ai_tail_shadow.py` — max |Δ| on bad/tail scores ≤ 1e-4.
5. Preset **`VEM.AI_Tail_Skip`** vs **`VEM.AI_Skip`** — fill results below.

### Tester — `VEM.AI_Tail_Shadow` (2023–2026, EURUSD M5)

**Live P&L (no skip — shadow only):** 412 trades · **+$14.59** · PF **1.14** · WR **65.3%** · DD **6.6%**

Parity: [`step-p4-2-tail-shadow.md`](step-p4-2-tail-shadow.md) — bad |Δ| **1.4e-4** · tail |Δ| **5.9e-4** · **PASS**

**Shadow log:** 4357 signal rows · 412 habitat-OK opened · `Common/Files/VEM_ai_shadow_EURUSD_M5.csv`

| Flag (habitat OK) | Rate | Count |
|-------------------|-----:|------:|
| `would_skip_bad` | 1.7% | 7 |
| `would_skip_tail` | 15.5% | 64 |
| `would_skip_any` | 15.8% | 65 |

**Skip sim on matched C1 profits** (395/396 trades aligned):

| Policy | Full net | Full PF | OOS net | OOS PF | OOS n | Gate |
|--------|----------|---------|---------|--------|-------|:----:|
| Baseline (no AI) | +16.58† | 1.17 | **9.08** | 1.30 | 111 | ref |
| Bad only (~2%) | +20.30 | 1.21 | **9.83** | 1.34 | 109 | **Y** |
| Tail only | +26.62 | 1.36 | 11.29 | 1.64 | 75 | **N** (n&lt;100) |
| Bad + tail (OR) | +27.86 | 1.38 | 12.53 | 1.76 | 74 | **N** (n&lt;100) |

† Tester shadow run printed +14.59 / 412 tr (close to C1 ref; 1 trade merge gap).

**Verdict (v1 threshold 0.742):** Parity OK · tail skip ~15% live · combined OOS n=74 — **reject**.

**Retune (Option B):** [`step-p4-2-tail-retune.md`](step-p4-2-tail-retune.md) — new threshold **`0.941500`** · OOS combo sim **$10.32 / PF 1.37 / n=107 / skip 3.6%** — **pass bar Y** vs `AI_Skip` $9.83 / n=109.

**Next:** Recompile → run **`VEM.AI_Tail_Skip`** tester to confirm live numbers.

### Tester — OOS window (user run 2026-05-31)

| Preset | OOS net | OOS PF | OOS n | vs `AI_Skip` ref |
|--------|--------:|-------:|------:|------------------|
| `VEM.AI_Skip` ref | **9.83** | **1.34** | **109** | — |
| Tester (both runs) | **8.33** | **1.24** | **123** | net **N** · PF **N** |

Screenshots for control + candidate showed **identical** stats (123 / $8.33 / PF 1.24) — tail skip likely added **no** extra OOS vetoes vs bad-only, or same preset loaded twice. Either way, **below** sign-off `AI_Skip` OOS.

**Decision: PARK P4-2** — keep default **`VEM.AI_Skip`**. Rollback preset if `AI_Tail_Skip` left loaded.

## Files

| Path | Role |
|------|------|
| `scripts/train_ai_tail.py` | Train + export |
| `scripts/export_ai_tail_model_mqh.py` | MQH weights |
| `scripts/validate_ai_tail_shadow.py` | Shadow parity |
| `Profiles/Tester/VEM.AI_Tail_Shadow.set` | Shadow run |
| `Profiles/Tester/VEM.AI_Tail_Skip.set` | Live skip trial |
