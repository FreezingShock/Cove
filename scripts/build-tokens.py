#!/usr/bin/env python3
"""Generate the radius and motion tokens for the app and the website from design/tokens.json.

Writes two marked blocks:
  - website/css/tokens.css        colors between /* BEGIN GENERATED: color */ and /* END GENERATED: color */
                                  radius and motion between /* BEGIN GENERATED: radius */ and /* END GENERATED */
  - Inlet/InletTheme.swift        radius and motion between // BEGIN GENERATED and // END GENERATED

Writes the type scale too:
  - website/css/type.css                  whole file, generated (web fonts and type roles)
  - Inlet/InletTheme.swift                between // BEGIN GENERATED: type and // END GENERATED: type

Usage:
  python3 scripts/build-tokens.py          rewrite the blocks
  python3 scripts/build-tokens.py --check  exit 1 if the blocks are out of date (CI)
"""
import html
import json
import math
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "tokens.json"
CSS_FILE = ROOT / "website" / "css" / "tokens.css"
SWIFT_FILE = ROOT / "Inlet" / "InletTheme.swift"
DESIGN_FILE = ROOT / "website" / "design.html"
TYPE_CSS_FILE = ROOT / "website" / "css" / "type.css"
SWIFT_TYPE_BEGIN, SWIFT_TYPE_END = "// BEGIN GENERATED: type", "// END GENERATED: type"

CSS_COLOR_BEGIN, CSS_COLOR_END = "/* BEGIN GENERATED: color", "/* END GENERATED: color */"
CSS_BEGIN, CSS_END = "/* BEGIN GENERATED: radius", "/* END GENERATED */"
SWIFT_BEGIN, SWIFT_END = "// BEGIN GENERATED: radius and motion.", "// END GENERATED: radius and motion"
COLOR_BEGIN, COLOR_END = "// BEGIN GENERATED: colors.", "// END GENERATED: colors"


def fmt(v):
    """Plain number text: 6 -> '6', 0.5 -> '0.5', 0.0 -> '0.0'."""
    return str(v)


def spring_samples(duration, bounce):
    """Position curve of a spring with SwiftUI's Spring(duration:bounce:) meaning.

    Mass 1, natural frequency w0 = 2*pi/duration, damping ratio z = 1 - bounce.
    Returns (settle_seconds, samples in 0...1 with 0 at the start and 1 at the end).
    """
    z = 1.0 - bounce
    w0 = 2 * math.pi / duration

    if z < 1:
        wd = w0 * math.sqrt(1 - z * z)

        def x(t):
            return 1 - math.exp(-z * w0 * t) * (math.cos(wd * t) + (z * w0 / wd) * math.sin(wd * t))
    else:
        def x(t):
            return 1 - math.exp(-w0 * t) * (1 + w0 * t)

    # Settle time: the last moment the curve is more than 0.1% away from its target.
    dt = duration / 4000
    settle, t = 0.0, 0.0
    while t < 10 * duration:
        if abs(x(t) - 1) > 0.001:
            settle = t + dt
        t += dt

    n = 48
    pts = [x(settle * i / n) for i in range(n + 1)]
    pts[0], pts[-1] = 0.0, 1.0
    return settle, pts


def linear_fn(pts):
    body = ", ".join(f"{p:.3f}".rstrip("0").rstrip(".") if p not in (0.0, 1.0) else fmt(p) for p in pts)
    return f"linear({body})"


