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
            let echo = echo(of: section, in: map, pieces: pieces)
            let rows = SongMapLayout.rowSpans(from: section.start, to: section.end, grid: map.grid,
                                              barsPerRow: barsPerRow, secondsPerRow: secondsPerRow)
                .map { span -> SongTab.Row in
                    let own = row(from: span.start, to: span.end, grid: map.grid, pieces: pieces, spelling: spelling)
                    return echo.map { writing($0, into: own, spelling: spelling) } ?? own
                }
            return SongTab.Section(heading: section.heading, start: section.start, end: section.end,
                                   bars: section.bars, rows: rows, sameAs: section.sameAs)
        }
        return SongTab(scale: map.scale, sections: sections)
    }

    static func row(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?,
                    pieces: [SongMap.Piece], spelling: NoteSpelling) -> SongTab.Row {
        let fullRow = grid.map { $0.barSeconds * Double(barsPerRow) } ?? secondsPerRow
        let lines = lines(from: start, to: end, pieces: pieces, spelling: spelling)
        return SongTab.Row(start: start, end: end, widthFraction: min(1, max(0, (end - start) / fullRow)),
                           ticks: SongMapLayout.ticks(from: start, to: end, grid: grid, secondsPerTick: secondsPerTick),
                           lines: lines, pieces: drew(lines))
    }

    /// The pieces that drew some lines, in the order their first taps come. A pass of a repeat is its loop's.
    static func drew(_ lines: [SongTab.Line]) -> [UUID] {
        var drew: [UUID] = []
        for column in lines.flatMap(\.columns).sorted(by: { $0.time < $1.time }) where !drew.contains(column.piece) {
            drew.append(column.piece)
        }
        return drew
    }

    // MARK: - Lines

    /// Chords above notes, then by lane, as on the board. A lane with nothing to draw in the row has no
    /// line: an empty loop and one tagged 🧩 by hand read as a gap (D4).
    static func lines(from start: TimeInterval, to end: TimeInterval, pieces: [SongMap.Piece],
                      spelling: NoteSpelling) -> [SongTab.Line] {
        SongMap.Layer.allCases.flatMap { layer -> [SongTab.Line] in
            // Within the board's tolerance, so the two views agree on which pieces a row holds.
            let tolerance = SongMapLayout.tolerance
            let here = pieces.filter {
                $0.layer == layer && $0.start < end - tolerance && $0.reach > start + tolerance
            }
            return Set(here.map(\.lane)).sorted().compactMap { lane in
                line(layer: layer, lane: lane, pieces: here.filter { $0.lane == lane },
                     during: start..<end, spelling: spelling)
            }
        }
    }

    /// One lane's taps in a row's stretch of the song. It's tab when any of them was placed on the neck, on
    /// the strings of the piece with the most of them. A loop that repeats is written out on every pass
    /// (D18), with *↻ ×8* where its repeats begin.
    static func line(layer: SongMap.Layer, lane: Int, pieces: [SongMap.Piece],
                     during row: Range<TimeInterval>, spelling: NoteSpelling) -> SongTab.Line? {
        var columns: [SongTab.Column] = []
        var staff: [Int] = []
        for piece in pieces {
            guard case .piece(let transcription) = piece.content else { continue }
            for sound in sounds(of: transcription, in: piece, during: row) {
                let column = column(sound.index, of: transcription, piece: piece.uid, layer: layer,
                                    spelling: spelling)
                if column.mark.isFrets, let openMidi = transcription.openMidi, openMidi.count > staff.count {
                    staff = openMidi
                }
                columns.append(column.moved(to: sound.time))
            }
        }
        columns.sort { $0.time < $1.time }
        // A sign goes in front of the tap it shares a time with, so it reads before the pass it begins.
        for sign in pieces.compactMap({ repeatSign($0, during: row) }) {
            columns.insert(sign, at: columns.firstIndex { $0.time >= sign.time - epsilon } ?? columns.endIndex)
        }
        guard !columns.isEmpty else { return nil }
        return SongTab.Line(layer: layer, lane: lane,
                            strings: staff.isEmpty ? [] : TabLine.stringNames(openMidi: staff), columns: columns)
    }

    /// How far a hair before a row's start still counts as in it. A pass lands on a row's start by
    /// arithmetic, and a hair either side of it must still land in one row, not both or neither.
    static let epsilon: TimeInterval = 0.000_001

    /// When a piece's taps sound in a row: each tap inside the loop, then again on every pass while it
    /// repeats (D18), up to where the repeats end. Only a tap inside the loop plays, so only those repeat.
    /// The loop's start is read within the board's tolerance: its edges read back a hair off, and a copy's
    /// first tap sits exactly on it (D16).
    static func sounds(of transcription: PieceTranscription, in piece: SongMap.Piece,
                       during row: Range<TimeInterval>) -> [(index: Int, time: TimeInterval)] {
        let length = piece.end - piece.start
        let from = row.lowerBound - epsilon
        let upTo = min(row.upperBound, piece.repeats?.end ?? piece.end) - epsilon
        return transcription.taps.indices.flatMap { index -> [(index: Int, time: TimeInterval)] in
            let seconds = transcription.taps[index].seconds
            guard seconds > piece.start - SongMapLayout.tolerance, seconds < piece.end else { return [] }
            // `repeats` is only there when a pass has length (`SongMapLayout.repeats`).
            let passes = piece.repeats == nil ? 1 : Int(((upTo - seconds) / length).rounded(.up))
            return (0..<max(passes, 1)).map { seconds + Double($0) * length }
                .filter { $0 >= from && $0 < upTo }
                .map { (index: index, time: $0) }
        }
    }

    /// Where a loop's repeats begin (D14), when that's in this row: *↻ ×8*, the count said once.
    static func repeatSign(_ piece: SongMap.Piece, during row: Range<TimeInterval>) -> SongTab.Column? {
        guard let repeats = piece.repeats,
              piece.end >= row.lowerBound - epsilon, piece.end < row.upperBound - epsilon else { return nil }
        return SongTab.Column(time: piece.end, piece: piece.uid, mark: .repeats(repeats.passes),
                              name: "\(piece.name) repeats, \(repeats.passes) times in all")
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
