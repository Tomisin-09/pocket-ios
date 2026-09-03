import SwiftUI

/// **Settings ▸ Practice** (ADR 0162 D2) — how a run behaves once you start playing: the count-in and
/// its length, whether the screen stays lit, what the click does during a strumming drill, and
/// whether a ramp announces a tempo change before taking it.
///
/// The tempo-change warning (ADR 0131) was its own top-level section; it belongs with Count-in
/// because both are the run telling you what happens next. Practice **reminders** (ADR 0186) join
/// for the same reason ADR 0162 D2 gives — a reminder changes how you practise — and add no tenth
/// row to the hub.
struct PracticeSettingsView: View {
    @AppStorage(AppSettings.Key.countInEnabled) private var countInEnabled = true
    @AppStorage(AppSettings.Key.countInBars) private var countInBars = AppSettings.countInBarsRange.lowerBound
    @AppStorage(AppSettings.Key.keepScreenAwake) private var keepScreenAwake = true
    @AppStorage(AppSettings.Key.strumClickFollowsPattern) private var strumClickFollowsPattern = true
    /// The reminder row being edited (ADR 0186 D12, amended), or `nil`. Held **here** rather than in
    /// `PracticeReminderSection` because a `.sheet` attached inside a `Form`'s `Section` does not
    /// present — see `RoutineDetailView+References`, which pays for that lesson.
    @State private var editingReminder: RoutineReminderTarget?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $countInEnabled) {
                    FieldInfoLabel(title: "Count-in", info: SettingsInfo.countIn)
                }
                if countInEnabled {
                    Stepper(value: $countInBars, in: AppSettings.countInBarsRange) {
                        LabeledContent("Count-in length", value: barsLabel(countInBars))
                    }
                }
                Toggle(isOn: $keepScreenAwake) {
                    FieldInfoLabel(title: "Keep screen awake", info: SettingsInfo.keepScreenAwake)
                }
                Toggle(isOn: $strumClickFollowsPattern) {
                    FieldInfoLabel(title: "Strumming click follows the pattern",
                                   info: SettingsInfo.strumClick)
                }
            }

            // Whether a ramp announces its next step before taking it (ADR 0131).
            TempoWarningSection()

            // A starting point for new reminders, and a list of the ones that exist (ADR 0186 D12).
            // The reminder itself is set on the routine (ADR 0163) — nothing here fires anything,
            // which is a thing the section now says before its controls rather than after.
            PracticeReminderSection(editing: $editingReminder)
        }
        .settingsScreen(title: "Practice")
        .sheet(item: $editingReminder) { target in
            RoutineReminderSheet(routineUID: target.uid, routineName: target.name,
                                 blockCount: target.blockCount)
        }
    }

    private func barsLabel(_ bars: Int) -> String { bars == 1 ? "1 bar" : "\(bars) bars" }
}

#Preview {
    NavigationStack { PracticeSettingsView() }
        .preferredColorScheme(.dark)
}
