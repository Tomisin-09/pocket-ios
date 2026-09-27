import SwiftUI

/// **The Journal's ＋** (ADR 0224) — the two things this space writes, both against nothing: a note
/// (ADR 0155) and a take.
///
/// A `Menu` rather than a second bar button, so the trailing edge keeps ADR 0126's grammar —
/// `ellipsis.circle` then `+` — instead of growing a third bare item, which is the shape 0155's open
/// toolbar question was settled to avoid. The glyph is `plus` because the menu is no longer only a
/// pencil; *Write a note* keeps the pencil inside it, so the note door still looks like the one on
/// every run screen.
///
/// Fixed-width label (ADR 0126): nothing on a nav bar may vary in width, or the inline title moves.
struct JournalNewMenu: View {
    let onWriteNote: () -> Void
    let onRecordTake: () -> Void

    var body: some View {
        Menu {
            Button(action: onWriteNote) {
                Label("Write a note", systemImage: "square.and.pencil")
            }
            Button(action: onRecordTake) {
                Label("Record a take", systemImage: "record.circle")
            }
        } label: {
            Image(systemName: "plus")
        }
        .tint(PocketColor.journal)
        .accessibilityLabel("Add to Journal")
    }
}
