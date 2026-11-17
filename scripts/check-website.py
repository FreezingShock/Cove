#!/usr/bin/env python3
"""Check the static Inlet website before it is published.

Checks, in order:
  1. index.html exists.
  2. Every local href/src points at a file that exists. A folder must have an index.html.
  3. Every #fragment link points at an id (or a[name]) on the target page.
  4. No resource (script, stylesheet, image, font, media, iframe) loads from
     another origin, and no CSS url() or @import reaches another origin.
     Plain <a href> links to other sites are fine. They are navigation, not requests.
     A <link rel="canonical"> or rel="alternate" may name the public URL.
  5. Every <img> has width, height and alt. Every srcset candidate exists.
  6. SEO and sharing: each indexable page has a title, a description, a canonical
     URL on the site, Open Graph and Twitter tags, and valid JSON-LD. A FAQPage's
     questions match the visible <summary> text.
  7. sitemap.xml lists every indexable page and only existing pages. robots.txt
     points at the sitemap and does not block the site. 404.html is noindex.
  8. site.webmanifest parses and its icons exist. favicon.ico and
     apple-touch-icon.png exist.

Usage: python3 scripts/check-website.py [website-dir]

Standard library only, so it runs on a bare GitHub runner with no install step.
"""

import json
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

# <link> rel values that fetch a resource. Others (canonical, alternate) are navigation.
RESOURCE_RELS = {"stylesheet", "icon", "apple-touch-icon", "preload", "modulepreload", "manifest", "prefetch"}

# The public address of the site. Canonical URLs, the sitemap and social tags must use it.
BASE = "https://freezingshock.github.io/Inlet/"

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
        self.meta: dict[str, str] = {}          # name or property -> content (first wins)
        self.canonical: str | None = None
        self.title = ""
        self.jsonld: list[str] = []
        self.summaries: list[str] = []
        self.imgs: list[dict] = []
        self._in_title = self._in_ld = self._in_summary = False
        self._buf = ""

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"])
        if tag == "a" and values.get("name"):
            self.ids.add(values["name"])

        if tag == "a" and values.get("href"):
            self.refs.append((tag, "href", values["href"], False))
        if tag == "link" and values.get("href"):
            rels = set((values.get("rel") or "").lower().split())
            is_resource = bool(rels & RESOURCE_RELS)
            self.refs.append((tag, "href", values["href"], is_resource))
            if "canonical" in rels:
                self.canonical = values["href"]
        if tag in RESOURCE_TAGS and values.get("src"):
            self.refs.append((tag, "src", values["src"], True))
        if tag in ("img", "source") and values.get("srcset"):
            for candidate in values["srcset"].split(","):
                url = candidate.strip().split()
                if url:
                    self.refs.append((tag, "srcset", url[0], True))

        if tag == "meta":
            key = values.get("name") or values.get("property")
            if key and values.get("content") is not None and key not in self.meta:
                self.meta[key] = values["content"]
        if tag == "title":
            self._in_title = True
        if tag == "script" and (values.get("type") or "").lower() == "application/ld+json":
            self._in_ld = True
            self._buf = ""
        if tag == "summary":
            self._in_summary = True
            self._buf = ""
        if tag == "img":
            self.imgs.append(values)

        style = values.get("style")
        if style:
            self.inline_css.append(style)

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if tag == "script" and self._in_ld:
            self._in_ld = False
            self.jsonld.append(self._buf)
        if tag == "summary" and self._in_summary:
            self._in_summary = False
            self.summaries.append(" ".join(self._buf.split()))

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_ld or self._in_summary:
            self._buf += data


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

    for html_path, scan in pages.items():
        rel = str(html_path.relative_to(root.resolve()))
        for img in scan.imgs:
            src = img.get("src", "?")
            for needed in ("alt", "width", "height"):
                if needed not in img:
                    errors.append(f"{rel}: <img src=\"{src}\"> is missing {needed}")

    check_seo(root, pages, errors)
    return errors, len(pages), ref_count


