# P4-0 — Phase 3 sign-off (frozen baseline)

**Date:** 2026-05-19 · **Symbol/TF:** EURUSD M5 · **Lot:** 0.01

Phase 3 (AI v0.1 entry layer) is **signed off in Strategy Tester**. Phase 4 work may begin. **Production reference** is frozen to `VEM.Production` (rules only).

---

## Frozen production control

| Item | Value |
|------|--------|
| **Preset** | `VEM.Production` |
| **Rules** | D1 + D6 + D7 + midline + E8c @ bar 4 |
| **AI inputs** | `inp_ai_shadow_enable=false` · `inp_ai_skip_enable=false` |
| **Archive** | `data/c1/VEM_trades_EURUSD_M5_prod_2023_2026_396.csv` |
| **Tester window** | 2023.01.01 → 2026.05.15 |

### Full span (396 trades)

| Net $ | PF | WR % | Trades |
|------:|---:|-----:|-------:|
| **+16.58** | **1.17** | **~65.7** | **396** |

### OOS pass window (2025-01-01 → 2026-05-15)

| Net $ | PF | WR % | Trades |
|------:|---:|-----:|-------:|
| **+9.08** | **1.30** | **~70.3** | **111** |

*Pass bar for all Phase 4 experiments: OOS net **≥ +$9.08** · PF **≥ 1.30** · WR **≥ 65%** · trades **≥ 100**.*

---

## Phase 3 tester gate (completed)

| Test ID | Preset | Result | Evidence |
|---------|--------|--------|----------|
| **T1 / T5** | `VEM.Production` | **PASS** | 396 · +$16.58 · PF 1.17 |
| **T3** | `VEM.AI_Shadow` | **PASS** | Same 396 trades · `ai_skip=0` · scorer Δ &lt; 0.001 |
| **T4** | `VEM.AI_Skip` | **PASS** | 389 · +$20.30 · OOS 109 · +$9.83 · PF 1.34 |

Reports: [`step-ai4-shadow-backtest.md`](step-ai4-shadow-backtest.md) · [`step-ai-v1-results.md`](step-ai-v1-results.md)

---

## AI v0.1 (optional — not production)

| Preset | Role | Promote to live? |
|--------|------|------------------|
| `VEM.AI_Shadow` | Log `ai_score` / `would_skip` only | No |
| `VEM.AI_Skip` | Block ~2% entries (7 full / 2 OOS) | **Tester only** until explicit decision |

Rollback: load `VEM.Production` → must reproduce table above.

---

## Phase 4 charter (why we proceed)

| Metric | Status | Phase 4 target |
|--------|--------|----------------|
| WR / PF / DD / OOS net | **Acceptable** | **Hold** pass bar |
| Avg loss vs avg win | **Weak** (~0.7–0.9R vs ~0.45R) | ↓ avg loss **0.55–0.65R** |
| Entry skip alone | **Marginal** (+$3.72 full span) | **Not sufficient** |

**Next ID:** **P4-1** (v0.2 half-lot) or **P4-3** (bar-state exit data) per [`filtersrecommedations.md` §10](filtersrecommedations.md#10-phase-4--ai-expectancy--avg-loss).

---

## Sign-off checklist

- [x] Production backtest matches archive (396 / +$16.58 / PF 1.17)
- [x] AI shadow parity (no order impact)
- [x] AI skip validated vs offline AI-3
- [x] Production rollback (E7) confirmed
- [x] Runbook: [`PRODUCTION_RUNBOOK.md`](PRODUCTION_RUNBOOK.md)

**Phase 3:** **CLOSED** · **Phase 4:** **OPEN** (P4-1 next)
