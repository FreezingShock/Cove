//
//  ThemeRuntime.swift
//  Inlet
//
//  The theme the tokens draw with right now. `ThemeStore` sets it when the
//  user picks or edits a theme, and `loadFromDefaults` sets it at launch.
//  The color tokens in InletTheme.swift read it each time they draw.
//

import SwiftUI

/// The part a generated color plays in a theme. Only these change with a theme.
enum ThemeRole {
    case background, glass, veil, accent, accentInk, accentSoft
}

enum ThemeRuntime {
    /// The theme in use. Inlet's own look until a Supporter picks another.
    static var current = AppTheme.standard

    /// Reads the saved choice at launch, before any window opens.
    static func loadFromDefaults(_ defaults: UserDefaults = .standard) {
        let selected = defaults.string(forKey: InletSettings.Key.activeTheme.rawValue) ?? AppTheme.standard.id
        current = AppTheme.effective(
            selectedID: selected,
            custom: AppTheme.savedThemes(in: defaults),
            supporter: Supporter.isOn(in: defaults)
        )
    }

    // MARK: Colors

    /// The custom accent, if the theme sets one.
    static var customAccent: ThemeColor.RGB? {
        current.accentHex.flatMap { ThemeColor.parseHex($0) }
    }

    /// A background token, tinted toward the theme's color.
    static func background(_ color: RGBA) -> RGBA {
        guard let tint = current.tintHex.flatMap({ ThemeColor.parseHex($0) }) else { return color }
        let mixed = ThemeColor.tinted(
            ThemeColor.RGB(r: color.r, g: color.g, b: color.b),
            toward: tint,
            strength: current.tintStrength
        )
        return RGBA(r: mixed.r, g: mixed.g, b: mixed.b, a: color.a)
    }

    /// A glass token. Keeps its color and scales its alpha by the glass setting.
    /// Inlet's default is 0.5, which leaves the alpha as designed.
    static func glass(_ color: RGBA) -> RGBA {
        let factor = current.glassIntensity / 0.5
        return RGBA(r: color.r, g: color.g, b: color.b, a: min(color.a * factor, 0.95))
    }

    /// The scrim behind the grid. Scales its alpha by the backdrop setting.
    static func veil(_ color: RGBA) -> RGBA {
        let factor = current.backdropVeil / 0.5
        return RGBA(r: color.r, g: color.g, b: color.b, a: min(color.a * factor, 0.9))
    }

    /// Builds a generated color token for the role it plays. The generator
    /// (scripts/build-tokens.py) writes a call here for each themable token,
    /// so the light and dark values stay in design/tokens.json.
    static func color(_ role: ThemeRole, light: RGBA, dark: RGBA) -> Color {
        switch role {
        case .background:
            return Color.inlet(light: background(light), dark: background(dark))
        case .glass:
            return Color.inlet(light: glass(light), dark: glass(dark))
        case .veil:
            return Color.inlet(light: veil(light), dark: veil(dark))
        case .accent, .accentInk, .accentSoft:
            guard let custom = customAccent else {
                return Color.inlet(light: light, dark: dark)
            }
            switch role {
            case .accent:
                return Color(red: custom.r, green: custom.g, blue: custom.b)
            case .accentInk:
                let ink = ThemeColor.inkOn(custom)
                return Color(red: ink.r, green: ink.g, blue: ink.b)
            default:
                return Color(red: custom.r, green: custom.g, blue: custom.b, opacity: 0.15)
            }
        }
    }

    // MARK: Sizes and labels

    /// Artwork size for each icon, in points.
    static var iconSize: CGFloat {
        CGFloat(min(max(current.iconSize, AppTheme.Limits.iconSize.lowerBound), AppTheme.Limits.iconSize.upperBound))
    }

    static var showsLabels: Bool { current.labelStyle != .hidden }

    static var labelFont: Font {
        current.labelStyle == .compact ? .system(size: 11, weight: .medium) : InletFont.iconLabel
    }
}
