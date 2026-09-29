import Foundation

/// **Copy a piece** (ADR 0232 D16): a new loop over a stretch the player picks, with a piece they've
/// counted written across it, pass after pass. The player's act, never suggested: *these bars go like
/// those*.
///
/// A copy is a loop of its own with a piece of its own, not a link. Change the first and the copies stay
/// as they were. That's what copying means, and it's why *Repeats* (D14) and *Same as* (D8) draw rather
/// than copy: copying is for when the player wants the notes written out where they play, to practise
/// them there or to change a bar of them.
enum SongMapCopy {

    /// A stretch a piece can be copied to.
    struct Target: Equatable, Identifiable, Sendable {
        let start: TimeInterval
        let end: TimeInterval
        /// What the list calls it: *Verse 1*, or *Bars 9–16* where the song has no sections.
        let title: String
        /// Where it is, when the title doesn't say: *Bars 9–24*, or *0:32–1:04*.
        let place: String?
        /// What the loop made there is called, as *Make a piece here* would call it (D9).
        let name: String
        /// The pieces already on this layer there, which the copy will sit beside, in a lane of its own.
        let alongside: [String]
        var id: TimeInterval { start }
    }

    /// The loop being copied: its piece, and where it sits in song seconds.
    struct Source: Equatable, Sendable {
        let piece: PieceTranscription
        let start: TimeInterval
        let end: TimeInterval
    }

    /// A loop to make.
    struct Copy: Equatable, Sendable {
        let name: String
        let start: TimeInterval
        let end: TimeInterval
        let piece: PieceTranscription
    }

    private static let tolerance = SongMapLayout.tolerance

    // MARK: - Where to

    /// Where a piece can be copied to: every section but the one it sits in, or, when the song has no
    /// sections, every row of the board but the one it sits in.
    static func targets(for piece: SongMap.Piece, in map: SongMap) -> [Target] {
        let middle = (piece.start + piece.end) / 2
        func holdsPiece(_ start: TimeInterval, _ end: TimeInterval) -> Bool { start <= middle && middle < end }
        guard map.hasSections else {
            return map.sections.flatMap(\.rows).filter { !holdsPiece($0.start, $0.end) }.map { row in
                Target(start: row.start, end: row.end, title: place(from: row.start, to: row.end, in: map),
                       place: nil, name: name(piece.layer, .none, from: row.start, to: row.end, in: map),
                       alongside: alongside(piece.layer, from: row.start, to: row.end, in: map))
            }
        }
        return map.sections.filter { !holdsPiece($0.start, $0.end) }.map { section in
            let title: String
            switch section.heading {
            case .marker(_, let label): title = label.isEmpty ? "Section" : label
            case .start, .none: title = "Start"
            }
            return Target(start: section.start, end: section.end, title: title,
                          place: place(from: section.start, to: section.end, in: map),
                          name: name(piece.layer, section.heading, from: section.start, to: section.end, in: map),
                          alongside: alongside(piece.layer, from: section.start, to: section.end, in: map))
        }
    }

    /// Bars `range.lowerBound` through `range.upperBound`, when the map has bars: from the first one's
    /// downbeat to the downbeat after the last, or the song's end. Named by where it is (*Chords, bars
    /// 9–12*), since it needn't sit in one section.
    static func bars(_ range: ClosedRange<Int>, layer: SongMap.Layer, in map: SongMap) -> Target? {
        guard let grid = map.grid, let songEnd = map.sections.last?.end,
              range.lowerBound >= 1, range.upperBound <= grid.downbeats.count else { return nil }
        let start = grid.downbeats[range.lowerBound - 1]
        let end = range.upperBound < grid.downbeats.count ? grid.downbeats[range.upperBound] : songEnd
        guard end - start > tolerance else { return nil }
        return Target(start: start, end: end, title: place(from: start, to: end, in: map), place: nil,
                      name: name(layer, .none, from: start, to: end, in: map),
                      alongside: alongside(layer, from: start, to: end, in: map))
    }

    /// A gap tapped on the board (D9), filled by a copy rather than left empty.
    static func target(for gap: SongMap.Gap) -> Target {
        Target(start: gap.start, end: gap.end, title: gap.name, place: nil, name: gap.name, alongside: [])
    }

    /// The pieces a gap can start from: every piece on its layer with a piece counted, in song order.
    static func sources(for gap: SongMap.Gap, in map: SongMap) -> [SongMap.Piece] {
        map.pieces.values
            .filter { $0.layer == gap.layer && $0.canCopy }
            .sorted { ($0.start, $0.uid.uuidString) < ($1.start, $1.uid.uuidString) }
    }

