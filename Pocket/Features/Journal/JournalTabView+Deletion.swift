import SwiftUI

/// **Removing things from the Journal feed** (ADR 0100 amendment, 2026-08-05).
///
/// ADR 0100 made this space read-only — reflection, not authoring — and ADR 0143 opened exactly one
/// crack in it: a *session* note belongs to no unit, so no per-owner sheet could ever reach it. That
/// rule turned out to be one the app's own designer forgot while using it (device pass 2026-08-05),
/// and a rule the designer forgets is not one a player will hold. So delete now reaches **every** row
/// here. Editing does not: that still lives in the per-owner `JournalSheet` (ADR 0142 J2). This adds
/// removal, not a third editing surface.
///
/// Split out of `JournalTabView` for the 400-line cap, the same reason `JournalTakeRow` was.
extension JournalTabView {

    /// The **hold menu** — the *only* way to delete from this feed, deliberately.
    ///
    /// Every other list in the app deletes on a trailing swipe. This one doesn't, because the cost of
    /// the mistake is different in kind: a deleted exercise or routine can be rebuilt from the same
    /// idea, but a note about how a session actually went — and a take of someone playing — has no
    /// source to regenerate it from. A swipe is the cheapest gesture in a list and the easiest to
    /// trigger while scrolling, and the Undo window is four seconds, which only helps if you noticed.
    /// A hold is deliberate, so the gesture now costs about what the mistake does. Rename keeps its
    /// swipe: it destroys nothing.
    ///
    /// A note gets Delete; a take gets Rename first, because renaming is the verb you reach for
    /// repeatedly and deleting is the one you reach for once.
    ///
    /// `role: .destructive` is right **here** and would be wrong on a swipe. In a menu it only colours
    /// the label; on a swipe button it plays SwiftUI's own row-removal animation the moment it's
    /// tapped, which under a *deferred* delete means the row leaves on a lie and never comes back on
    /// Undo. The row disappears here because `items` filters out anything pending — and reappears for
    /// the same reason.
    @ViewBuilder func holdMenu(for item: JournalTimeline.Item) -> some View {
        if case .take(let take) = item {
            Button {
                renaming = StableRef(value: take)
            } label: {
                Label(take.title == nil ? "Name this take" : "Rename", systemImage: "pencil")
            }
        }
        Button(role: .destructive) {
            requestDelete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Hide the row, raise the Undo toast, and schedule the real delete for when the window closes.
    ///
    /// A take's **audio file** goes with it (ADR 0069 retention) — and the deferral is precisely what
    /// makes offering that safe: nothing is removed from disk while Undo is still on screen. The
    /// player is stopped up front rather than in the deferred closure, since hearing a take you just
    /// deleted keep playing is its own kind of wrong.
    func requestDelete(_ item: JournalTimeline.Item) {
        let context = modelContext
        switch item {
        case .note(let entry):
            rowDeletion.request(PocketRowDelete(id: item.id, name: name(of: item)) {
                JournalWriter.delete(entry, from: context)
                try? context.save()
            })
        case .take(let take):
            if player.isPlaying(take.fileName) { player.stop() }
            rowDeletion.request(PocketRowDelete(id: item.id, name: name(of: item)) {
                try? RecordingStore.delete(fileName: take.fileName)
                context.delete(take)
                try? context.save()
            })
        }
        haptic(.light)
    }

    /// What the toast calls the row — "Deleted this take". Deliberately short: a note's own text is
    /// often a paragraph, and a toast is not the place to quote it back.
    private func name(of item: JournalTimeline.Item) -> String {
        switch item {
        case .note(let entry):
            if case .session = entry.ownerKind { return "this session note" }
            return "this note"
        case .take(let take):
            return take.title.map { "“\($0)”" } ?? "this take"
        }
    }
}
