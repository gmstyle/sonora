#!/usr/bin/env python3
"""Insert a new version heading into CHANGELOG.md, above previous releases."""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path


def insert_entry(changelog: Path, version: str, notes: str, date: str) -> bool:
    notes = notes.strip()
    if not notes:
        print("Release notes are empty; leaving CHANGELOG.md unchanged.", file=sys.stderr)
        return False

    heading = f"## [{version}]"
    text = changelog.read_text(encoding="utf-8")
    if heading in text:
        print(f"CHANGELOG.md already has {heading}; skipping.", file=sys.stderr)
        return False

    entry = f"{heading} - {date}\n\n{notes}\n\n"
    marker = "## ["
    index = text.find(marker)
    if index == -1:
        new_text = text.rstrip() + "\n\n" + entry
    else:
        new_text = text[:index] + entry + text[index:]

    changelog.write_text(new_text, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version", help="Version label, e.g. 1.7.1+57")
    parser.add_argument("notes_file", type=Path, help="Markdown file with release notes")
    parser.add_argument(
        "changelog",
        nargs="?",
        type=Path,
        default=Path("CHANGELOG.md"),
        help="Path to CHANGELOG.md",
    )
    args = parser.parse_args()

    if not args.changelog.exists():
        print(
            f"Missing {args.changelog}. Commit a seed CHANGELOG.md before releasing.",
            file=sys.stderr,
        )
        return 1

    notes = args.notes_file.read_text(encoding="utf-8")
    date = datetime.now(timezone.utc).date().isoformat()
    insert_entry(args.changelog, args.version, notes, date)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
