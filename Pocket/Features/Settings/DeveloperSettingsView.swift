#if DEBUG
import SwiftData
import SwiftUI

/// **Settings ▸ Developer** — DEBUG-only scaffolding, gathered behind one row (ADR 0162 D8).
///
/// The whole file is inside `#if DEBUG`, so none of this exists in a shipping build. Gathering it
/// here is not only tidiness: on the flat screen these sections were a meaningful share of both
/// the scroll and `SettingsView`'s line count, and none of them belong in a player's field of view
/// even in a TestFlight build.
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var context

    /// Re-arms the one-time "you've earned a name" prompt without a data-wiping reinstall.
    @AppStorage(AppSettings.Key.artistNamePromptSeen) private var artistNamePromptSeen = false
    /// Re-arms the first-launch curation intake (ADR 0113 S2).
    @AppStorage(AppSettings.Key.artistIntakeSeen) private var artistIntakeSeen = false
    var body: some View {
        Form {
            // A/B the stretcher-latency correction (ADR 0140 §3).
            DebugAudioSection()

            Section {
                Button("Reset naming prompt", role: .destructive, action: resetNamingPrompt)
                Button("Reset first-launch intake", role: .destructive, action: resetIntake)
                Button("Reset review ask", role: .destructive, action: resetReviewAsk)
            } header: {
                Text("First-run flows")
            } footer: {
                Text("Clears your artist name and re-arms the “you've earned a name” prompt; the "
                     + "second row re-arms the first-launch curation intake. The third forgets that "
                     + "we asked for a review — note that iOS keeps its own budget on top of ours, "
                     + "so the system dialog may still decline to appear.")
            }
        }
        .settingsScreen(title: "Developer")
    }

    /// Clear the artist name and re-arm the one-time naming prompt, so the "you've earned a name"
    /// ceremony can be exercised again on a real install (no reinstall / data loss).
    private func resetNamingPrompt() {
        Profile.setArtistName(nil, in: context)
        artistNamePromptSeen = false
    }

    /// Re-arm the one-time first-launch curation intake. Leaves the stored curation in place (it stays
    /// visible/editable under "You"); this only flips the "seen" gate so Home offers the flow again.
    private func resetIntake() {
        artistIntakeSeen = false
    }

    /// Forget that the app has asked for a review, so the ladder's last rung can be exercised again
    /// (ADR 0214). This clears **our** record only — iOS's own three-per-year budget is invisible to
    /// the process and unaffected, so the system dialog may still show nothing after this. That is
    /// the feature's central fact, not a bug in this button.
    private func resetReviewAsk() {
        ReviewPrompt.resetForTesting()
    }
}

#Preview {
    NavigationStack { DeveloperSettingsView() }
        .modelContainer(for: Profile.self, inMemory: true)
}
#endif
