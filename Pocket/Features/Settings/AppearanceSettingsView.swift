import SwiftUI

/// **Settings ▸ Appearance** (ADR 0162 D2) — how the app presents itself: light/dark, whether the
/// exercise highlight walks, and how notes are spelled.
///
/// **Note names lives here, and that placement is the ADR's grouping rule in miniature.** Accidentals
/// are implemented in music theory but *experienced* as how a note is written, and a player hunting
/// for them is thinking about what they see — not about `NoteSpelling`. Grouping by "what am I trying
/// to change?" rather than by subsystem is what puts it next to Light/Dark instead of next to the
/// tuner.
struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system
    @AppStorage(AppSettings.Key.exerciseAnimates) private var exerciseAnimates = AppSettings.exerciseAnimatesDefault

    var body: some View {
        Form {
            Section {
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
