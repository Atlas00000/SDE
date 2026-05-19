# AI-1 — Canonical C1 dataset

**Status:** **Next** (user action in Strategy Tester)

---

## Why

Current `Common/Files/VEM_trades_EURUSD_M5.csv` mixes production-path trades with **E10 experiment** rows (`e10` exits). Phase 3 models need **one** clean export from the locked production stack.

---

## Steps (MT5 Strategy Tester)

1. **Delete or rename** existing `VEM_trades_EURUSD_M5.csv` in `Terminal/Common/Files/` (backup first if needed).
2. In Strategy Tester → **Inputs** → **Load** → **`VEM.C1_Production`**  
   (file: `MQL5/Profiles/Tester/VEM.C1_Production.set` — must start with `VEM` to show in the list).  
   Production without log: **`VEM.Production`**.
3. Symbol **EURUSD** · **M5** · deposit **$200** · lot **0.01**.
4. Run **full span** (match production evidence):
   - IS: `2024.01.01` → `2024.12.31`
   - OOS: `2025.01.01` → `2026.05.15`  
   Or one continuous `2024.01.01` → `2026.05.15` run.
5. Copy resulting CSV to archive name, e.g.  
   `VEM_trades_EURUSD_M5_prod_20260519.csv`
6. Re-run analysis:
   ```powershell
   cd MQL5\Experts\VEM
   python scripts/c1b_production_buckets.py --csv "...\VEM_trades_EURUSD_M5_prod_20260519.csv"
   python scripts/train_ai_v0.py --csv "...\VEM_trades_EURUSD_M5_prod_20260519.csv"
   ```

---

## Pass checks

| Check | Target |
|-------|--------|
| OOS trades | ~**111** |
| OOS net | ~**+$9.08** |
| No `e10` exits | 0 |
| Exit mix | mostly `midline`, some `sl` / `e8c` |

---

## After AI-1

- Re-evaluate **AI-2** / **AI-3** on clean file only.
- Then consider **AI-4** shadow if val AUC ≥ ~0.60 stable.
