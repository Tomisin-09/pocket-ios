import SwiftUI

/// **Settings ▸ Appearance** (ADR 0162 D2) — how the app presents itself: its moon theme, light/dark,
/// whether the exercise highlight walks, and how notes are spelled.
///
/// **Theme comes first** (ADR 0311 D7), as a row that says its value (ADR 0258): the theme's moon and
/// name, opening the Theme screen. **App Icon** sits directly under it (ADR 0314 D1), saying the icon
/// on the Home Screen the same way, because the two are chosen together and one can follow the other.
/// *System / Light / Dark* stays one control in the same group, under both, because it answers a
/// different question (which canvas, not which colours), and the Theme screen shows each theme in both
/// appearances rather than repeating it.
///
/// **Note names lives here, and that placement is the ADR's grouping rule in miniature.** Accidentals
/// are implemented in music theory but *experienced* as how a note is written, and a player hunting
/// for them is thinking about what they see — not about `NoteSpelling`. Grouping by "what am I trying
/// to change?" rather than by subsystem is what puts it next to Light/Dark instead of next to the
/// tuner.
struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system
    @AppStorage(AppSettings.Key.exerciseAnimates) private var exerciseAnimates = AppSettings.exerciseAnimatesDefault

    @AppStorage(AppSettings.Key.appIcon) private var iconChoice = AppIconChoice.standard
    @Environment(PlanStore.self) private var plan: PlanStore?

    /// The theme the app is drawn in (the choice while the plan is on, Blood Moon while it's off).
    @Environment(\.moonTheme) private var theme

    /// The icon choice the Home Screen shows, which is the stored one only while the plan allows it.
    private var icon: AppIconChoice {
        AppIconChoice.effective(chosen: iconChoice, planIsOn: plan.planIsOn, planHasResolved: plan?.hasResolved ?? true)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink { ThemeSettingsView() } label: {
                    HubRow(icon: "moon", title: "Theme") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(PocketColor.practice)
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)
                            Text(theme.name)
                                .foregroundStyle(PocketColor.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .accessibilityIdentifier(UITestHooks.themeRow)
                NavigationLink { AppIconSettingsView() } label: {
                    HubRow(icon: "app", title: "App Icon") {
                        HStack(spacing: 6) {
                            AppIconImage(moon: icon.icon(drawnTheme: theme), size: 18)
                            Text(icon.name)
                                .foregroundStyle(PocketColor.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .accessibilityIdentifier(UITestHooks.appIconRow)
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("System follows your device's Light/Dark setting.")
            }

            Section("Motion") {
                Toggle(isOn: $exerciseAnimates) {
                    FieldInfoLabel(title: "Animate exercises", info: SettingsInfo.animateExercises)
                }
            }

            // Sharps vs flats where nothing else decides (ADR 0123). Keeps its own section for the
            // footer that says what it does *not* override.
            NoteSpellingSection()
        }
        .settingsScreen(title: "Appearance")
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .preferredColorScheme(.dark)
}
