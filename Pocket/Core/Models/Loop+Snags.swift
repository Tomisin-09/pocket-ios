import Foundation

/// A snag on a loop's piece (ADR 0234 D7): the mark, and the note it falls on, if one is near enough.
struct PieceSnag {
    let snag: Snag
    let note: Int?
}

extension Loop {
    /// The song's snags inside this loop's span, in song order, each with the tap of `taps` it falls on.
    /// Inside the span, not tagged with this loop: the positional rule the practice screen draws by (ADR
    /// 0203 D1), so a stumble marked with no loop armed still lands on the note it caught on.
    func snags(onTaps taps: [TimeInterval]) -> [PieceSnag] {
        guard let song else { return [] }
        let region = startSeconds...max(startSeconds, endSeconds)
        return song.snags
            .filter { region.contains($0.seconds) }
            .sorted { ($0.seconds, $0.uid.uuidString) < ($1.seconds, $1.uid.uuidString) }
            .map { PieceSnag(snag: $0, note: SnagOnPiece.note(at: $0.seconds, taps: taps)) }
    }

    /// The same, on the piece in use; none when the loop has no piece.
    var snagsOnPiece: [PieceSnag] {
        guard let piece = transcription else { return [] }
        return snags(onTaps: piece.taps.map(\.seconds))
    }

    /// The note of the piece in use that snag `uid` falls on, or `nil`: gone, outside the span, or too far
    /// from any tap.
    func pieceNote(forSnag uid: UUID) -> Int? {
        snagsOnPiece.first { $0.snag.uid == uid }?.note
    }
}

extension Loop {
    /// The line written on snag `uid`, the latest if there's more than one: a note that carries the snag's
    /// id (ADR 0234 D7), in **any** of the song's loops' Journals (ADR 0238). The waveform writes a new line
    /// to the loop the snag was made under, which may not be this one, and it has to show here too.
    func line(forSnag uid: UUID) -> JournalEntry? {
        SnagLine.lines(in: (song?.loops ?? [self]).flatMap(\.journal))[uid]
    }
}
