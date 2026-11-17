//
//  OnboardingSteps.swift
//  Inlet
//
//  The welcome, habit, permissions and summary screens, and the small pieces
//  they share (heading, icon tile, option card, app tile). The shortcut and
//  try-it screens are in OnboardingShortcutSteps.swift.
//

import AppKit
import SwiftUI

// MARK: - Shared pieces

/// Ink for text on a filled control: white in light mode, the base color in dark mode.
enum OnboardingInk {
    static let onInk = Color.inlet(light: .init(r: 1, g: 1, b: 1), dark: .init(r: 0.020, g: 0.027, b: 0.047))
    static let glyph = Color.onboardingHex(0x0B111C)
}

/// Step tints. The mockup gives each card its own fill; these are not theme
/// tokens, so they are kept here rather than in InletTheme.swift.
enum OnboardingTint {
    static let teal = Color.onboardingHex(0x46E6D6)
    static let blue = Color.onboardingHex(0x7AA2FF)
    static let coral = Color.onboardingHex(0xFF9A7A)
    static let amber = Color.onboardingHex(0xFFC85C)
    static let pink = Color.onboardingHex(0xFF8FC2)
    static let green = Color.onboardingHex(0x7BE495)
}

/// The eyebrow, title and optional lead that open every screen.
struct OnboardingHeader: View {
    let eyebrow: String?
    let title: String
    let lead: String?
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 0) {
            if let eyebrow {
                Text(eyebrow)
                    .font(InletFont.label)
                    .textCase(.uppercase)
                    .tracking(InletTracking.label)
                    .foregroundStyle(InletColor.text2)
                    .padding(.bottom, InletSpace.s)
            }
            Text(title)
                .font(InletFont.wordmark)
                .tracking(InletTracking.display)
                .foregroundStyle(InletColor.text)
                .multilineTextAlignment(centered ? .center : .leading)
            if let lead {
                Text(lead)
                    .font(InletFont.subhead)
                    .foregroundStyle(InletColor.text2)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .frame(maxWidth: 560, alignment: centered ? .center : .leading)
                    .padding(.top, InletSpace.s)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// A square tile with a white-on-tint SF Symbol, the icon style used on every option.
struct OnboardingIconTile: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(OnboardingInk.glyph)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: InletRadius.icon(size), style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A selectable card: a gradient lozenge when on, with a tinted inner ring.
struct OnboardingCard<Content: View>: View {
    let isOn: Bool
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(InletSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                if isOn {
                    shape.fill(LinearGradient(colors: [InletColor.selTop, InletColor.selBot], startPoint: .top, endPoint: .bottom))
                } else {
                    shape.fill(InletColor.field)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                    .strokeBorder(tint, lineWidth: 2)
                    .opacity(isOn ? 1 : 0)
            }
            .inletAnimation(.inletPress, value: isOn)
    }
}

/// The round radio mark on a habit card.
struct OnboardingRadio: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? InletColor.text : InletColor.text3, lineWidth: 1.5)
            if isOn {
                Circle()
                    .fill(InletColor.text)
                    .padding(5)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

/// A sample app tile for the welcome row and the practice desk.
struct OnboardingAppTile: View {
    let app: OnboardingSampleApp
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: app.symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [app.top, app.bottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

// MARK: - Step 0: welcome

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                .accessibilityHidden(true)

            OnboardingHeader(
                eyebrow: "Let’s get you set up",
                title: "Welcome to Inlet",
                lead: "Every app on your Mac in one searchable grid, opened with a shortcut from anywhere. It takes about a minute.",
                centered: true
            )
            .padding(.top, InletSpace.xl)

            HStack(spacing: InletSpace.m) {
                ForEach(OnboardingSampleApp.all) { app in
                    OnboardingAppTile(app: app)
                }
            }
            .padding(.top, 30)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 1: habit

struct HabitStep: View {
    let model: OnboardingModel

    private struct Option: Identifiable {
        let habit: OnboardingHabit
        let title: String
        let detail: String
        let symbol: String
        let tint: Color
        var id: OnboardingHabit { habit }
    }

    private let options: [Option] = [
        Option(habit: .spotlight, title: "Spotlight", detail: "I press ⌘ Space and type the name", symbol: "magnifyingglass", tint: OnboardingTint.amber),
        Option(habit: .dock, title: "The Dock", detail: "I click app icons along the bottom", symbol: "dock.rectangle", tint: OnboardingTint.blue),
        Option(habit: .launchpad, title: "Launchpad", detail: "I miss the old grid of icons", symbol: "square.grid.2x2", tint: OnboardingTint.pink),
        Option(habit: .finder, title: "Finder", detail: "I dig through the Applications folder", symbol: "folder", tint: OnboardingTint.green),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                eyebrow: "Step 1 of 4",
                title: "How do you open apps today?",
                lead: "This sets the shortcut we suggest later. You can change everything in Settings."
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: InletSpace.m), GridItem(.flexible(), spacing: InletSpace.m)],
                spacing: InletSpace.m
            ) {
                ForEach(options) { option in
                    let isOn = model.habit == option.habit
                    Button {
                        model.pick(option.habit)
                    } label: {
                        OnboardingCard(isOn: isOn, tint: option.tint) {
                            HStack(alignment: .center, spacing: InletSpace.l) {
                                OnboardingIconTile(systemName: option.symbol, tint: option.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .font(InletFont.headline)
                                        .foregroundStyle(InletColor.text)
                                    Text(option.detail)
                                        .font(InletFont.body)
                                        .foregroundStyle(InletColor.text2)
                                }
                                Spacer(minLength: 0)
                                OnboardingRadio(isOn: isOn)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.top, InletSpace.xxl)
        }
    }
}

// MARK: - Step 2: permissions

struct AccessStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                eyebrow: "Step 2 of 4",
                title: "Two optional permissions",
                lead: "Inlet works without either one. Each makes it more useful, and you can change both later in System Settings."
            )

            VStack(spacing: InletSpace.m) {
                AccessRow(
                    symbol: "folder",
                    tint: OnboardingTint.coral,
                    title: "Files and Folders",
                    detail: "Find documents in Desktop, Documents and Downloads. Spotlight does the search, and Inlet only reads the results.",
                    isOn: Binding(get: { model.includeFiles }, set: { model.setIncludeFiles($0) })
                )
                AccessRow(
                    symbol: "power",
                    tint: OnboardingTint.teal,
                    title: "Open at Login",
                    detail: "Have Inlet ready the moment you sign in. You can turn this off in Login Items.",
                    isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) })
                )
            }
            .padding(.top, InletSpace.xxl)

            if let loginError = model.loginError {
                Text(loginError)
                    .font(InletFont.body)
                    .foregroundStyle(InletColor.text)
                    .padding(.horizontal, InletSpace.l)
                    .padding(.vertical, InletSpace.m)
                    .background(InletColor.cFill, in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                            .strokeBorder(OnboardingTint.amber, lineWidth: 1.5)
                    )
                    .padding(.top, InletSpace.l)
            }

            HStack(spacing: InletSpace.s) {
                OnboardingIconTile(systemName: "lock.fill", tint: OnboardingTint.green, size: 24)
                Text("The only network call Inlet makes is an optional update check.")
                    .font(InletFont.body)
                    .foregroundStyle(InletColor.text)
            }
            .padding(.leading, InletSpace.s)
            .padding(.trailing, InletSpace.l)
            .padding(.vertical, InletSpace.s)
            .background(InletColor.cFill, in: Capsule())
            .overlay(Capsule().strokeBorder(InletColor.hair, lineWidth: 1))
            .padding(.top, InletSpace.xl)
        }
    }
}

