//
//  OnboardingShortcutSteps.swift
//  Inlet
//
//  The shortcut builder (step 3) and the live try-it desk (step 4). The desk
//  opens from the real global hotkey, because the model borrows
//  HotkeyManager's handlers while this step is on screen.
//

import KeyboardShortcuts
import SwiftUI

// MARK: - Step 3: shortcut builder

struct ShortcutStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                eyebrow: "Step 3 of 4",
                title: "Pick your shortcut",
                lead: "Press it from anywhere to open Inlet. Choose what opens, how you press it, and which keys to use."
            )

            HStack(alignment: .top, spacing: InletSpace.section) {
                VStack(alignment: .leading, spacing: InletSpace.xl) {
                    OnboardingFieldGroup(title: "Opens", hint: model.surface.hint) {
                        Picker("What opens", selection: $model.surface) {
                            ForEach(OnboardingSurface.allCases) { surface in
                                Text(surface.label).tag(surface)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    OnboardingFieldGroup(title: "Press", hint: model.press.hint) {
                        Picker("How you press it", selection: $model.press) {
                            ForEach(OnboardingPress.allCases) { press in
                                Text(press.label).tag(press)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                .frame(width: 270)

                VStack(alignment: .leading, spacing: InletSpace.xl) {
                    OnboardingFieldGroup(title: "Modifier keys") {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: InletSpace.s), GridItem(.flexible(), spacing: InletSpace.s)],
                            alignment: .leading,
                            spacing: InletSpace.s
                        ) {
                            ForEach(OnboardingModifier.all) { modifier in
                                ModifierChip(
                                    modifier: modifier,
                                    isOn: model.modifiers.contains(modifier.flag),
                                    toggle: { model.modifiers.formSymmetricDifference(modifier.flag) }
                                )
                            }
                        }
                    }

                    OnboardingFieldGroup(title: "Key") {
                        Picker("Key", selection: $model.key) {
                            ForEach(OnboardingKey.allCases) { key in
                                Text(key.label).tag(key)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    preview

                    if let message = model.shortcutBlock ?? model.shortcutWarning {
                        Text(message)
                            .font(InletFont.body)
                            .foregroundStyle(InletColor.text)
                            .padding(.horizontal, InletSpace.l)
                            .padding(.vertical, InletSpace.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(InletColor.cFill, in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                                    .strokeBorder(OnboardingTint.amber, lineWidth: 1.5)
                            )
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    if !model.shortcutNote.isEmpty {
                        Text(model.shortcutNote)
                            .font(InletFont.body)
                            .foregroundStyle(InletColor.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, InletSpace.xxl)
        }
        .inletAnimation(.inletOpen, value: model.modifiers.rawValue)
    }

    /// The keycaps and the sentence that reads them back, so the user sees the
    /// exact shortcut before pressing it.
    private var preview: some View {
        VStack(spacing: InletSpace.l) {
            HStack(spacing: InletSpace.s) {
                ForEach(model.keySymbols, id: \.self) { symbol in
                    Keycap(label: symbol)
                }
            }
            Text("\(model.hotkeyLabel) opens Inlet")
                .font(InletFont.body)
                .foregroundStyle(InletColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, InletSpace.xl)
        .padding(.horizontal, InletSpace.l)
        .background(InletColor.field, in: RoundedRectangle(cornerRadius: InletRadius.md + InletSpace.s, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shortcut preview: \(model.hotkeyLabel)")
    }
}

/// A heading, an optional hint under the control, and the control itself.
private struct OnboardingFieldGroup<Content: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: InletSpace.s) {
            Text(title)
                .font(InletFont.label)
                .textCase(.uppercase)
                .tracking(InletTracking.label)
                .foregroundStyle(InletColor.text2)
            content
            if let hint {
                Text(hint)
                    .font(InletFont.body)
                    .foregroundStyle(InletColor.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A modifier toggle. On is ink-filled, the same as a selected segment.
private struct ModifierChip: View {
    let modifier: OnboardingModifier
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: InletSpace.s) {
                Text(modifier.symbol)
                    .font(.system(size: 17))
                Text(modifier.name)
                    .font(InletFont.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? OnboardingInk.onInk : InletColor.text)
            .padding(.horizontal, InletSpace.m + InletSpace.xxs)
            .frame(height: InletSize.hitTarget - InletSpace.xs)
            .background(isOn ? InletColor.text : InletColor.field, in: RoundedRectangle(cornerRadius: InletRadius.md - InletSpace.xs, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: InletRadius.md - InletSpace.xs, style: .continuous)
                    .strokeBorder(InletColor.hair, lineWidth: isOn ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .inletAnimation(.inletPress, value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(modifier.name)
    }
}

/// One key on the keycap row. The Space bar is drawn wider.
private struct Keycap: View {
    let label: String

    private var isWide: Bool { label == "Space" }

    var body: some View {
        Text(label)
            .font(.system(size: isWide ? 18 : 24, weight: .semibold))
            .foregroundStyle(InletColor.text)
            .frame(minWidth: isWide ? 176 : 58, minHeight: 58)
            .padding(.horizontal, InletSpace.l - InletSpace.xxs)
            .background(
                LinearGradient(colors: [InletColor.selTop, InletColor.selBot], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                    .strokeBorder(InletColor.selRing, lineWidth: 1)
            )
            .shadow(color: InletColor.selShadow, radius: 8, y: 6)
    }
}

// MARK: - Step 4: try it

struct TryStep: View {
    @Bindable var model: OnboardingModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                eyebrow: "Step 4 of 4",
                title: "Try it out",
                lead: "Press \(model.hotkeyLabel) from anywhere. Inlet opens right here, and you can type to search."
            )

            Text("Press \(model.hotkeyLabel) now")
                .font(InletFont.headline)
                .foregroundStyle(InletColor.text)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(InletColor.field, in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous)
                        .strokeBorder(OnboardingTint.teal, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
                .padding(.top, InletSpace.xl)

            desk
                .padding(.top, InletSpace.m)

            statusLine
                .padding(.top, InletSpace.m)

            Button(model.deskOpen ? "Close Inlet" : "Open with a click instead") {
                model.toggleDeskFromButton()
            }
            .buttonStyle(OnboardingButtonStyle(kind: .ghost))
            .padding(.top, InletSpace.xs)
        }
        .inletAnimation(.inletOpen, value: model.deskOpen)
    }

    // MARK: Desk

    private var desk: some View {
        ZStack(alignment: .top) {
            deskBackground

            if model.deskOpen {
                panel
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 4) {
                    Text("Inlet is closed")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Press \(model.hotkeyLabel) to open it.")
                        .font(InletFont.body)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            dock
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, InletSpace.s)
        }
        .frame(height: 236)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: InletRadius.md + InletSpace.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: InletRadius.md + InletSpace.s, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Practice desktop")
    }

    private var deskBackground: some View {
        ZStack {
            LinearGradient(colors: [Color.onboardingHex(0x2A3A5C), Color.onboardingHex(0x0E1626)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [OnboardingTint.teal.opacity(0.6), .clear], center: UnitPoint(x: 0.14, y: 0.18), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [OnboardingTint.blue.opacity(0.55), .clear], center: UnitPoint(x: 0.88, y: 0.88), startRadius: 0, endRadius: 280)
        }
    }

    /// Grid and quick panel look different, as they do in the app. Both use the
    /// same search field and filter the same sample apps.
    @ViewBuilder
    private var panel: some View {
        switch model.surface {
        case .grid:
            searchPanel(width: 600, columns: 8, apps: shownApps)
                .padding(.top, 14)
        case .quick:
            searchPanel(width: 330, columns: 4, apps: Array(shownApps.prefix(4)))
                .padding(.bottom, 58)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var shownApps: [OnboardingSampleApp] {
        let query = model.query.trimmingCharacters(in: .whitespaces).lowercased()
        return OnboardingSampleApp.all.filter { query.isEmpty || $0.name.lowercased().contains(query) }
    }

    private func searchPanel(width: CGFloat, columns: Int, apps: [OnboardingSampleApp]) -> some View {
        VStack(spacing: InletSpace.m) {
            TextField("Search apps and files", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .padding(.horizontal, InletSpace.l - InletSpace.xxs)
                .frame(height: 38)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: InletRadius.sm, style: .continuous))
                .onKeyPress(.escape) {
                    model.closeDesk()
                    return .handled
                }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: InletSpace.s + InletSpace.xxs), count: columns),
                spacing: InletSpace.s + InletSpace.xxs
            ) {
                ForEach(apps) { app in
                    VStack(spacing: 6) {
                        OnboardingAppTile(app: app, size: 46)
                        Text(app.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                }
            }

            if apps.isEmpty {
                Text("No apps or files match “\(model.query)”.")
                    .font(InletFont.subhead)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, InletSpace.xl)
            }
        }
        .padding(InletSpace.panelPad)
        .frame(width: width)
        .background {
            // A dark glass sheet over the desk. The desk is dark in both modes,
            // so this does not follow the theme's light glass.
            let shape = RoundedRectangle(cornerRadius: InletRadius.md + InletSpace.s, style: .continuous)
            shape
                .fill(Color(white: 0.05, opacity: 0.5))
                .overlay(
                    shape.fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: InletRadius.md + InletSpace.s, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .onAppear {
            searchFocused = true
        }
    }

    /// Decorative: the dock is drawn so the desk reads as a Mac, not a box.
    private var dock: some View {
        HStack(spacing: InletSpace.s) {
            ForEach(Array(OnboardingSampleApp.all.prefix(5))) { app in
                OnboardingAppTile(app: app, size: 28)
            }
        }
        .padding(.horizontal, InletSpace.m)
        .padding(.vertical, 6)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: InletRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: Status

    @ViewBuilder
    private var statusLine: some View {
        if model.tried {
            Text("**That’s it.** The shortcut opened Inlet. \(model.tryNote)")
                .font(InletFont.subhead)
                .foregroundStyle(InletColor.text2)
        } else {
            Text("Nothing yet. Press \(model.hotkeyLabel) to try it.")
                .font(InletFont.subhead)
                .foregroundStyle(InletColor.text2)
        }
    }
}
