#!/usr/bin/env python3
"""Fill the release notes on the website's changelog page from GitHub Releases.

Usage:
  render-changelog.py --repo FreezingShock/Inlet --page website/changelog.html
  render-changelog.py --releases-file releases.json --page website/changelog.html

The page holds a block between two markers:

  <!-- release-notes:start -->
  ...
  <!-- release-notes:end -->

This script replaces everything between the markers. With no published releases
it writes the empty state, so the page stays correct before the first release.

Releases come from `gh api --paginate repos/<repo>/releases`, which needs GH_TOKEN
or a logged-in gh. The Website workflow runs this at build time on the staged
copy of the site. The site never calls the API from the visitor's browser.

Drafts are left out. Each release body is Markdown, so it goes through a small
converter that handles what release notes use: headings, bullet and numbered
lists, paragraphs, code spans, bold, italics, links and #123 issue or pull
request references. Everything else is escaped, and raw HTML in a body is shown
as text. Images are never written out, so the page loads nothing from another
site.

Standard library only.
"""

import argparse
import datetime
import html
import json
import os
import re
import subprocess
import sys

START_MARKER = "<!-- release-notes:start -->"
END_MARKER = "<!-- release-notes:end -->"
BLOCK = re.compile(
    re.escape(START_MARKER) + r"(.*?)" + re.escape(END_MARKER), re.DOTALL
)
SAFE_SCHEMES = ("https://", "http://")
REPO_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


class RenderError(Exception):
    """Raised for a problem the build should stop on."""


# ---------------------------------------------------------------- input


def parse_json_documents(text: str) -> list:
    """Read one or more concatenated JSON arrays, as `gh api --paginate` prints them."""
    decoder = json.JSONDecoder()
    items: list = []
    index = 0
    text = text.strip()
    while index < len(text):
        value, index = decoder.raw_decode(text, index)
        if isinstance(value, list):
            items.extend(value)
        else:
            raise RenderError("expected a JSON array of releases")
        while index < len(text) and text[index].isspace():
            index += 1
    return items


def fetch_releases(repo: str) -> list:
    if not REPO_PATTERN.match(repo):
        raise RenderError(f"not a valid owner/name repository: {repo!r}")
    try:
        result = subprocess.run(
            ["gh", "api", "--paginate", f"repos/{repo}/releases"],
            capture_output=True,
            text=True,
            check=False,
            env=os.environ.copy(),
        )
    except FileNotFoundError as error:
        raise RenderError("gh is not installed, so the releases cannot be read") from error
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()[-1:] or ["no output"]
        raise RenderError(f"gh api could not list releases for {repo}: {detail[0]}")
    return parse_json_documents(result.stdout)


def published(releases: list) -> list:
    """Keep releases that are public. Drafts and unpublished entries are left out."""
    kept = [r for r in releases if isinstance(r, dict) and not r.get("draft") and r.get("published_at")]
    kept.sort(key=lambda r: r["published_at"], reverse=True)
    return kept


# ---------------------------------------------------------------- Markdown


def inline(text: str, repo: str) -> str:
    """Render one line of inline Markdown. Escapes everything first."""
    pieces = []
    last = 0
    for match in re.finditer(r"`([^`\n]+)`", text):
        pieces.append(("text", text[last:match.start()]))
        pieces.append(("code", match.group(1)))
        last = match.end()
    pieces.append(("text", text[last:]))

    out = []
    for kind, chunk in pieces:
        if kind == "code":
            out.append(f"<code>{html.escape(chunk, quote=False)}</code>")
        else:
            out.append(markup_text(chunk, repo))
    return "".join(out)


