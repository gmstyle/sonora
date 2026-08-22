#!/usr/bin/env python3
"""Generate user-facing release notes from conventional commits since the previous tag."""

from __future__ import annotations

import re
import subprocess
import sys

SKIP_SUBJECT_PREFIXES = (
    "chore(release)",
    "docs(release)",
    "chore(changelog)",
)

SECTIONS: tuple[tuple[str, str], ...] = (
    ("feat", "Features"),
    ("fix", "Bug Fixes"),
    ("perf", "Performance"),
)

# Types that should not appear in the in-app / GitHub release notes.
SKIP_TYPES = {
    "chore",
    "docs",
    "ci",
    "test",
    "style",
    "build",
    "refactor",
}

CONV = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?:\s+(?P<subject>.+)$",
    re.IGNORECASE,
)


def _git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        check=check,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _previous_tag() -> str:
    if len(sys.argv) > 1 and sys.argv[1]:
        return sys.argv[1]
    try:
        return _git("describe", "--tags", "--abbrev=0")
    except subprocess.CalledProcessError:
        return ""


def _subjects(range_spec: str) -> list[str]:
    args = ["log", "--pretty=format:%s", "--no-merges"]
    if range_spec:
        args.append(range_spec)
    output = _git(*args)
    if not output:
        return []
    return output.splitlines()


def _format_item(scope: str | None, subject: str) -> str:
    subject = subject.strip()
    if subject:
        subject = subject[0].upper() + subject[1:]
    if scope:
        return f"- **{scope}**: {subject}"
    return f"- {subject}"


def generate(from_ref: str | None = None) -> str:
    previous = from_ref if from_ref is not None else _previous_tag()
    range_spec = f"{previous}..HEAD" if previous else "HEAD"
    print(
        f"Generating release notes since {previous or 'the beginning of history'}",
        file=sys.stderr,
    )
    buckets: dict[str, list[str]] = {title: [] for _, title in SECTIONS}

    for message in _subjects(range_spec):
        if any(message.startswith(prefix) for prefix in SKIP_SUBJECT_PREFIXES):
            continue
        match = CONV.match(message)
        if not match:
            continue
        commit_type = match.group("type").lower()
        if commit_type in SKIP_TYPES:
            continue
        title = next((title for typ, title in SECTIONS if typ == commit_type), None)
        if title is None:
            continue
        buckets[title].append(_format_item(match.group("scope"), match.group("subject")))

    parts = [
        f"### {title}\n\n" + "\n".join(buckets[title])
        for _, title in SECTIONS
        if buckets[title]
    ]
    text = "\n\n".join(parts).strip()
    return text or "Maintenance and internal improvements."


def main() -> int:
    sys.stdout.write(generate() + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
