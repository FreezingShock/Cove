//
//  OnboardingGroupsStep.swift
//  Inlet
//
//  Step 3: choose which of the six preset groups start on. Each card shows
//  the group's color and icon, as it looks on the group bar, and how many
//  installed apps it would hold.
//

import SwiftUI

struct GroupsStep: View {
    let model: OnboardingModel

    private let columns = [
        GridItem(.flexible(), spacing: InletSpace.m),
        GridItem(.flexible(), spacing: InletSpace.m),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                eyebrow: "Step 3 of 5",
                title: "Choose your groups",
                lead: "Groups are the tabs above the grid. Apps sort themselves into the groups you keep on. Turn off any you don’t want to start with."
            )

            LazyVGrid(columns: columns, spacing: InletSpace.m) {
                ForEach(AppGroup.presets) { preset in
                    GroupChoiceCard(
                        preset: preset,
                        isOn: model.presetChoices.contains(preset.suggestedCategory ?? .other),
                        appCount: model.appCount(in: preset.suggestedCategory ?? .other),
                        toggle: { model.togglePreset(preset.suggestedCategory ?? .other) }
                    )
                }
            }
            .padding(.top, InletSpace.xxl)

            footnote
                .padding(.top, InletSpace.l)
        }
        .inletAnimation(.inletPress, value: model.presetChoices)
    }

    /// Explains the rules under the cards: what happens when a group is off,
    /// and why Continue is blocked when none is on.
    @ViewBuilder
    private var footnote: some View {
        if model.presetChoices.isEmpty {
            Text("Keep at least one group on. Inlet needs a group to put your apps in.")
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
        } else {
            Text("Apps from a group you turn off move to Other. You can add, rename or delete groups later from the Groups panel.")
                .font(InletFont.body)
                .foregroundStyle(InletColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One preset group. A tap turns it on or off. The card keeps the same
/// shape either way, so the grid does not jump.
private struct GroupChoiceCard: View {
    let preset: AppGroup
    let isOn: Bool
    let appCount: Int
    let toggle: () -> Void

    private var category: AppCategory { preset.suggestedCategory ?? .other }

    var body: some View {
        Button(action: toggle) {
            OnboardingCard(isOn: isOn, tint: preset.color.color) {
                HStack(alignment: .center, spacing: InletSpace.l) {
                    OnboardingIconTile(systemName: preset.symbol, tint: preset.color.color)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(InletFont.headline)
                            .foregroundStyle(InletColor.text)
                        Text(detail)
                            .font(InletFont.body)
                            .foregroundStyle(InletColor.text2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    OnboardingCheck(isOn: isOn)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title) group")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var detail: String {
        if !isOn { return "Off. Its apps move to Other." }
        switch appCount {
        case 0: return "On. No apps yet."
        case 1: return "On. 1 app."
        default: return "On. \(appCount) apps."
        }
    }
}

/// The square check on a group card: outlined when off, filled with a tick when on.
private struct OnboardingCheck: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isOn ? InletColor.text : InletColor.text3, lineWidth: 1.5)
            if isOn {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(InletColor.text)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(OnboardingInk.onInk)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
