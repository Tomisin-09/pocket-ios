import Foundation

/// Lays a song's loops out as the map's board (ADR 0232 D2–D6): sections from the markers that start
/// one, rows of 8 bars or 16 seconds, and each loop in a lane of its layer, placed where it is and never
/// snapped.
enum SongMapLayout {

    /// Bars in a full row when the song has a grid.
    static let barsPerRow = 8
    /// Seconds in a full row when it doesn't.
    static let secondsPerRow: TimeInterval = 16
    /// How far apart the time marks are in seconds scale.
    static let secondsPerTick: TimeInterval = 4
    /// A stretch before the first section shorter than this is folded into it rather than headed
    /// *Start*: a section marker dropped just after 0:00 means the song starts there.
    static let shortestLead: TimeInterval = 1
    /// Two times this close are the same place.
    static let tolerance: TimeInterval = 0.01

    static func build(_ input: SongMapInput) -> SongMap {
        let grid = input.grid.flatMap { $0.downbeats.isEmpty || $0.barSeconds <= 0 ? nil : $0 }
        let pieces = placePieces(input.loops, duration: input.duration)
        let (sectionMarkers, pinMarkers) = splitMarkers(input.markers, duration: input.duration)
        let sections = spans(of: sectionMarkers, duration: input.duration).map { span in
            let rows = rowSpans(from: span.start, to: span.end, grid: grid).map { row in
                makeRow(row, grid: grid, pins: pinMarkers, pieces: pieces)
            }
            return SongMap.Section(heading: span.heading, start: span.start, end: span.end, rows: rows,
                                   bars: grid.flatMap { barRange(from: span.start, to: span.end, in: $0) })
        }
        return SongMap(scale: grid == nil ? .seconds : .bars, sections: sections,
                       pieces: Dictionary(uniqueKeysWithValues: pieces.map { ($0.uid, $0) }), grid: grid)
    }

    // MARK: - Pieces

    /// Which layer a loop is on (D3). Its names decide: every named tap reading as a chord (a chord named
    /// by ear, or a shape on the neck that spells one, ADR 0227 D7) puts it with the chords. With no names,
    /// its type decides.
    static func layer(of loop: SongMapInput.LoopInput) -> SongMap.Layer {
        if let piece = loop.piece {
            let named = piece.taps.compactMap(\.label)
            if !named.isEmpty {
                let openMidi = piece.openMidi ?? []
                return named.allSatisfy { $0.readsAsChord(openMidi: openMidi) } ? .chords : .notes
            }
        }
        return loop.type == .chords ? .chords : .notes
    }

    static func content(of loop: SongMapInput.LoopInput) -> SongMap.Content {
        if let piece = loop.piece { return .piece(piece) }
        return loop.handTagged ? .handTagged : .empty
    }

    /// Every loop with a length inside the song, each given the lowest lane of its layer that is free
    /// where it starts. Assigned once for the whole song, so a piece keeps its lane from row to row.
    static func placePieces(_ loops: [SongMapInput.LoopInput], duration: TimeInterval) -> [SongMap.Piece] {
        struct Clamped { let loop: SongMapInput.LoopInput, start: TimeInterval, end: TimeInterval }
        let clamped = loops.compactMap { loop -> Clamped? in
            let start = min(max(loop.start, 0), duration), end = min(max(loop.end, 0), duration)
            return end - start > tolerance ? Clamped(loop: loop, start: start, end: end) : nil
        }
        // Earliest first; the longer of two that start together takes the lower lane; the uid breaks a
        // tie, so the same loops always lay out the same way.
        let ordered = clamped.sorted {
            if abs($0.start - $1.start) > tolerance { return $0.start < $1.start }
            if abs($0.end - $1.end) > tolerance { return $0.end > $1.end }
            return $0.loop.uid.uuidString < $1.loop.uid.uuidString
        }
        var laneEnds: [SongMap.Layer: [TimeInterval]] = [:]
        return ordered.map { item in
            let layer = layer(of: item.loop)
            var ends = laneEnds[layer, default: []]
            let lane = ends.firstIndex { $0 <= item.start + tolerance } ?? ends.count
            if lane == ends.count { ends.append(item.end) } else { ends[lane] = item.end }
            laneEnds[layer] = ends
            return SongMap.Piece(uid: item.loop.uid, name: item.loop.name, start: item.start, end: item.end,
                                 layer: layer, lane: lane, content: content(of: item.loop))
        }
    }

    // MARK: - Sections

    /// Markers that start a section, earliest first with duplicates at the same time dropped, and the
    /// rest, which are pins. A dropped duplicate becomes a pin so it can still be reached.
    static func splitMarkers(_ markers: [SongMapInput.MarkerInput],
                             duration: TimeInterval) -> (sections: [SongMapInput.MarkerInput],
                                                         pins: [SongMapInput.MarkerInput]) {
        let inside = markers.filter { $0.seconds >= 0 && $0.seconds < duration }
            .sorted { $0.seconds < $1.seconds }
        var sections: [SongMapInput.MarkerInput] = [], pins: [SongMapInput.MarkerInput] = []
        for marker in inside {
            if marker.startsSection,
               sections.last.map({ marker.seconds - $0.seconds > tolerance }) ?? true {
                sections.append(marker)
            } else {
                pins.append(marker)
            }
        }
        return (sections, pins)
    }

    struct Span: Equatable {
        let heading: SongMap.SectionHeading
        let start: TimeInterval
        let end: TimeInterval
    }

