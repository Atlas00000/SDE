#!/usr/bin/env python3
"""INF-7-002: Render AI + INF gate summary from journals → stdout / STATUS.md."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
INF_JOURNAL = ROOT / "Diagnostics" / "INF-test-journal.csv"
AI_JOURNAL = ROOT / "Diagnostics" / "AI-test-journal.csv"
MANIFEST = ROOT / "models" / "manifest.json"
STATUS_PATH = ROOT / "STATUS.md"

INF_GATES: list[tuple[str, str, str]] = [
    ("INF-0", "Schema + dataset", "INF-0-006"),
    ("INF-1", "Shadow CSV audit", "INF-1-006"),
    ("INF-2", "Reproducible replay", "INF-2-006"),
    ("INF-3", "Golden replay CI", "INF-3-006"),
    ("INF-4", "Feature parity", "INF-4-006"),
    ("INF-5", "Walk-forward gate", "INF-5-006"),
    ("INF-6", "Deployment bundle", "INF-6-006"),
    ("INF-7", "Ops dashboard", "INF-7-006"),
]

INF_OPTIONAL: list[tuple[str, str, str]] = [
    ("INF-8", "Runtime IPC (v2)", "INF-8-006"),
]

AI_TESTER_GATES: list[tuple[str, str, str]] = [
    ("AI-3", "AI123_SHADOW Tester", "AI-123-005"),
    ("AI-4", "AI1234_SHADOW Tester", "AI-1234-005"),
    ("AI-5", "AI12_SHADOW Tester", "AI-12-006"),
]

PRESET_LADDER: list[tuple[int, str, str, str | None]] = [
    (0, "PROD_EURUSD-M1", "A", "AI-0-003"),
    (1, "AI0_Export_*", "A", "AI-0-003"),
    (2, "AI1_SHADOW_*", "A", None),
    (3, "AI123_SHADOW_*", "A", "AI-123-005"),
    (4, "AI1234_SHADOW_*", "A", "AI-1234-005"),
    (5, "AI12_SHADOW_*", "A", "AI-12-006"),
    (6, "AI123_LIVE_*", "C", None),
    (7, "AI1234_SIZING_LIVE_*", "C", "AI-1234-SIZING-006"),
    (8, "AI1234_LIVE_*", "C", None),
]


def load_journal(path: Path) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame()
    df = pd.read_csv(path)
    df = df.dropna(how="all")
    if "task_id" in df.columns:
        df["task_id"] = df["task_id"].astype(str).str.strip()
    if "verdict" in df.columns:
        df["verdict"] = df["verdict"].astype(str).str.strip().str.upper()
    return df


def latest_rows(df: pd.DataFrame) -> dict[str, pd.Series]:
    if df.empty or "task_id" not in df.columns:
        return {}
    out: dict[str, pd.Series] = {}
    for task_id, group in df.groupby("task_id"):
        out[str(task_id)] = group.iloc[-1]
    return out


def gate_status(latest: dict[str, pd.Series], task_id: str) -> tuple[str, str]:
    row = latest.get(task_id)
    if row is None:
        return "MISSING", "—"
    verdict = str(row.get("verdict", "")).upper() or "?"
    note = str(row.get("notes", "") or row.get("preset_or_artifact", "") or "")[:48]
    return verdict, note


def load_manifest() -> dict:
    if not MANIFEST.exists():
        return {}
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def build_inf_table(inf_latest: dict[str, pd.Series]) -> pd.DataFrame:
    rows = []
    for phase, label, task_id in INF_GATES:
        verdict, note = gate_status(inf_latest, task_id)
        rows.append({"track": "INF", "id": phase, "gate": label, "task_id": task_id, "verdict": verdict, "notes": note})
    return pd.DataFrame(rows)


def build_inf_optional_table(inf_latest: dict[str, pd.Series]) -> pd.DataFrame:
    rows = []
    for phase, label, task_id in INF_OPTIONAL:
        verdict, note = gate_status(inf_latest, task_id)
        rows.append({"track": "INF", "id": phase, "gate": label, "task_id": task_id, "verdict": verdict, "notes": note})
    return pd.DataFrame(rows)


def build_ai_table(ai_latest: dict[str, pd.Series]) -> pd.DataFrame:
    rows = []
    for step, label, task_id in AI_TESTER_GATES:
        verdict, note = gate_status(ai_latest, task_id)
        rows.append({"track": "AI", "id": step, "gate": label, "task_id": task_id, "verdict": verdict, "notes": note})
    return pd.DataFrame(rows)


def build_preset_table(ai_latest: dict[str, pd.Series]) -> pd.DataFrame:
    rows = []
    for step, preset, track, journal_id in PRESET_LADDER:
        if journal_id:
            verdict, _ = gate_status(ai_latest, journal_id)
            status = "PASS" if verdict == "PASS" else verdict
        elif track == "C":
            status = "BLOCKED" if step in (6, 8) else "optional"
        else:
            status = "optional" if step == 2 else "baseline" if step == 0 else "—"
        rows.append({"step": step, "preset": preset, "track": track, "status": status, "journal": journal_id or "—"})
    return pd.DataFrame(rows)


def inf_gate_pass(inf_table: pd.DataFrame) -> bool:
    core = inf_table[inf_table["id"] != "INF-7"]
    return bool((core["verdict"] == "PASS").all())


def ai_tester_pass(ai_table: pd.DataFrame) -> bool:
    return bool((ai_table["verdict"] == "PASS").all())


def render_markdown(
    inf_table: pd.DataFrame,
    inf_optional: pd.DataFrame,
    ai_table: pd.DataFrame,
    preset_table: pd.DataFrame,
    manifest: dict,
    *,
    generated_at: str,
) -> str:
    inf_ok = inf_gate_pass(inf_table)
    ai_ok = ai_tester_pass(ai_table)
    gate = "PASS" if inf_ok and ai_ok else "BLOCKED"

    lines = [
        "# ORBVWAP STATUS",
        "",
        f"**Generated:** {generated_at} · `python Scripts/status.py --write`",
        "",
        f"## INF-GATE: **{gate}**",
        "",
        "Chart LIVE (preset steps 6 & 8) requires INF-GATE **PASS** + demo sign-off.",
        "",
        f"| Field | Value |",
        f"|-------|-------|",
        f"| bundle_id | `{manifest.get('bundle_id', '—')}` |",
        f"| ea_version | `{manifest.get('ea_version', '—')}` |",
        f"| git_sha | `{manifest.get('git_sha', '—')}` |",
        "",
        "## Infra gates (Track B)",
        "",
        "| Phase | Gate | Task | Verdict | Notes |",
        "|-------|------|------|---------|-------|",
    ]

    for _, row in inf_table.iterrows():
        lines.append(
            f"| {row['id']} | {row['gate']} | `{row['task_id']}` | **{row['verdict']}** | {row['notes']} |"
        )

    if not inf_optional.empty:
        lines.extend(
            [
                "",
                "## Optional — runtime IPC (INF-8 · does not block chart LIVE v1)",
                "",
                "| Phase | Gate | Task | Verdict | Notes |",
                "|-------|------|------|---------|-------|",
            ]
        )
        for _, row in inf_optional.iterrows():
            lines.append(
                f"| {row['id']} | {row['gate']} | `{row['task_id']}` | **{row['verdict']}** | {row['notes']} |"
            )

    lines.extend(
        [
            "",
            "## AI Tester gates (Track A minimum)",
            "",
            "| Step | Gate | Task | Verdict | Notes |",
            "|------|------|------|---------|-------|",
        ]
    )
    for _, row in ai_table.iterrows():
        lines.append(
            f"| {row['id']} | {row['gate']} | `{row['task_id']}` | **{row['verdict']}** | {row['notes']} |"
        )

    lines.extend(
        [
            "",
            "## Preset ladder",
            "",
            "| Step | Preset | Track | Status | Journal |",
            "|------|--------|-------|--------|---------|",
        ]
    )
    for _, row in preset_table.iterrows():
        lines.append(
            f"| {int(row['step'])} | `{row['preset']}` | {row['track']} | {row['status']} | {row['journal']} |"
        )

    lines.extend(
        [
            "",
            "## Quick commands",
            "",
            "```bash",
            "make status          # regenerate this file",
            "make replay-all      # INF-2",
            "make test-golden     # INF-3",
            "make parity-check    # INF-4",
            "make walkforward     # INF-5",
            "python Scripts/build_bundle.py --verify   # INF-6",
            "make test-ipc        # INF-8 (optional)",
            "```",
            "",
            "See [AGENTS.md](./AGENTS.md) for full repo map.",
            "",
        ]
    )
    return "\n".join(lines)


def print_summary(
    inf_table: pd.DataFrame,
    ai_table: pd.DataFrame,
    manifest: dict,
) -> None:
    inf_ok = inf_gate_pass(inf_table)
    ai_ok = ai_tester_pass(ai_table)
    gate = "PASS" if inf_ok and ai_ok else "BLOCKED"

    print("=== ORBVWAP gate summary ===")
    print(f"bundle_id={manifest.get('bundle_id', '—')} ea_version={manifest.get('ea_version', '—')}")
    print(f"INF-GATE: {gate}\n")

    combined = pd.concat([inf_table, ai_table], ignore_index=True)
    cols = ["track", "id", "gate", "task_id", "verdict"]
    print(combined[cols].to_string(index=False))

    if gate == "PASS":
        print("\n[PASS] INF-GATE — chart LIVE presets 6 & 8 may proceed (with demo sign-off)")
    else:
        print("\n[BLOCKED] INF-GATE — chart LIVE blocked")


def main() -> int:
    parser = argparse.ArgumentParser(description="ORBVWAP status dashboard (INF-7)")
    parser.add_argument("--write", action="store_true", help="Write STATUS.md")
    parser.add_argument("--output", type=Path, default=STATUS_PATH)
    args = parser.parse_args()

    inf_df = load_journal(INF_JOURNAL)
    ai_df = load_journal(AI_JOURNAL)
    inf_latest = latest_rows(inf_df)
    ai_latest = latest_rows(ai_df)
    manifest = load_manifest()

    inf_table = build_inf_table(inf_latest)
    inf_optional = build_inf_optional_table(inf_latest)
    ai_table = build_ai_table(ai_latest)
    preset_table = build_preset_table(ai_latest)

    print_summary(inf_table, ai_table, manifest)

    if args.write:
        generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        md = render_markdown(
            inf_table,
            inf_optional,
            ai_table,
            preset_table,
            manifest,
            generated_at=generated_at,
        )
        args.output.write_text(md, encoding="utf-8")
        print(f"\nWrote {args.output}")

    inf_ok = inf_gate_pass(inf_table)
    ai_ok = ai_tester_pass(ai_table)
    return 0 if inf_ok and ai_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
