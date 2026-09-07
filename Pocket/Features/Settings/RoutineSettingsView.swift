import SwiftUI

/// **Settings ▸ Routines** (ADR 0162 D2) — how a routine moves between its blocks: whether each
/// block starts itself, whether the Done screen is skipped, how long the breather is, and whether a
/// song block loops as an open jam.
///
/// Unchanged from the flat screen's "Routines" section but for its home; the hub row reports the
/// auto-start state, which is the setting people come here to check. **Ask to tune up** (ADR 0195)
/// joins on the same reading: it is one more thing a routine does between its blocks — here, before
/// the first one. It is the only row on this screen the player can also set from somewhere else,
/// because the prompt it governs carries its own `Don't ask again`.
struct RoutineSettingsView: View {
    @AppStorage(AppSettings.Key.routineAutoStart) private var routineAutoStart = true
    @AppStorage(AppSettings.Key.routineAutoAdvance) private var routineAutoAdvance = false
    @AppStorage(AppSettings.Key.routineRestSeconds) private var routineRestSeconds = 20
    @AppStorage(AppSettings.Key.routineSongLoop) private var routineSongLoop = true
    /// Bound to the constant, never a literal — the `@AppStorage` default is what SwiftUI uses for an
    /// unset key and it does not consult `AppSettings.routineTunerOffer` (ADR 0195 D4).
    @AppStorage(AppSettings.Key.routineTunerOffer)
    private var routineTunerOffer = AppSettings.routineTunerOfferDefault

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $routineAutoStart) {
                    FieldInfoLabel(title: "Auto-start blocks", info: SettingsInfo.routineAutoStart)
                }
                Toggle(isOn: $routineAutoAdvance) {
                    FieldInfoLabel(title: "Advance automatically", info: SettingsInfo.routineAutoAdvance)
                }
                Stepper(value: $routineRestSeconds, in: AppSettings.routineRestSecondsRange, step: 5) {
                    LabeledContent {
                        Text("\(routineRestSeconds)s")
                    } label: {
                        FieldInfoLabel(title: "Rest length", info: SettingsInfo.routineRest)
                    }
                }
                Toggle(isOn: $routineSongLoop) {
                    FieldInfoLabel(title: "Loop song blocks", info: SettingsInfo.routineSongLoop)
                }
                // The tune-up prompt (ADR 0195). Here rather than under Practice because it is a
                // thing a *routine* does when it starts, which is what this screen is a list of.
                // The prompt's own `Don't ask again` writes this same key, so the two never disagree.
                Toggle(isOn: $routineTunerOffer) {
                    FieldInfoLabel(title: "Ask to tune up", info: SettingsInfo.routineTunerOffer)
                }
            }
        }
        .settingsScreen(title: "Routines")
    }
}

#Preview {
    NavigationStack { RoutineSettingsView() }
        .preferredColorScheme(.dark)
}