/// One permission: an icon, a short explanation, and a native switch.
private struct AccessRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .center, spacing: InletSpace.l) {
            OnboardingIconTile(systemName: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(InletFont.headline)
                    .foregroundStyle(InletColor.text)
                Text(detail)
                    .font(InletFont.body)
                    .foregroundStyle(InletColor.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: InletSpace.l)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(InletColor.accent)
        }
        .padding(InletSpace.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InletColor.field, in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
    }
}

// MARK: - Summary (after the try step)

struct DoneStep: View {
    let model: OnboardingModel
    let onChangeShortcut: () -> Void
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(InletColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(InletColor.accentInk)
            }
            .frame(width: 74, height: 74)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)

            OnboardingHeader(
                eyebrow: "All set",
                title: "Inlet is ready",
                lead: "Press \(model.hotkeyLabel) from anywhere to open it. Here is what you chose.",
                centered: true
            )
            .padding(.top, InletSpace.xl)

            summaryCard
                .padding(.top, InletSpace.xxl)

            HStack(spacing: InletSpace.m) {
                Button("Change shortcut", action: onChangeShortcut)
                    .buttonStyle(OnboardingButtonStyle(kind: .ghost))
                Button("Start using Inlet", action: onStart)
                    .buttonStyle(OnboardingButtonStyle(kind: .primary))
            }
            .padding(.top, InletSpace.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, InletSpace.xxxl)
        .padding(.top, InletSpace.xxl)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .inletOpen) {
                appeared = true
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.summaryRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(InletColor.hair)
                        .frame(height: 1)
                }
                HStack {
                    Text(row.label)
                        .foregroundStyle(InletColor.text2)
                    Spacer()
                    Text(row.value)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(InletColor.text)
                }
                .font(InletFont.subhead)
                .padding(.horizontal, InletSpace.xl)
                .padding(.vertical, 11)
            }
        }
        .frame(width: 460)
        .background(InletColor.field, in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
    }
}
