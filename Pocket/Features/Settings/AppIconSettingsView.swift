import SwiftUI

/// **Settings ▸ Appearance ▸ App Icon** (ADR 0314): which icon sits on the Home Screen. *Matches theme*
/// first, drawing the icon the current theme wears, then the eight moons' icons as tiles, so the screen
/// shows the icons rather than naming them.
///
/// **Tapping applies at once**, as the Theme screen does: there is no Save. iOS then confirms the change
/// with an alert of its own, which follows the tap that explains it.
///
/// **A moon's icon is part of the plan, as its theme is** (D3). The screen is open to everyone; Blood
/// Moon's icon and *Matches theme* are free, and another moon, tapped while the plan is off, opens the
/// wall in a sheet. A purchase there keeps the icon that was tapped and closes it.
struct AppIconSettingsView: View {
    @AppStorage(AppSettings.Key.appIcon) private var chosen = AppIconChoice.standard
    @Environment(PlanStore.self) private var plan: PlanStore?
    /// The theme the app is drawn in, whose icon *Matches theme* shows.
    @Environment(\.moonTheme) private var drawn
    @State private var wallFor: MoonTheme?

    /// The choice the Home Screen shows, which is the stored one only while the plan allows it.
    private var current: AppIconChoice {
        AppIconChoice.effective(chosen: chosen, planIsOn: plan.planIsOn, planHasResolved: plan?.hasResolved ?? true)
    }

    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 12, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button { chosen = .matchesTheme } label: {
                    MatchesThemeCard(drawn: drawn, isCurrent: current == .matchesTheme)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(UITestHooks.appIconOption(AppIconChoice.matchesTheme.rawValue))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Or keep one icon, whatever the theme")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(MoonTheme.allCases) { moon in
                            Button { choose(moon) } label: {
                                IconTile(moon: moon, isCurrent: current == .moon(moon), isLocked: isLocked(moon))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(UITestHooks.appIconOption(moon.rawValue))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .settingsScreen(title: "App Icon")
        // One sheet at the body root, never on a tile (the iOS 18 row-sheet trap).
        .sheet(item: $wallFor) { moon in
            PlanGated(.appIcon, presentation: .modal) {
                ThemeArrives { chosen = .moon(moon) }
            }
        }
    }

    /// Locked while StoreKit says the plan is off, never before it has said, and never Blood Moon.
    private func isLocked(_ moon: MoonTheme) -> Bool {
        moon != .standard && plan.showsPlanLocks
    }

    private func choose(_ moon: MoonTheme) {
        if moon == .standard || plan.planIsOn {
            chosen = .moon(moon)
        } else {
            wallFor = moon
        }
    }
}

/// The App Icon as the Home Screen draws it: the icon's own render, in the rounded square iOS cuts.
struct AppIconImage: View {
    let moon: MoonTheme
    let size: CGFloat

    var body: some View {
        Image(moon.iconTileImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            // iOS's icon corner is about 22.4% of the side.
            .clipShape(RoundedRectangle(cornerRadius: size * 0.224, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.224, style: .continuous)
                    .strokeBorder(PocketColor.surfaceBorder, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

/// *Matches theme*: the icon the current theme wears, which is what the Home Screen shows while this is
/// the choice, and the line that says it changes when the theme does.
private struct MatchesThemeCard: View {
    let drawn: MoonTheme
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            AppIconImage(moon: drawn, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppIconChoice.matchesTheme.name)
                    .font(.futura(.headline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("Changes with the theme. Now \(drawn.name).")
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
        .accessibilityLabel(AppIconChoice.matchesTheme.name)
        .accessibilityHint("Changes with the theme. Now \(drawn.name).")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// One moon's icon and its name, ringed while it's the one on the Home Screen.
private struct IconTile: View {
    let moon: MoonTheme
    let isCurrent: Bool
    let isLocked: Bool

    private let side: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            AppIconImage(moon: moon, size: side)
                .padding(3)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: side * 0.224 + 3, style: .continuous)
                            .strokeBorder(PocketColor.practice, lineWidth: 2.5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isLocked {
                        PlanLockBadge()
                            .padding(4)
                            .background(PocketColor.background, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            Text(moon.name)
                .font(.futura(.caption, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? PocketColor.textPrimary : PocketColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(moon.name)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .planLockedValue(isLocked)
    }
}

#Preview("App Icon — on the plan") {
    NavigationStack { AppIconSettingsView() }
        .environment(PlanStore(preview: .payOnce))
        .preferredColorScheme(.dark)
}

#Preview("App Icon — free") {
    NavigationStack { AppIconSettingsView() }
        .environment(PlanStore(preview: .none))
}
