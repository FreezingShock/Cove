#!/usr/bin/env python3
"""Write or extract Cove's release notes.

Usage:
  changelog.py write --version 0.2 --build 2 [--range origin/main..HEAD] [--file CHANGELOG.md]
  changelog.py extract --version 0.2 [--file CHANGELOG.md]

`write` lists the commits in --range (default origin/main..HEAD, meaning every
commit not yet on main) and inserts a "## [0.2] - YYYY-MM-DD" section above the
existing sections of CHANGELOG.md. Entries come from PR titles: a squash-merged
commit "Title (#12)" gives "- Title (#12)", and a merge commit uses the PR title
from its body. Release-prep commits ("Release 0.2") are left out.

`extract` prints the body of one released section. The release workflow uses it
as the GitHub Release notes.

Standard library only.
"""

import argparse
import datetime
import re
import subprocess
import sys

DEFAULT_HEADER = (
    "# Changelog\n\n"
    "Notable changes to Cove, newest first. The release workflow writes each "
    "section from merged PR titles, so keep the wording in PR titles clear.\n\n"
)
SECTION_START = re.compile(r"^## ", re.MULTILINE)
MERGE_PR = re.compile(r"^Merge pull request #(\d+) from [^\n]*")
SQUASH_PR = re.compile(r"^(.*?)\s*\(#(\d+)\)$")
RELEASE_PREP = re.compile(r"^Release \d")


def die(message: str) -> None:
    print(f"changelog.py: error: {message}", file=sys.stderr)
    sys.exit(1)


def commits(rev_range: str) -> list[tuple[str, str]]:
    result = subprocess.run(
        ["git", "log", "--first-parent", "--reverse", "--format=%s%x1f%b%x1e", rev_range],
        capture_output=True,
        text=True,
        check=True,
    )
    records = []
    for record in result.stdout.split("\x1e"):
        if not record.strip():
            continue
        subject, _, body = record.partition("\x1f")
        records.append((subject.strip(), body.strip()))
    return records


def entry_for(subject: str, body: str) -> str | None:
    """Return one changelog bullet for a commit, or None if it should be skipped."""
    merge = MERGE_PR.match(subject)
    if merge:
        number = merge.group(1)
        first_line = next((line.strip() for line in body.splitlines() if line.strip()), "")
        title = first_line or subject
    else:
        number = None
        squash = SQUASH_PR.match(subject)
        if squash:
            title, number = squash.group(1), squash.group(2)
        else:
            title = subject

    if not title or RELEASE_PREP.match(title) or title.startswith("Merge "):
        return None
    return f"- {title} (#{number})" if number else f"- {title}"


def write(version: str, build: str, rev_range: str, path: str) -> None:
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except FileNotFoundError:
        text = DEFAULT_HEADER

    if re.search(rf"^## \[{re.escape(version)}\]", text, re.MULTILINE):
        die(f"CHANGELOG.md already has a section for {version}")

    entries = [e for e in (entry_for(s, b) for s, b in commits(rev_range)) if e]
    if not entries:
        die(f"nothing to release: no commits in {rev_range}")

    today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    section = f"## [{version}] - {today} (build {build})\n\n" + "\n".join(entries) + "\n\n"

    match = SECTION_START.search(text)
    if match:
        text = text[: match.start()] + section + text[match.start():]
    else:
        text = text.rstrip("\n") + "\n\n" + section
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"Wrote {len(entries)} entries for {version} to {path}")


def extract(version: str, path: str) -> None:
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except FileNotFoundError:
        die(f"{path} not found")

    start = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n", text, re.MULTILINE)
    if not start:
        die(f"no section for {version} in {path}")
    rest = text[start.end():]
    end = SECTION_START.search(rest)
    body = rest[: end.start()] if end else rest
    print(body.strip())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    write_cmd = sub.add_parser("write")
    write_cmd.add_argument("--version", required=True)
    write_cmd.add_argument("--build", required=True)
    write_cmd.add_argument("--range", default="origin/main..HEAD")
    write_cmd.add_argument("--file", default="CHANGELOG.md")

    extract_cmd = sub.add_parser("extract")
    extract_cmd.add_argument("--version", required=True)
    extract_cmd.add_argument("--file", default="CHANGELOG.md")

    args = parser.parse_args()
    if args.command == "write":
        write(args.version, args.build, args.range, args.file)
    else:
        extract(args.version, args.file)


if __name__ == "__main__":
    main()