def build_css(cfg):
    r, m = cfg["radius"], cfg["motion"]
    s = r["scale"]
    lines = [
        "/* BEGIN GENERATED: radius and motion. Source: design/tokens.json, built by scripts/build-tokens.py.",
        "   Edit the JSON and rerun the script; do not hand-edit this block. */",
        ":root {",
        "  /* Radius (px). Inner = outer - inset; see the nesting table in design/tokens.json. */",
    ]
    for k, v in s.items():
        lines.append(f"  --r-{k}: {v}px;")
    lines += [
        f"  --r-pill: {r['pill']}px;",
        f"  --r-hair: {r['hair']}px;",
        f"  --r-icon: {r['iconRatio']};  /* app icon squircle, as a fraction of the icon size */",
        "",
        "  /* Motion durations (seconds). */",
    ]
    for k, v in m["durations"].items():
        lines.append(f"  --dur-{k}: {fmt(v)}s;")
    lines += ["", "  /* Spacing (px). One 4 pt based scale. 44 is a hit target, not spacing. */"]
    for v in cfg["space"]["scale"]:
        lines.append(f"  --space-{v}: {v}px;")
    lines += ["", "  /* Easing curves. */"]
    for k, v in m["easing"].items():
        lines.append(f"  --ease-{k}: cubic-bezier({', '.join(fmt(x) for x in v)});")
    lines += [
        "",
        "  /* Springs, matched to the app: a linear() curve and the time it takes to settle. Use only",
        "     where linear() is supported (@supports (transition-timing-function: linear(0, 1))). */",
    ]
    for name, sp in m["springs"].items():
        settle, pts = spring_samples(sp["duration"], sp["bounce"])
        lines.append(f"  --spring-{name}: {linear_fn(pts)};")
        lines.append(f"  --spring-{name}-dur: {settle:.3f}s;")
    lines += ["}", "/* END GENERATED */"]
    return "\n".join(lines) + "\n"


def build_color(cfg):
    """Light, system dark, forced dark and forced light color sets for the website."""
    c = cfg["color"]

    def rules(selector, vals, scheme):
        body = [f"  --{k}: {v};" for k, v in vals.items()]
        body.append(f"  color-scheme: {scheme};")
        return [f"{selector} {{", *body, "}"]

    lines = [
        "/* BEGIN GENERATED: color. Source: design/tokens.json, built by scripts/build-tokens.py.",
        "   Edit the JSON and rerun the script; do not hand-edit this block. */",
        "/* Light */",
        *rules(":root", c["light"], "light"),
        "/* Dark (system) */",
        "@media (prefers-color-scheme: dark) {",
        *["  " + l for l in rules(':root:not([data-theme="light"])', c["dark"], "dark")],
        "}",
        "/* Dark (forced) */",
        *rules(':root[data-theme="dark"], .t-dark', c["dark"], "dark"),
        "/* Light (forced, for side-by-side sheets) */",
        *rules(".t-light", c["light"], "light"),
        "/* END GENERATED: color */",
    ]
    return "\n".join(lines) + "\n"


