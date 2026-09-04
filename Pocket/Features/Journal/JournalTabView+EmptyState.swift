import SwiftUI

/// **What the Journal space says when it has nothing to show** — and, since ADR 0190, *why*.
///
/// Split out of `JournalTabView` for the 400-line cap, the same reason `JournalTakeRow` and
/// `JournalTabView+Deletion` were. It earns a file rather than a few lines because the screen now has
/// three ways to be empty and they mean different things: a journal with nothing in it yet, a search
/// that matched nothing, and a **filter the player left on**. Only the first is good news.
///
/// The rule this file exists to hold (ADR 0190 D8): **the empty state names the thing that emptied
/// it.** A persisted filter is only safe when the screen admits it is in force — the options glyph
/// fills, and if the result is nothing at all, this text says which filter did it and how to undo it.
/// Without that, a player who left *Pinned only* on comes back to a year-old journal showing nothing
/// and reasonably concludes the app lost it.
///
/// `searching` and `emptyState` are not `private`: `private` is file-scoped in Swift, and
/// `JournalTabView.body` reads both.
extension JournalTabView {

    // MARK: - Empty state

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyGlyph)
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.textSecondary)
            Text(emptyTitle)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(emptyMessage)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Whether a live search is narrowing the feed (drives the "no matches" empty state).
    var searching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var emptyGlyph: String {
        if searching { return "magnifyingglass" }
        return pinnedOnly ? "pin" : "book.closed"
    }

    /// What the scope calls its rows in a sentence — so the pinned empty state can say "notes" or
    /// "takes" rather than repeating the picker's own capitalised labels back at the player.
    private var scopeNoun: String {
        switch scope {
        case .all: return "entries"
        case .notes: return "notes"
        case .takes: return "takes"
        }
    }

    /// The empty state names **the filter that emptied the screen** (ADR 0190 D8), never the generic
    /// "Nothing here yet" — a player who left *Pinned only* on and comes back to a year-old journal
    /// showing nothing must be told why, or the reasonable conclusion is that the app lost it.
    private var emptyTitle: String {
        if searching { return "No matches" }
        if pinnedOnly { return "No pinned \(scopeNoun)" }
        switch scope {
        case .all: return "Nothing here yet"
        case .notes: return "No notes yet"
        case .takes: return "No takes yet"
        }
    }

    private var emptyMessage: String {
        if searching {
            return "Nothing matches “\(query)”. Try a song, exercise, template, or date."
        }
        if pinnedOnly {
            // Says where the gesture is, because the hold menu is the only place it lives and a menu
            // is exactly the affordance a player cannot see from here (ADR 0190 D3).
            return "Hold any row and choose Pin to keep it here. Turn off Pinned only to see "
                + "everything again."
        }
        switch scope {
        case .all:
            return "Notes you write and takes you record gather here — from your loops and "
                + "exercises, or straight from this screen."
        case .notes:
            // This is the line that teaches the ＋ exists, so it is doing more work than it looks
            // (ADR 0155). Before that button, "after a run" was the only true answer.
            return "Jot a goal, a breakthrough or a struggle — after a run, or any time with ＋."
        case .takes:
            return "Arm recording next to Start training to capture your playing."
        }
    }
}
