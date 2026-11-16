//
//  OnboardingView.swift
//  Cove
//
//  The setup window's frame: the progress bars, the current screen, and the
//  footer with Back, Skip and Continue. The screens are in
//  OnboardingSteps.swift and OnboardingShortcutSteps.swift.
//

import SwiftUI

struct OnboardingView: View {
    /// The window's fixed size. Matches the Onboarding mockup's window.
    static let size = CGSize(width: 880, height: 620)

    let model: OnboardingModel
    /// Closes the window. Called by "Start using Cove".
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            progressBars
            content
            if model.step != .done {
                footer
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .covePanelGlass(cornerRadius: CoveRadius.window)
        .background { backdrop }
    }

    // MARK: Progress

    private var progressBars: some View {
        HStack(spacing: CoveSpace.xs) {
            ForEach(0..<OnboardingStep.barCount, id: \.self) { index in
                Capsule()
                    .fill(index <= model.step.rawValue ? CoveColor.accent : CoveColor.track)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, CoveSpace.xxxl)
        .padding(.top, CoveSpace.xxl)
        .coveAnimation(.coveOpen, value: model.step)
    }

    // MARK: Screens

    private var content: some View {
        ZStack(alignment: .top) {
            stepView(model.step)
                .id(model.step)
                .transition(stepTransition)
        }
        .padding(.horizontal, CoveSpace.xxxl)
        .padding(.top, CoveSpace.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .coveAnimation(.coveOpen, value: model.step)
    }

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStep()
        case .habit:
            HabitStep(model: model)
        case .access:
            AccessStep(model: model)
        case .shortcut:
            ShortcutStep(model: model)
        case .tryIt:
            TryStep(model: model)
        case .done:
            DoneStep(model: model, onChangeShortcut: { model.go(to: .shortcut) }, onStart: {
                model.finish()
                onClose()
            })
        }
    }

    /// Screens rise in with a small spring. Reduce Motion gets a plain crossfade.
    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 14))
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: CoveSpace.s) {
                if model.canGoBack {
                    Button("Back") { model.back() }
                        .buttonStyle(OnboardingButtonStyle(kind: .ghost))
                }
            }
            .frame(minWidth: 170, alignment: .leading)

            Spacer()

            HStack(spacing: CoveSpace.s) {
                if model.canSkip {
                    Button("Skip for now") { model.skipTry() }
                        .buttonStyle(OnboardingButtonStyle(kind: .ghost))
                }
                Button(model.continueTitle) { model.next() }
                    .buttonStyle(OnboardingButtonStyle(kind: .primary))
                    .disabled(!model.canContinue)
            }
            .frame(minWidth: 170, alignment: .trailing)
        }
        .padding(.horizontal, CoveSpace.section + CoveSpace.s)
        .frame(height: 88)
    }

    // MARK: Backdrop

    /// The glow behind the glass, from the theme's glow tokens. Glass needs
    /// something behind it to refract, or the window reads as flat grey.
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [CoveColor.base2, CoveColor.base], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [CoveColor.glowA, .clear], center: UnitPoint(x: 0.18, y: 0.14), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [CoveColor.glowB, .clear], center: UnitPoint(x: 0.88, y: 0.92), startRadius: 0, endRadius: 560)
            RadialGradient(colors: [CoveColor.glowC, .clear], center: UnitPoint(x: 0.6, y: 0.3), startRadius: 0, endRadius: 360)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoveRadius.window, style: .continuous))
    }
}

/// Primary is the ink-filled pill that moves the flow forward. Ghost is the
/// quiet text button beside it.
struct OnboardingButtonStyle: ButtonStyle {
    enum Kind {
        case primary, ghost
    }

    let kind: Kind

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(kind == .primary ? OnboardingInk.onInk : CoveColor.text2)
            .padding(.horizontal, kind == .primary ? 24 : 16)
            .frame(height: CoveSize.hitTarget)
            .background(kind == .primary ? CoveColor.text : Color.clear, in: Capsule())
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.covePress, value: configuration.isPressed)
    }
}
