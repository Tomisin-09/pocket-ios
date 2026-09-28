import Foundation

/// A loop's saved **piece** as the Journal shows it (ADR 0229): **one row per loop**, drawn from the piece
/// itself, so it is always the current version. Saving again moves it rather than adding a row, which is
/// what a line per save did (ADR 0225 D7), and there is no text to edit apart from the piece.
///
/// Pure and SwiftUI-free, like the rest of `JournalTimeline`, so which pieces show and when is tested.
struct JournalPiece {
    let loop: Loop
    let piece: PieceTranscription
    /// When the piece last changed, which is where it sits on the feed.
    let date: Date

    /// The pieces on these loops, for the feed. A piece saved before ADR 0229 has no date until
    /// `PieceDateBackfill` runs; until then it takes the loop's latest 🧩 *Transcribed* line, which every
    /// save wrote. One with neither is left out rather than dated to a day it wasn't made.
    static func all(in loops: [Loop]) -> [JournalPiece] {
        loops.compactMap { loop in
            guard loop.transcriptionData != nil, let piece = loop.transcription,
                  let date = piece.changedAt ?? latestLine(on: loop) else { return nil }
            return JournalPiece(loop: loop, piece: piece, date: date)
        }
    }

    /// When the loop's newest 🧩 line was written, or `nil` when it has none.
    static func latestLine(on loop: Loop) -> Date? {
        loop.journal.filter { $0.kind == .transcribed }.map(\.createdAt).max()
    }
}
