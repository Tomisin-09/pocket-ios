import SwiftUI

/// **Settings ▸ Practice** (ADR 0162 D2) — how a run behaves once you start playing: the count-in and
/// its length, whether the screen stays lit, what the click does during a strumming drill, and
/// whether a ramp announces a tempo change before taking it.
///
/// The tempo-change warning (ADR 0131) was its own top-level section; it belongs with Count-in
/// because both are the run telling you what happens next.
struct PracticeSettingsView: View {
    @AppStorage(AppSettings.Key.countInEnabled) private var countInEnabled = true
    @AppStorage(AppSettings.Key.countInBars) private var countInBars = AppSettings.countInBarsRange.lowerBound
    @AppStorage(AppSettings.Key.keepScreenAwake) private var keepScreenAwake = true
    @AppStorage(AppSettings.Key.strumClickFollowsPattern) private var strumClickFollowsPattern = true

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
        }
        .settingsScreen(title: "Practice")
    }

    private func barsLabel(_ bars: Int) -> String { bars == 1 ? "1 bar" : "\(bars) bars" }
}

#Preview {
    NavigationStack { PracticeSettingsView() }
        .preferredColorScheme(.dark)
}
