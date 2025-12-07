#!/usr/bin/env python3
"""
Generate packages/gaussian/README.md from a stable template and source-of-truth files.

Sources:
- STATUS.md (phase/progress/tests/release)
- ROADMAP.md (milestones)
- docs/GAS_BENCHMARKS.md (gas snapshot)
- docs/test_coverage_review.md (coverage snapshot)
- Move.toml (version for dependency snippet)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from string import Template


try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover - fallback for older Python
    import tomli as tomllib  # type: ignore


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_PATH = ROOT / "scripts" / "readme_template.md"
READ_ME_PATH = ROOT / "README.md"
STATUS_PATH = ROOT / "STATUS.md"
ROADMAP_PATH = ROOT / "ROADMAP.md"
GAS_PATH = ROOT / "docs" / "GAS_BENCHMARKS.md"
COVERAGE_PATH = ROOT / "docs" / "test_coverage_review.md"
MOVE_TOML_PATH = ROOT / "Move.toml"


def load_toml_block(path: Path) -> dict:
    """Parse the first ```toml block from a markdown file."""
    text = path.read_text(encoding="utf-8")
    match = re.search(r"```toml\s*(.*?)```", text, re.DOTALL)
    if not match:
        return {}
    return tomllib.loads(match.group(1))


def read_status() -> dict:
    data = load_toml_block(STATUS_PATH)
    return {
        "last_updated": data.get("last_updated", "TBD"),
        "phase": data.get("phase", "Unknown"),
        "progress_percent": data.get("progress_percent", 0),
        "release": data.get("release", "main"),
        "tests_passing": data.get("tests_passing", "N/A"),
        "notes": data.get("status_notes", []),
    }


def read_roadmap() -> dict:
    data = load_toml_block(ROADMAP_PATH)
    return {
        "next_milestone": data.get("next_milestone", "TBD"),
        "target_date": data.get("target_date", "TBD"),
        "upcoming": data.get("upcoming", []),
    }


def read_move_version() -> str:
    try:
        pkg = tomllib.loads(MOVE_TOML_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return "main"
    version = (
        pkg.get("package", {}).get("version")
        or pkg.get("package", {}).get("ver")
        or ""
    )
    if not version:
        return "main"
    version = str(version)
    return version if version.startswith("v") else f"v{version}"


def read_gas_snapshot() -> dict:
    text = GAS_PATH.read_text(encoding="utf-8")
    date = _extract_first(r"\*\*Date\*\*:\s*(.+)", text, default="TBD")
    package_id = _extract_first(r"\*\*Package\*\*:\s*`([^`]+)`", text, default="TBD")
    avg = _extract_first(r"Avg Computation Cost \|\s*([^|\n]+)", text, default="n/a")
    success = _extract_first(r"Successful \|\s*([^|\n]+)", text, default="n/a")
    note = (
        "See docs/GAS_BENCHMARKS.md for full table; CDF/PPF entries require redeploy."
    )
    summary = f"{success} successful funcs, avg compute {avg}".strip()
    return {"date": date, "package_id": package_id, "summary": f"{summary}. {note}"}


def read_coverage_snapshot() -> dict:
    text = COVERAGE_PATH.read_text(encoding="utf-8")
    date = _extract_first(r"\*\*Date\*\*:\s*(.+)", text, default="TBD")
    status = _extract_first(r"\*\*Status\*\*:\s*(.+)", text, default="See coverage doc")
    return {"date": date, "status": status}


def _extract_first(pattern: str, text: str, default: str = "") -> str:
    match = re.search(pattern, text)
    return match.group(1).strip() if match else default


def format_bullets(items: list[str], indent: str = "") -> str:
    if not items:
        return f"{indent}- (none)"
    return "\n".join(f"{indent}- {item}" for item in items)


def render_readme() -> str:
    status = read_status()
    roadmap = read_roadmap()
    gas = read_gas_snapshot()
    coverage = read_coverage_snapshot()
    dep_rev = read_move_version()

    template = Template(TEMPLATE_PATH.read_text(encoding="utf-8"))
    content = template.safe_substitute(
        status_release=status["release"],
        status_phase=status["phase"],
        status_progress=status["progress_percent"],
        status_tests=status["tests_passing"],
        status_last_updated=status["last_updated"],
        status_notes_bullets=format_bullets(status["notes"]),
        dep_rev=dep_rev,
        gas_date=gas["date"],
        gas_package=gas["package_id"],
        gas_summary=gas["summary"],
        coverage_date=coverage["date"],
        coverage_status=coverage["status"],
        roadmap_next=roadmap["next_milestone"],
        roadmap_target=roadmap["target_date"],
        roadmap_upcoming_bullets=format_bullets(roadmap["upcoming"]),
    ).rstrip()
    return content + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Regenerate packages/gaussian/README.md from template + status files."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if README.md is out-of-sync.",
    )
    args = parser.parse_args()

    new_content = render_readme()

    if args.check:
        current = READ_ME_PATH.read_text(encoding="utf-8") if READ_ME_PATH.exists() else ""
        if current.rstrip() != new_content.rstrip():
            sys.stderr.write("README.md is out-of-sync. Run scripts/update_readme.py\n")
            return 1
        return 0

    READ_ME_PATH.write_text(new_content, encoding="utf-8")
    print("Regenerated README.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())