def build_swift(cfg):
    r, m = cfg["radius"], cfg["motion"]
    s = r["scale"]
    doc = {
        "xs": "keycaps, symbol tiles",
        "sm": "small tiles, sidebar rows, theme thumbnails",
        "md": "rows and groups inside a 32 pt panel with 16 pt padding",
        "lg": "cards inside a 32 pt panel with 12 pt padding",
        "row": "selected row inside a results panel (32 - 8)",
        "sidebar": "Settings sidebar inside a 26 pt window with 8 pt inset",
        "window": "Settings and onboarding window",
        "panel": "every glass panel: results, quick panel, folder overlay",
    }
    out = [
        "// BEGIN GENERATED: radius and motion. Source: design/tokens.json, built by scripts/build-tokens.py.",
        "// Edit the JSON and rerun the script; do not hand-edit this block.",
        "",
        "// MARK: - Shape tokens (points). Radii nest: inner = outer - inset (see design/tokens.json)",
        "",
        "enum InletRadius {",
    ]
    for k, v in s.items():
        out.append(f"    static let {k}: CGFloat = {fmt(v)}  // {doc.get(k, '')}".rstrip())
    out += [
        f"    static let pill: CGFloat = {fmt(r['pill'])}  // capsule ends",
        f"    static let hair: CGFloat = {fmt(r['hair'])}  // rules, progress bars",
        f"    /// App icons use {r['iconRatio'] * 100:.1f}% of their width as the corner radius.",
        f"    static let iconRatio: CGFloat = {fmt(r['iconRatio'])}",
        "    static func icon(_ size: CGFloat) -> CGFloat { size * iconRatio }",
        "}",
        "",
        "// MARK: - Motion tokens",
        "",
        "/// Springs are `Spring(duration:bounce:)` (macOS 14+). Bounce in, never out: `dismiss` has no bounce.",
        "enum InletMotion {",
    ]
    spring_names = {
        "snap": "Hover, selection move, focus ring",
        "press": "Icon and button press, release overshoot",
        "open": "Full grid appears, icons ripple out from center",
        "morph": "Search capsule melts into the results panel",
        "rise": "Quick panel rises out of the Dock icon",
        "settle": "Grid reflow when a search filters icons",
        "dismiss": "Anything closing. Never bounce on the way out",
    }
    for name, sp in m["springs"].items():
        out.append(f"    /// {spring_names.get(name, sp.get('use', ''))}")
        out.append(f"    static let {name} = Spring(duration: {fmt(sp['duration'])}, bounce: {fmt(sp['bounce'])})")
    out.append("")
    out.append("    /// Durations (seconds) for fades and loops that are not springs.")
    for k, v in m["durations"].items():
        out.append(f"    static let {k}: Double = {fmt(v)}")
    out += [
        "}",
        "",
        "extension Animation {",
    ]
    for name in m["springs"]:
        out.append(f"    static var inlet{name[0].upper()}{name[1:]}: Animation {{ .spring(InletMotion.{name}) }}")
    out += [
        "    /// Fades and cross-dissolves. Use this for Reduce Motion fallbacks as well.",
        "    static var inletFade: Animation { .easeInOut(duration: InletMotion.fast) }",
        "",
        "    /// For a drag release: carries the drag's speed into the rise spring (macOS 14+).",
        "    static func inletRelease(velocity: Double) -> Animation {",
        "        .interpolatingSpring(InletMotion.rise, initialVelocity: velocity)",
        "    }",
        "}",
        "// END GENERATED: radius and motion",
    ]
    return "\n".join(out) + "\n"


SWIFT_WEIGHTS = {"regular": ".regular", "medium": ".medium", "semibold": ".semibold", "bold": ".bold"}


