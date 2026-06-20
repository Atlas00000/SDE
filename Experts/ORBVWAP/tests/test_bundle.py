"""INF-6: deployment manifest bundle verification."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "models" / "manifest.json"
BUILD_SCRIPT = ROOT / "scripts" / "build_bundle.py"


def test_manifest_exists():
    assert MANIFEST.exists(), f"missing {MANIFEST}"


def test_bundle_verify_passes():
    result = subprocess.run(
        [sys.executable, str(BUILD_SCRIPT), "--verify"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_manifest_has_required_fields():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for key in ("bundle_id", "git_sha", "ea_version", "presets", "artifacts", "models"):
        assert key in data, f"missing manifest field: {key}"


def test_chart_live_presets_pinned():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    live = [p for p in data["presets"] if p.get("role") == "chart_live"]
    assert live, "expected chart_live presets in manifest"
