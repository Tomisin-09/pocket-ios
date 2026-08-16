import SwiftData
import SwiftUI

/// The **Settings hub** (ADR 0162) — a short list of destinations, pushed from the Home toolbar gear.
///
/// This was thirteen sections in one flat `Form`, grown one section per ADR in the order the ADRs
/// landed. It is now nine rows that each push a screen owning one coherent group, which is the shape
/// `ToolkitView` (ADR 0096) already uses and the shape the platform's own Settings uses — so it costs
/// the player no new idea. ADR 0050 chose a push over a sheet *"so it can grow sub-screens"*; this is
/// that affordance finally being spent.
///
/// **The grouping rule is "what am I trying to change?", not "which subsystem implements it"** — see
/// ADR 0162 D2 for why Note names sits under Appearance and haptics sits with the metronome click.
///
/// **Each row states its value** where a single setting dominates the destination (D3), so the common
/// visit ends without opening anything. *Song player* shows nothing on purpose: it holds four
/// unranked toggles, and electing one to display would misreport the screen.
///
/// This is pure information architecture — no key, no default, no model and no migration changed
/// (D9). A player updating finds their settings exactly as they left them, in different places.
struct SettingsView: View {
    /// The local artist profile (ADR 0113); drives the "You" row's summary. At most one row.
    @Query private var profiles: [Profile]
    @Environment(\.isPro) private var isPro
    /// **Optional** for the same reason `TrialCountdownRow` makes it optional: previews don't inject a
    /// `TrialReminder`, and a non-optional `@Environment(Observable.self)` traps when it's missing.
    /// Absent reminder = no trial, which is the right answer in a preview anyway.
    @Environment(TrialReminder.self) private var trialReminder: TrialReminder?

    // Read only to summarise the rows — each destination owns the binding that writes them.
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system
    @AppStorage(AppSettings.Key.clickTimbre) private var clickTimbre = ClickTimbre.default
    @AppStorage(AppSettings.Key.countInEnabled) private var countInEnabled = true
    @AppStorage(AppSettings.Key.routineAutoStart) private var routineAutoStart = true
    /// The `= false` is unreachable — `AppSettings.seedAnalyticsDefaultIfNeeded` writes this at launch
    /// (ADR 0147 §3) — but it is the safe direction if it ever were reached.
    @AppStorage(AppSettings.Key.analyticsEnabled) private var analyticsEnabled = false

    var body: some View {
        Form {
            // State — who you are and what you have — rather than preferences, so it sits above them.
            Section {
                NavigationLink { YouSettingsView() } label: {
                    SettingsHubRow(icon: "person.crop.circle", title: "You", value: youSummary)
                }
                NavigationLink { ProSettingsView() } label: {
                    SettingsHubRow(icon: "moon.stars", title: "Red Moon Pro", value: proSummary)
                }
            }

            Section("Preferences") {
                NavigationLink { AppearanceSettingsView() } label: {
                    SettingsHubRow(icon: "paintbrush", title: "Appearance", value: appearance.label)
                }
                NavigationLink { SoundFeelSettingsView() } label: {
                    SettingsHubRow(icon: "speaker.wave.2", title: "Sound & feel",
                                   value: clickTimbre.displayName)
                }
                NavigationLink { PracticeSettingsView() } label: {
                    // "timer", not "guitars" — the six-string glyph collapses into an illegible
                    // tangle at row size (caught on the device pass).
                    SettingsHubRow(icon: "timer", title: "Practice",
                                   value: countInEnabled ? "Count-in on" : "Count-in off")
                }
                NavigationLink { RoutineSettingsView() } label: {
                    SettingsHubRow(icon: "list.bullet.rectangle", title: "Routines",
                                   value: routineAutoStart ? "Auto-start on" : "Auto-start off")
                }
                // No trailing value on purpose (D3) — four unranked toggles, none of them the answer.
                NavigationLink { SongPlayerSettingsView() } label: {
                    SettingsHubRow(icon: "waveform", title: "Song player")
                }
            }

            Section {
                NavigationLink { PrivacySettingsView() } label: {
                    SettingsHubRow(icon: "hand.raised", title: "Privacy", value: privacySummary)
                }
                NavigationLink { AboutSettingsView() } label: {
                    SettingsHubRow(icon: "info.circle", title: "Help & About")
                }
            }

            // Hidden during a screenshot shoot as well as in release. The footer says it plainly —
            // never present in a shipping build — and a figure in the user manual is a picture of
            // the shipping build, so a Debug-only tenth destination in it is simply wrong (ADR 0165).
            // The manual's own alt text for this screen lists the nine that ship.
            #if DEBUG
            if !ScreenshotSeed.isShooting {
                Section {
                    NavigationLink { DeveloperSettingsView() } label: {
                        SettingsHubRow(icon: "hammer", title: "Developer")
                    }
                } footer: {
                    Text("DEBUG only — never present in a shipping build.")
                }
            }
            #endif
        }
        .settingsScreen(title: "Settings")
    }

    /// "Tomisin · Guitar", or just the instrument before a name has been set. The instrument always
    /// has a value (the model's axis is non-optional and falls back to guitar, ADR 0116), so the row
    /// is never blank.
    private var youSummary: String {
        let instrument = (profiles.first?.preferredInstrument ?? .guitar).displayName
        guard let name = profiles.first?.artistName, !name.isEmpty else { return instrument }
        return "\(name) · \(instrument)"
    }

    /// A running trial outranks the entitlement — it's the thing with a deadline on it (ADR 0144 D6).
    private var proSummary: String {
        if let days = trialReminder?.daysRemaining() {
            return "Trial · \(days) day\(days == 1 ? "" : "s")"
        }
        return isPro ? "Active" : "Free"
    }

    /// Says what the setting *does*, not whether a thing called "privacy" is on — "Privacy · On" would
    /// be genuinely ambiguous about which way the switch points.
    private var privacySummary: String {
        analyticsEnabled ? "Sharing usage" : "Not sharing"
    }
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Settings — regular width (iPad groundwork)") {
    NavigationStack { SettingsView() }
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
        .modelContainer(for: Profile.self, inMemory: true)
        .environment(StoreManager())
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
        .modelContainer(for: Profile.self, inMemory: true)
        .environment(StoreManager())
}
