import SwiftUI

/// **Settings ▸ Help & About ▸ Diagnostics** (ADR 0183) — what iOS has told us went wrong, and the
/// one switch that lets it travel with a support message.
///
/// **Not a Settings hub destination.** ADR 0162 D2 groups the hub by *"what am I trying to change?"*
/// and this changes nothing; it lives beside Contact support because feeding a support message is
/// its only purpose. A screen a player opens once, after something has already gone wrong, does not
/// earn a permanent row on the top level.
///
/// **Everything on it is already bounded.** The rows are the same `DiagnosticEvent`s the attached
/// line is built from, rendered by the same pure type — so what is on screen and what would be sent
/// cannot drift, which is the test ADR 0161 D3 actually sets.
struct DiagnosticsSettingsView: View {

    /// Optional for the same reason as in `AboutSection`: the recorder is owned by `PocketApp`, and
    /// the non-optional environment read traps anywhere that root is absent — previews included.
    @Environment(DiagnosticsRecorder.self) private var recorder: DiagnosticsRecorder?

    /// The literal is `AppSettings.attachDiagnosticsDefault`, not `false` — a `@AppStorage` uses the
    /// value it declares for an unset key and never consults the accessor beside it.
    @AppStorage(AppSettings.Key.attachDiagnostics)
    private var attachDiagnostics = AppSettings.attachDiagnosticsDefault

    private var events: [DiagnosticEvent] { recorder?.events ?? [] }

    var body: some View {
        Form {
            Section {
                if events.isEmpty {
                    Text("Nothing to report.")
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DiagnosticSummary.rowTitle(for: event))
                            Text(DiagnosticSummary.rowDetail(for: event))
                                .font(.footnote)
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                Text("Reported by iOS")
            } footer: {
                // The cadence is the single most useful thing this screen can say. Without it an
                // empty list reads as "the feature is broken" on the one day it is most likely to be
                // looked at — the day after a crash.
                Text("iOS collects these in the background and hands them over about once a day, so "
                    + "something that just happened won't be here yet. They are kept on your device "
                    + "and are not sent anywhere on their own.")
            }

            Section {
                Toggle(isOn: $attachDiagnostics) {
                    FieldInfoLabel(title: "Include in support messages",
                                   info: SettingsInfo.attachDiagnostics)
                }

                if let line = recorder?.supportLine {
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(PocketColor.textSecondary)
                }
            } header: {
                Text("Support")
            } footer: {
                Text(attachDiagnostics
                     ? "Shown again in the message before you send it."
                     : "Off — a support message carries your app version, your iOS version and your "
                        + "device model, and nothing else.")
            }

            if !events.isEmpty {
                Section {
                    Button("Clear", role: .destructive) { recorder?.clear() }
                } footer: {
                    Text("Forgets what is listed above. It does not stop iOS collecting more.")
                }
            }
        }
        .settingsScreen(title: "Diagnostics")
    }
}

#Preview("Reports") {
    NavigationStack { DiagnosticsSettingsView() }
        .environment(DiagnosticsRecorder(usesSystemMetrics: false, seeded: [
            DiagnosticEvent(kind: .crash, date: .now.addingTimeInterval(-86_400),
                            detail: "EXC_BAD_ACCESS", appBuild: "4", systemVersion: "18.5"),
            DiagnosticEvent(kind: .crash, date: .now.addingTimeInterval(-6 * 86_400),
                            detail: "SIGTRAP", appBuild: "3", systemVersion: "18.5"),
            DiagnosticEvent(kind: .hang, date: .now.addingTimeInterval(-9 * 86_400),
                            detail: "froze for 4.2s", appBuild: "3", systemVersion: "18.4")
        ]))
        .preferredColorScheme(.dark)
}

#Preview("Nothing to report") {
    NavigationStack { DiagnosticsSettingsView() }
        .environment(DiagnosticsRecorder(usesSystemMetrics: false, seeded: []))
        .preferredColorScheme(.dark)
}
