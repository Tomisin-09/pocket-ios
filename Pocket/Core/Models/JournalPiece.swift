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

/// One song's pieces under the **Pieces** scope (ADR 0232 D20): the cross-song way into *Map the song*, so
/// the Journal groups by song there rather than by day.
///
/// The pieces run in **song order**, where each loop starts, because that's how the map lays them out and
/// how the song plays; the songs run by when their newest piece changed, so the song being worked on is at
/// the top. Pure, like `JournalTimeline`, so both orders are tested.
struct JournalSongPieces: Identifiable {
    /// `nil` for a loop with no song, which the Journal still shows but can't map.
    let song: Song?
    /// Never empty, in song order.
    let pieces: [JournalPiece]
    /// When the song's newest piece last changed.
    let latest: Date

    /// The first piece's loop, which stands for the song where an identity is needed: `Song` has no `uid`,
    /// and a `persistentModelID` can change under a save (ADR 0090).
    var lead: Loop { pieces[0].loop }
    var id: UUID { lead.uid }

    /// The pieces among `items`, one group per song. Newest puts the song changed most recently first, and
    /// oldest turns that round; the order within a song is the song's own either way. Pieces with no song
    /// come last.
    static func group(_ items: [JournalTimeline.Item],
                      order: JournalTimeline.SortOrder) -> [JournalSongPieces] {
        let pieces = items.compactMap { item -> JournalPiece? in
            if case .piece(let piece) = item { piece } else { nil }
        }
        let bySong = Dictionary(grouping: pieces) { $0.loop.song.map(ObjectIdentifier.init) }
        let groups = bySong.values.map { pieces in
            JournalSongPieces(song: pieces[0].loop.song,
                              pieces: pieces.sorted(by: playsFirst),
                              latest: pieces.map(\.date).max() ?? .distantPast)
        }
        let songs = groups.filter { $0.song != nil }.sorted(by: changedFirst)
        return (order == .newest ? songs : songs.reversed()) + groups.filter { $0.song == nil }
    }

    /// Where it starts in the song; a tie (two pieces starting together) goes to the shorter, as the map's
    /// lanes do, then to the uid so the order never changes from one redraw to the next.
    private static func playsFirst(_ lhs: JournalPiece, _ rhs: JournalPiece) -> Bool {
        if lhs.loop.start != rhs.loop.start { return lhs.loop.start < rhs.loop.start }
        if lhs.loop.end != rhs.loop.end { return lhs.loop.end < rhs.loop.end }
        return lhs.loop.uid.uuidString < rhs.loop.uid.uuidString
    }

    /// The song changed most recently first; songs changed at the same moment by title.
    private static func changedFirst(_ lhs: JournalSongPieces, _ rhs: JournalSongPieces) -> Bool {
        if lhs.latest != rhs.latest { return lhs.latest > rhs.latest }
        return (lhs.song?.title ?? "").localizedStandardCompare(rhs.song?.title ?? "") == .orderedAscending
    }
}
