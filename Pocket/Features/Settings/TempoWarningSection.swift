import SwiftUI

/// The **tempo-change warning** row in Settings (ADR 0131) — whether a running ramp announces its next
/// step before taking it.
///
/// Its own section so the footer can say what the warning actually does without crowding the Practice
/// toggles it sits under — inside `PracticeSettingsView` since ADR 0162, because a warning about a
/// coming tempo change belongs with Count-in: both are the run telling you what happens next.
struct TempoWarningSection: View {
    @AppStorage(AppSettings.Key.tempoChangeWarning)
    private var warningRaw = TempoChangeWarning.default.rawValue

    private var selection: Binding<TempoChangeWarning> {
        Binding(get: { AppSettings.resolvedTempoWarning(storedValue: warningRaw) },
                set: { warningRaw = $0.rawValue })
    }

    var body: some View {
        Section {
            Picker("Warn before a change", selection: selection) {
                ForEach(TempoChangeWarning.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Tempo changes")
        } footer: {
            Text("A climbing ramp shows the tempo it's about to move to, a bar before it moves — so "
                 + "you can be ready for it instead of catching up. Turned off, the ramp steps "
                 + "without saying so.")
        }
    }
}

#Preview {
    Form { TempoWarningSection() }
}
