import SwiftUI

/// **Settings ▸ Routines** (ADR 0162 D2) — how a routine moves between its blocks: whether each
/// block starts itself, whether the Done screen is skipped, how long the breather is, and whether a
/// song block loops as an open jam.
///
/// Unchanged from the flat screen's "Routines" section but for its home; the hub row reports the
/// auto-start state, which is the setting people come here to check.
struct RoutineSettingsView: View {
    @AppStorage(AppSettings.Key.routineAutoStart) private var routineAutoStart = true
    @AppStorage(AppSettings.Key.routineAutoAdvance) private var routineAutoAdvance = false
    @AppStorage(AppSettings.Key.routineRestSeconds) private var routineRestSeconds = 20
    @AppStorage(AppSettings.Key.routineSongLoop) private var routineSongLoop = true

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
            }
        }
        .settingsScreen(title: "Routines")
    }
}

#Preview {
    NavigationStack { RoutineSettingsView() }
        .preferredColorScheme(.dark)
}
