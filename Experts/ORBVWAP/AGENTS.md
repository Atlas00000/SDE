# ORBVWAP — Agent guide

Quick map for humans and coding agents working in this repo.

**Live dashboard:** run `python Scripts/status.py --write` → [STATUS.md](./STATUS.md)

---

## Doc ownership (INF-7-004)

| Document | Owns | Do not duplicate here |
|----------|------|------------------------|
| [System Design.md](./System%20Design.md) | Wiring, INF phases, preset ladder, INF-GATE | Model math, PROD metrics tables |
| [aidesign.md](./aidesign.md) | AI layer design, training gates, ablation | INF pipeline steps |
| [System Profile.md](./System%20Profile.md) | PROD v3 edge, frozen geometry, baseline metrics | AI preset wiring |
| [ailayers.md](./ailayers.md) | AI-0…AI-4 task checklist | Infra Makefile targets |
| [Diagnostics/ai/README.md](./Diagnostics/ai/README.md) | Python CLI commands | System overview |
| **AGENTS.md** (this file) | Repo map + commands | Long-form design prose |
| **STATUS.md** | Generated gate table | Manual edits (regenerate instead) |

---

## Repo layout

```
ORBVWAP/
  ORBVWAP.mq5                 # EA entry
  Include/ORBVWAP/            # MQL5 modules (PROD + Ai*.mqh)
  Presets/                    # .set files (also copy to Profiles/Tester/)
  models/                     # ai*_v1.json + manifest.json (deploy bundle)
  schemas/                    # CSV/parquet contracts (INF-0)
  Diagnostics/
    AI-test-journal.csv       # Track A — MT5 Tester sign-off
    INF-test-journal.csv      # Track B — infra pipeline sign-off
    ai/                       # Offline train + replay + gates
    datasets/                 # ORBVWAP_ai_dataset_v1.parquet
  tests/                      # pytest (golden, parity, walk-forward, bundle)
  Scripts/                    # build_bundle.py, status.py, ai1_sidecar.py (INF-8)
  Makefile                    # Local gate shortcuts
  docker/                     # Reproducible replay image (INF-2)
```

Git remote root is `MQL5/` (parent of `Experts/ORBVWAP/`).

---

## Critical rules

1. **PROD v3 geometry is frozen** — no signal/exit changes without explicit edge review ([System Profile.md](./System%20Profile.md)).
2. **Chart LIVE ≠ Tester PASS** — preset steps 6 & 8 on a **demo chart** only after **INF-GATE PASS** ([STATUS.md](./STATUS.md)).
3. **Deploy unit = bundle** — `models/manifest.json` `bundle_id` must match `ORBVWAP_BUNDLE_ID` in `Constants.mqh` and shadow CSV.
4. **Retrain loop** — change `.mqh` → recompile EA (F7) → reload preset → journal row.

---

## Makefile targets

```bash
make install            # pip install -r requirements-lock.txt
make replay-all         # INF-2 offline replay gate
make test-golden        # INF-3 pytest golden snapshots
make update-golden      # bump golden JSON (intentional only)
make parity-check       # INF-4 feature parity
make walkforward        # INF-5 3-fold gate
make status             # INF-7 print + write STATUS.md
make test-ipc           # INF-8 IPC + runtime pytest
make docker-replay      # INF-2 in container
```

---

## INF-8 runtime IPC (optional · v2)

See [Diagnostics/ai/INF-8-runbook.md](./Diagnostics/ai/INF-8-runbook.md).

```bash
# Strategy Tester — start BEFORE pressing Start
python Scripts/ai1_sidecar.py --mode tester
python Scripts/ai_sidecar_health.py --mode tester

# Live / demo chart — allow http://127.0.0.1:8766 in MT5 WebRequest list
python Scripts/ai_inference_server.py

make test-ipc
```

---

## Python gates (from repo root)

```bash
# Track B — infra
python Diagnostics/ai/build_dataset.py --validate-parquet Diagnostics/datasets/ORBVWAP_ai_dataset_v1.parquet
python Diagnostics/ai/replay_all.py
python Diagnostics/ai/golden_replay.py
python Diagnostics/ai/parity_check.py --all-rows
python Diagnostics/ai/walkforward.py
python Scripts/build_bundle.py --verify

# Track A — shadow audit (after Tester run)
python Diagnostics/ai/audit_shadow.py path/to/ORBVWAP_ai_shadow.csv --check-ai2

# Dashboard
python Scripts/status.py
python Scripts/status.py --write
```

---

## INF-GATE checklist

All must be **PASS** before chart LIVE (see [System Design.md §6.2](./System%20Design.md#62-inf-gate-blocks-chart-live)):

| Check | Command / journal |
|-------|-------------------|
| INF-0 schema | `INF-0-006` |
| INF-1 shadow | `INF-1-006` + `audit_shadow.py` |
| INF-2 replay | `make replay-all` · `INF-2-006` |
| INF-3 golden CI | `make test-golden` · `INF-3-006` |
| INF-4 parity | `make parity-check` · `INF-4-006` |
| INF-5 walk-forward | `make walkforward` · `INF-5-006` |
| INF-6 bundle | `python Scripts/build_bundle.py --verify` · `INF-6-006` |
| AI Tester 3–5 | `AI-123-005`, `AI-1234-005`, `AI-12-006` |

---

## Preset ladder (summary)

| Step | Preset pattern | Track | Chart? |
|------|----------------|-------|--------|
| 0 | `PROD_EURUSD-M1` | baseline | yes (PROD) |
| 1–5 | `AI*_SHADOW_*` / export | Tester | no |
| 6 | `AI123_LIVE_*` | chart LIVE | after INF-GATE |
| 7 | `AI1234_SIZING_LIVE_*` | Tester | no |
| 8 | `AI1234_LIVE_*` | chart LIVE | last |

Full wiring: [System Design.md §7.3](./System%20Design.md#73-preset-ladder).

---

## CI

GitHub Actions: `MQL5/.github/workflows/orbvwap-ai-replay.yml` on `Experts/ORBVWAP/**` changes.

Runs: `replay_all.py` · golden · parity · walk-forward pytest.

---

## Common agent tasks

| Task | Start here |
|------|------------|
| Fix offline replay drift | `tests/golden/`, `replay_expectations.json` |
| Bump models | `train_l1.py` … `train_exit.py` → `build_bundle.py` → recompile |
| Add journal row | Append CSV; run `make status` |
| MT5 Tester sign-off | Load preset from `Presets/` · EURUSD M1 · 6y · append `AI-test-journal.csv` |
| Chart LIVE | Confirm `STATUS.md` INF-GATE PASS · demo · min lot · 2+ weeks |

---

## Version pins (current)

- **EA:** v1.23 · **bundle:** `orbvwap-v1.23-ai1234`
- **Python:** 3.11+ · locked deps in `requirements-lock.txt`