def build_type_css(cfg):
    t = cfg["type"]["web"]
    roles = t["roles"]
    w = t["weights"]
    lines = [
        "/* Generated from design/tokens.json by scripts/build-tokens.py. Do not hand-edit; change the JSON and rerun. */",
        "",
        "/* Figtree, self-hosted (SIL Open Font License, see fonts/OFL-Figtree.txt). One variable file covers",
        "   weights 300 to 900. Latin subset only; anything else falls back to the system stack. */",
        "@font-face {",
        "  font-family: \"Figtree\";",
        "  src: url(\"../fonts/figtree-latin-wght.woff2\") format(\"woff2\");",
        "  font-weight: 300 900;",
        "  font-style: normal;",
        "  font-display: swap;",
        "}",
        "",
        ":root {",
        f"  --font-ui: {t['stack']};",
        f"  --font-mono: {t['mono']};",
    ]
    for k, v in w.items():
        lines.append(f"  --w-{k}: {v};")
    for name, r in roles.items():
        lines.append(f"  --fs-{name}: {r['size']};")
        lines.append(f"  --fw-{name}: var(--w-{r['weight']});")
        lines.append(f"  --lh-{name}: {fmt(r['lineHeight'])};")
        lines.append(f"  --ls-{name}: {r['tracking']};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def build_type_swift(cfg):
    roles = cfg["type"]["app"]["roles"]
    out = [
        "// BEGIN GENERATED: type. Source: design/tokens.json, built by scripts/build-tokens.py.",
        "// Edit the JSON and rerun the script; do not hand-edit this block.",
        "",
        "/// Type roles. SF Pro throughout, through Font.system, which picks the optical size itself.",
        "/// SwiftUI has no 650 weight, so the spec's 650 becomes .semibold.",
        "enum InletFont {",
    ]
    for name, r in roles.items():
        weight = SWIFT_WEIGHTS[r["weight"]]
        if r["weight"] == "regular":
            expr = f"Font.system(size: {fmt(r['size'])})"
        else:
            expr = f"Font.system(size: {fmt(r['size'])}, weight: {weight})"
        out.append(f"    static let {name} = {expr}  // {r['use']}")
    out += [
        "}",
        "// END GENERATED: type",
    ]
    return "\n".join(out) + "\n"



APP_COLOR_NAMES = [
    "base", "base2", "glowA", "glowB", "glowC", "window", "grouped", "text", "text2", "text3",
    "hair", "accent", "accentInk", "accentSoft", "logoAqua", "gFill", "gSolid", "gSheenTop",
    "gSheenBot", "gHl", "gLow", "gRimA", "gRimB", "gRimC", "gRimD", "gEdge", "gShadow", "gSpec",
    "cFill", "selTop", "selBot", "selHl", "selRing", "selShadow", "hover", "scrim", "track",
    "knob", "field", "iconShadow", "accentHover", "accentPressed", "pressed", "focus",
]


def css_name(swift_name):
    return re.sub(r"([A-Z]|\d+)", lambda m: "-" + m.group(1).lower(), swift_name)


def parse_css_color(value):
    """'#RRGGBB', 'rgb(...)' or 'rgba(...)' to [r, g, b] or [r, g, b, a] in 0...1."""
    v = value.strip()
    if v.startswith("#"):
        h = v[1:]
        return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    m = re.fullmatch(r"rgba?\(([^)]*)\)", v)
    if not m:
        raise ValueError(f"not a color: {value!r}")
    parts = [x.strip() for x in m.group(1).split(",")]
    out = [float(parts[i]) / 255 for i in range(3)]
    if len(parts) == 4:
        out.append(float(parts[3]))
    return out


def swift_num(v):
    return f"{round(v, 4):g}"


def swift_rgba(vals):
    parts = [f"r: {swift_num(vals[0])}", f"g: {swift_num(vals[1])}", f"b: {swift_num(vals[2])}"]
    if len(vals) == 4:
        parts.append(f"a: {swift_num(vals[3])}")
    return ".init(" + ", ".join(parts) + ")"


# Tokens a Supporter theme can change. They are emitted as computed
# properties that call ThemeRuntime.color(role, ...), which applies the theme.
# Everything else is a plain `static let`.
THEMABLE_ROLES = {
    "base": "background", "base2": "background", "window": "background",
    "gFill": "glass", "scrim": "veil",
    "accent": "accent", "accentInk": "accentInk", "accentSoft": "accentSoft",
}


def build_swift_colors(cfg):
    c = cfg["color"]
    out = [
        "// BEGIN GENERATED: colors. Source: design/tokens.json (color), built by scripts/build-tokens.py.",
        "// Edit the JSON and rerun the script; do not hand-edit this block.",
    ]
    for name in APP_COLOR_NAMES:
        key = css_name(name)
        light, dark = c["light"][key], c["dark"][key]
        l_rgba, d_rgba = swift_rgba(parse_css_color(light)), swift_rgba(parse_css_color(dark))
        out.append(f"    /// {light} / {dark}")
        if name in THEMABLE_ROLES:
            out.append(f"    static var {name}: Color {{ ThemeRuntime.color(.{THEMABLE_ROLES[name]}, light: {l_rgba}, dark: {d_rgba}) }}")
        else:
            out.append(f"    static let {name} = Color.inlet(light: {l_rgba}, dark: {d_rgba})")
    out.append("// END GENERATED: colors")
    return "\n".join(out) + "\n"


def splice(text, begin, end, block, path):
    start = text.find(begin)
    stop = text.find(end, start)
    if start == -1 or stop == -1:
        sys.exit(f"{path}: missing {begin!r} ... {end!r} markers")
    stop += len(end)
    # Keep everything after the END marker as it was, so reruns are stable.
    return text[:start] + block + text[stop:].lstrip("\n") if False else text[:start] + block + text[stop:].removeprefix("\n")


# ---------- Design system page (website/design.html) ----------
# The token sections of the page are generated here, so the page shows the same values the app
# and the site use. Contrast is checked on every build: text pairs must hold 4.5:1.
CORE_COLORS = [
    "base", "window", "grouped", "text", "text-2", "text-3", "hair", "accent", "accent-soft",
    "accent-ink", "logo-aqua", "glow-a", "g-fill", "g-solid", "scrim", "track", "hover",
]
CONTRAST_PAIRS = [("text", "base"), ("text-2", "base"), ("text-3", "base"),
                  ("text", "grouped"), ("accent-ink", "accent")]
MIN_CONTRAST = 4.5
TYPE_SAMPLES = {
    "display": "Every app, one keystroke away.",
    "section": "Search, sort and open from one place.",
    "feature": "Your files, grouped your way.",
    "lede": "Inlet opens with one key and gets out of the way.",
    "body": "Results update as you type, and every file keeps its place.",
    "small": "Paths and secondary text sit one step down.",
    "caption": "~/Documents/Projects/Inlet",
    "label": "Supporter · Groups",
}


def _lum(rgb):
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _over(fg, bg):
    """Composite an (r, g, b[, a]) color over an opaque (r, g, b)."""
    a = fg[3] if len(fg) == 4 else 1.0
    return [fg[i] * a + bg[i] * (1 - a) for i in range(3)]


def contrast_ratio(fg, bg, under):
    """WCAG ratio of fg on bg. Both may be translucent; bg sits on the opaque `under` color."""
    base = parse_css_color(under)[:3]
    surface = _over(parse_css_color(bg), base)
    text = _over(parse_css_color(fg), surface)
    hi, lo = sorted((_lum(text), _lum(surface)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def build_design_page(cfg):
    """Returns {name: block} for each generated section of website/design.html."""
    e = lambda v: html.escape(str(v), quote=True)
    c, t, rs, m, sp = cfg["color"], cfg["type"], cfg["radius"], cfg["motion"], cfg["space"]

    def wrap(name, body):
        return (f"<!-- BEGIN GENERATED: design-{name}. Source: design/tokens.json, built by scripts/build-tokens.py.\n"
                f"     Edit the JSON and rerun the script; do not hand-edit this block. -->\n"
                f"{body}\n<!-- END GENERATED: design-{name} -->\n")

    blocks = {}

    # Color: one panel per mode. The panels force their own mode with .t-light and .t-dark, so both show on any page.
    panels = []
    for mode, label, cls in (("light", "Light", "t-light"), ("dark", "Dark", "t-dark")):
        chips = "\n".join(
            f'<li class="ds-sw"><span class="ds-chip" style="background:var(--{k})"></span>'
            f'<span class="ds-sw-name">{e(k)}</span><code>{e(c[mode][k])}</code></li>'
            for k in CORE_COLORS)
        panels.append(f'<div class="ds-theme {cls}">\n<p class="ds-theme-name">{label}</p>\n'
                      f'<ul class="ds-swatches">\n{chips}\n</ul>\n</div>')
    blocks["color"] = wrap("color", '<div class="ds-theme-grid">\n' + "\n".join(panels) + "\n</div>")

    rows = []
    for mode in ("light", "dark"):
        for fg, bg in CONTRAST_PAIRS:
            ratio = contrast_ratio(c[mode][fg], c[mode][bg], c[mode]["base"])
            if ratio < MIN_CONTRAST:
                sys.exit(f"{mode}: {fg} on {bg} is {ratio:.2f}:1, below {MIN_CONTRAST}:1")
            rows.append(f'<tr><th scope="row">{e(fg)} on {e(bg)}</th><td>{e(mode)}</td>'
                        f'<td>{ratio:.1f}:1</td></tr>')
    blocks["contrast"] = wrap("contrast",
        '<table class="ds-table">\n<thead><tr><th scope="col">Text on surface</th><th scope="col">Mode</th>'
        '<th scope="col">Contrast</th></tr></thead>\n<tbody>\n' + "\n".join(rows) + "\n</tbody>\n</table>")

    # Type: web roles rendered at their real settings, app roles as a spec table.
    web = t["web"]
    web_rows = []
    for name, role in web["roles"].items():
        spec = f"{role['size']} · {role['weight']} · line {role['lineHeight']} · tracking {role['tracking']}"
        caps = " ds-caps" if name == "label" else ""
        style = (f"font-size:var(--fs-{name});font-weight:var(--fw-{name});"
                 f"line-height:var(--lh-{name});letter-spacing:var(--ls-{name})")
        web_rows.append(
            f'<div class="ds-type-row"><div class="ds-type-meta"><p class="ds-role">{e(name)}</p>'
            f'<p class="ds-spec">{e(spec)}</p></div>'
            f'<p class="ds-type-sample{caps}" style="{style}">{e(TYPE_SAMPLES.get(name, name))}</p></div>')
    app_rows = "\n".join(
        f'<tr><th scope="row">{e(n)}</th><td>{e(v["size"])} pt</td><td>{e(v["weight"])}</td><td>{e(v["use"])}</td></tr>'
        for n, v in t["app"]["roles"].items())
    blocks["type"] = wrap("type",
        '<div class="ds-type">\n<p class="ds-sub">Website: Figtree, self-hosted</p>\n' + "\n".join(web_rows) +
        '\n</div>\n<div class="ds-type-app">\n<p class="ds-sub">App: SF Pro through Font.system</p>\n'
        '<table class="ds-table">\n<thead><tr><th scope="col">Role</th><th scope="col">Size</th>'
        '<th scope="col">Weight</th><th scope="col">Use</th></tr></thead>\n<tbody>\n' + app_rows +
        "\n</tbody>\n</table>\n</div>")

    # Shape: radii as tiles, nesting as a table, plus pill and hairline.
    tiles = "\n".join(
        f'<li class="ds-radius"><span class="ds-radius-tile" style="border-radius:var(--r-{k})" aria-hidden="true"></span>'
        f'<p class="ds-sw-name">{e(k)}</p><code>{v}</code></li>'
        for k, v in rs["scale"].items())
    nest = "\n".join(
        f'<tr><th scope="row">{e(n["inner"])} in {e(n["outer"])}</th><td>{e(n["inset"])}</td><td>{e(n["use"])}</td></tr>'
        for n in rs["nesting"])
    blocks["radius"] = wrap("radius",
        f'<ul class="ds-radii">\n{tiles}\n</ul>\n'
        f'<p class="ds-note">Pill <code>{e(rs["pill"])}</code> · hairline <code>{e(rs["hair"])}</code> · '
        f'app icon corner <code>{e(rs["iconRatio"])}</code> of the icon width.</p>\n'
        '<table class="ds-table">\n<thead><tr><th scope="col">Inner in outer</th><th scope="col">Inset</th>'
        '<th scope="col">Use</th></tr></thead>\n<tbody>\n' + nest + "\n</tbody>\n</table>")

    # Space: the 4 pt scale, drawn from the --space-N variables in tokens.css.
    bars = "\n".join(
        f'<li class="ds-space"><span class="ds-space-bar" style="width:var(--space-{v})" aria-hidden="true"></span>'
        f'<code>{v}</code></li>'
        for v in sp["scale"])
    blocks["space"] = wrap("space",
        f'<ul class="ds-spaces">\n{bars}\n</ul>\n'
        f'<p class="ds-note">Base <code>{e(sp["base"])}</code> pt. Hit target <code>{e(sp["hitTarget"])}</code> pt, '
        'which is not spacing.</p>')

    # Motion: durations, easing curves and springs. Each spring has a track you can play.
    durs = "\n".join(f'<tr><th scope="row">{e(k)}</th><td>{e(v)} s</td></tr>' for k, v in m["durations"].items())
    eases = "\n".join(
        f'<tr><th scope="row">{e(k)}</th><td><code>cubic-bezier({", ".join(str(x) for x in v)})</code></td></tr>'
        for k, v in m["easing"].items())
    springs = []
    for name, sprg in m["springs"].items():
        springs.append(
            f'<div class="ds-spring-row">\n<div class="ds-spring-meta"><p class="ds-role">{e(name)}</p>'
            f'<p class="ds-spec">{e(sprg["duration"])} s · bounce {e(sprg["bounce"])}</p>'
            f'<p class="ds-use">{e(sprg["use"])}</p></div>\n'
            f'<button class="ds-track" type="button" aria-pressed="false" '
            f'aria-label="Play the {e(name)} spring" '
            f'style="--sp:var(--spring-{name});--spd:var(--spring-{name}-dur)">'
            f'<span class="ds-dot" aria-hidden="true"></span></button>\n</div>')
    blocks["motion"] = wrap("motion",
        '<div class="ds-motion-grid">\n'
        f'<div><p class="ds-sub">Durations</p><table class="ds-table"><tbody>\n{durs}\n</tbody></table></div>\n'
        f'<div><p class="ds-sub">Easing</p><table class="ds-table"><tbody>\n{eases}\n</tbody></table></div>\n'
        '</div>\n<p class="ds-sub">Springs</p>\n<div class="ds-springs">\n' + "\n".join(springs) + "\n</div>")

    return blocks



def main():
    check = "--check" in sys.argv
    cfg = json.loads(SOURCE.read_text())
    css_block = build_css(cfg)
    color_block = build_color(cfg)
    swift_block = build_swift(cfg)
    swift_color_block = build_swift_colors(cfg)
    design_blocks = build_design_page(cfg)
    design_now = DESIGN_FILE.read_text()
    design_new = design_now
    for name, block in design_blocks.items():
        design_new = splice(design_new, f"<!-- BEGIN GENERATED: design-{name}", f"<!-- END GENERATED: design-{name} -->", block, DESIGN_FILE)

    css_now = CSS_FILE.read_text()
    swift_now = SWIFT_FILE.read_text()
    css_new = splice(css_now, CSS_COLOR_BEGIN, CSS_COLOR_END, color_block, CSS_FILE)
    css_new = splice(css_new, CSS_BEGIN, CSS_END, css_block, CSS_FILE)
    swift_new = splice(swift_now, SWIFT_BEGIN, SWIFT_END, swift_block, SWIFT_FILE)
    swift_new = splice(swift_new, COLOR_BEGIN, COLOR_END, swift_color_block, SWIFT_FILE)
    swift_new = splice(swift_new, SWIFT_TYPE_BEGIN, SWIFT_TYPE_END, build_type_swift(cfg), SWIFT_FILE)
    type_css_now = TYPE_CSS_FILE.read_text() if TYPE_CSS_FILE.exists() else ""
    type_css_new = build_type_css(cfg)

    targets = [
        (CSS_FILE, css_now, css_new),
        (SWIFT_FILE, swift_now, swift_new),
        (TYPE_CSS_FILE, type_css_now, type_css_new),
        (DESIGN_FILE, design_now, design_new),
    ]

    if check:
        stale = [str(p.relative_to(ROOT)) for p, now, new in targets if now != new]
        if stale:
            print("Out of date, run: python3 scripts/build-tokens.py ->", ", ".join(stale))
            sys.exit(1)
        print("Token blocks are up to date.")
        return

    for path, now, new in targets:
        if now != new:
            path.write_text(new)
    print("Wrote " + ", ".join(str(p.relative_to(ROOT)) for p, _, _ in targets))


if __name__ == "__main__":
    main()
