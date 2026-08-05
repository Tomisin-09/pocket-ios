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

    /// The trailing swipe's Delete, for any row on the feed.
    ///
    /// **Never `role: .destructive`.** A destructive swipe button plays SwiftUI's own row-removal
    /// animation the instant it is tapped, whether or not the data changed — which under a *deferred*
    /// delete means the row vanishes on a lie and doesn't come back on Undo. The row disappears here
    /// because `items` filters out anything pending, and reappears for the same reason.
    @ViewBuilder func deleteButton(for item: JournalTimeline.Item) -> some View {
        Button {
            requestDelete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
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
