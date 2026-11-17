//
//  OnboardingView.swift
//  Inlet
//
//  The setup window's frame: the progress bars, the current screen, and the
//  footer with Back, Skip and Continue. The screens are in
//  OnboardingSteps.swift, OnboardingGroupsStep.swift and
//  OnboardingShortcutSteps.swift.
//

import SwiftUI

struct OnboardingView: View {
    /// The window's fixed size. Matches the Onboarding mockup's window.
    static let size = CGSize(width: 880, height: 620)

    let model: OnboardingModel
    /// Closes the window. Called by "Start using Inlet".
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
        .inletPanelGlass(cornerRadius: InletRadius.window)
        .background { backdrop }
    }

    // MARK: Progress

    private var progressBars: some View {
        HStack(spacing: InletSpace.xs) {
            ForEach(0..<OnboardingStep.barCount, id: \.self) { index in
                Capsule()
                    .fill(index <= model.step.rawValue ? InletColor.focus : InletColor.track)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, InletSpace.xxxl)
        .padding(.top, InletSpace.xxl)
        .inletAnimation(.inletOpen, value: model.step)
    }

    // MARK: Screens

    private var content: some View {
        ZStack(alignment: .top) {
            stepView(model.step)
                .id(model.step)
                .transition(stepTransition)
        }
        .padding(.horizontal, InletSpace.xxxl)
        .padding(.top, InletSpace.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .inletAnimation(.inletOpen, value: model.step)
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
        case .groups:
            GroupsStep(model: model)
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
            HStack(spacing: InletSpace.s) {
                if model.canGoBack {
                    Button("Back") { model.back() }
                        .buttonStyle(OnboardingButtonStyle(kind: .ghost))
                }
            }
            .frame(minWidth: 170, alignment: .leading)

            Spacer()

            HStack(spacing: InletSpace.s) {
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
        .padding(.horizontal, InletSpace.section + InletSpace.s)
        .frame(height: 88)
    }

    // MARK: Backdrop

    /// The glow behind the glass, from the theme's glow tokens. Glass needs
    /// something behind it to refract, or the window reads as flat grey.
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [InletColor.base2, InletColor.base], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [InletColor.glowA, .clear], center: UnitPoint(x: 0.18, y: 0.14), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [InletColor.glowB, .clear], center: UnitPoint(x: 0.88, y: 0.92), startRadius: 0, endRadius: 560)
            RadialGradient(colors: [InletColor.glowC, .clear], center: UnitPoint(x: 0.6, y: 0.3), startRadius: 0, endRadius: 360)
        }
        .clipShape(RoundedRectangle(cornerRadius: InletRadius.window, style: .continuous))
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
            .font(InletFont.headline)
            .foregroundStyle(kind == .primary ? OnboardingInk.onInk : InletColor.text2)
            .padding(.horizontal, kind == .primary ? 24 : 16)
            .frame(height: InletSize.hitTarget)
            .background(kind == .primary ? InletColor.text : Color.clear, in: Capsule())
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.inletPress, value: configuration.isPressed)
    }
}