def markup_text(chunk: str, repo: str) -> str:
    # Images would load from another site, which the page must never do. Drop them.
    chunk = re.sub(r"!\[[^\]\n]*\]\([^)\n]*\)", "", chunk)
    safe = html.escape(chunk, quote=False)
    safe = re.sub(
        r"\[([^\]\n]+)\]\((https?://[^\s)\"'<>]+)\)",
        lambda m: f'<a href="{m.group(2)}" target="_blank" rel="noopener">{m.group(1)}</a>',
        safe,
    )
    safe = re.sub(r"\*\*([^*\n]+)\*\*", r"<strong>\1</strong>", safe)
    safe = re.sub(r"(?<![\w*])\*([^*\s][^*\n]*?)\*(?![\w*])", r"<em>\1</em>", safe)
    safe = re.sub(r"(?<![\w])_([^_\s][^_\n]*?)_(?![\w])", r"<em>\1</em>", safe)
    # Link #123 to the pull request or issue. Skip text already inside a link.
    parts = re.split(r"(<a [^>]*>.*?</a>)", safe)
    for index, part in enumerate(parts):
        if part.startswith("<a "):
            continue
        parts[index] = re.sub(
            r"(?<![\w&/#])#(\d+)\b",
            lambda m: f'<a href="https://github.com/{repo}/pull/{m.group(1)}" target="_blank" rel="noopener">#{m.group(1)}</a>',
            part,
        )
    return "".join(parts)


BULLET = re.compile(r"^\s{0,3}[-*+]\s+(.*)$")
NUMBERED = re.compile(r"^\s{0,3}\d+[.)]\s+(.*)$")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
QUOTE = re.compile(r"^\s{0,3}>\s?(.*)$")


def markdown_to_html(source: str, repo: str) -> str:
    """Convert release-note Markdown to HTML. Output is escaped and uses no images."""
    lines = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out: list[str] = []
    paragraph: list[str] = []
    listing: tuple[str, list[str]] | None = None  # (tag, items)
    fence: list[str] | None = None

    def flush_paragraph() -> None:
        if paragraph:
            out.append(f"<p>{inline(' '.join(paragraph), repo)}</p>")
            paragraph.clear()

    def flush_list() -> None:
        nonlocal listing
        if listing:
            tag, items = listing
            out.append(f"<{tag}>" + "".join(f"<li>{item}</li>" for item in items) + f"</{tag}>")
            listing = None

    for raw in lines:
        if fence is not None:
            if raw.strip().startswith("```"):
                out.append(f'<pre><code>{html.escape(chr(10).join(fence), quote=False)}</code></pre>')
                fence = None
            else:
                fence.append(raw)
            continue
        if raw.strip().startswith("```"):
            flush_paragraph()
            flush_list()
            fence = []
            continue
        if not raw.strip():
            flush_paragraph()
            flush_list()
            continue

        heading = HEADING.match(raw)
        if heading:
            flush_paragraph()
            flush_list()
            out.append(f"<h4 class=\"release-sub\">{inline(heading.group(1), repo)}</h4>")
            continue

        bullet = BULLET.match(raw)
        number = NUMBERED.match(raw)
        if bullet or number:
            flush_paragraph()
            tag = "ul" if bullet else "ol"
            text = (bullet or number).group(1)
            if listing and listing[0] != tag:
                flush_list()
            if not listing:
                listing = (tag, [])
            listing[1].append(inline(text, repo))
            continue

        quote = QUOTE.match(raw)
        if quote:
            flush_paragraph()
            flush_list()
            out.append(f"<blockquote><p>{inline(quote.group(1), repo)}</p></blockquote>")
            continue

        if listing and raw.startswith(" ") and listing[1]:
            # A wrapped line inside a list item continues that item.
            listing[1][-1] += " " + inline(raw.strip(), repo)
            continue

        flush_list()
        paragraph.append(raw.strip())

    if fence is not None:
        out.append(f'<pre><code>{html.escape(chr(10).join(fence), quote=False)}</code></pre>')
    flush_paragraph()
    flush_list()
    return "\n".join(out)


# ---------------------------------------------------------------- HTML


def format_date(iso: str) -> tuple[str, str]:
    """Return (datetime attribute, visible text) for an ISO 8601 timestamp."""
    when = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return when.date().isoformat(), f"{when.day} {when.strftime('%B %Y')}"


