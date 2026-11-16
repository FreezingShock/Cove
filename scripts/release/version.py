#!/usr/bin/env python3
"""Read or bump Cove's version in Cove.xcodeproj/project.pbxproj.

Usage:
  version.py current
  version.py bump (minor|patch|major|X.Y[.Z])

`current` prints "<version> <build>", for example "0.1 1".
`bump` rewrites MARKETING_VERSION and CURRENT_PROJECT_VERSION in every build
configuration, then prints the new "<version> <build>" pair. The build number
always goes up by one. An explicit X.Y[.Z] must be higher than the current
version.

Standard library only, so it runs on the ubuntu-latest and macos runners.
"""

import pathlib
import re
import sys

PBXPROJ = pathlib.Path("Cove.xcodeproj/project.pbxproj")
MARKETING = re.compile(r'(\bMARKETING_VERSION = )"?([^";\n]+)"?;')
BUILD = re.compile(r'(\bCURRENT_PROJECT_VERSION = )"?([^";\n]+)"?;')
VERSION_RE = re.compile(r"\d+(\.\d+){0,2}")
EXPLICIT_RE = re.compile(r"\d+\.\d+(\.\d+)?")


def die(message: str) -> None:
    print(f"version.py: error: {message}", file=sys.stderr)
    sys.exit(1)


def read_values(text: str) -> tuple[str, str]:
    versions = {m.group(2).strip() for m in MARKETING.finditer(text)}
    builds = {m.group(2).strip() for m in BUILD.finditer(text)}
    if not versions or not builds:
        die("MARKETING_VERSION or CURRENT_PROJECT_VERSION not found in project.pbxproj")
    if len(versions) != 1 or len(builds) != 1:
        die(f"build configurations disagree: versions {sorted(versions)}, builds {sorted(builds)}")
    version, build = versions.pop(), builds.pop()
    if not VERSION_RE.fullmatch(version):
        die(f"unsupported MARKETING_VERSION '{version}'")
    if not build.isdigit():
        die(f"CURRENT_PROJECT_VERSION must be an integer, got '{build}'")
    return version, build


def as_tuple(version: str) -> tuple[int, int, int]:
    parts = [int(p) for p in version.split(".")] + [0, 0]
    return parts[0], parts[1], parts[2]


def next_version(current: str, kind: str) -> str:
    if EXPLICIT_RE.fullmatch(kind):
        if as_tuple(kind) <= as_tuple(current):
            die(f"requested version {kind} is not higher than current {current}")
        return kind
    major, minor, patch = as_tuple(current)
    if kind == "major":
        return f"{major + 1}.0"
    if kind == "minor":
        return f"{major}.{minor + 1}"
    if kind == "patch":
        return f"{major}.{minor}.{patch + 1}"
    die(f"bump must be minor, patch, major or an explicit X.Y[.Z], got '{kind}'")
    raise AssertionError("unreachable")


def main(argv: list[str]) -> None:
    if not PBXPROJ.exists():
        die(f"{PBXPROJ} not found. Cove.xcodeproj lands with PR #1 on integration.")
    text = PBXPROJ.read_text(encoding="utf-8")
    version, build = read_values(text)

    if argv == ["current"]:
        print(f"{version} {build}")
        return

    if len(argv) == 2 and argv[0] == "bump":
        new_version = next_version(version, argv[1])
        new_build = str(int(build) + 1)
        text = MARKETING.sub(lambda m: f"{m.group(1)}{new_version};", text)
        text = BUILD.sub(lambda m: f"{m.group(1)}{new_build};", text)
        PBXPROJ.write_text(text, encoding="utf-8")
        print(f"{new_version} {new_build}")
        return

    die("usage: version.py current | version.py bump (minor|patch|major|X.Y[.Z])")


if __name__ == "__main__":
    main(sys.argv[1:])
