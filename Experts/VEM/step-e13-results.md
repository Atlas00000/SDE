# Step E13 — Tester results (T-E13)

**Preset:** `VEM.E13_Production` · **Date:** 2026-05-19  
**Verdict:** **DISCARD** — E13 stays **OFF** on production

---

## T-E13 (reported)

| Metric | Value |
|--------|------:|
| Total trades | **289** |
| Net profit | **−$1.10** |
| Profit factor | **0.99** |
| Win rate | **60.21%** (174 / 115) |
| Gross profit / loss | $77.24 / −$78.34 |
| Avg win / avg loss | **$0.44** / **−$0.68** |
| Max equity DD | $12.79 (**6.35%**) |
| Sharpe | −0.44 |

---

## vs pass bar (production control reference)

| Gate | Required | T-E13 |
|------|----------|-------|
| OOS net | ≥ **+$9.08** | **FAIL** (−$1.10 on run window) |
| PF | ≥ **1.30** | **FAIL** (0.99) |
| WR | ≥ **65%** | **FAIL** (60.2%) |
| Avg loss | ↓ vs prod (~$0.91) | **FAIL** (loss **larger** than win) |

**Production ref (locked):** ~**396** tr full · OOS **111** · **+$9.08** · PF **1.30** · WR **~70%**.

---

## Interpretation

- E13 v1 **does not** improve expectancy: scratches / early closes **cut WR** and leave **avg loss > avg win**.
- Same failure mode as **E10** family (state exit on low MFE) — not promoted on production stack.
- **289** trades vs **~396** prod full-span — confirm tester **from/to** matches `VEM.Production` T-CTRL; if dates differ, re-run control for apples-to-apples.

---

## Next

- **E13:** OFF on `VEM.Production` (default). No E13-v2 unless new hypothesis.
- **Queue:** **E14** (soft SL tighten) or stop rules-exit R&D; deploy **`VEM.Production`** / optional **`VEM.AI_Skip`**.
