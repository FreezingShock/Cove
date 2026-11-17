//
//  InletControls.swift
//  Inlet
//
//  Shared control styles, so every button and row in the app shows the same
//  hover, press and focus states. All colors and motion come from InletTheme,
//  which is generated from design/tokens.json.
//

import SwiftUI

// MARK: - Accent button

/// The accent-filled button used for actions inside glass: Restore, Undo,
/// Show All Apps. Accent is the fill and `accentInk` is the text, never the
/// other way round. Hover steps the fill darker (Light) or brighter (Dark),
/// press sinks it to 96% with the press spring, and disabled fades it.
/// Under Reduce Motion nothing scales.
struct InletAccentButtonStyle: ButtonStyle {
    /// Nil gives a capsule, the default for compact actions.
    var cornerRadius: CGFloat? = nil
    /// Stretches the label across the width it is given.
    var fillsWidth = false
    /// A fixed height for a large button. Nil keeps the compact, padded size.
    var height: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        InletAccentButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            fillsWidth: fillsWidth,
            height: height
        )
    }
}

private struct InletAccentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat?
    let fillsWidth: Bool
    let height: CGFloat?

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        if configuration.isPressed { return InletColor.accentPressed }
        return isHovered ? InletColor.accentHover : InletColor.accent
    }

    private var shape: AnyShape {
        if let cornerRadius {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        return AnyShape(Capsule())
    }

    var body: some View {
        configuration.label
            .font(InletFont.section)
            .foregroundStyle(InletColor.accentInk)
            .padding(.horizontal, InletSpace.l)
            .padding(.vertical, height == nil ? InletSpace.s : 0)
            .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil, minHeight: height, maxHeight: height)
            .background(shape.fill(fill))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.38)
            .onHover { isHovered = $0 }
            .inletAnimation(.inletSnap, value: isHovered)
            .inletAnimation(.inletPress, value: configuration.isPressed)
    }
}

// MARK: - Row and tile button

/// A plain button that draws a row, tile or segment: a hover fill when the
/// pointer is over it, a stronger press fill while the mouse is down. The
/// label keeps its own content and selection. Under Reduce Motion the fills
/// change without any movement.
struct InletRowButtonStyle: ButtonStyle {
    /// The corner of the hover and press fill. Match the content's shape.
    var cornerRadius: CGFloat = InletRadius.row

    func makeBody(configuration: Configuration) -> some View {
        InletRowButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct InletRowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fill: Color {
        if configuration.isPressed { return InletColor.pressed }
        return isHovered ? InletColor.hover : Color.clear
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .onHover { isHovered = $0 }
            .inletAnimation(.inletSnap, value: isHovered)
            .inletAnimation(.inletPress, value: configuration.isPressed)
    }
}

// MARK: - Keyboard focus

extension View {
    /// The 2 pt focus ring for keyboard focus (T3.5). It uses `focus`, not the
    /// accent, so it stays visible on cream.
    func inletFocusRing(_ isFocused: Bool, cornerRadius: CGFloat = InletRadius.row) -> some View {
        overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(InletColor.focus, lineWidth: 2)
            }
        }
    }
}
