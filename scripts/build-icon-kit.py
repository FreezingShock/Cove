#!/usr/bin/env python3
"""Build the Inlet icon kit from design/icons/kit.json.

Outputs (all generated, do not hand-edit):
  website/assets/icon-kit/<id>.svg   standalone icons (adapt to light/dark)
  website/assets/icon-kit/sprite.svg all icons as <symbol>s
  docs/icon-kit.html                 the kit preview sheet (open from the repo)
Use `--check` in CI to confirm the outputs are current.

Kit rules: 24px grid, 1.5 stroke, square caps, miter joins, no curves
except where the glyph needs one. Every icon has at most one accent
element (class "a"): a filled square in the accent color, the same move as
the Grid app icon. Class "m" marks the part that nudges on hover.
"""
import json, sys, pathlib, html
ROOT = pathlib.Path(__file__).resolve().parent.parent
kit = json.loads((ROOT / "design/icons/kit.json").read_text())
OUT = ROOT / "website/assets/icon-kit"

STYLE = ('.s{fill:none;stroke:#17150F;stroke-width:1.5;stroke-linecap:square;stroke-linejoin:miter}'
         '.k-a{fill:#46E6D6;stroke:#17150F}'
         '@media (prefers-color-scheme:dark){.s{stroke:#F4EFE6}.k-a{stroke:#F4EFE6}}')

def standalone(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
            f'<style>{STYLE}</style><g class="s">{body}</g></svg>\n')

def build():
    files = {}
    syms = []
    for group, icons in kit.items():
        for k, (label, body) in icons.items():
            files[f"website/assets/icon-kit/{k}.svg"] = standalone(body)
            syms.append(f'<symbol id="k-{k}" viewBox="0 0 24 24">{body}</symbol>')
    files["website/assets/icon-kit/sprite.svg"] = (
        '<svg xmlns="http://www.w3.org/2000/svg" style="display:none">' + "".join(syms) + '</svg>\n')
    files["docs/icon-kit.html"] = sheet()
    return files

def inline(k, body, cls="kit"):
    return (f'<svg class="{cls}" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true" '
            f'focusable="false">{body}</svg>')

def sheet():
    sections = []
    titles = {"ui": ("Interface", "Search, close, arrows, appearance."),
              "install": ("Download and install", "One glyph for each step of getting the app running."),
              "feature": ("Features", "What Inlet does, drawn on the tile grid."),
              "audience": ("Audiences and pages", "Who it is for and where to reach us."),
              "group": ("Groups", "Starting points for the preset groups.")}
    for g, icons in kit.items():
        cells = "".join(
            f'<li class="kit-cell"><span class="kit-tile">{inline(k, b)}</span><code>{k}</code><small>{html.escape(l)}</small></li>'
            for k, (l, b) in icons.items())
        t, d = titles[g]
        sections.append(f'<section class="kit-sec"><div class="kit-head"><h2>{t}</h2><p>{d}</p></div><ul class="kit-grid">{cells}</ul></section>')
    sample = "".join(f'<span class="kit-tile kit-tile--lg">{inline(k, kit["feature"][k][1])}</span>' for k in ("grid","folder","tag","pages","eye"))
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex">
<title>Inlet icon kit</title>
<link rel="icon" href="../website/favicon.ico" sizes="any">
<link rel="stylesheet" href="../website/css/tokens.css">
<link rel="stylesheet" href="../website/css/type.css">
<link rel="stylesheet" href="../website/css/site.css">
<link rel="stylesheet" href="../website/css/icons.css">
<style>
.kit-page{{max-width:1120px;margin:0 auto;padding:56px 16px 96px}}
.kit-page h1{{font-size:clamp(40px,6vw,72px);line-height:.98;letter-spacing:-.045em;margin:0 0 16px}}
.kit-page .kit-lede{{max-width:52ch;color:var(--text-2);font-size:18px;line-height:1.55}}
.kit-rules{{display:grid;grid-template-columns:repeat(4,1fr);margin:40px 0 8px;border-top:1px solid var(--text)}}
.kit-rules div{{padding:16px 16px 0 0;font-size:14px;color:var(--text-2);border-right:1px solid var(--hair)}}
.kit-rules div:last-child{{border-right:0}}
.kit-rules b{{display:block;color:var(--text);font-size:15px;margin-bottom:4px}}
.kit-sec{{padding:48px 0 0}}
.kit-head{{display:flex;align-items:baseline;gap:20px;border-top:1px solid var(--text);padding-top:12px;margin-bottom:8px;flex-wrap:wrap}}
.kit-head h2{{margin:0;font-size:13px;letter-spacing:.08em;text-transform:uppercase}}
.kit-head p{{margin:0;color:var(--text-3);font-size:14px}}
.kit-grid{{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(148px,1fr));border-left:1px solid var(--hair)}}
.kit-cell{{display:flex;flex-direction:column;align-items:flex-start;gap:6px;padding:20px 16px;border-right:1px solid var(--hair);border-bottom:1px solid var(--hair)}}
.kit-cell code{{font:600 12px/1.2 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--text)}}
.kit-cell small{{font-size:13px;color:var(--text-3)}}
.kit-demo{{display:flex;gap:16px;flex-wrap:wrap;margin-top:20px;align-items:center}}
.kit-ink{{background:#17150F;color:#F4EFE6;padding:28px;margin-top:48px;display:flex;gap:16px;flex-wrap:wrap;align-items:center}}
.kit-ink p{{margin:0 12px 0 0;font-size:14px;color:rgba(244,239,230,.78)}}
@media (max-width:700px){{.kit-rules{{grid-template-columns:1fr 1fr}}.kit-rules div:nth-child(2){{border-right:0}}.kit-rules div:nth-child(n+3){{border-top:1px solid var(--hair);margin-top:14px;padding-top:14px}}}}
</style>
</head>
<body>
<main class="kit-page" id="top">
  <p class="kit-lede" style="margin:0 0 20px;font-weight:600;color:var(--text)">Inlet / Icon kit</p>
  <h1>Tiles, drawn straight.</h1>
  <p class="kit-lede">{sum(len(v) for v in kit.values())} icons built on the same 24px grid as the app icon. Sharp square strokes, one aqua square on each. Hover a tile to see it move.</p>
  <div class="kit-rules">
    <div><b>24px grid</b>Everything snaps to whole or half pixels.</div>
    <div><b>1.5 stroke</b>Square caps and mitered joins. No rounded ends.</div>
    <div><b>One accent</b>A single filled aqua square, like the Grid icon.</div>
    <div><b>Light and dark</b>Strokes follow text color. Aqua stays aqua.</div>
  </div>
  <div class="kit-demo" aria-label="Tile sizes">{sample}</div>
  {"".join(sections)}
  <div class="kit-ink" data-theme-fixed="dark">
    <p>On ink:</p>{"".join(f'<span class="kit-tile kit-tile--lg kit-tile--ink">{inline(k, b)}</span>' for k, (l, b) in list(kit["install"].items())[:6])}
  </div>
</main>
</body>
</html>
'''

if __name__ == "__main__":
    files = build()
    check = "--check" in sys.argv
    bad = []
    for rel, txt in files.items():
        p = ROOT / rel
        if check:
            if not p.exists() or p.read_text() != txt: bad.append(rel)
        else:
            p.parent.mkdir(parents=True, exist_ok=True); p.write_text(txt)
    if check:
        if bad: sys.exit("icon kit out of date: " + ", ".join(bad[:5]) + "  (run scripts/build-icon-kit.py)")
        print("icon kit is current")
    else:
        print(f"wrote {len(files)} files")
