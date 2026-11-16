//
//  CoveTheme.swift
//  Cove
//
//  Design tokens from theme-spec.md (v1.1): colors, shape, spacing, type,
//  spring motion, glass, and the accessibility fallbacks.
//  Target: macOS 26. Written against Apple's docs (checked 2026-11-16) but
//  not compiled yet: build in Xcode 26 and fix anything the compiler flags.
//

import SwiftUI
import AppKit

// MARK: - Light/dark color helper

/// Red, green, blue and alpha in 0...1, so a token can be written once
/// with a value for each appearance.
struct RGBA {
    var r: Double, g: Double, b: Double, a: Double
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

extension Color {
    /// A color that switches with the window's appearance, like an asset
    /// catalog color. `bestMatch` picks the Dark value when the window is dark.
    static func cove(light: RGBA, dark: RGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark.nsColor : light.nsColor
        })
    }
}

// MARK: - Color tokens

/// Each token's comment gives the spec's light value / dark value.
enum CoveColor {
    /// #E6ECF2 / #05070C
    static let base = Color.cove(light: .init(r: 0.902, g: 0.925, b: 0.949), dark: .init(r: 0.020, g: 0.027, b: 0.047))
    /// #F6F8FB / #0B0F18
    static let base2 = Color.cove(light: .init(r: 0.965, g: 0.973, b: 0.984), dark: .init(r: 0.043, g: 0.059, b: 0.094))
    /// rgba(70,230,214,0.42) / rgba(40,200,196,0.42)
    static let glowA = Color.cove(light: .init(r: 0.275, g: 0.902, b: 0.839, a: 0.42), dark: .init(r: 0.157, g: 0.784, b: 0.769, a: 0.42))
    /// rgba(122,138,255,0.34) / rgba(64,84,210,0.40)
    static let glowB = Color.cove(light: .init(r: 0.478, g: 0.541, b: 1.000, a: 0.34), dark: .init(r: 0.251, g: 0.329, b: 0.824, a: 0.40))
    /// rgba(255,255,255,0.85) / rgba(120,90,220,0.16)
    static let glowC = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.85), dark: .init(r: 0.471, g: 0.353, b: 0.863, a: 0.16))
    /// #F4F6F9 / #161A22
    static let window = Color.cove(light: .init(r: 0.957, g: 0.965, b: 0.976), dark: .init(r: 0.086, g: 0.102, b: 0.133))
    /// #FFFFFF / rgba(255,255,255,0.055)
    static let grouped = Color.cove(light: .init(r: 1, g: 1, b: 1), dark: .init(r: 1, g: 1, b: 1, a: 0.055))
    /// #0B111C / #FFFFFF
    static let text = Color.cove(light: .init(r: 0.043, g: 0.067, b: 0.110), dark: .init(r: 1, g: 1, b: 1))
    /// rgba(16,24,40,0.66) / rgba(235,240,255,0.72)
    static let text2 = Color.cove(light: .init(r: 0.063, g: 0.094, b: 0.157, a: 0.66), dark: .init(r: 0.922, g: 0.941, b: 1.000, a: 0.72))
    /// rgba(16,24,40,0.62) / rgba(235,240,255,0.54). v1.1 value, meets 4.5:1 for text.
    static let text3 = Color.cove(light: .init(r: 0.063, g: 0.094, b: 0.157, a: 0.62), dark: .init(r: 0.922, g: 0.941, b: 1.000, a: 0.54))
    /// rgba(12,22,44,0.10) / rgba(255,255,255,0.12)
    static let hair = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.10), dark: .init(r: 1, g: 1, b: 1, a: 0.12))
    /// #0E968A / #46E6D6. Controls and icons only, never body text on light.
    static let accent = Color.cove(light: .init(r: 0.055, g: 0.588, b: 0.541), dark: .init(r: 0.275, g: 0.902, b: 0.839))
    /// #066F67 / #46E6D6. v1.1 value, meets 4.5:1 for text.
    static let accentText = Color.cove(light: .init(r: 0.024, g: 0.435, b: 0.404), dark: .init(r: 0.275, g: 0.902, b: 0.839))
    /// #FFFFFF / #022522
    static let accentInk = Color.cove(light: .init(r: 1, g: 1, b: 1), dark: .init(r: 0.008, g: 0.145, b: 0.133))
    /// rgba(14,150,138,0.14) / rgba(70,230,214,0.16)
    static let accentSoft = Color.cove(light: .init(r: 0.055, g: 0.588, b: 0.541, a: 0.14), dark: .init(r: 0.275, g: 0.902, b: 0.839, a: 0.16))
    /// #46E6D6 in both appearances
    static let logoAqua = Color(red: 0.275, green: 0.902, blue: 0.839)
    /// rgba(250,252,255,0.50) / rgba(12,16,26,0.55)
    static let gFill = Color.cove(light: .init(r: 0.980, g: 0.988, b: 1.000, a: 0.50), dark: .init(r: 0.047, g: 0.063, b: 0.102, a: 0.55))
    /// #FFFFFF / #242A35. Replaces glass under Reduce Transparency and Increase Contrast.
    static let gSolid = Color.cove(light: .init(r: 1, g: 1, b: 1), dark: .init(r: 0.141, g: 0.165, b: 0.208))
    /// rgba(255,255,255,0.62) / rgba(255,255,255,0.13)
    static let gSheenTop = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.62), dark: .init(r: 1, g: 1, b: 1, a: 0.13))
    /// rgba(255,255,255,0.18) / rgba(255,255,255,0.04)
    static let gSheenBot = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.18), dark: .init(r: 1, g: 1, b: 1, a: 0.04))
    /// rgba(255,255,255,0.95) / rgba(255,255,255,0.42)
    static let gHl = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.95), dark: .init(r: 1, g: 1, b: 1, a: 0.42))
    /// rgba(255,255,255,0.35) / rgba(255,255,255,0.08)
    static let gLow = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.35), dark: .init(r: 1, g: 1, b: 1, a: 0.08))
    /// rgba(255,255,255,0.95) / rgba(255,255,255,0.50)
    static let gRimA = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.95), dark: .init(r: 1, g: 1, b: 1, a: 0.50))
    /// rgba(255,255,255,0.35) / rgba(255,255,255,0.14)
    static let gRimB = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.35), dark: .init(r: 1, g: 1, b: 1, a: 0.14))
    /// rgba(12,22,44,0.06) / rgba(255,255,255,0.06)
    static let gRimC = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.06), dark: .init(r: 1, g: 1, b: 1, a: 0.06))
    /// rgba(255,255,255,0.70) / rgba(255,255,255,0.22)
    static let gRimD = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.70), dark: .init(r: 1, g: 1, b: 1, a: 0.22))
    /// rgba(12,22,44,0.10) / rgba(0,0,0,0.40)
    static let gEdge = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.10), dark: .init(r: 0, g: 0, b: 0, a: 0.40))
    /// rgba(28,44,80,0.16) / rgba(0,0,0,0.55)
    static let gShadow = Color.cove(light: .init(r: 0.110, g: 0.173, b: 0.314, a: 0.16), dark: .init(r: 0, g: 0, b: 0, a: 0.55))
    /// rgba(255,255,255,0.55) / rgba(255,255,255,0.16)
    static let gSpec = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.55), dark: .init(r: 1, g: 1, b: 1, a: 0.16))
    /// rgba(250,252,255,0.38) / rgba(12,16,26,0.35)
    static let cFill = Color.cove(light: .init(r: 0.980, g: 0.988, b: 1.000, a: 0.38), dark: .init(r: 0.047, g: 0.063, b: 0.102, a: 0.35))
    /// rgba(255,255,255,0.92) / rgba(255,255,255,0.24)
    static let selTop = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.92), dark: .init(r: 1, g: 1, b: 1, a: 0.24))
    /// rgba(255,255,255,0.62) / rgba(255,255,255,0.10)
    static let selBot = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 0.62), dark: .init(r: 1, g: 1, b: 1, a: 0.10))
    /// rgba(255,255,255,1.00) / rgba(255,255,255,0.55)
    static let selHl = Color.cove(light: .init(r: 1, g: 1, b: 1, a: 1.00), dark: .init(r: 1, g: 1, b: 1, a: 0.55))
    /// rgba(12,22,44,0.08) / rgba(255,255,255,0.16)
    static let selRing = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.08), dark: .init(r: 1, g: 1, b: 1, a: 0.16))
    /// rgba(28,44,80,0.14) / rgba(0,0,0,0.30)
    static let selShadow = Color.cove(light: .init(r: 0.110, g: 0.173, b: 0.314, a: 0.14), dark: .init(r: 0, g: 0, b: 0, a: 0.30))
    /// rgba(12,22,44,0.05) / rgba(255,255,255,0.07)
    static let hover = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.05), dark: .init(r: 1, g: 1, b: 1, a: 0.07))
    /// rgba(236,241,246,0.42) / rgba(4,6,10,0.44)
    static let scrim = Color.cove(light: .init(r: 0.925, g: 0.945, b: 0.965, a: 0.42), dark: .init(r: 0.016, g: 0.024, b: 0.039, a: 0.44))
    /// rgba(12,22,44,0.46) / rgba(255,255,255,0.40). v1.1 value, meets 3:1 for control state.
    static let track = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.46), dark: .init(r: 1, g: 1, b: 1, a: 0.40))
    /// #FFFFFF / #F4F6FA
    static let knob = Color.cove(light: .init(r: 1, g: 1, b: 1), dark: .init(r: 0.957, g: 0.965, b: 0.980))
    /// rgba(12,22,44,0.05) / rgba(255,255,255,0.07)
    static let field = Color.cove(light: .init(r: 0.047, g: 0.086, b: 0.173, a: 0.05), dark: .init(r: 1, g: 1, b: 1, a: 0.07))
    /// rgba(28,44,80,0.22) / rgba(0,0,0,0.45)
    static let iconShadow = Color.cove(light: .init(r: 0.110, g: 0.173, b: 0.314, a: 0.22), dark: .init(r: 0, g: 0, b: 0, a: 0.45))
}

