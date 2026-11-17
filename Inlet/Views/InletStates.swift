//
//  InletStates.swift
//  Inlet
//
//  Shared views for the states where there is nothing to show: a loading
//  line, an empty list, a failed or blocked step. Every one is a symbol, a
//  short title, one line of help and an optional action, so each "nothing
//  here" moment reads the same. Colors and type come from InletTheme.
//

import SwiftUI

/// A centred message for an empty or blocked state.
///
/// Use it where the grid or a list has nothing to draw. Give it an action only
/// when the user can actually fix the problem from here (Rescan, Clear Search,
/// Open Login Items). Otherwise the message is enough.
struct InletStateView: View {
    /// An SF Symbol shown in a soft tile above the title.
    let symbol: String
    /// One short line, such as "No apps found".
    let title: String
    /// What happened and what to do about it. Kept to one or two sentences.
    let message: String
    /// The label of the optional action button. Nil hides the button.
    var actionTitle: String? = nil
    /// Runs when the action button is tapped.
    var action: (() -> Void)? = nil

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: InletSpace.m) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(InletText.secondary(contrast))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: InletRadius.lg, style: .continuous)
                        .fill(InletColor.hover)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(InletFont.headline)
                .foregroundStyle(InletColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)

            Text(message)
                .font(InletFont.body)
                .foregroundStyle(InletText.secondary(contrast))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(InletAccentButtonStyle())
                    .padding(.top, InletSpace.xs)
            }
        }
        .padding(InletSpace.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// A small spinner with a caption, for work that is still running.
///
/// It stays centred in the grid area so the first scan never looks like a
/// blank window.
struct InletLoadingView: View {
    /// What is running, in the present tense, such as "Finding your apps…".
    let message: String

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: InletSpace.m) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(InletFont.caption)
                .foregroundStyle(InletText.secondary(contrast))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
