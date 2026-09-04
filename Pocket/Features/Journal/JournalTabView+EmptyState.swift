import SwiftUI

/// **What the Journal space says when it has nothing to show** — and, since ADR 0190, *why*.
///
/// Split out of `JournalTabView` for the 400-line cap, the same reason `JournalTakeRow` and
/// `JournalTabView+Deletion` were. It earns a file rather than a few lines because the screen now has
/// four ways to be empty and they mean different things: a journal with nothing in it yet, a search
/// that matched nothing, and **either of two filters the player left on**. Only the first is good
/// news.
///
/// The rule this file exists to hold (ADR 0190 D8): **the empty state names the thing that emptied
/// it.** A persisted filter is only safe when the screen admits it is in force — the options glyph
/// fills, and if the result is nothing at all, this text says which filter did it and how to undo it.
/// Without that, a player who left *Pinned only* on comes back to a year-old journal showing nothing
/// and reasonably concludes the app lost it. The owner filter (ADR 0190 D5) arrives under the same
/// obligation and is the more dangerous of the two, because *Show ▸ Session* narrows a full journal
/// to nothing for a player who has never run a routine — a state the app can reach on its own.
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
        if pinnedOnly { return "pin" }
        // The one glyph that says "a filter is on" without naming which — the same
        // `line.3.horizontal.decrease.circle` `LibraryOptionsMenu` gives its widen filter. The words
        // below do the naming; a per-kind glyph here would say it twice and agree only by luck.
        if ownerFilter.isFiltering { return "line.3.horizontal.decrease.circle" }
        return "book.closed"
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
        // Both filters are named when both are on. A title that reported only one would send the
        // player to turn that one off and leave them on a screen still empty for the other reason,
        // which is the same wrong conclusion this whole file exists to prevent.
        if pinnedOnly { return "No pinned \(scopeNoun)\(underOwner)" }
        if ownerFilter.isFiltering { return "No \(scopeNoun)\(underOwner)" }
        switch scope {
        case .all: return "Nothing here yet"
        case .notes: return "No notes yet"
        case .takes: return "No takes yet"
        }
    }

    /// " under Loop or Session" — the ticked kinds as a trailing phrase, empty when none are.
    ///
    /// It quotes the sheet's own rows **verbatim** rather than inflecting nouns of its own: *Just me*
    /// has no lower-case form that survives being pushed into a sentence ("no just me entries"), and
    /// a second wording for a filter is a second thing to keep in step with the control.
    ///
    /// **Every ticked kind is named, and joined with "or".** A count would be shorter and would lose
    /// the two things this sentence exists to give: which filters are on, and that they are a union
    /// (ADR 0159 §3). There are at most five.
    private var underOwner: String {
        guard let phrase = ownerFilter.phrase else { return "" }
        return " under \(phrase)"
    }

    private var emptyMessage: String {
        if searching {
            return "Nothing matches “\(query)”. Try a song, exercise, template, or date."
        }
        if pinnedOnly, let phrase = ownerFilter.phrase {
            // **Both routes, because both filters are on.** Offering only the pin sends the player to
            // turn it off and leaves them on a screen still empty under the ticked kinds — the
            // same wrong conclusion this file exists to prevent, reached one step later. Found by
            // looking at the built screen: the title said both and the sentence under it said one.
            return "Nothing you have pinned is filed under \(phrase). Turn off Pinned "
                + "only, or open ⋯ ▸ Show and choose All."
        }
        if pinnedOnly {
            // Says where the gesture is, because the hold menu is the only place it lives and a menu
            // is exactly the affordance a player cannot see from here (ADR 0190 D3).
            return "Hold any row and choose Pin to keep it here. Turn off Pinned only to see "
                + "everything again."
        }
        if let phrase = ownerFilter.phrase {
            // Names the route, not the state, because the player has to undo this from a menu they
            // cannot see from here. **Every word is something on that menu**: ⋯ opens it, *Show* is
            // a row on it, *All* is the first row of the sheet that opens. An instruction naming a
            // control that isn't drawn is worse than none — this line first said "Set Show back to
            // All" while the picker rendered inline with no title at all, which is what sent the
            // picker out of the menu altogether.
            return "Nothing in your journal is filed under \(phrase). "
                + "Open ⋯ ▸ Show and choose All to see everything again."
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
