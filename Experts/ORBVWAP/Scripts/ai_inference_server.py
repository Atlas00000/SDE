#!/usr/bin/env python3
"""
ORBVWAP INF-8 — Full AI stack HTTP inference server (live chart)

Usage:
  python Scripts/ai_inference_server.py
  curl http://127.0.0.1:8766/health
  curl -X POST http://127.0.0.1:8766/score/batch -H "Content-Type: application/json" -d "{...}"
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from ai1_runtime import FAILOPEN_SCORE, score_from_json  # noqa: E402
from ai_stack_runtime import (  # noqa: E402
    DEFAULT_AI1,
    DEFAULT_AI2,
    DEFAULT_AI3,
    DEFAULT_AI4,
    ai4_params,
    health_payload,
    load_stack,
    score_ai2_mult,
    score_batch,
    score_entry,
    score_regime,
)

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8766
DEFAULT_LOG = SCRIPT_DIR / "logs" / "orbvwap_inference.jsonl"


@dataclass
class InferenceContext:
    stack: dict
    started_at: float
    log_path: Path
    infer_lock: threading.Lock = field(default_factory=threading.Lock)

    @property
    def uptime_s(self) -> float:
        return time.time() - self.started_at


class InferenceLogger:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(
        self,
        route: str,
        latency_ms: float,
        payload: dict[str, Any],
        *,
        error: str | None = None,
        fallback: bool = False,
    ) -> None:
        row = {
            "ts": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
            "route": route,
            "latency_ms": round(latency_ms, 2),
            "fallback": fallback,
            "error": error,
            **payload,
        }
        line = json.dumps(row, separators=(",", ":"), default=str)
        with self._lock:
            with self.path.open("a", encoding="utf-8") as f:
                f.write(line + "\n")


def load_context(
    ai1_path: Path | None,
    ai2_path: Path | None,
    ai3_path: Path | None,
    ai4_path: Path | None,
    log_path: Path,
) -> InferenceContext:
    stack = load_stack(ai1_path, ai2_path, ai3_path, ai4_path)
    return InferenceContext(stack=stack, started_at=time.time(), log_path=log_path.resolve())


def make_handler(ctx: InferenceContext, logger: InferenceLogger):
    class InferenceHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args: Any) -> None:
            sys.stderr.write(f"{self.address_string()} - {fmt % args}\n")

        def _read_json(self) -> dict[str, Any]:
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length <= 0:
                return {}
            raw = self.rfile.read(length)
            if not raw:
                return {}
            parsed = json.loads(raw.decode("utf-8"))
            if not isinstance(parsed, dict):
                raise ValueError("JSON body must be an object")
            return parsed

        def _send_json(self, status: int, payload: dict[str, Any]) -> None:
            body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path.rstrip("/") == "/health":
                self._send_json(
                    200,
                    health_payload(ctx.stack, ctx.uptime_s, str(ctx.log_path)),
                )
                return
            self._send_json(404, {"ok": False, "error": "not_found", "path": self.path})

        def do_POST(self) -> None:
            path = self.path.rstrip("/")
            t0 = time.perf_counter()
            try:
                body = self._read_json()
            except (json.JSONDecodeError, ValueError) as exc:
                self._send_json(
                    200,
                    {
                        "ok": True,
                        "fallback": True,
                        "error": f"bad_json: {exc}",
                        "ai1_score": FAILOPEN_SCORE,
                        "ai2_mult": 1.0,
                        "ai3_allow": True,
                    },
                )
                return

            try:
                with ctx.infer_lock:
                    if path == "/score/ai1":
                        score, _ = score_from_json(ctx.stack["ai1"], body)
                        fb = score == FAILOPEN_SCORE and bool(body)
                        out = {
                            "ok": True,
                            "ai1_score": round(score, 6),
                            "ai2_mult": round(score_ai2_mult(ctx.stack["ai2"], score), 4),
                            "fallback": fb,
                        }
                        a4 = ai4_params(ctx.stack["ai4"])
                        out["ai4_stall_minutes"] = a4["stall_minutes"]
                        out["ai4_stall_mfe_frac"] = a4["stall_mfe_frac"]
                    elif path == "/score/regime":
                        chop, allow, fb = score_regime(ctx.stack["ai3"], body)
                        out = {
                            "ok": True,
                            "chop_prob": round(chop, 6),
                            "ai3_allow": allow,
                            "fallback": fb,
                        }
                    elif path == "/score/entry":
                        ai1_score, ai2_mult, fb = score_entry(
                            ctx.stack["ai1"], ctx.stack["ai2"], body
                        )
                        out = {
                            "ok": True,
                            "ai1_score": round(ai1_score, 6),
                            "ai2_mult": round(ai2_mult, 4),
                            "fallback": fb,
                        }
                    elif path == "/score/batch":
                        out = score_batch(ctx.stack, body)
                    else:
                        self._send_json(404, {"ok": False, "error": "not_found", "path": self.path})
                        return
            except Exception as exc:
                out = {
                    "ok": True,
                    "fallback": True,
                    "error": str(exc),
                    "ai1_score": FAILOPEN_SCORE,
                    "ai2_mult": 1.0,
                    "ai3_allow": True,
                }

            latency_ms = (time.perf_counter() - t0) * 1000.0
            out["latency_ms"] = round(latency_ms, 2)
            logger.write(path, latency_ms, out, error=out.get("error"), fallback=bool(out.get("fallback")))
            self._send_json(200, out)

    return InferenceHandler


def run_server(host: str, port: int, ctx: InferenceContext) -> int:
    logger = InferenceLogger(ctx.log_path)
    handler = make_handler(ctx, logger)
    server = ThreadingHTTPServer((host, port), handler)
    hp = health_payload(ctx.stack, ctx.uptime_s, str(ctx.log_path))
    print(f"ORBVWAP AI stack server: http://{host}:{port}")
    print(f"AI-1 tau={hp['ai1_tau']} · AI-4 stall={hp['ai4_stall_minutes']}m mfe<{hp['ai4_stall_mfe_frac']}")
    print(f"Models: ai1 ai2 ai3 ai4 from models/")
    print(f"Inference log: {ctx.log_path}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nInference server stopped.")
        return 0
    finally:
        server.server_close()


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP full AI stack HTTP server (INF-8)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--ai1-model", type=Path, default=None)
    parser.add_argument("--ai2-model", type=Path, default=None)
    parser.add_argument("--ai3-model", type=Path, default=None)
    parser.add_argument("--ai4-model", type=Path, default=None)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    args = parser.parse_args()

    try:
        ctx = load_context(
            args.ai1_model or DEFAULT_AI1,
            args.ai2_model or DEFAULT_AI2,
            args.ai3_model or DEFAULT_AI3,
            args.ai4_model or DEFAULT_AI4,
            args.log,
        )
        return run_server(args.host, args.port, ctx)
    except OSError as exc:
        print(f"ERROR: bind failed ({exc})", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
