# AI pipeline

**Offline training:** ✅ **CLOSED** (2026-06-11) · all layers PASS in `Diagnostics/AI-test-journal.csv`  
**Sign-off:** [aidesign.md §6.5](../aidesign.md#65-sign-off-wiring-chart--connection-rules) · [ailayers.md](../ailayers.md)

---

## Sign-off preset chart (v1 · compile-time `.mqh`)

| Step | Preset | AI-1 | AI-2 | AI-3 | AI-4 | Tester | Live |
|------|--------|------|------|------|------|--------|------|
| 0 | `PROD_EURUSD-M1` | OFF | OFF | OFF | OFF | ✓ | ✓ |
| 1 | `AI0_Export` | export CSV | | | | ✓ | — |
| 2 | `AI1_SHADOW` | SHADOW | OFF | OFF | OFF | ✓ | optional |
| 3 | `AI123_SHADOW` | LIVE | SHADOW | SHADOW | OFF | ✅ done | — |
| 4 | `AI1234_SHADOW` | LIVE | SHADOW | LIVE | SHADOW | ✅ done | — |
| 5 | `AI12_SHADOW` | LIVE | SHADOW | OFF | OFF | ⬜ | — |
| 6 | **`AI123_LIVE`** | LIVE | OFF | LIVE | OFF | ⬜ | **deploy** |
| 7 | `AI1234_SIZING_LIVE` | LIVE | LIVE | LIVE | SHADOW | ⬜ | after 6 |
| 8 | **`AI1234_LIVE`** | LIVE | LIVE | LIVE | LIVE | ⬜ | last |

**After retrain:** `train_*.py` → recompile EA → reload preset.

### v2 IPC (future · not in ORBVWAP v1 yet)

- **Tester:** `FILE_COMMON` sidecars in `Terminal\Common\Files\Logs\` · start sidecars **before** test · `req != last_req`
- **Live:** HTTP inference preset · **not** HTTP in Tester
- **Fail-open:** neutral scores + timeout log = AI inactive (rules-only trades)
- **Never:** health probe mid-backtest · agent `MQL5/Files/` for IPC

---

## 1. Backtest export (MT5) — AI-0

*Done for v1. Re-run only on retrain trigger.*

1. Delete old `ORBVWAP_decisions.csv` and `ORBVWAP_outcomes.csv` in Tester agent `MQL5/Files/`.
2. Compile **ORBVWAP v1.22+**.
3. Load `ORBVWAP_AI0_Export_PROD_EURUSD-M1_full.set`.
4. Run EURUSD M1 backtest (e.g. 6-year window).

## 2. Build dataset — AI-0 ✅

```bash
pip install pandas pyarrow

python Diagnostics/ai/build_dataset.py ^
  "%APPDATA%\MetaQuotes\Tester\<terminal>\Agent-127.0.0.1-3000\MQL5\Files\ORBVWAP_decisions.csv" ^
  "%APPDATA%\MetaQuotes\Tester\<terminal>\Agent-127.0.0.1-3000\MQL5\Files\ORBVWAP_outcomes.csv"
```

Output: `Diagnostics/datasets/ORBVWAP_ai_dataset_v1.parquet`

## 3. Baseline replay — AI-0 ✅

```bash
python Diagnostics/ai/replay_policy.py
```

Result: n=358 · PF=1.29 · holdout PF=1.43 · journal `AI-0-003` **PASS**.

## 4. AI-1 L1 scorer — offline ✅

```bash
python Diagnostics/ai/train_l1.py
```

Outputs: `models/ai1_v1.json` · `Include/ORBVWAP/AiScorer.mqh` · journal `AI-1-003` **PASS** (τ=0.30 · holdout PF=1.49).

## 5. AI-1 MT5 — partial ✅

Journal: `AI-123-005` · preset `ORBVWAP_AI123_SHADOW_PROD` · 342 trades · PF=1.33 · DD=8.34%.

## 6. AI-2 sizing — offline ✅

```bash
python Diagnostics/ai/replay_sizing.py
python Diagnostics/ai/simulate_ai2.py
```

Outputs: `models/ai2_v1.json` · `AiSizer.mqh` · journal `AI-2-002` **PASS**.  
Sim: deploy stack net **+18%** · production-safety checks PASS · MT5 proj **~$54.62** from $46.33 base.

**Undone:** MT5 `AI12_SHADOW` · `AI1234_SIZING_LIVE` Tester run.

## 7. AI-3 regime — offline ✅

```bash
python Diagnostics/ai/train_regime.py
python Diagnostics/ai/replay_regime.py
```

Journal `AI-3-003` **PASS** · holdout n=97 · PF=1.43.

**Undone:** `AI123_LIVE` Tester + demo sign-off.

## 8. AI-4 exit overlay — offline ✅ *(proxy paths)*

```bash
python Diagnostics/ai/build_paths.py
python Diagnostics/ai/train_exit.py
python Diagnostics/ai/replay_exit.py
```

Stall scratch: **45 min**, close if MFE &lt; **0.25× range**.

**Undone:** real paths v2 · `AI1234_LIVE` with exit LIVE (last).

## 9. Full-stack MT5 — partial ✅

| Preset | AI-1 | AI-2 | AI-3 | AI-4 | Journal |
|--------|------|------|------|------|---------|
| `AI123_SHADOW` | LIVE | SHADOW | SHADOW | OFF | `AI-123-005` |
| `AI1234_SHADOW` | LIVE | SHADOW | LIVE | SHADOW | `AI-1234-005` |
| `AI12_SHADOW` | LIVE | SHADOW | OFF | OFF | ⬜ |
| `AI123_LIVE` | LIVE | OFF | LIVE | OFF | ⬜ deploy |
| `AI1234_SIZING_LIVE` | LIVE | LIVE | LIVE | SHADOW | ⬜ |
| `AI1234_LIVE` | LIVE | LIVE | LIVE | LIVE | ⬜ last |

Promote one preset stage at a time · journal each Tester run.