// MARK: - Text roles with Increase Contrast

/// Secondary and tertiary text, and hairlines. Under Increase Contrast,
/// the faint roles switch to full text so they pass 4.5:1 with margin.
/// Views read `@Environment(\.colorSchemeContrast)` and pass it in.
enum CoveText {
    static func secondary(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? CoveColor.text : CoveColor.text2
    }
    static func tertiary(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? CoveColor.text : CoveColor.text3
    }
    static func hairline(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? CoveColor.text.opacity(0.24) : CoveColor.hair
    }
}

// MARK: - Shape tokens (points)

enum CoveRadius {
    static let xs: CGFloat = 6        // keycaps
    static let sm: CGFloat = 10       // small tiles, theme thumbnails
    static let md: CGFloat = 14       // settings groups, quick panel rows
    static let row: CGFloat = 20      // search rows, top-hit lozenge, grid cell hover
    static let window: CGFloat = 26   // settings window
    static let panel: CGFloat = 28    // results panel, quick panel
    static let overlay: CGFloat = 32  // full-width panels

    /// App icons use 22.4% of their width as the corner radius.
    static func icon(_ size: CGFloat) -> CGFloat { size * 0.224 }
}

// MARK: - Spacing (points). Scale: 2, 4, 8, 12, 14, 16, 20, 24, 32, 44, 84

