import SwiftUI

/// The standing control over anonymous product analytics (ADR 0120), and the promise the consent
/// ask makes good on ("you can change this any time in Settings").
///
/// Analytics is opt-in, so this toggle is **off** until the player explicitly turns it on, whether
/// here or in `AnalyticsConsentSheet`. Both write the same `AppSettings.Key.analyticsEnabled`, and
/// `Analytics` re-reads it on every single event, so flipping it off stops collection on the next
/// event with no relaunch.
///
/// Deliberately **one toggle, not an "off-the-grid mode"** — that idea was written down while the
/// plan was still opt-out, where a distinct master switch would have been needed. Opt-in makes
/// off-the-grid the default state, and since the app makes no other network calls, such a mode
/// would govern this single flag while implying a far broader guarantee. Withdrawal has to be as
/// easy as granting; it does not have to be a feature.
///
/// Its own file (like `NoteSpellingSection`) so `SettingsView` stays inside the file-length ceiling,
/// and its own section so the footer — which is the honest statement of what is and isn't collected
/// — isn't buried under unrelated rows.
struct PrivacySection: View {
    @AppStorage(AppSettings.Key.analyticsEnabled) private var analyticsEnabled = false

    var body: some View {
        Section {
            Toggle(isOn: $analyticsEnabled) {
                FieldInfoLabel(title: "Share anonymous usage", info: SettingsInfo.analytics)
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Off unless you turn it on. Turned on, Red Moon counts which features get used so "
                 + "we know what to improve — anonymously, with no account and no advertising ID. "
                 + "Your playing never leaves this device: not your recordings, your notes, your "
                 + "song names or your artist name.")
        }
    }
}

#Preview {
    Form { PrivacySection() }
}
