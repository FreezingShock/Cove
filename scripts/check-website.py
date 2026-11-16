#!/usr/bin/env python3
"""Check the static Inlet website before it is published.

Checks, in order:
  1. index.html exists.
  2. Every local href/src points at a file that exists. A folder must have an index.html.
  3. Every #fragment link points at an id (or a[name]) on the target page.
  4. No resource (script, stylesheet, image, font, media, iframe) loads from
     another origin, and no CSS url() or @import reaches another origin.
     Plain <a href> links to other sites are fine. They are navigation, not requests.

Usage: python3 scripts/check-website.py [website-dir]

Standard library only, so it runs on a bare GitHub runner with no install step.
"""

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

# Tags that fetch a resource when the page loads. Links to other sites are
# not allowed from these.
RESOURCE_TAGS = {"script", "img", "source", "iframe", "video", "audio", "embed", "track"}

# Schemes we never check as files.
IGNORED_SCHEMES = {"mailto", "tel", "data", "javascript", "blob"}

EXTERNAL_CSS = re.compile(
    r"""url\(\s*['"]?\s*(https?:)?//|@import\s+(url\(\s*)?['"]?\s*(https?:)?//""",
    re.IGNORECASE,
)


class PageScan(HTMLParser):
    """Collects link and resource references, plus every id on the page."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.refs: list[tuple[str, str, str, bool]] = []  # (tag, attr, value, is_resource)
        self.ids: set[str] = set()
        self.inline_css: list[str] = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"])
        if tag == "a" and values.get("name"):
            self.ids.add(values["name"])

        if tag == "a" and values.get("href"):
            self.refs.append((tag, "href", values["href"], False))
        if tag == "link" and values.get("href"):
            self.refs.append((tag, "href", values["href"], True))
        if tag in RESOURCE_TAGS and values.get("src"):
            self.refs.append((tag, "src", values["src"], True))

        style = values.get("style")
        if style:
            self.inline_css.append(style)


def check_site(root: Path) -> tuple[list[str], int, int]:
    errors: list[str] = []
    index = root / "index.html"
    if not index.is_file():
        return [f"{index} is missing"], 0, 0

    pages: dict[Path, PageScan] = {}
    for html in sorted(root.rglob("*.html")):
        scan = PageScan()
        scan.feed(html.read_text(encoding="utf-8"))
        pages[html.resolve()] = scan

    ref_count = 0
    for html_path, scan in pages.items():
        rel = html_path.relative_to(root.resolve())

        for css in scan.inline_css:
            if EXTERNAL_CSS.search(css):
                errors.append(f"{rel}: inline style loads from another site")

        for tag, attr, value, is_resource in scan.refs:
            ref_count += 1
            value = value.strip()
            parts = urlsplit(value)

            if parts.scheme in IGNORED_SCHEMES:
                continue

            if parts.scheme in ("http", "https") or value.startswith("//"):
                if is_resource:
                    errors.append(
                        f"{rel}: <{tag} {attr}=\"{value}\"> loads from another site "
                        "(the page must make no external requests)"
                    )
                continue

            if parts.scheme:
                # Any other scheme is unexpected in this site, so flag it.
                errors.append(f"{rel}: <{tag} {attr}=\"{value}\"> uses unexpected scheme '{parts.scheme}'")
                continue

            # Same-page anchor, such as #features.
            if not parts.path:
                if parts.fragment and unquote(parts.fragment) not in scan.ids:
                    errors.append(f"{rel}: link #{parts.fragment} has no matching id on this page")
                continue

            # Local file or folder. A leading slash means the site root.
            base = root.resolve() if parts.path.startswith("/") else html_path.parent
            target = (base / unquote(parts.path.lstrip("/"))).resolve()

            if target.is_dir():
                target = target / "index.html"

            if not target.is_file():
                errors.append(f"{rel}: <{tag} {attr}=\"{value}\"> points at a file that does not exist")
                continue

            if parts.fragment and target in pages:
                if unquote(parts.fragment) not in pages[target].ids:
                    errors.append(
                        f"{rel}: link {value} has no matching id in {target.relative_to(root.resolve())}"
                    )

    for path in sorted(root.rglob("*.css")):
        text = path.read_text(encoding="utf-8")
        if EXTERNAL_CSS.search(text):
            errors.append(f"{path.relative_to(root)}: stylesheet loads from another site")

    return errors, len(pages), ref_count


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "website")
    if not root.is_dir():
        print(f"error: {root} is not a folder", file=sys.stderr)
        return 2

    errors, page_count, ref_count = check_site(root)
    if errors:
        for error in errors:
            print(f"error: {error}")
        print(f"\n{len(errors)} problem(s) in {page_count} page(s).")
        return 1

    print(f"OK: checked {page_count} page(s) and {ref_count} link(s) or resource(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