enum CoveSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let panelPad: CGFloat = 14
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
    static let xxxl: CGFloat = 44
    static let gridTop: CGFloat = 84
}

// MARK: - Sizes (points)

enum CoveSize {
    static let gridIcon: CGFloat = 72
    static let gridCell = CGSize(width: 144, height: 108)
    static let gridColumns = 7
    static let gridRowGap: CGFloat = 26
    /// Side padding around the grid. Not in the spec; kept from v0.1 until the 0.5 polish pass.
    static let gridSidePadding: CGFloat = 40
    /// Window width that fits every column plus side padding.
    static var gridWindowWidth: CGFloat {
        gridCell.width * CGFloat(gridColumns) + gridSidePadding * 2
    }

    static let searchField = CGSize(width: 500, height: 48)
    static let searchFieldFocusedWidth: CGFloat = 560
    static let categoryBarHeight: CGFloat = 36

    static let quickPanelWidth: CGFloat = 372
    static let quickIcon: CGFloat = 56
    static let dockIcon: CGFloat = 52
    static let rowIcon: CGFloat = 30

    static let hitTarget: CGFloat = 44
    static let settingsWindow = CGSize(width: 700, height: 520)
}

// MARK: - Type (SF Pro throughout; see spec section 7a)

/// SwiftUI has no 650 weight, so the spec's 650 becomes .semibold (600).
/// Hierarchy comes from size and weight, not color.
enum CoveFont {
    static let wordmark = Font.system(size: 26, weight: .semibold)  // Display
    static let title = Font.system(size: 20, weight: .semibold)     // Title
    static let headline = Font.system(size: 15, weight: .semibold)  // Headline: top hit and row titles
    static let subhead = Font.system(size: 14)                      // Subhead: page intros
    static let body = Font.system(size: 13)                         // Body
    static let section = Font.system(size: 13, weight: .semibold)  // Section label on the launcher
    static let caption = Font.system(size: 12)                      // Caption: paths, footers
    static let label = Font.system(size: 11, weight: .semibold)    // Label: use with textCase(.uppercase)
    static let search = Font.system(size: 18)                      // Launcher search input
    static let iconLabel = Font.system(size: 12, weight: .medium)  // One line under each icon
}

