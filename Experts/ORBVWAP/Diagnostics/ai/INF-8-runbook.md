# INF-8 — v2 runtime IPC runbook

Full **AI-1..AI-4** stack from `models/*.json` via Python — no `.mqh` recompile after retrain. Live chart preset **`AI1234_HTTP_LIVE`** mirrors compiled **`AI1234_LIVE`**.

## Transports

| Environment | Preset | Transport | Python process |
|-------------|--------|-----------|----------------|
| **Strategy Tester** | `ORBVWAP_AI1_SIDECAR_SHADOW_*` | `FILE_COMMON` binary IPC | `ai1_sidecar.py --mode tester` |
| **Live / demo chart (full stack)** | `ORBVWAP_AI1234_HTTP_LIVE_*` | `WebRequest` → localhost | `ai_inference_server.py` |
| **Live / demo (AI-1 only · legacy)** | `ORBVWAP_AI1_HTTP_SHADOW_*` | `WebRequest` → localhost | `ai_inference_server.py` |
| **Default v1** | `ORBVWAP_AI1234_LIVE_*` | Compiled `.mqh` | none |

Shared IPC path (both EA and Python):

`%APPDATA%\MetaQuotes\Terminal\Common\Files\Logs\ORBVWAP_ai1_sidecar.bin`

Port **8766** (ORBVWAP) — distinct from VWAPMRE **8765**.

## Strategy Tester (sidecar)

1. Recompile EA (F7) after pulling INF-8 changes.
2. Start sidecar **before** pressing Start in Tester:

   ```powershell
   cd Experts\ORBVWAP
   python Scripts/ai1_sidecar.py --mode tester
   ```

3. Load preset `ORBVWAP_AI1_SIDECAR_SHADOW_PROD_EURUSD-M1.set`.
4. Run backtest with `InpEnableAiShadowLog=true`.
5. Audit shadow CSV (same gate as INF-1):

   ```powershell
   python Diagnostics/ai/audit_shadow.py "%APPDATA%\MetaQuotes\Terminal\Common\Files\Logs\ORBVWAP_ai_shadow.csv"
   ```

6. Health probe (optional):

   ```powershell
   python Scripts/ai_sidecar_health.py --mode tester
   ```

### Sidecar rules

- Sidecar accepts **`req != last_req`** (not `>`).
- EA writes 10-feature vector; Python scores from `models/ai1_v1.json`.
- Timeout / missing sidecar → **fail-open `ai1_score=0.5`** (logged in Experts).

## Live chart (HTTP full stack)

1. Start inference server (loads **all** `models/ai*_v1.json`):

   ```powershell
   python Scripts/ai_inference_server.py
   curl http://127.0.0.1:8766/health
   ```

2. MT5 → **Tools → Options → Expert Advisors** → allow `http://127.0.0.1:8766`.

3. Attach EA with **`ORBVWAP_AI1234_HTTP_LIVE_PROD_EURUSD-M1.set`** (full stack LIVE from Python).

4. Experts log on init: `AI runtime=HTTP full stack (AI-1..AI-4 from Python)`.

5. Audit shadow CSV after session(s) — mixed scores, not 100% fail-open.

## Retrain loop (runtime)

1. Retrain → update `models/ai*_v1.json` (and optionally regenerate `.mqh` for v1 fallback).
2. **Restart** sidecar or HTTP server (loads JSON on start).
3. No EA recompile required when using INF-8 HTTP / sidecar presets.

## pytest gate

```bash
python -m pytest tests/test_ai1_ipc.py tests/test_stack_runtime.py -v
make test-ipc
```

## Fail-open audit (INF-8-004)

Uses the same `audit_shadow.py` as INF-1:

- ≥ 2 distinct `ai1_score` buckets on active rows
- Not 100% stuck at neutral (0.5 or 1.0)
- Sidecar/HTTP timeout spam in Experts = investigate before sign-off