    /// The song cut at each section marker (D6). A short lead before the first is folded into it.
    static func spans(of sectionMarkers: [SongMapInput.MarkerInput], duration: TimeInterval) -> [Span] {
        guard duration > 0 else { return [] }
        guard let first = sectionMarkers.first else { return [Span(heading: .none, start: 0, end: duration)] }
        var spans: [Span] = []
        if first.seconds >= shortestLead { spans.append(Span(heading: .start, start: 0, end: first.seconds)) }
        for (index, marker) in sectionMarkers.enumerated() {
            let start = index == 0 && first.seconds < shortestLead ? 0 : marker.seconds
            let end = index + 1 < sectionMarkers.count ? sectionMarkers[index + 1].seconds : duration
            spans.append(Span(heading: .marker(uid: marker.uid, label: marker.label), start: start, end: end))
        }
        return spans
    }

    // MARK: - Rows

    /// Where the rows of one section break. With a grid, every eighth downbeat from the section's start,
    /// so a pickup before the first downbeat rides in the first row. Without one, every 16 seconds. The
    /// Tab view asks for shorter rows (ADR 0232 D10).
    static func rowSpans(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?,
                         barsPerRow: Int = SongMapLayout.barsPerRow,
                         secondsPerRow: TimeInterval = SongMapLayout.secondsPerRow)
        -> [(start: TimeInterval, end: TimeInterval)] {
        let breaks: [TimeInterval]
        if let grid {
            let downbeats = grid.downbeats.filter { $0 >= start - tolerance && $0 < end - tolerance }
            breaks = stride(from: barsPerRow, to: downbeats.count, by: barsPerRow).map { downbeats[$0] }
        } else {
            breaks = Array(stride(from: start + secondsPerRow, to: end - tolerance, by: secondsPerRow))
        }
        let edges = [start] + breaks.filter { $0 > start + tolerance } + [end]
        return zip(edges, edges.dropFirst()).map { ($0, $1) }
    }

    static func makeRow(_ span: (start: TimeInterval, end: TimeInterval), grid: SongMapInput.Grid?,
                        pins: [SongMapInput.MarkerInput], pieces: [SongMap.Piece]) -> SongMap.Row {
        let (start, end) = span
        let fullRow = grid.map { $0.barSeconds * Double(barsPerRow) } ?? secondsPerRow
        let lanes = SongMap.Layer.allCases.flatMap { layer -> [SongMap.Lane] in
            let here = pieces.filter { $0.layer == layer && $0.start < end && $0.end > start }
            let laneCount = (here.map(\.lane).max() ?? 0) + 1
            return (0..<laneCount).map { index in
                SongMap.Lane(layer: layer, index: index,
                             placements: here.filter { $0.lane == index }.map { place($0, from: start, to: end) })
            }
        }
        return SongMap.Row(start: start, end: end,
                           widthFraction: min(1, max(0, (end - start) / fullRow)),
                           ticks: ticks(from: start, to: end, grid: grid),
                           pins: pins.filter { $0.seconds >= start && $0.seconds < end }
                               .map { SongMap.Pin(uid: $0.uid, time: $0.seconds, label: $0.label) },
                           lanes: lanes)
    }

    static func place(_ piece: SongMap.Piece, from start: TimeInterval, to end: TimeInterval) -> SongMap.Placement {
        let from = max(piece.start, start), upTo = min(piece.end, end)
        var taps: [TimeInterval] = []
        if case .piece(let transcription) = piece.content {
            taps = transcription.taps.map(\.seconds).filter { $0 >= from && $0 < upTo }
        }
        return SongMap.Placement(uid: piece.uid, start: from, end: upTo,
                                 continuesBefore: piece.start < start - tolerance,
                                 continuesAfter: piece.end > end + tolerance, taps: taps)
    }

    /// Bar lines with their numbers, counted from the first downbeat in the song, or a time mark on every
    /// fourth second of song time (every `secondsPerTick`).
    static func ticks(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?,
                      secondsPerTick: TimeInterval = SongMapLayout.secondsPerTick) -> [SongMap.Tick] {
        if let grid {
            return grid.downbeats.enumerated()
                .filter { $0.element >= start - tolerance && $0.element < end - tolerance }
                .map { SongMap.Tick(time: $0.element, bar: $0.offset + 1) }
        }
        let first = (start / secondsPerTick).rounded(.up) * secondsPerTick
        return stride(from: first, to: end - tolerance, by: secondsPerTick).map { SongMap.Tick(time: $0, bar: nil) }
    }

    /// The bars a stretch touches, for a section's heading: from the bar it starts in to the bar it ends
    /// in. A stretch before the first downbeat starts in bar 1.
    static func barRange(from start: TimeInterval, to end: TimeInterval,
                         in grid: SongMapInput.Grid) -> ClosedRange<Int>? {
        let first = grid.downbeats.lastIndex { $0 <= start + tolerance } ?? 0
        let last = grid.downbeats.lastIndex { $0 < end - tolerance } ?? 0
        return (first + 1)...max(first + 1, last + 1)
    }
}

extension PieceLabel {
    /// True when this answer reads as a chord (ADR 0227 D7): a chord named by ear, or a shape on the neck
    /// that spells one. A single note or a double-stop that isn't a chord doesn't. What puts a piece in
    /// the song map's chords layer (ADR 0232 D3).
    func readsAsChord(openMidi: [Int]) -> Bool {
        if case .chord = earReading(openMidi: openMidi)?.kind { return true }
        return false
    }
}
