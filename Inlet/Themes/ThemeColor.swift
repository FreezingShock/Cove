//
//  ThemeColor.swift
//  Inlet
//
//  Color math for themes: hex in and out, tinting by hue, and contrast.
//  Plain functions on numbers, so the tests need no window or AppKit.
//

import Foundation

enum ThemeColor {
    /// Red, green and blue, each 0...1.
    struct RGB: Equatable, Sendable {
        var r: Double
        var g: Double
        var b: Double
    }

    /// Reads "#RRGGBB", "RRGGBB" or the short "#RGB" form. Nil for anything else.
    static func parseHex(_ text: String) -> RGB? {
        var digits = text.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.allSatisfy({ $0.isHexDigit }) else { return nil }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return RGB(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    /// "#RRGGBB" in upper case.
    static func hex(_ color: RGB) -> String {
        func byte(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(color.r), byte(color.g), byte(color.b))
    }

    /// Hue in 0...1, saturation and brightness in 0...1.
    static func hsb(_ color: RGB) -> (hue: Double, saturation: Double, brightness: Double) {
        let top = max(color.r, color.g, color.b)
        let bottom = min(color.r, color.g, color.b)
        let span = top - bottom
        var hue = 0.0
        if span > 0 {
            if top == color.r {
                hue = (color.g - color.b) / span
            } else if top == color.g {
                hue = (color.b - color.r) / span + 2
            } else {
                hue = (color.r - color.g) / span + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let saturation = top > 0 ? span / top : 0
        return (hue, saturation, top)
    }

    /// The inverse of `hsb`.
    static func rgb(hue: Double, saturation: Double, brightness: Double) -> RGB {
        let h = (hue - floor(hue)) * 6
        let sector = Int(floor(h)) % 6
        let f = h - floor(h)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))
        switch sector {
        case 0: return RGB(r: brightness, g: t, b: p)
        case 1: return RGB(r: q, g: brightness, b: p)
        case 2: return RGB(r: p, g: brightness, b: t)
        case 3: return RGB(r: p, g: q, b: brightness)
        case 4: return RGB(r: t, g: p, b: brightness)
        default: return RGB(r: brightness, g: p, b: q)
        }
    }

    /// Keeps the base color's brightness and takes the tint's hue. Saturation
    /// scales with `strength`, so a light tint still gives a dark background
    /// in Dark mode. Strength 0 returns the base unchanged.
    static func tinted(_ base: RGB, toward tint: RGB, strength: Double) -> RGB {
        let amount = min(max(strength, 0), 1)
        guard amount > 0 else { return base }
        let target = hsb(tint)
        let source = hsb(base)
        return rgb(hue: target.hue, saturation: target.saturation * amount, brightness: source.brightness)
    }

    /// WCAG relative luminance: 0 for black, 1 for white.
    static func luminance(_ color: RGB) -> Double {
        func linear(_ x: Double) -> Double {
            x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    /// Whichever of white or near-black gives more contrast on `fill`.
    static func inkOn(_ fill: RGB) -> RGB {
        let l = luminance(fill)
        let withWhite = 1.05 / (l + 0.05)
        let withBlack = (l + 0.05) / 0.05
        return withWhite >= withBlack
            ? RGB(r: 1, g: 1, b: 1)
            : RGB(r: 0.020, g: 0.027, b: 0.047)
    }

    /// WCAG contrast ratio between two colors, from 1 to 21.
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