def slug(text: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return cleaned or "release"


def release_card(release: dict, repo: str, latest_id: object) -> str:
    tag = str(release.get("tag_name") or "")
    title = str(release.get("name") or tag or "Untitled release").strip()
    stamp, shown = format_date(release["published_at"])
    url = str(release.get("html_url") or f"https://github.com/{repo}/releases/tag/{tag}")
    if not url.startswith("https://github.com/"):
        url = f"https://github.com/{repo}/releases"
    body = (release.get("body") or "").strip()
    notes = markdown_to_html(body, repo) if body else "<p>No notes were written for this release.</p>"

    tags = []
    if release.get("id") == latest_id:
        tags.append('<span class="release-tag is-latest">Latest</span>')
    if release.get("prerelease"):
        tags.append('<span class="release-tag">Pre-release</span>')

    anchor = f"release-{slug(tag or title)}"
    return (
        f'<li class="release" id="{html.escape(anchor)}">\n'
        f'  <div class="release-meta">\n'
        f'    <h3 class="release-ver">{html.escape(title)}</h3>\n'
        f'    <p class="release-date"><time datetime="{stamp}">{shown}</time></p>\n'
        + (f'    <p class="release-tags">{"".join(tags)}</p>\n' if tags else "")
        + "  </div>\n"
        f'  <div class="release-body">\n{notes}\n'
        f'    <p class="release-link"><a href="{html.escape(url)}" target="_blank" rel="noopener">Release page on GitHub</a></p>\n'
        f"  </div>\n"
        f"</li>"
    )


def empty_state(repo: str) -> str:
    return (
        '<div class="release-empty" role="status">\n'
        '  <p class="release-empty-title">No release yet</p>\n'
        '  <p>Inlet is still in development. The first version to ship is listed here with what changed in it, '
        "and this page updates itself when a release is published.</p>\n"
        '  <div class="release-empty-actions">\n'
        f'    <a class="btn btn-ghost" href="https://github.com/{repo}/commits/main" target="_blank" rel="noopener">Commit log</a>\n'
        f'    <a class="btn btn-ghost" href="https://github.com/{repo}/releases" target="_blank" rel="noopener">Releases on GitHub</a>\n'
        "  </div>\n"
        "</div>"
    )


def render_block(releases: list, repo: str) -> str:
    public = published(releases)
    if not public:
        return empty_state(repo)
    latest = next((r for r in public if not r.get("prerelease")), None)
    latest_id = latest.get("id") if latest else None
    cards = "\n".join(release_card(r, repo, latest_id) for r in public)
    return f'<ol class="releases">\n{cards}\n</ol>'


def render_page(page_text: str, releases: list, repo: str) -> str:
    if len(BLOCK.findall(page_text)) != 1:
        raise RenderError(f"the page must contain exactly one {START_MARKER} ... {END_MARKER} block")
    block = render_block(releases, repo)
    replacement = f"{START_MARKER}\n{block}\n{END_MARKER}"
    return BLOCK.sub(lambda _m: replacement, page_text, count=1)


# ---------------------------------------------------------------- CLI


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--page", required=True, help="the changelog HTML file to update in place")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "FreezingShock/Inlet"))
    parser.add_argument("--releases-file", help="read releases from this JSON file instead of the API")
    args = parser.parse_args(argv)

    try:
        if args.releases_file:
            with open(args.releases_file, encoding="utf-8") as handle:
                releases = parse_json_documents(handle.read())
        else:
            releases = fetch_releases(args.repo)
        with open(args.page, encoding="utf-8") as handle:
            page_text = handle.read()
        updated = render_page(page_text, releases, args.repo)
    except (RenderError, json.JSONDecodeError, OSError, ValueError) as error:
        print(f"::error::render-changelog: {error}", file=sys.stderr)
        return 1

    with open(args.page, "w", encoding="utf-8") as handle:
        handle.write(updated)
    count = len(published(releases))
    print(f"Changelog: {count} published release{'s' if count != 1 else ''} written to {args.page}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
