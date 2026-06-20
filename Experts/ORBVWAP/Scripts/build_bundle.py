#!/usr/bin/env python3
"""INF-6: Build and verify ORBVWAP deployment manifest bundle."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "models" / "manifest.json"
CONSTANTS_PATH = ROOT / "Include" / "ORBVWAP" / "Constants.mqh"
PRESETS_DIR = ROOT / "Presets"
DATASET = ROOT / "Diagnostics" / "datasets" / "ORBVWAP_ai_dataset_v1.parquet"

DEFAULT_BUNDLE_ID = "orbvwap-v1.23-ai1234"
DEFAULT_PROD_PRESET = "ORBVWAP_PROD_EURUSD-M1.set"

DEFAULT_PRESETS = [
    {"name": "ORBVWAP_PROD_EURUSD-M1.set", "step": 0, "role": "baseline"},
    {"name": "ORBVWAP_AI0_Export_PROD_EURUSD-M1_full.set", "step": 1, "role": "export"},
    {"name": "ORBVWAP_AI1_SHADOW_PROD_EURUSD-M1.set", "step": 2, "role": "tester_shadow"},
    {"name": "ORBVWAP_AI123_SHADOW_PROD_EURUSD-M1.set", "step": 3, "role": "tester_shadow"},
    {"name": "ORBVWAP_AI1234_SHADOW_PROD_EURUSD-M1.set", "step": 4, "role": "tester_shadow"},
    {"name": "ORBVWAP_AI12_SHADOW_PROD_EURUSD-M1.set", "step": 5, "role": "tester_shadow"},
    {"name": "ORBVWAP_AI123_LIVE_PROD_EURUSD-M1.set", "step": 6, "role": "chart_live"},
    {"name": "ORBVWAP_AI1234_SIZING_LIVE_PROD_EURUSD-M1.set", "step": 7, "role": "tester_live"},
    {"name": "ORBVWAP_AI1234_LIVE_PROD_EURUSD-M1.set", "step": 8, "role": "chart_live"},
]

MQH_ARTIFACTS = [
    "Include/ORBVWAP/AiFeatures.mqh",
    "Include/ORBVWAP/AiScorer.mqh",
    "Include/ORBVWAP/AiSizer.mqh",
    "Include/ORBVWAP/AiRegime.mqh",
    "Include/ORBVWAP/AiExit.mqh",
]

MODEL_ARTIFACTS = [
    "models/ai1_v1.json",
    "models/ai2_v1.json",
    "models/ai3_v1.json",
    "models/ai4_v1.json",
]


def read_constants() -> dict[str, str]:
    text = CONSTANTS_PATH.read_text(encoding="utf-8")
    version = re.search(r'#define\s+ORBVWAP_EA_VERSION\s+"([^"]+)"', text)
    bundle = re.search(r'#define\s+ORBVWAP_BUNDLE_ID\s+"([^"]+)"', text)
    if not version or not bundle:
        raise ValueError(f"Could not parse EA version/bundle from {CONSTANTS_PATH}")
    return {"ea_version": version.group(1), "bundle_id": bundle.group(1)}


def write_constants(bundle_id: str, ea_version: str | None = None) -> None:
    text = CONSTANTS_PATH.read_text(encoding="utf-8")
    if ea_version:
        text = re.sub(
            r'(#define\s+ORBVWAP_EA_VERSION\s+)"[^"]+"',
            rf'\1"{ea_version}"',
            text,
        )
    text = re.sub(
        r'(#define\s+ORBVWAP_BUNDLE_ID\s+)"[^"]+"',
        rf'\1"{bundle_id}"',
        text,
    )
    CONSTANTS_PATH.write_text(text, encoding="utf-8")


def git_sha() -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT.parents[1],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def load_model_summaries() -> list[dict]:
    summaries: list[dict] = []
    for rel in MODEL_ARTIFACTS:
        path = ROOT / rel
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        entry = {
            "model_id": data.get("model_id", path.stem),
            "layer": data.get("layer", path.stem.split("_")[0].upper()),
            "artifact": rel.replace("\\", "/"),
            "gate_verdict": data.get("metrics", {}).get("verdict", data.get("verdict", "PASS")),
        }
        if "tau" in data:
            entry["tau"] = data["tau"]
        if data.get("type"):
            entry["type"] = data["type"]
        if "stall_minutes" in data:
            entry["stall_minutes"] = data["stall_minutes"]
        if "stall_mfe_frac" in data:
            entry["stall_mfe_frac"] = data["stall_mfe_frac"]
        mqh_map = {
            "ai1_v1": "Include/ORBVWAP/AiScorer.mqh",
            "ai2_v1": "Include/ORBVWAP/AiSizer.mqh",
            "ai3_v1": "Include/ORBVWAP/AiRegime.mqh",
            "ai4_v1": "Include/ORBVWAP/AiExit.mqh",
        }
        if entry["model_id"] in mqh_map:
            entry["mql5"] = mqh_map[entry["model_id"]]
        summaries.append(entry)

    if not summaries:
        summaries = json.loads(MANIFEST_PATH.read_text(encoding="utf-8")).get("models", [])
    return summaries


def build_manifest(bundle_id: str, presets: list[dict]) -> dict:
    const = read_constants()
    return {
        "schema_version": 1,
        "bundle_id": bundle_id,
        "project": "ORBVWAP",
        "ea_version": const["ea_version"],
        "git_sha": git_sha(),
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "dataset_version": DATASET.name if DATASET.exists() else "ORBVWAP_ai_dataset_v1.parquet",
        "prod_preset": DEFAULT_PROD_PRESET,
        "deploy_path": "offline PASS -> MT5 shadow backtest -> chart LIVE (pinned preset)",
        "deploy_rule": (
            "Chart LIVE uses a preset listed in presets[] only; "
            "compile-time ORBVWAP_BUNDLE_ID must match bundle_id; "
            "Tester/chart logs and ai_shadow.csv carry the same bundle_id."
        ),
        "presets": presets,
        "artifacts": {
            "mqh": MQH_ARTIFACTS,
            "models": MODEL_ARTIFACTS,
        },
        "models": load_model_summaries(),
    }


def verify_manifest(manifest: dict) -> list[str]:
    errors: list[str] = []
    const = read_constants()

    for key in (
        "schema_version",
        "bundle_id",
        "ea_version",
        "git_sha",
        "built_at",
        "prod_preset",
        "presets",
        "artifacts",
        "models",
    ):
        if key not in manifest:
            errors.append(f"manifest missing field: {key}")

    if manifest.get("bundle_id") != const["bundle_id"]:
        errors.append(
            f"bundle_id mismatch: manifest={manifest.get('bundle_id')} "
            f"constants={const['bundle_id']}"
        )
    if manifest.get("ea_version") != const["ea_version"]:
        errors.append(
            f"ea_version mismatch: manifest={manifest.get('ea_version')} "
            f"constants={const['ea_version']}"
        )

    for preset in manifest.get("presets", []):
        name = preset.get("name", "")
        path = PRESETS_DIR / name
        if not path.exists():
            errors.append(f"missing preset file: Presets/{name}")

    prod = manifest.get("prod_preset")
    if prod and not (PRESETS_DIR / prod).exists():
        errors.append(f"missing prod_preset: Presets/{prod}")

    for group in manifest.get("artifacts", {}).values():
        for rel in group:
            if not (ROOT / rel).exists():
                errors.append(f"missing artifact: {rel}")

    chart_live = [p for p in manifest.get("presets", []) if p.get("role") == "chart_live"]
    if not chart_live:
        errors.append("presets[] must include at least one chart_live entry")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Build or verify ORBVWAP deployment bundle (INF-6)")
    parser.add_argument("--verify", action="store_true", help="Verify manifest matches EA constants and files")
    parser.add_argument("--bundle-id", default=None, help="Set bundle_id (also stamps Constants.mqh)")
    parser.add_argument("--write", action="store_true", help="Write models/manifest.json")
    args = parser.parse_args()

    if args.verify:
        if not MANIFEST_PATH.exists():
            print(f"[FAIL] missing manifest: {MANIFEST_PATH}", file=sys.stderr)
            return 1
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        errors = verify_manifest(manifest)
        if errors:
            print("[FAIL]")
            for err in errors:
                print(f"  - {err}")
            return 1
        print(f"[PASS] bundle_id={manifest['bundle_id']} ea_version={manifest['ea_version']}")
        print(f"  presets={len(manifest.get('presets', []))} artifacts verified")
        return 0

    const = read_constants()
    bundle_id = args.bundle_id or const["bundle_id"] or DEFAULT_BUNDLE_ID

    if args.bundle_id:
        write_constants(bundle_id)

    manifest = build_manifest(bundle_id, DEFAULT_PRESETS)
    errors = verify_manifest(manifest)
    if errors:
        print("[FAIL] pre-write verification")
        for err in errors:
            print(f"  - {err}")
        return 1

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[OK] wrote {MANIFEST_PATH}")
    print(f"  bundle_id={manifest['bundle_id']} git_sha={manifest['git_sha']}")
    print(f"  presets={len(manifest['presets'])} models={len(manifest['models'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
