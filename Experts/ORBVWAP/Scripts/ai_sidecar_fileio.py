"""Windows-friendly shared binary read/write for MT5 sidecar IPC."""

from __future__ import annotations

import sys
from pathlib import Path

if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes

    _GENERIC_READ = 0x80000000
    _GENERIC_WRITE = 0x40000000
    _FILE_SHARE_READ = 0x00000001
    _FILE_SHARE_WRITE = 0x00000002
    _OPEN_EXISTING = 3
    _OPEN_ALWAYS = 4
    _INVALID_HANDLE_VALUE = wintypes.HANDLE(-1).value

    _CreateFileW = ctypes.windll.kernel32.CreateFileW
    _ReadFile = ctypes.windll.kernel32.ReadFile
    _WriteFile = ctypes.windll.kernel32.WriteFile
    _CloseHandle = ctypes.windll.kernel32.CloseHandle

    def _win_open(path: Path, write: bool) -> int | None:
        access = _GENERIC_READ | (_GENERIC_WRITE if write else 0)
        handle = _CreateFileW(
            str(path),
            access,
            _FILE_SHARE_READ | _FILE_SHARE_WRITE,
            None,
            _OPEN_EXISTING if path.is_file() else _OPEN_ALWAYS,
            0,
            None,
        )
        if handle == _INVALID_HANDLE_VALUE:
            return None
        return int(handle)

    def _win_read(handle: int, size: int) -> bytes | None:
        buf = ctypes.create_string_buffer(size)
        n = wintypes.DWORD(0)
        ok = _ReadFile(handle, buf, size, ctypes.byref(n), None)
        if not ok or n.value != size:
            return None
        return buf.raw

    def _win_write(handle: int, data: bytes) -> bool:
        n = wintypes.DWORD(0)
        buf = ctypes.create_string_buffer(data, len(data))
        ok = _WriteFile(handle, buf, len(data), ctypes.byref(n), None)
        return bool(ok and n.value == len(data))

    def read_block_shared(path: Path, size: int) -> bytes | None:
        handle = _win_open(path, write=False)
        if handle is None:
            return None
        try:
            return _win_read(handle, size)
        finally:
            _CloseHandle(handle)

    def write_block_shared(path: Path, data: bytes) -> bool:
        path.parent.mkdir(parents=True, exist_ok=True)
        handle = _win_open(path, write=True)
        if handle is None:
            return False
        try:
            return _win_write(handle, data)
        finally:
            _CloseHandle(handle)

else:

    def read_block_shared(path: Path, size: int) -> bytes | None:
        try:
            with path.open("rb") as f:
                data = f.read(size)
            return data if len(data) == size else None
        except OSError:
            return None

    def write_block_shared(path: Path, data: bytes) -> bool:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("r+b" if path.is_file() else "wb") as f:
                f.seek(0)
                f.write(data)
                f.flush()
            return True
        except OSError:
            return False
