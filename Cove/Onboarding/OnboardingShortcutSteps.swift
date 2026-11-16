//
//  OnboardingShortcutSteps.swift
//  Cove
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
                lead: "Press it from anywhere to open Cove. Choose what opens, how you press it, and which keys to use."
            )

            HStack(alignment: .top, spacing: CoveSpace.section) {
                VStack(alignment: .leading, spacing: CoveSpace.xl) {
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

                VStack(alignment: .leading, spacing: CoveSpace.xl) {
                    OnboardingFieldGroup(title: "Modifier keys") {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: CoveSpace.s), GridItem(.flexible(), spacing: CoveSpace.s)],
                            alignment: .leading,
                            spacing: CoveSpace.s
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
                            .font(CoveFont.body)
                            .foregroundStyle(CoveColor.text)
                            .padding(.horizontal, CoveSpace.l)
                            .padding(.vertical, CoveSpace.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CoveColor.cFill, in: RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous)
                                    .strokeBorder(OnboardingTint.amber, lineWidth: 1.5)
                            )
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    if !model.shortcutNote.isEmpty {
                        Text(model.shortcutNote)
                            .font(CoveFont.body)
                            .foregroundStyle(CoveColor.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, CoveSpace.xxl)
        }
        .coveAnimation(.coveOpen, value: model.modifiers.rawValue)
    }

    /// The keycaps and the sentence that reads them back, so the user sees the
    /// exact shortcut before pressing it.
    private var preview: some View {
        VStack(spacing: CoveSpace.l) {
            HStack(spacing: CoveSpace.s) {
                ForEach(model.keySymbols, id: \.self) { symbol in
                    Keycap(label: symbol)
                }
            }
            Text("\(model.hotkeyLabel) opens Cove")
                .font(CoveFont.body)
                .foregroundStyle(CoveColor.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CoveSpace.xl)
        .padding(.horizontal, CoveSpace.l)
        .background(CoveColor.field, in: RoundedRectangle(cornerRadius: CoveRadius.md + CoveSpace.s, style: .continuous))
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
        VStack(alignment: .leading, spacing: CoveSpace.s) {
            Text(title)
                .font(CoveFont.label)
                .textCase(.uppercase)
                .tracking(CoveTracking.label)
                .foregroundStyle(CoveColor.text2)
            content
            if let hint {
                Text(hint)
                    .font(CoveFont.body)
                    .foregroundStyle(CoveColor.text2)
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
            HStack(spacing: CoveSpace.s) {
                Text(modifier.symbol)
                    .font(.system(size: 17))
                Text(modifier.name)
                    .font(CoveFont.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? OnboardingInk.onInk : CoveColor.text)
            .padding(.horizontal, CoveSpace.m + CoveSpace.xxs)
            .frame(height: CoveSize.hitTarget - CoveSpace.xs)
            .background(isOn ? CoveColor.text : CoveColor.field, in: RoundedRectangle(cornerRadius: CoveRadius.md - CoveSpace.xs, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.md - CoveSpace.xs, style: .continuous)
                    .strokeBorder(CoveColor.hair, lineWidth: isOn ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .coveAnimation(.covePress, value: isOn)
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
            .foregroundStyle(CoveColor.text)
            .frame(minWidth: isWide ? 176 : 58, minHeight: 58)
            .padding(.horizontal, CoveSpace.l - CoveSpace.xxs)
            .background(
                LinearGradient(colors: [CoveColor.selTop, CoveColor.selBot], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(CoveColor.selRing, lineWidth: 1)
            )
            .shadow(color: CoveColor.selShadow, radius: 8, y: 6)
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
                lead: "Press \(model.hotkeyLabel) from anywhere. Cove opens right here, and you can type to search."
            )

            Text("Press \(model.hotkeyLabel) now")
                .font(CoveFont.headline)
                .foregroundStyle(CoveColor.text)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CoveColor.field, in: RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous)
                        .strokeBorder(OnboardingTint.teal, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
                .padding(.top, CoveSpace.xl)

            desk
                .padding(.top, CoveSpace.m)

            statusLine
                .padding(.top, CoveSpace.m)

            Button(model.deskOpen ? "Close Cove" : "Open with a click instead") {
                model.toggleDeskFromButton()
            }
            .buttonStyle(OnboardingButtonStyle(kind: .ghost))
            .padding(.top, CoveSpace.xs)
        }
        .coveAnimation(.coveOpen, value: model.deskOpen)
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
                    Text("Cove is closed")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Press \(model.hotkeyLabel) to open it.")
                        .font(CoveFont.body)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            dock
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, CoveSpace.s)
        }
        .frame(height: 236)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CoveRadius.md + CoveSpace.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.md + CoveSpace.s, style: .continuous)
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
        VStack(spacing: CoveSpace.m) {
            TextField("Search apps and files", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .padding(.horizontal, CoveSpace.l - CoveSpace.xxs)
                .frame(height: 38)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .onKeyPress(.escape) {
                    model.closeDesk()
                    return .handled
                }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: CoveSpace.s + CoveSpace.xxs), count: columns),
                spacing: CoveSpace.s + CoveSpace.xxs
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
                    .font(CoveFont.subhead)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, CoveSpace.xl)
            }
        }
        .padding(CoveSpace.panelPad)
        .frame(width: width)
        .background {
            // A dark glass sheet over the desk. The desk is dark in both modes,
            // so this does not follow the theme's light glass.
            let shape = RoundedRectangle(cornerRadius: CoveRadius.md + CoveSpace.s, style: .continuous)
            shape
                .fill(Color(white: 0.05, opacity: 0.5))
                .overlay(
                    shape.fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.md + CoveSpace.s, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .onAppear {
            searchFocused = true
        }
    }

    /// Decorative: the dock is drawn so the desk reads as a Mac, not a box.
    private var dock: some View {
        HStack(spacing: CoveSpace.s) {
            ForEach(Array(OnboardingSampleApp.all.prefix(5))) { app in
                OnboardingAppTile(app: app, size: 28)
            }
        }
        .padding(.horizontal, CoveSpace.m)
        .padding(.vertical, 6)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: CoveRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: Status

    @ViewBuilder
    private var statusLine: some View {
        if model.tried {
            Text("**That’s it.** The shortcut opened Cove. \(model.tryNote)")
                .font(CoveFont.subhead)
                .foregroundStyle(CoveColor.text2)
        } else {
            Text("Nothing yet. Press \(model.hotkeyLabel) to try it.")
                .font(CoveFont.subhead)
                .foregroundStyle(CoveColor.text2)
        }
    }
}
