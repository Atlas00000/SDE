"""Binary IPC for ORBVWAP AI-1 sidecar (must match Include/ORBVWAP/Ai1Sidecar.mqh)."""

from __future__ import annotations

import struct
from typing import Sequence

MAGIC = 0x3149524F  # b"ORI1"
VERSION = 1
N_FEATURES = 10
BLOCK_SIZE = 116

STATUS_IDLE = 0
STATUS_REQUEST = 1
STATUS_READY = 2
STATUS_ERROR = 3

FAILOPEN_SCORE = 0.5

_STRUCT = struct.Struct("<IIQQId" + "d" * N_FEATURES)


def pack_block(
    request_seq: int,
    response_seq: int,
    status: int,
    ai1_score: float,
    features: Sequence[float],
) -> bytes:
    if len(features) != N_FEATURES:
        raise ValueError(f"expected {N_FEATURES} features, got {len(features)}")
    return _STRUCT.pack(MAGIC, VERSION, request_seq, response_seq, status, ai1_score, *features)


def unpack_block(data: bytes) -> dict:
    if len(data) < BLOCK_SIZE:
        raise ValueError(f"block too short: {len(data)}")
    vals = _STRUCT.unpack(data[:BLOCK_SIZE])
    magic, version = vals[0], vals[1]
    if magic != MAGIC:
        raise ValueError(f"bad magic: {magic:#x}")
    if version != VERSION:
        raise ValueError(f"bad version: {version}")
    return {
        "request_seq": vals[2],
        "response_seq": vals[3],
        "status": vals[4],
        "ai1_score": vals[5],
        "features": list(vals[6:]),
    }
