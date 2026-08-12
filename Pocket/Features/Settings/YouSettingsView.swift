import SwiftData
import SwiftUI

/// **Settings ▸ You** (ADR 0162 D2) — who you are and what you play: the artist name (ADR 0113) and
/// the four curation fields the first-launch intake collects, which `ProfileCurationSection` owns.
///
/// The two were separate top-level sections ("You" and "Your sound") on the flat screen. They answer
/// the same question and now share a destination.
///
/// **The name still commits on submit and on leave** — but "leave" now means leaving *this* screen
/// rather than the whole of Settings, which is strictly earlier and strictly better. Writing once per
/// edit rather than per keystroke is what keeps a half-typed name from inserting a `Profile` row.
struct YouSettingsView: View {
    @Environment(\.modelContext) private var context
    /// The local artist profile (ADR 0113). At most one row; `.first` is the singleton (or `nil` on an
    /// untouched install, before a name has ever been set).
    @Query private var profiles: [Profile]
    /// Draft of the artist name being edited. Seeded from the profile on appear and committed on
    /// submit / when the screen leaves.
    @State private var artistNameDraft = ""

    var body: some View {
        Form {
            Section {
                TextField("Artist name", text: $artistNameDraft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(commitArtistName)
            } footer: {
                Text("Your artist name greets you on the home screen. Optional, and it stays on this device.")
            }

            // The curation fields (ADR 0113 S2) — the intake's four questions, editable any time.
            ProfileCurationSection(profile: profiles.first)
        }
        .settingsScreen(title: "You")
        .onAppear { artistNameDraft = profiles.first?.artistName ?? "" }
        // Commit when the screen leaves too, so an edit typed without pressing Done still saves.
        .onDisappear(perform: commitArtistName)
    }

    /// Persist the drafted artist name to the local profile (creating the singleton row on first
    /// non-empty name, clearing it back to name-free when blank).
    private func commitArtistName() {
        Profile.setArtistName(artistNameDraft, in: context)
    }
}

#Preview {
    NavigationStack { YouSettingsView() }
        .modelContainer(for: Profile.self, inMemory: true)
}
