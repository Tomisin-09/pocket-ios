import Foundation

/// A loop's repeats on the map (ADR 0232 D14, D15): where they stop, how many passes that is, and the ways
/// the hold menu offers to set them. The player's word, never detected, and drawn as a band, never copies.
extension SongMapLayout {

    /// Where the section a loop sits in ends: the one holding its middle, so a loop that starts a beat
    /// early still belongs to the section it plays in. The song's end when there are no sections.
    static func sectionEnd(from start: TimeInterval, to end: TimeInterval, spans: [Span],
                           duration: TimeInterval) -> TimeInterval {
        let middle = (start + end) / 2
        return spans.first { $0.start <= middle && middle < $0.end }?.end ?? duration
    }

    /// Where a loop's repeats stop (D15), and how far they read as reaching now. A section named that's
    /// gone, or that ends no later than the loop's own, is its own section's end; one reaching the song's
    /// end is the song's end, so the menu ticks the choice that says so.
    static func repeatEnd(_ reach: SongMap.RepeatsTo, sectionEnd: TimeInterval, spans: [Span],
                          duration: TimeInterval) -> (to: SongMap.RepeatsTo, end: TimeInterval) {
        let end: TimeInterval
        switch reach {
        case .sectionEnd:
            end = sectionEnd
        case .songEnd:
            end = duration
        case .through(let uid):
            end = spans.first { span in
                if case .marker(let marker, _) = span.heading { return marker == uid }
                return false
            }?.end ?? sectionEnd
        }
        if end <= sectionEnd + tolerance { return (.sectionEnd, sectionEnd) }
        if end >= duration - tolerance { return (.songEnd, duration) }
        return (reach, end)
    }

    /// A loop's repeats, from its end to where they stop, when there's room for at least half a pass more,
    /// so there's something to draw. The count is to the nearest whole pass; the band still runs all the
    /// way, because that's what the player said.
    static func repeats(from start: TimeInterval, to end: TimeInterval,
                        sectionEnd: TimeInterval) -> SongMap.Repeat? {
        let length = end - start
        guard length > tolerance, sectionEnd - end >= length / 2 else { return nil }
        return SongMap.Repeat(end: sectionEnd, passes: Int(((sectionEnd - start) / length).rounded()))
    }

    /// The part of a loop's repeats that falls in a row.
    static func band(_ piece: SongMap.Piece, from start: TimeInterval, to end: TimeInterval) -> SongMap.Band? {
        guard let repeats = piece.repeats else { return nil }
        let from = max(piece.end, start), upTo = min(repeats.end, end)
        guard upTo - from > tolerance else { return nil }
        return SongMap.Band(uid: piece.uid, start: from, end: upTo,
                            continuesBefore: from > piece.end + tolerance,
                            continuesAfter: repeats.end > end + tolerance, passes: repeats.passes)
    }

    /// How far a piece's repeats can run (D15), nearest first: to the end of its section, on through each
    /// later section but the last, and to the end of the song. Each is offered only with room for half a
    /// pass more. Without sections, the song's end is its section's end, so that's the only one.
    static func repeatChoices(for piece: SongMap.Piece, in map: SongMap) -> [SongMap.RepeatChoice] {
        struct Reach { let to: SongMap.RepeatsTo, title: String, end: TimeInterval }
        let songEnd = map.sections.last?.end ?? piece.sectionEnd
        var reaches = [Reach(to: .sectionEnd, title: map.hasSections ? "To the end of the section"
                                                                      : "To the end of the song",
                             end: piece.sectionEnd)]
        let later = map.sections.filter {
            $0.start >= piece.sectionEnd - tolerance && $0.end < songEnd - tolerance
        }
        let labels = later.compactMap { section -> String? in
            if case .marker(_, let label) = section.heading { return label }
            return nil
        }
        for section in later {
            guard case .marker(let uid, let label) = section.heading else { continue }
            let name = label.isEmpty ? "Section" : label
            // Two sections called *Chorus* are told apart by where they start.
            let place = labels.filter { $0 == label }.count > 1
                ? ", " + (section.bars.map { "bar \($0.lowerBound)" } ?? timecode(section.start)) : ""
            reaches.append(Reach(to: .through(uid), title: "Through \(name)\(place)", end: section.end))
        }
        if piece.sectionEnd < songEnd - tolerance {
            reaches.append(Reach(to: .songEnd, title: "To the end of the song", end: songEnd))
        }
        return reaches.compactMap { reach in
            repeats(from: piece.start, to: piece.end, sectionEnd: reach.end).map {
                SongMap.RepeatChoice(to: reach.to, title: reach.title, passes: $0.passes)
            }
        }
    }
}
