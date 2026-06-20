#!/usr/bin/env python3
"""
ORBVWAP INF-8 — AI-1 sidecar daemon (FILE_COMMON IPC)

Scores AI-1 from feature vector written by EA. Start before Strategy Tester Start.

Usage:
  python Scripts/ai1_sidecar.py --mode tester
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from ai1_ipc import (  # noqa: E402
    BLOCK_SIZE,
    FAILOPEN_SCORE,
    STATUS_ERROR,
    STATUS_IDLE,
    STATUS_READY,
    STATUS_REQUEST,
    pack_block,
    unpack_block,
)
from ai1_runtime import load_model, score_features  # noqa: E402
from ai_sidecar_fileio import read_block_shared, write_block_shared  # noqa: E402
from ai_sidecar_ipc import AI1_IPC_NAME, detect_ipc_file  # noqa: E402


def run_sidecar(
    ipc_path: Path,
    model_path: Path | None,
    poll_ms: int,
    once: bool,
) -> int:
    model = load_model(model_path)
    ipc_path.parent.mkdir(parents=True, exist_ok=True)
    if not ipc_path.is_file():
        idle = pack_block(0, 0, STATUS_IDLE, FAILOPEN_SCORE, [0.0] * 10)
        ipc_path.write_bytes(idle)

    print(f"AI-1 sidecar listening: {ipc_path}")
    print(f"Model: {model.get('model_id', 'ai1_v1')} tau={model.get('tau', 0.3)}")
    last_req = 0
    last_status = -1

    while True:
        data = read_block_shared(ipc_path, BLOCK_SIZE)
        if data is None:
            time.sleep(poll_ms / 1000.0)
            if once:
                return 2
            continue

        try:
            block = unpack_block(data)
        except ValueError:
            time.sleep(poll_ms / 1000.0)
            if once:
                return 2
            continue

        req = int(block["request_seq"])
        status = int(block["status"])
        feats = block["features"]

        if status != last_status:
            print(f"IPC status={status} req={req}", flush=True)
            last_status = status

        if status == STATUS_REQUEST and req != last_req:
            last_req = req
            print(f"AI1 pending req={req} ...", flush=True)
            try:
                score = score_features(model, feats)
                out = pack_block(req, req, STATUS_READY, score, feats)
                write_block_shared(ipc_path, out)
                print(f"AI1 req={req} -> {score:.4f}")
            except Exception as exc:
                err = pack_block(req, req, STATUS_ERROR, FAILOPEN_SCORE, feats)
                write_block_shared(ipc_path, err)
                print(f"ERROR req={req}: {exc}", file=sys.stderr)

        if once:
            return 0
        time.sleep(poll_ms / 1000.0)


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP AI-1 sidecar (INF-8)")
    parser.add_argument("--ipc-file", type=Path, default=None)
    parser.add_argument("--model", type=Path, default=None)
    parser.add_argument(
        "--mode",
        choices=("auto", "live", "tester"),
        default="tester",
        help="IPC path: FILE_COMMON under Terminal\\Common\\Files",
    )
    parser.add_argument("--poll-ms", type=int, default=10)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    try:
        return run_sidecar(
            args.ipc_file or detect_ipc_file(AI1_IPC_NAME, args.mode),
            args.model,
            args.poll_ms,
            args.once,
        )
    except KeyboardInterrupt:
        print("\nAI-1 sidecar stopped.")
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