/// Tracking values from the spec, converted from em to points.
enum CoveTracking {
    static let display: CGFloat = -0.78  // -0.03em at 26 pt
    static let title: CGFloat = -0.4     // -0.02em at 20 pt
    static let label: CGFloat = 0.66     // 0.06em at 11 pt
}

// MARK: - Motion tokens

/// Each spring is `Spring(duration:bounce:)` (macOS 14+).
/// Bounce in, never out: `dismiss` has no bounce.
enum CoveMotion {
    /// Hover, selection move, focus ring
    static let snap = Spring(duration: 0.24, bounce: 0.0)
    /// Icon and button press, release overshoot
    static let press = Spring(duration: 0.26, bounce: 0.42)
    /// Full grid appears, icons ripple out from center
    static let open = Spring(duration: 0.46, bounce: 0.24)
    /// Search capsule melts into the results panel
    static let morph = Spring(duration: 0.52, bounce: 0.30)
    /// Quick panel rises out of the Dock icon
    static let rise = Spring(duration: 0.50, bounce: 0.32)
    /// Grid reflow when a search filters icons
    static let settle = Spring(duration: 0.60, bounce: 0.18)
    /// Anything closing. Never bounce on the way out
    static let dismiss = Spring(duration: 0.26, bounce: 0.0)
}

extension Animation {
    static var coveSnap: Animation { .spring(CoveMotion.snap) }
    static var covePress: Animation { .spring(CoveMotion.press) }
    static var coveOpen: Animation { .spring(CoveMotion.open) }
    static var coveMorph: Animation { .spring(CoveMotion.morph) }
    static var coveRise: Animation { .spring(CoveMotion.rise) }
    static var coveSettle: Animation { .spring(CoveMotion.settle) }
    static var coveDismiss: Animation { .spring(CoveMotion.dismiss) }

    /// For a drag release: carries the drag's speed into the rise spring (macOS 14+).
    static func coveRelease(velocity: Double) -> Animation {
        .interpolatingSpring(CoveMotion.rise, initialVelocity: velocity)
    }
}

// MARK: - Glass

/// Panel glass for text-bearing surfaces. Always tinted so text stays readable.
/// Under Reduce Transparency it becomes a solid fill and keeps the rim.
private struct CovePanelGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(CoveColor.gSolid)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(CoveColor.gEdge, lineWidth: 1)
                )
        } else {
            content.glassEffect(.regular.tint(CoveColor.gFill), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

/// Capsule glass for a single control (search field, category bar).
private struct CoveCapsuleGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let interactive: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Capsule().fill(CoveColor.gSolid))
                .overlay(Capsule().strokeBorder(CoveColor.gEdge, lineWidth: 1))
        } else {
            content.glassEffect(.regular.tint(CoveColor.cFill).interactive(interactive), in: .capsule)
        }
    }
}

extension View {
    /// Panel glass: search results, Files list, quick panel.
    func covePanelGlass(cornerRadius: CGFloat = CoveRadius.panel) -> some View {
        modifier(CovePanelGlass(cornerRadius: cornerRadius))
    }

    /// Capsule glass: search field, category bar, small toolbars.
    func coveCapsuleGlass(interactive: Bool = true) -> some View {
        modifier(CoveCapsuleGlass(interactive: interactive))
    }

    /// Selected lozenge: the one item Return will open. A gradient, not glass.
    func coveLozenge(cornerRadius: CGFloat = CoveRadius.row) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [CoveColor.selTop, CoveColor.selBot], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(CoveColor.selRing, lineWidth: 1)
                )
                .shadow(color: CoveColor.selShadow, radius: 9, y: 4)
        )
    }
}

// MARK: - Reduce Motion

/// Applies a Cove spring, or a 0.2 s fade when Reduce Motion is on.
/// Nothing bounces or moves in that case: the change crossfades.
private struct CoveAnimated<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}

extension View {
    /// Use this for every Cove animation instead of `.animation(_:value:)`.
    func coveAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(CoveAnimated(animation: animation, value: value))
    }
}
