import Foundation
import SwiftData

/// Stamps a date onto every **piece saved before ADR 0229**, run at launch beside the other backfills.
///
/// Until 0229 a piece had no date of its own: each save wrote a dated 🧩 line to the Journal instead. Now
/// the Journal shows the piece itself, dated by `PieceTranscription.changedAt`, and a player who deletes
/// the old lines must not lose the piece from the feed with them. So each undated piece takes its loop's
/// newest 🧩 line, the save that made it, and a piece with no line left takes today, the first day it
/// shows.
///
/// **Runs every launch**, not once: a piece restored from an archive written before 0229 arrives undated
/// too. It costs a fetch of the loops and a decode of the few that hold a piece, and it only ever writes
/// to an undated one, so a re-run changes nothing.
enum PieceDateBackfill {

    /// Date every undated piece in the store. Fetches **all** loops and filters in memory, never an
    /// optional `#Predicate` (the SwiftData optional-predicate freeze).
    static func run(into context: ModelContext, now: Date = .now) {
        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        // Every loop is visited: `map` first, so a `contains` can't stop at the first write.
        guard loops.map({ apply(to: $0, now: now) }).contains(true) else { return }
        try? context.save()
    }

    /// The per-loop rule, apart from the store so it's unit-tested. Returns whether it wrote.
    @discardableResult
    static func apply(to loop: Loop, now: Date) -> Bool {
        guard loop.transcriptionData != nil, var piece = loop.transcription, piece.changedAt == nil
        else { return false }
        piece.changedAt = JournalPiece.latestLine(on: loop) ?? now
        loop.transcription = piece
        return true
    }
}
