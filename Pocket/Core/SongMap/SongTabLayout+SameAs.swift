import Foundation

/// A section that's the same as an earlier one (ADR 0232 D8) has the earlier one's bars written out in the
/// tab (D19), so its chords and notes read where they play rather than a scroll away. They're drawn from
/// the earlier section's pieces every time and never stored, so change one and both sections change.
extension SongTabLayout {

    /// What a section that's the same as an earlier one writes out.
    struct Echo: Equatable, Sendable {
        /// The earlier section's stretch of the song.
        let source: Range<TimeInterval>
        /// How far on its bars are written.
        let shift: TimeInterval
        /// The pieces that draw in the earlier section, less any repeat that plays on into this one: that
        /// draws here as itself, and would otherwise be written twice.
        let pieces: [SongMap.Piece]
    }

    static func echo(of section: SongMap.Section, in map: SongMap, pieces: [SongMap.Piece]) -> Echo? {
        guard let named = section.sameAs, let source = map.sections.first(where: {
            if case .marker(let uid, _) = $0.heading { return uid == named.uid }
            return false
        }) else { return nil }
        let tolerance = SongMapLayout.tolerance
        let theirs = pieces.filter {
            $0.start < source.end - tolerance && $0.reach > source.start + tolerance
                && !($0.repeats != nil && $0.reach > section.start + tolerance)
        }
        guard !theirs.isEmpty else { return nil }
        return Echo(source: source.start..<source.end,
                    shift: shift(from: source.start, to: section.start, grid: map.grid), pieces: theirs)
    }

    /// How far on an earlier section's bars are written in a later one. With bars, from the 1 nearest the
    /// earlier section's start to the 1 nearest the later one's, so a marker set a hair off the 1 doesn't
    /// move every chord with it. Without, from marker to marker.
    static func shift(from source: TimeInterval, to target: TimeInterval, grid: SongMapInput.Grid?) -> TimeInterval {
        guard let downbeats = grid?.downbeats, !downbeats.isEmpty else { return target - source }
        let nearest = { (time: TimeInterval) in downbeats.min { abs($0 - time) < abs($1 - time) } ?? time }
        return nearest(target) - nearest(source)
    }

    /// A row of the later section, with the earlier section's matching bars written in on lines of their
    /// own, above its own lines in each layer. They're written only as far as the earlier section runs: a
    /// longer section has empty bars after them.
    static func writing(_ echo: Echo, into row: SongTab.Row, spelling: NoteSpelling) -> SongTab.Row {
        let from = max(row.start - echo.shift, echo.source.lowerBound)
        let upTo = min(row.end - echo.shift, echo.source.upperBound)
        guard upTo - from > SongMapLayout.tolerance else { return row }
        let written = lines(from: from, to: upTo, pieces: echo.pieces, spelling: spelling).map { line in
            SongTab.Line(layer: line.layer, lane: line.lane, strings: line.strings,
                         columns: line.columns.map { $0.moved(to: $0.time + echo.shift) }, isSameAs: true)
        }
        guard !written.isEmpty else { return row }
        let lines = (written + row.lines).sorted { lhs, rhs in
            if lhs.layer != rhs.layer { return lhs.layer < rhs.layer }
            if lhs.isSameAs != rhs.isSameAs { return lhs.isSameAs }
            return lhs.lane < rhs.lane
        }
        return SongTab.Row(start: row.start, end: row.end, widthFraction: row.widthFraction, ticks: row.ticks,
                           lines: lines, pieces: drew(lines), sourceStart: row.lines.isEmpty ? from : nil)
    }
}
