#!/usr/bin/env python3
"""Tests for render-changelog.py. Run: python3 scripts/release/test_render_changelog.py"""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("render_changelog", HERE / "render-changelog.py")
rc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(rc)

REPO = "FreezingShock/Inlet"
PAGE = """<main>
  <!-- release-notes:start -->
  OLD CONTENT
  <!-- release-notes:end -->
</main>
"""


def release(tag, published_at, body="", **extra):
    data = {
        "id": abs(hash(tag)) % 10**9,
        "tag_name": tag,
        "name": f"Inlet {tag}",
        "published_at": published_at,
        "html_url": f"https://github.com/{REPO}/releases/tag/{tag}",
        "body": body,
        "draft": False,
        "prerelease": False,
    }
    data.update(extra)
    return data


class MarkdownTests(unittest.TestCase):
    def convert(self, text):
        return rc.markdown_to_html(text, REPO)

    def test_bullets_become_one_list_with_pr_links(self):
        html_out = self.convert("- Add folders (#12)\n- Fix hotkey (#13)")
        self.assertEqual(
            html_out,
            '<ul><li>Add folders (<a href="https://github.com/FreezingShock/Inlet/pull/12" target="_blank" rel="noopener">#12</a>)'
            '</li><li>Fix hotkey (<a href="https://github.com/FreezingShock/Inlet/pull/13" target="_blank" rel="noopener">#13</a>)</li></ul>',
        )

    def test_script_tags_are_escaped(self):
        out = self.convert("<script>alert(1)</script> and **bold**")
        self.assertNotIn("<script>", out)
        self.assertIn("&lt;script&gt;", out)
        self.assertIn("<strong>bold</strong>", out)

    def test_images_are_dropped_so_nothing_loads_from_elsewhere(self):
        out = self.convert("Before ![shot](https://evil.example/x.png) after")
        self.assertNotIn("<img", out)
        self.assertNotIn("evil.example", out)
        self.assertIn("Before", out)

    def test_only_http_links_become_anchors(self):
        out = self.convert("[ok](https://example.com/a?b=1&c=2) and [bad](javascript:alert(1))")
        self.assertIn('href="https://example.com/a?b=1&amp;c=2"', out)
        self.assertNotIn('href="javascript', out)

    def test_headings_code_and_fences(self):
        out = self.convert("## Notes\n\nUse `x < y`.\n\n```\nlet a = 1 < 2\n```")
        self.assertIn('<h4 class="release-sub">Notes</h4>', out)
        self.assertIn("<code>x &lt; y</code>", out)
        self.assertIn("<pre><code>let a = 1 &lt; 2</code></pre>", out)

    def test_wrapped_list_line_joins_its_item(self):
        out = self.convert("- Long item that\n  continues here")
        self.assertEqual(out, "<ul><li>Long item that continues here</li></ul>")


class BlockTests(unittest.TestCase):
    def test_no_releases_writes_empty_state(self):
        out = rc.render_page(PAGE, [], REPO)
        self.assertIn("No release yet", out)
        self.assertNotIn("OLD CONTENT", out)
        self.assertIn(rc.START_MARKER, out)
        self.assertIn(rc.END_MARKER, out)

    def test_drafts_and_unpublished_are_skipped(self):
        releases = [
            release("0.3", "2026-12-03T10:00:00Z", draft=True),
            release("0.2", "2026-12-01T10:00:00Z", body="- Thing (#5)"),
            release("0.2-draft", None),
        ]
        out = rc.render_page(PAGE, releases, REPO)
        self.assertIn('id="release-0-2"', out)
        self.assertNotIn("0.3", out)
        self.assertNotIn("0-2-draft", out)

    def test_newest_first_and_latest_tag_skips_prereleases(self):
        releases = [
            release("0.3-rc1", "2026-12-05T10:00:00Z", prerelease=True),
            release("0.2", "2026-12-01T10:00:00Z", body="- Thing"),
            release("0.1", "2026-11-20T10:00:00Z", body="- First"),
        ]
        out = rc.render_page(PAGE, releases, REPO)
        self.assertLess(out.index('id="release-0-3-rc1"'), out.index('id="release-0-2"'))
        self.assertLess(out.index('id="release-0-2"'), out.index('id="release-0-1"'))
        self.assertIn("Pre-release", out)
        latest_index = out.index("is-latest")
        self.assertGreater(latest_index, out.index('id="release-0-2"'))
        self.assertLess(latest_index, out.index('id="release-0-1"'))

    def test_date_text_and_datetime_attribute(self):
        out = rc.render_page(PAGE, [release("0.2", "2026-12-01T10:00:00Z", body="- x")], REPO)
        self.assertIn('<time datetime="2026-12-01">1 December 2026</time>', out)

    def test_release_without_body_gets_a_note(self):
        out = rc.render_page(PAGE, [release("0.2", "2026-12-01T10:00:00Z", body="")], REPO)
        self.assertIn("No notes were written for this release.", out)

    def test_page_without_markers_is_refused(self):
        with self.assertRaises(rc.RenderError):
            rc.render_page("<main></main>", [], REPO)

    def test_concatenated_pages_of_json_parse(self):
        text = json.dumps([release("0.1", "2026-11-20T10:00:00Z")]) + json.dumps([release("0.2", "2026-12-01T10:00:00Z")])
        self.assertEqual(len(rc.parse_json_documents(text)), 2)


class CliTests(unittest.TestCase):
    def test_end_to_end_with_releases_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            page = os.path.join(tmp, "changelog.html")
            data = os.path.join(tmp, "releases.json")
            Path(page).write_text(PAGE, encoding="utf-8")
            Path(data).write_text(json.dumps([release("0.2", "2026-12-01T10:00:00Z", body="- Thing (#5)")]), encoding="utf-8")
            self.assertEqual(rc.main(["--page", page, "--releases-file", data, "--repo", REPO]), 0)
            written = Path(page).read_text(encoding="utf-8")
            self.assertIn("Thing", written)
            self.assertNotIn("OLD CONTENT", written)

    def test_bad_repo_name_fails(self):
        with self.assertRaises(rc.RenderError):
            rc.fetch_releases("not a repo")


if __name__ == "__main__":
    unittest.main()
