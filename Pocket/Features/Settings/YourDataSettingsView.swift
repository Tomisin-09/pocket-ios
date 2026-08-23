import SwiftUI

/// **Settings ▸ Your data** (ADR 0181) — what the app holds of yours, and how to get it out.
///
/// One destination rather than two, because export and storage answer halves of the same question.
/// Export (ADR 0181) came first; Storage (ADR 0182) sits under it, and the two share this screen on
/// purpose: the number that says how much space your recordings take is the same number that says
/// how big your archive will be.
///
/// **The name is not new.** `FAQEntry.privacy` is already titled *"Your data"* and so is
/// `docs/manual/privacy.md`. Inventing a tenth word for a concept the app has already named twice
/// would be the expensive kind of tidy.
///
/// **It sits in the unheaded bottom group, not under Preferences** — ADR 0162 D2 groups by *"what am
/// I trying to change?"*, and an export changes nothing. It belongs beside Privacy and Help & About,
/// which are the other two rows you visit to find something out rather than to alter something.
struct YourDataSettingsView: View {
    var body: some View {
        Form {
            ExportSection()
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