    /// What a loop made there is called, as *Make a piece here* would call it (D9).
    private static func name(_ layer: SongMap.Layer, _ heading: SongMap.SectionHeading, from start: TimeInterval,
                             to end: TimeInterval, in map: SongMap) -> String {
        SongMapLayout.pieceName(layer: layer, heading: heading, from: start, to: end, grid: map.grid)
    }

    /// The pieces on `layer` with anything there, repeats included, in song order.
    private static func alongside(_ layer: SongMap.Layer, from start: TimeInterval, to end: TimeInterval,
                                  in map: SongMap) -> [String] {
        map.pieces.values
            .filter { $0.layer == layer && $0.start < end - tolerance && $0.reach > start + tolerance }
            .sorted { ($0.start, $0.uid.uuidString) < ($1.start, $1.uid.uuidString) }
            .map(\.name)
    }

    /// *Bars 9–16*, *Bar 9*, or *0:32–0:48* in seconds scale.
    static func place(from start: TimeInterval, to end: TimeInterval, in map: SongMap) -> String {
        if let grid = map.grid, let bars = SongMapLayout.barRange(from: start, to: end, in: grid) {
            return bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
        }
        return "\(timecode(start))–\(timecode(end))"
    }

    // MARK: - What's written

    /// How far apart the passes are: the piece's length to the nearest whole bar with a grid (at least
    /// one), so pass after pass starts on the same beat of the bar though the loop was drawn a hair long
    /// or short. Its own length without a grid.
    static func period(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?) -> TimeInterval {
        let length = end - start
        guard let grid, grid.barSeconds > 0 else { return length }
        return max(1, (length / grid.barSeconds).rounded()) * grid.barSeconds
    }

    /// *every 4 bars*, *every bar*, or *every 6 seconds* without a grid.
    static func every(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?) -> String {
        let period = period(from: start, to: end, grid: grid)
        if let grid, grid.barSeconds > 0 {
            let bars = Int((period / grid.barSeconds).rounded())
            return bars == 1 ? "every bar" : "every \(bars) bars"
        }
        let seconds = Int(period.rounded())
        return seconds == 1 ? "every second" : "every \(seconds) seconds"
    }

    /// The source's taps written across `target`: the first pass starting where the target starts, each
    /// tap as far into it as it was into the loop, then again every `period`. Only one period's taps are
    /// written each pass, so passes never write a tap twice, and a tap that would land past the target's
    /// end is left off. Nothing is snapped: a tap keeps its place in the bar.
    static func taps(of source: Source, across target: (start: TimeInterval, end: TimeInterval),
                     grid: SongMapInput.Grid?) -> [PieceTranscription.Tap] {
        let period = period(from: source.start, to: source.end, grid: grid)
        guard period > tolerance else { return [] }
        let upTo = min(source.end, source.start + period) - tolerance
        let pattern = source.piece.taps.filter { $0.seconds >= source.start - tolerance && $0.seconds < upTo }
        return stride(from: target.start, to: target.end - tolerance, by: period).flatMap { pass in
            pattern.compactMap { tap -> PieceTranscription.Tap? in
                let seconds = pass + max(tap.seconds - source.start, 0)
                guard seconds < target.end - tolerance else { return nil }
                return PieceTranscription.Tap(seconds: seconds, label: tap.label)
            }
        }
    }

    /// The loops copying a piece makes, one for each target in song order. Each is named as *Make a piece
    /// here* would name it, with a number when the song, or an earlier copy made with it, has that name
    /// already. Its tuning is the piece's, and it's dated `now`. A target no tap lands in makes nothing.
    static func copies(of source: Source, into targets: [Target], grid: SongMapInput.Grid?,
                       existingNames: [String], now: Date) -> [Copy] {
        var names = existingNames
        return targets.sorted { $0.start < $1.start }.compactMap { target in
            let written = taps(of: source, across: (target.start, target.end), grid: grid)
            guard !written.isEmpty else { return nil }
            let name = SongMapLayout.unusedName(target.name, among: names)
            names.append(name)
            var copied = PieceTranscription(taps: written, openMidi: source.piece.openMidi,
                                            tuningLabel: source.piece.tuningLabel)
            copied.changedAt = now
            return Copy(name: name, start: target.start, end: target.end, piece: copied)
        }
    }
}
