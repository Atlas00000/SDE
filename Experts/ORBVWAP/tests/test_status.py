"""INF-7: status dashboard smoke tests."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATUS_SCRIPT = ROOT / "Scripts" / "status.py"


def test_status_script_runs():
    result = subprocess.run(
        [sys.executable, str(STATUS_SCRIPT)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "INF-GATE: PASS" in result.stdout


def test_status_writes_markdown(tmp_path):
    out = tmp_path / "STATUS.md"
    result = subprocess.run(
        [sys.executable, str(STATUS_SCRIPT), "--write", "--output", str(out)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert out.exists()
    text = out.read_text(encoding="utf-8")
    assert "INF-GATE" in text
    assert "INF-0" in text
