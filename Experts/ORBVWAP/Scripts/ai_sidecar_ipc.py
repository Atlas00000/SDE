"""Shared IPC path resolution for ORBVWAP Python sidecars (FILE_COMMON)."""

from __future__ import annotations

import os
from pathlib import Path

DEFAULT_TERMINAL_ID = "D0E8209F77C8CF37AD8BF550E51FF075"
AI1_IPC_NAME = r"Logs\ORBVWAP_ai1_sidecar.bin"


def terminal_root() -> Path:
    return Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal" / DEFAULT_TERMINAL_ID


def common_ipc_file(filename: str) -> Path:
    """EA sidecars use FILE_COMMON — shared across chart, tester, and Python."""
    return (
        Path(os.environ.get("APPDATA", ""))
        / "MetaQuotes"
        / "Terminal"
        / "Common"
        / "Files"
        / filename.replace("\\", "/")
    )


def detect_ipc_file(filename: str, mode: str = "auto") -> Path:
    """Resolve mmap IPC file. mode: live, tester, auto — all use Terminal\\Common\\Files."""
    if mode in ("live", "tester", "auto"):
        return common_ipc_file(filename)
    return common_ipc_file(filename)
