import Foundation

/// Draws a song's tab from its map (ADR 0232 D10): the board's sections, in rows of 4 bars (8 seconds
/// without a grid), with a line for every lane that has taps in the row. Nothing is snapped: a column
/// sits at its tap's time, and is only nudged when it would print over the one before.
///
/// Widths are in **characters**. The tab is set in a fixed-width font, as tab is, so a column's width is
/// its length and the view turns characters into points once.
enum SongTabLayout {

    /// Bars in a full row: half the board's, so a bar has room for what's in it.
    static let barsPerRow = 4
    /// Seconds in a full row when the song has no grid.
    static let secondsPerRow: TimeInterval = 8
    /// How far apart the time marks are in seconds scale.
    static let secondsPerTick: TimeInterval = 2
    /// Characters kept clear between two columns.
    static let gap: Double = 1
    /// How far a column sits after its time, so a note on the beat doesn't print over the bar line.
    static let lead: Double = 0.5

    static func build(_ map: SongMap, spelling: NoteSpelling) -> SongTab {
        let pieces = map.pieces.values.sorted {
            $0.start == $1.start ? $0.uid.uuidString < $1.uid.uuidString : $0.start < $1.start
        }
        let sections = map.sections.map { section in
            let rows = SongMapLayout.rowSpans(from: section.start, to: section.end, grid: map.grid,
                                              barsPerRow: barsPerRow, secondsPerRow: secondsPerRow)
                .map { row(from: $0.start, to: $0.end, grid: map.grid, pieces: pieces, spelling: spelling) }
            return SongTab.Section(heading: section.heading, start: section.start, end: section.end,
                                   bars: section.bars, rows: rows, sameAs: section.sameAs)
        }
        return SongTab(scale: map.scale, sections: sections)
    }

    static func row(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?,
                    pieces: [SongMap.Piece], spelling: NoteSpelling) -> SongTab.Row {
        let fullRow = grid.map { $0.barSeconds * Double(barsPerRow) } ?? secondsPerRow
        let lines = lines(from: start, to: end, pieces: pieces, spelling: spelling)
        // The pieces that drew it, in the order their first taps (or their repeats) come.
        let marks = lines.flatMap(\.columns).map { (time: $0.time, piece: $0.piece) }
            + lines.flatMap(\.repeats).map { (time: $0.start, piece: $0.piece) }
        var drew: [UUID] = []
        for mark in marks.sorted(by: { $0.time < $1.time }) where !drew.contains(mark.piece) {
            drew.append(mark.piece)
        }
        return SongTab.Row(start: start, end: end, widthFraction: min(1, max(0, (end - start) / fullRow)),
                           ticks: SongMapLayout.ticks(from: start, to: end, grid: grid, secondsPerTick: secondsPerTick),
                           lines: lines, pieces: drew)
    }

    // MARK: - Lines

    /// Chords above notes, then by lane, as on the board. A lane with nothing to draw in the row has no
    /// line: an empty loop and one tagged 🧩 by hand read as a gap (D4).
    static func lines(from start: TimeInterval, to end: TimeInterval, pieces: [SongMap.Piece],
                      spelling: NoteSpelling) -> [SongTab.Line] {
        SongMap.Layer.allCases.flatMap { layer -> [SongTab.Line] in
            let here = pieces.filter { $0.layer == layer && $0.start < end && $0.reach > start }
            return Set(here.map(\.lane)).sorted().compactMap { lane in
                line(layer: layer, lane: lane, pieces: here.filter { $0.lane == lane },
                     during: start..<end, spelling: spelling)
            }
        }
    }

    /// One lane's taps in a row's stretch of the song. It's tab when any of them was placed on the neck, on
    /// the strings of the piece with the most of them.
    static func line(layer: SongMap.Layer, lane: Int, pieces: [SongMap.Piece],
                     during row: Range<TimeInterval>, spelling: NoteSpelling) -> SongTab.Line? {
        var columns: [SongTab.Column] = []
        var staff: [Int] = []
        let repeats = pieces.compactMap { repeatMark($0, during: row) }
        for piece in pieces {
            guard case .piece(let transcription) = piece.content else { continue }
            let from = max(piece.start, row.lowerBound), upTo = min(piece.end, row.upperBound)
            for index in transcription.taps.indices {
                let seconds = transcription.taps[index].seconds
                guard seconds >= from, seconds < upTo else { continue }
                let column = column(index, of: transcription, piece: piece.uid, layer: layer, spelling: spelling)
                if column.mark.isFrets, let openMidi = transcription.openMidi, openMidi.count > staff.count {
                    staff = openMidi
                }
                columns.append(column)
            }
        }
        guard !columns.isEmpty || !repeats.isEmpty else { return nil }
        return SongTab.Line(layer: layer, lane: lane,
                            strings: staff.isEmpty ? [] : TabLine.stringNames(openMidi: staff),
                            columns: columns.sorted { $0.time < $1.time }, repeats: repeats)
    }

