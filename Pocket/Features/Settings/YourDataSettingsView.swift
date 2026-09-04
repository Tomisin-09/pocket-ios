import SwiftUI

/// **Settings ▸ Your data** (ADR 0181) — what the app holds of yours, and how to get it out.
///
/// One destination rather than two, because export, restore and storage answer parts of the same
/// question. Export (ADR 0181) came first; Restore (ADR 0188 S3) sits directly under it, because the
/// two are one operation seen from either end and a player looking for the way back in looks where
/// the way out was; Storage (ADR 0182) sits under both, and shares the screen on purpose — the number
/// that says how much space your recordings take is the same number that says how big your archive
/// will be.
///
/// **The name is not new.** `FAQEntry.privacy` is already titled *"Your data"* and so is
/// `docs/manual/privacy.md`. Inventing a tenth word for a concept the app has already named twice
/// would be the expensive kind of tidy.
///
/// **It sits in the unheaded bottom group, not under Preferences** — ADR 0162 D2 groups by *"what am
/// I trying to change?"*, and none of these is a setting. That reading held trivially while the
/// screen only exported; Restore does change the library, and it still belongs here rather than under
/// Preferences, because what it changes is your *material* and not the app's behaviour — the same
/// distinction that puts importing a song in the Library and not in Settings.
struct YourDataSettingsView: View {
    var body: some View {
        Form {
            ExportSection()
            RestoreSection()
            StorageSection()
        }
        .settingsScreen(title: "Your data")
    }
}

#Preview {
    NavigationStack { YourDataSettingsView() }
        .preferredColorScheme(.dark)
        .modelContainer(for: Song.self, inMemory: true)
}
