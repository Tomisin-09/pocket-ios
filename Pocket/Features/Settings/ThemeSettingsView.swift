import SwiftUI

/// **Settings ▸ Appearance ▸ Theme** (ADR 0311 D7): the eight moon themes as cards, each drawing that
/// theme's own *Start* button, a strip of waveform and the mastery dots, on the cream canvas and the
/// near-black one side by side. It shows the theme rather than a swatch that names it, and someone on
/// *System* sees both appearances in a day, so the screen doesn't repeat the Light/Dark control.
///
/// **Tapping a card applies it at once**, and the screen recolours around you: there is no Save.
///
/// **The themes are part of the plan** (ADR 0312 D1). The screen is open to everyone, because its cards
/// are what the plan would bring. Blood Moon is free; another theme, tapped while the plan is off, opens
/// the wall in a sheet, and a purchase there applies the theme that was tapped and closes it, so the
/// player arrives where they were going (ADR 0256 D3).
struct ThemeSettingsView: View {
    @AppStorage(AppSettings.Key.moonTheme) private var chosen = MoonTheme.standard
    @Environment(PlanStore.self) private var plan: PlanStore?
    /// The theme the app is drawn in, which is the choice only while the plan is on.
    @Environment(\.moonTheme) private var drawn
    @State private var wallFor: MoonTheme?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(MoonTheme.allCases) { theme in
                    Button { choose(theme) } label: {
                        ThemeCard(theme: theme, isCurrent: theme == drawn, isLocked: isLocked(theme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(UITestHooks.themeCard(theme.rawValue))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .settingsScreen(title: "Theme")
        // One sheet at the body root, never on a card (the iOS 18 row-sheet trap).
        .sheet(item: $wallFor) { theme in
            PlanGated(.theme, presentation: .modal) {
                ThemeArrives { chosen = theme }
            }
        }
    }

    /// Locked while StoreKit says the plan is off, and never before it has said (a paying player must
    /// not see locks flash on), and never Blood Moon.
    private func isLocked(_ theme: MoonTheme) -> Bool {
        theme != .standard && plan.showsPlanLocks
    }

    private func choose(_ theme: MoonTheme) {
        if theme == .standard || plan.planIsOn {
            chosen = theme
        } else {
            wallFor = theme
        }
    }
}

extension MoonTheme: Identifiable {
    var id: Self { self }
}

/// What the wall's sheet becomes once the plan is on: nothing to look at. It applies the theme (or, on
/// the App Icon screen, the icon) the player tapped and closes the sheet, so the screen behind it shows
/// the choice made.
struct ThemeArrives: View {
    let apply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear.onAppear {
            apply()
            dismiss()
        }
    }
}

/// One theme, shown rather than named (ADR 0311 D7).
private struct ThemeCard: View {
    let theme: MoonTheme
    let isCurrent: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ThemePreview().environment(\.colorScheme, .light)
                ThemePreview().environment(\.colorScheme, .dark)
            }
            // The preview is drawn in the card's theme, whatever the app is drawn in.
            .environment(\.moonTheme, theme)
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PocketColor.surfaceBorder, lineWidth: 1)
            }
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name)
                        .font(.futura(.headline, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(theme.line)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.practice)
                        .accessibilityHidden(true)
                } else if isLocked {
                    PlanLockBadge()
                }
            }
        }
        .padding(12)
        .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(PocketColor.practice, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(theme.name)
        .accessibilityHint(theme.line)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .planLockedValue(isLocked)
    }
}

/// Half a card: a theme in one appearance. Everything in it reads `PocketColor`, so it is drawn in
/// whatever theme and appearance its environment says, which is the card's.
private struct ThemePreview: View {
    /// A made-up waveform: the same shape on every card, so the eye compares colour, not shape.
    private static let bars: [CGFloat] = [0.35, 0.55, 0.8, 0.6, 0.95, 0.7, 0.45, 0.65, 0.9, 0.5, 0.75, 0.4,
                                          0.6, 0.85, 0.55, 0.3, 0.7, 0.5]
    /// How much of the strip has played.
    private static let played = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 2) {
                ForEach(Self.bars.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < Self.played ? PocketColor.waveformBarPlayed : PocketColor.waveformBar)
                        .frame(width: 3, height: 30 * Self.bars[index])
                }
            }
            .frame(height: 30)
            HStack(spacing: 8) {
                Text("Start")
                    .font(.futura(size: 13, weight: .semibold))
                    .foregroundStyle(PocketColor.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(PocketColor.practiceCTA, in: Capsule())
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { dot in
                        Circle()
                            .fill(dot < 3 ? PocketColor.mastery : PocketColor.surfaceStandard)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(PocketColor.background)
    }
}

#Preview("Theme — on the plan") {
    NavigationStack { ThemeSettingsView() }
        .environment(PlanStore(preview: .payOnce))
        .preferredColorScheme(.dark)
}

#Preview("Theme — free") {
    NavigationStack { ThemeSettingsView() }
        .environment(PlanStore(preview: .none))
}
