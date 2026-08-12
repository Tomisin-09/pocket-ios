import SwiftUI

/// **Settings ▸ Privacy** (ADR 0162 D2) — the standing control over anonymous product analytics.
///
/// **This screen is one push deeper than it used to be, and D7 is where that was checked rather than
/// assumed.** Under ADR 0147's `.notify` model this toggle *is* the "simple, free means of objecting"
/// the UK DUAA 2025 Sch A1 para 5 exception is conditional on; under `.ask` it is the withdrawal
/// control ePrivacy requires. A control reached by *Settings ▸ Privacy* is still simple and free: two
/// taps from anywhere, labelled with the word a player would look for, and the hub row states its
/// current value so the state is legible without opening it.
///
/// Nothing about the mechanism changed — same key, same per-event re-read, same region-branching
/// footer. `PrivacySection` moved file, not behaviour.
///
/// A side effect worth noting: `ArtistIntakeView` has always promised "Turn it off any time in
/// Settings ▸ Privacy." That sentence was aspirational when written. It is now literally true.
struct PrivacySettingsView: View {
    var body: some View {
        Form {
            PrivacySection()
        }
        .settingsScreen(title: "Privacy")
    }
}

#Preview {
    NavigationStack { PrivacySettingsView() }
        .preferredColorScheme(.dark)
}
