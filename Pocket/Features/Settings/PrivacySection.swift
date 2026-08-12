import SwiftUI

/// The standing control over anonymous product analytics (ADR 0120, region-split by ADR 0147).
///
/// **This toggle is unchanged by 0147, and that is the point** — under `.notify` it *is* the
/// "simple, free means of objecting" the DUAA Sch A1 para 5 exception is conditional on. Under
/// `.ask` it remains the withdrawal control ePrivacy requires and the promise the consent sheet
/// makes good on ("you can change this any time in Settings"). One control, two legal jobs, no
/// branching in the mechanism.
///
/// Only the **footer** branches, because only the starting position differs. Both models write the
/// same `AppSettings.Key.analyticsEnabled`, and `Analytics` re-reads it on every single event, so
/// flipping it off stops collection on the next event with no relaunch.
///
/// Deliberately **one toggle, not an "off-the-grid mode"** — that idea was written down while the
/// plan was still opt-out, where a distinct master switch would have been needed. Since the app
/// makes no other network calls, such a mode would govern this single flag while implying a far
/// broader guarantee. Withdrawal has to be as easy as granting; it does not have to be a feature.
///
/// Its own section so the footer — which is the honest statement of what is and isn't collected —
/// isn't buried under unrelated rows. Hosted by `PrivacySettingsView` since ADR 0162; the standing
/// "add no row to `SettingsView`, it is at the cap" warning that used to live here is retired, because
/// the hub split is what removed the cap.
struct PrivacySection: View {
    /// The `= false` is unreachable: `AppSettings.seedAnalyticsDefaultIfNeeded` writes the key at
    /// launch, so it is always present here (ADR 0147 §3). Kept as a safe-direction backstop —
    /// coordinating this literal with the two others is exactly what the seeding removed the need
    /// for, and what would otherwise show an **off** toggle to a player who is **on**.
    @AppStorage(AppSettings.Key.analyticsEnabled) private var analyticsEnabled = false

    private var consentModel: AnalyticsPolicy.ConsentModel {
        AnalyticsPolicy.consentModel(regionCode: Locale.current.region?.identifier)
    }

    var body: some View {
        Section {
            Toggle(isOn: $analyticsEnabled) {
                FieldInfoLabel(title: "Share anonymous usage", info: SettingsInfo.analytics)
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text(footer)
        }
    }

    /// The first sentence is the only difference: under `.ask` analytics starts off and the player
    /// turned it on, under `.notify` it starts on and this is how they turn it off. Everything after
    /// it — what is counted, and what never leaves the device — is identical, because what the app
    /// actually does is identical.
    private var footer: String {
        let opening = consentModel == .ask
            ? "Off unless you turn it on. Turned on, Red"
            : "On by default, and off the moment you say so. Red"
        return opening
            + " Moon counts which features get used so we know what to improve — anonymously, with "
            + "no account and no advertising ID. Your playing never leaves this device: not your "
            + "recordings, your notes, your song names or your artist name."
    }
}

#Preview {
    Form { PrivacySection() }
}
