#!/usr/bin/env python3
"""
ORBVWAP INF-8 — Local HTTP inference server for AI-1 (live chart)

Usage:
  python Scripts/ai_inference_server.py
  curl http://127.0.0.1:8766/health
  curl -X POST http://127.0.0.1:8766/score/ai1 -H "Content-Type: application/json" -d "{...}"
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

from ai1_runtime import DEFAULT_MODEL, FAILOPEN_SCORE, load_model, score_from_json  # noqa: E402

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8766
DEFAULT_LOG = SCRIPT_DIR / "logs" / "orbvwap_inference.jsonl"


@dataclass
class InferenceContext:
    model: dict
    model_path: Path
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


def load_context(model_path: Path | None, log_path: Path) -> InferenceContext:
    model_file = (model_path or DEFAULT_MODEL).resolve()
    model = load_model(model_file)
    return InferenceContext(
        model=model,
        model_path=model_file,
        started_at=time.time(),
        log_path=log_path.resolve(),
    )


def score_ai1(ctx: InferenceContext, logger: InferenceLogger, body: dict[str, Any]) -> dict[str, Any]:
    t0 = time.perf_counter()
    fallback = False
    err: str | None = None
    score = FAILOPEN_SCORE

    try:
        with ctx.infer_lock:
            score, _ = score_from_json(ctx.model, body)
        if score == FAILOPEN_SCORE and body:
            fallback = True
            err = err or "invalid_features"
    except Exception as exc:
        fallback = True
        err = str(exc)
        score = FAILOPEN_SCORE

    latency_ms = (time.perf_counter() - t0) * 1000.0
    out = {
        "ok": True,
        "ai1_score": round(float(score), 6),
        "model_id": ctx.model.get("model_id", "ai1_v1"),
        "latency_ms": round(latency_ms, 2),
        "fallback": fallback,
    }
    if err:
        out["error"] = err
    logger.write("/score/ai1", latency_ms, {"ai1_score": out["ai1_score"]}, error=err, fallback=fallback)
    return out


def health_payload(ctx: InferenceContext) -> dict[str, Any]:
    return {
        "ok": True,
        "uptime_s": round(ctx.uptime_s, 2),
        "model_id": ctx.model.get("model_id", "ai1_v1"),
        "model_path": str(ctx.model_path),
        "tau": ctx.model.get("tau", 0.3),
        "log_path": str(ctx.log_path),
        "routes": {"health": "GET /health", "ai1": "POST /score/ai1"},
    }


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
                self._send_json(200, health_payload(ctx))
                return
            self._send_json(404, {"ok": False, "error": "not_found", "path": self.path})

        def do_POST(self) -> None:
            path = self.path.rstrip("/")
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
                    },
                )
                return

            if path == "/score/ai1":
                self._send_json(200, score_ai1(ctx, logger, body))
                return

            self._send_json(404, {"ok": False, "error": "not_found", "path": self.path})

    return InferenceHandler


def run_server(host: str, port: int, ctx: InferenceContext) -> int:
    logger = InferenceLogger(ctx.log_path)
    handler = make_handler(ctx, logger)
    server = ThreadingHTTPServer((host, port), handler)
    print(f"ORBVWAP AI inference server: http://{host}:{port}")
    print(f"Model: {ctx.model_path} tau={ctx.model.get('tau', 0.3)}")
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
    parser = argparse.ArgumentParser(description="ORBVWAP AI-1 HTTP inference server (INF-8)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--model", type=Path, default=None)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    args = parser.parse_args()

    try:
        ctx = load_context(args.model, args.log)
        return run_server(args.host, args.port, ctx)
    except OSError as exc:
        print(f"ERROR: bind failed ({exc})", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
