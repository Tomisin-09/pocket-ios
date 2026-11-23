import SwiftUI

/// **Settings ▸ Appearance** (ADR 0162 D2) — how the app presents itself: its moon theme, light/dark,
/// whether the exercise highlight walks, and how notes are spelled.
///
/// **Theme comes first** (ADR 0311 D7), as a row that says its value (ADR 0258): the theme's moon and
/// name, opening the Theme screen. *System / Light / Dark* stays one control directly under it, because
/// the two answer different questions (which colours, and which canvas), and the Theme screen shows
/// each theme in both appearances rather than repeating it.
///
/// **Note names lives here, and that placement is the ADR's grouping rule in miniature.** Accidentals
/// are implemented in music theory but *experienced* as how a note is written, and a player hunting
/// for them is thinking about what they see — not about `NoteSpelling`. Grouping by "what am I trying
/// to change?" rather than by subsystem is what puts it next to Light/Dark instead of next to the
/// tuner.
struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system
    @AppStorage(AppSettings.Key.exerciseAnimates) private var exerciseAnimates = AppSettings.exerciseAnimatesDefault

    /// The theme the app is drawn in (the choice while the plan is on, Blood Moon while it's off).
    @Environment(\.moonTheme) private var theme

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