def local_path(root: Path, url: str) -> Path | None:
    """Map a BASE URL to its file under root, or None if it is not under BASE."""
    if not url.startswith(BASE):
        return None
    rel = url[len(BASE):].split("#")[0].split("?")[0]
    target = root / rel
    if rel == "" or target.is_dir():
        target = target / "index.html"
    return target


def check_seo(root: Path, pages: dict, errors: list[str]) -> None:
    by_name = {p.relative_to(root.resolve()).as_posix(): scan for p, scan in pages.items()}
    indexable = {}

    for name, scan in by_name.items():
        if name == "404.html":
            if "noindex" not in scan.meta.get("robots", "").lower():
                errors.append("404.html must be noindex")
            continue
        if scan.meta.get("robots", "").lower().find("noindex") >= 0:
            errors.append(f"{name}: is noindex, so it cannot be in the sitemap")
            continue
        indexable[name] = scan
        if not scan.title.strip():
            errors.append(f"{name}: <title> is empty")
        desc = scan.meta.get("description", "")
        if not 50 <= len(desc) <= 160:
            errors.append(f"{name}: meta description is {len(desc)} characters (want 50 to 160)")
        expected = BASE + ("" if name == "index.html" else name)
        if scan.canonical != expected:
            errors.append(f"{name}: canonical is {scan.canonical!r}, want {expected!r}")
        for key in ("og:title", "og:description", "og:url", "og:image", "twitter:card", "twitter:title"):
            if not scan.meta.get(key):
                errors.append(f"{name}: missing {key}")
        image = scan.meta.get("og:image", "")
        target = local_path(root, image)
        if target is None or not target.is_file():
            errors.append(f"{name}: og:image {image!r} is not a file on the site")
        for block in scan.jsonld:
            try:
                data = json.loads(block)
            except json.JSONDecodeError as exc:
                errors.append(f"{name}: JSON-LD does not parse ({exc})")
                continue
            if data.get("@type") == "FAQPage":
                questions = [q.get("name", "") for q in data.get("mainEntity", [])]
                if sorted(questions) != sorted(scan.summaries):
                    errors.append(f"{name}: FAQPage questions do not match the visible <summary> text")

    sitemap = root / "sitemap.xml"
    if not sitemap.is_file():
        errors.append("sitemap.xml is missing")
    else:
        locs = re.findall(r"<loc>\s*(.*?)\s*</loc>", sitemap.read_text(encoding="utf-8"))
        listed = set()
        for loc in locs:
            target = local_path(root, loc)
            if target is None:
                errors.append(f"sitemap.xml: {loc} is not under {BASE}")
                continue
            name = target.relative_to(root).as_posix()
            listed.add(name)
            if not target.is_file():
                errors.append(f"sitemap.xml: {loc} does not exist")
            elif name not in indexable:
                errors.append(f"sitemap.xml: {loc} is not an indexable page")
        for name in sorted(set(indexable) - listed):
            errors.append(f"sitemap.xml does not list {name}")

    robots = root / "robots.txt"
    if not robots.is_file():
        errors.append("robots.txt is missing")
    else:
        text = robots.read_text(encoding="utf-8")
        if f"Sitemap: {BASE}sitemap.xml" not in text:
            errors.append(f"robots.txt does not point at {BASE}sitemap.xml")
        if re.search(r"^Disallow:\s*/\s*$", text, re.M):
            errors.append("robots.txt blocks the whole site")

    manifest = root / "site.webmanifest"
    if not manifest.is_file():
        errors.append("site.webmanifest is missing")
    else:
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
            for icon in data.get("icons", []):
                if not (root / icon["src"]).is_file():
                    errors.append(f"site.webmanifest icon {icon['src']} does not exist")
        except (json.JSONDecodeError, KeyError) as exc:
            errors.append(f"site.webmanifest does not parse ({exc})")

    for needed in ("favicon.ico", "apple-touch-icon.png"):
        if not (root / needed).is_file():
            errors.append(f"{needed} is missing")


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
