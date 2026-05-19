# Step E14 — Tester results (T-E14)

**Preset:** `VEM.E14_Production` · **Date:** 2026-05-19  
**Verdict:** **DISCARD** — E14 stays **OFF**; exit R&D **closed**

---

## T-E14 (reported)

| Metric | Value |
|--------|------:|
| Total trades | **289** |
| Net profit | **−$2.46** |
| Profit factor | **0.97** |
| Win rate | **62.63%** (181 / 108) |
| Avg win / avg loss | **$0.43** / **−$0.75** |
| Max equity DD | **$13.71** (**6.81%**) |

---

## vs pass bar

| Gate | Required | T-E14 |
|------|----------|-------|
| OOS net | ≥ **+$9.08** | **FAIL** |
| PF | ≥ **1.30** | **FAIL** (0.97) |
| WR | ≥ **65%** | **FAIL** (62.6%) |
| ↓ avg loss | vs prod | **FAIL** (loss > win) |

Same failure class as **E13** / **E10** — do not promote.

---

## Default after exit R&D

Use **`VEM.AI_Skip`** (rules + ~2% entry veto). Rollback / rules-only baseline: **`VEM.Production`**.
