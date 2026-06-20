# ORBVWAP STATUS

**Generated:** 2026-06-20 00:40 UTC · `python Scripts/status.py --write`

## INF-GATE: **PASS**

Chart LIVE (preset steps 6 & 8) requires INF-GATE **PASS** + demo sign-off.

| Field | Value |
|-------|-------|
| bundle_id | `orbvwap-v1.23-ai1234` |
| ea_version | `1.23` |
| git_sha | `b9f3328` |

## Infra gates (Track B)

| Phase | Gate | Task | Verdict | Notes |
|-------|------|------|---------|-------|
| INF-0 | Schema + dataset | `INF-0-006` | **PASS** | decisions+outcomes+dataset v1 contracts; 0 dup d |
| INF-1 | Shadow CSV audit | `INF-1-006` | **PASS** | EA v1.23; 16965 eval rows; ai1 55 buckets (0.053 |
| INF-2 | Reproducible replay | `INF-2-006` | **PASS** | local + Docker orbvwap-ai image; holdout pf 1.43 |
| INF-3 | Golden replay CI | `INF-3-006` | **PASS** | golden_replay.py + pytest; GitHub Actions orbvwa |
| INF-4 | Feature parity | `INF-4-006` | **PASS** | AiFeatures.mqh shared export+scorer; export_feat |
| INF-5 | Walk-forward gate | `INF-5-006` | **PASS** | AI-3+AI-1+AI-2 stack; no OOS window PF < PROD*0. |
| INF-6 | Deployment bundle | `INF-6-006` | **PASS** | git b9f3328; 9 presets; EA OnInit logs bundle_id |
| INF-7 | Ops dashboard | `INF-7-006` | **PASS** | INF-GATE PASS; AI+INF table from journals; doc o |

## Optional — runtime IPC (INF-8 · does not block chart LIVE v1)

| Phase | Gate | Task | Verdict | Notes |
|-------|------|------|---------|-------|
| INF-8 | Runtime IPC (v2) | `INF-8-006` | **PASS** | IPC 116-byte ORI1 block; HTTP :8766; presets SID |

## AI Tester gates (Track A minimum)

| Step | Gate | Task | Verdict | Notes |
|------|------|------|---------|-------|
| AI-3 | AI123_SHADOW Tester | `AI-123-005` | **PASS** | AI1 LIVE AI2/3 SHADOW; WR 54.97% DD 8.34% net 34 |
| AI-4 | AI1234_SHADOW Tester | `AI-1234-005` | **PASS** | AI1+AI3 LIVE AI2+AI4 SHADOW; WR 58.10% DD 5.89%  |
| AI-5 | AI12_SHADOW Tester | `AI-12-006` | **PASS** | AI1 LIVE AI2 SHADOW; WR 54.81% DD 8.34% net 34.1 |

## Preset ladder

| Step | Preset | Track | Status | Journal |
|------|--------|-------|--------|---------|
| 0 | `PROD_EURUSD-M1` | A | PASS | AI-0-003 |
| 1 | `AI0_Export_*` | A | PASS | AI-0-003 |
| 2 | `AI1_SHADOW_*` | A | optional | — |
| 3 | `AI123_SHADOW_*` | A | PASS | AI-123-005 |
| 4 | `AI1234_SHADOW_*` | A | PASS | AI-1234-005 |
| 5 | `AI12_SHADOW_*` | A | PASS | AI-12-006 |
| 6 | `AI123_LIVE_*` | C | BLOCKED | — |
| 7 | `AI1234_SIZING_LIVE_*` | C | PASS | AI-1234-SIZING-006 |
| 8 | `AI1234_LIVE_*` | C | BLOCKED | — |

## Quick commands

```bash
make status          # regenerate this file
make replay-all      # INF-2
make test-golden     # INF-3
make parity-check    # INF-4
make walkforward     # INF-5
python Scripts/build_bundle.py --verify   # INF-6
make test-ipc        # INF-8 (optional)
```

See [AGENTS.md](./AGENTS.md) for full repo map.
