#!/usr/bin/env python3
"""Probe ORBVWAP AI-1 sidecar IPC file (INF-8 health check)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from ai1_ipc import BLOCK_SIZE, MAGIC, VERSION, unpack_block  # noqa: E402
from ai_sidecar_fileio import read_block_shared  # noqa: E402
from ai_sidecar_ipc import AI1_IPC_NAME, detect_ipc_file  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP AI-1 sidecar IPC probe")
    parser.add_argument("--ipc-file", type=Path, default=None)
    parser.add_argument("--mode", choices=("auto", "live", "tester"), default="tester")
    args = parser.parse_args()

    ipc_path = args.ipc_file or detect_ipc_file(AI1_IPC_NAME, args.mode)
    print(f"IPC file: {ipc_path}")

    if not ipc_path.is_file():
        print("[FAIL] file missing — start ai1_sidecar.py first")
        return 1

    data = read_block_shared(ipc_path, BLOCK_SIZE)
    if data is None:
        print("[FAIL] could not read block")
        return 1

    try:
        block = unpack_block(data)
    except ValueError as exc:
        print(f"[FAIL] unpack: {exc}")
        return 1

    print(f"[OK] magic={MAGIC:#x} version={VERSION} status={block['status']} req={block['request_seq']}")
    print(f"     ai1_score={block['ai1_score']:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