    /// A loop's repeats in a row's stretch (D14), as a label: the chart writes the progression once and
    /// says it repeats, so its taps are never drawn again.
    static func repeatMark(_ piece: SongMap.Piece, during row: Range<TimeInterval>) -> SongTab.RepeatMark? {
        guard let repeats = piece.repeats else { return nil }
        let from = max(piece.end, row.lowerBound), upTo = min(repeats.end, row.upperBound)
        guard upTo - from > SongMapLayout.tolerance else { return nil }
        return SongTab.RepeatMark(piece: piece.uid, name: piece.name, start: from, end: upTo,
                                  passes: repeats.passes, continues: from > piece.end + SongMapLayout.tolerance)
    }

    /// One tap as the tab draws it. In the chords layer it's the chord's symbol, however it was named
    /// (D10: *chord symbols sit at their taps*). In the notes layer, notes on the neck are tab, and a name
    /// given by ear is the name. A tap with no name, or one that can't be read, is a slash.
    static func column(_ index: Int, of transcription: PieceTranscription, piece: UUID, layer: SongMap.Layer,
                       spelling: NoteSpelling) -> SongTab.Column {
        let tap = transcription.taps[index]
        let name = tap.label?.name(openMidi: transcription.openMidi ?? [], spelling: spelling)
        let mark: SongTab.Mark
        if layer == .notes, let cells = cells(index, of: transcription) {
            mark = .frets(cells)
        } else {
            mark = name.map(SongTab.Mark.name) ?? .slash
        }
        return SongTab.Column(time: tap.seconds, piece: piece, mark: mark, name: name)
    }

    /// A tap's notes on the neck, a cell per string as `TabLine` writes it, with the join from the tap
    /// before in front (`h7`, `/9`). `nil` when none of them sits on a string the tuning has.
    static func cells(_ index: Int, of transcription: PieceTranscription) -> [SongTab.FretCell]? {
        let openMidi = transcription.openMidi ?? []
        let labels = transcription.labels
        let notes = (labels[index]?.frettedNotes ?? []).filter {
            openMidi.indices.contains($0.string) && $0.fret >= 0
        }
        guard !notes.isEmpty else { return nil }
        let join = NeckJoin.symbol(into: index, of: labels) ?? ""
        return notes.sorted { $0.string < $1.string }.map {
            SongTab.FretCell(string: $0.string, text: join + TabLine.cell($0))
        }
    }

    // MARK: - Fitting

    /// Where each column's left edge goes, in characters from the row's start, in a row `width`
    /// characters wide. A column sits just after its time. One that would print over the column before
    /// is pushed right just far enough to clear it, and a line pushed past the row's end is drawn back
    /// from the end, so the order of the taps is always kept and nothing overlaps.
    static func spread(_ columns: [SongTab.Column], in row: SongTab.Row, width: Double) -> [Double] {
        var placed: [Double] = []
        for (index, column) in columns.enumerated() {
            let atTime = row.position(of: column.time) * width + lead
            let clear = index == 0 ? 0 : placed[index - 1] + Double(columns[index - 1].width) + gap
            placed.append(max(atTime, clear))
        }
        var limit = width
        for index in placed.indices.reversed() {
            placed[index] = min(placed[index], limit - Double(columns[index].width))
            limit = placed[index] - gap
        }
        return placed
    }

    /// The width a row draws at, in characters: the width it has, or, when a line holds more than fits,
    /// just wide enough for it. The row then scrolls sideways, and its bar lines stretch with it, so a
    /// fast run is never squeezed into overprinting.
    static func width(of row: SongTab.Row, available: Double) -> Double {
        let needed = row.lines.map { line -> Double in
            let widths = line.columns.map { Double($0.width) }.reduce(0, +)
            let gaps = gap * Double(max(line.columns.count - 1, 0))
            return lead + widths + gaps
        }
        return max(available, needed.max() ?? 0)
    }
}
