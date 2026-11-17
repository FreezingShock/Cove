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
import json
import math
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "tokens.json"
CSS_FILE = ROOT / "website" / "css" / "tokens.css"
SWIFT_FILE = ROOT / "Inlet" / "InletTheme.swift"
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
    "knob", "field", "iconShadow", "accentHover", "accentPressed", "pressed",
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


def main():
    check = "--check" in sys.argv
    cfg = json.loads(SOURCE.read_text())
    css_block = build_css(cfg)
    color_block = build_color(cfg)
    swift_block = build_swift(cfg)
    swift_color_block = build_swift_colors(cfg)

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
