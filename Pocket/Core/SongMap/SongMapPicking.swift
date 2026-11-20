import Foundation

/// Picking on the song map (ADR 0308 D1–D3, D8): the one way of choosing pieces, which ends in **Watch** or
/// **Put it together**. What a section's name shows while picking, what a tap on it picks, and what
/// watching the picks lights, plays and is called.
///
/// Pure and SwiftUI-free (AGENTS.md), beside `SongMapTogether`, which reads the same picks as a routine.
enum SongMapPicking {

    // MARK: - Sections (D1)

    /// What a section's name shows while picking: a filled check when every piece in it is picked, a dash
    /// when part of it is, an empty circle when none of it is. Not `none`/`some`, which an optional `Mark`
    /// would read as `Optional`'s own cases.
    enum Mark: Equatable, Sendable { case all, part, empty }

    /// The pieces a section holds: each one whose middle it holds, as a loop's repeats count the section it
    /// sits in (`SongMapLayout.sectionEnd`), so a piece starting a beat early belongs to the section it plays in.
    static func pieces(in section: SongMap.Section, of map: SongMap) -> Set<UUID> {
        Set(map.pieces.values.filter { piece in
            let middle = (piece.start + piece.end) / 2
            return section.start <= middle && middle < section.end
        }.map(\.uid))
    }

    static func mark(of section: SongMap.Section, picked: Set<UUID>, in map: SongMap) -> Mark {
        let held = pieces(in: section, of: map)
        let count = held.intersection(picked).count
        if held.isEmpty || count == 0 { return .empty }
        return count == held.count ? .all : .part
    }

    /// A tap on a section's name while picking: every piece in it picked, or, when all of them already
    /// are, all of them let go.
    static func toggle(_ section: SongMap.Section, picked: Set<UUID>, in map: SongMap) -> Set<UUID> {
        let held = pieces(in: section, of: map)
        return held.isSubset(of: picked) ? picked.subtracting(held) : picked.union(held)
    }

    // MARK: - What watching the picks plays (D2, D3)

    /// A piece in the stretch that would light but isn't picked: it plays, and stays dark (D3).
    struct Dark: Equatable, Sendable {
        let name: String
        /// Where it plays inside the stretch, its repeats included.
        let start: TimeInterval
        let reach: TimeInterval
    }

    /// The picks, read for **Watch**.
    struct Watch: Equatable, Sendable {
        /// *Verse 2 and Solo*, *Solo 4 and Solo 5* (D2).
        let title: String
        /// From the start of the first piece picked to the end of the last, its repeats included (D2).
        let start: TimeInterval
        let end: TimeInterval
        /// The bars the stretch covers, or `nil` when the map is in seconds.
        let bars: ClosedRange<Int>?
        /// The picks that light: the notes picked, or the chords when no notes are (D3, D4). Under notes, a
        /// chord is never drawn.
        let lit: Set<UUID>
        /// What stays dark, in the order it plays (D3).
        let dark: [Dark]
        /// The song's downbeats, for the bar counter while it plays (D2). `nil` in seconds.
        let downbeats: [TimeInterval]?

        /// *Bars 39–42*, or *1:54–2:10* in seconds.
        var place: String {
            if let bars { return SongMapPicking.bars(bars) }
            return "\(timecode(start))–\(timecode(end))"
        }

        /// Under the sheet's title (D2): *Bars 39–42 · starts at 1:54*, or *Starts at 1:54* in seconds.
        var sheetLine: String {
            bars.map { "\(SongMapPicking.bars($0)) · starts at \(timecode(start))" } ?? "Starts at \(timecode(start))"
        }

        /// The play button (D2): *Play from bar 39*, or *Play from 1:54* in seconds.
        var playLabel: String {
            bars.map { "Play from bar \($0.lowerBound)" } ?? "Play from \(timecode(start))"
        }

        /// The bar's first line (D8): *Solo 4 and Solo 5 · Bars 39–42*.
        var barLine: String { "\(title) · \(place)" }

        /// What the bar and the sheet say stays dark (D3), or `nil` when nothing does.
        var darkLine: String? { SongMapPicking.darkLine(dark.map(\.name)) }

        /// The bar playing at `time`, counted from the song's first, or `nil` in seconds.
        func bar(at time: TimeInterval) -> Int? {
            downbeats.map { beats in (beats.lastIndex { $0 <= time + 0.001 } ?? 0) + 1 }
        }

        /// What the neck says while a dark piece plays (D3): *Not picked: Solo 5*. The later-starting one
        /// where two overlap, as the merge shows.
        func notPicked(at time: TimeInterval) -> String? {
            dark.last { $0.start <= time && time < $0.reach }.map { "Not picked: \($0.name)" }
        }
    }

    /// The picks read for Watch, or `nil` with nothing picked.
    static func watch(_ picked: Set<UUID>, in map: SongMap) -> Watch? {
        let pieces = picked.compactMap { map.pieces[$0] }.sorted(by: playsFirst)
        guard let start = pieces.map(\.start).min(), let end = pieces.map(\.reach).max(), end > start else {
            return nil
        }
        let notes = pieces.contains { $0.layer == .notes }
        let lights = { (piece: SongMap.Piece) in !notes || piece.layer == .notes }
        let dark = map.pieces.values
            .filter { !picked.contains($0.uid) && lights($0) && isOnTheNeck($0) && $0.start < end && $0.reach > start }
            .sorted(by: playsFirst)
            .map { Dark(name: name(of: $0), start: max($0.start, start), reach: min($0.reach, end)) }
        return Watch(title: title(of: pieces, in: map), start: start, end: end,
                     bars: map.grid.flatMap { SongMapLayout.barRange(from: start, to: end, in: $0) },
                     lit: Set(pieces.filter(lights).map(\.uid)), dark: dark, downbeats: map.grid?.downbeats)
    }

    // MARK: - Words

    /// The sheet's title (D2): whole sections in a row by their names, otherwise the pieces. Never *the whole
    /// song*: every piece of a song without sections still plays only from the first to the last.
    private static func title(of pieces: [SongMap.Piece], in map: SongMap) -> String {
        if let names = sectionsInARow(Set(pieces.map(\.uid)), in: map) { return joined(names, rangeFrom: 3) }
        return joined(pieces.map(name(of:)), rangeFrom: 4)
    }

    /// The names of the sections picked, when the picks are exactly some whole sections in a row. A section
    /// with no pieces between two picked ones doesn't break the row: it plays in the stretch either way.
    private static func sectionsInARow(_ picked: Set<UUID>, in map: SongMap) -> [String]? {
        let sections = map.sections.filter { $0.heading != .none }
        let held = sections.map { pieces(in: $0, of: map) }
        let whole = sections.indices.filter { !held[$0].isEmpty && held[$0].isSubset(of: picked) }
        guard let first = whole.first, let last = whole.last,
              (first...last).allSatisfy({ held[$0].isSubset(of: picked) }),
              whole.reduce(into: Set<UUID>(), { $0.formUnion(held[$1]) }) == picked else { return nil }
        return sections[first...last].map { section in
            switch section.heading {
            case .none, .start: "Start"
            case .marker(_, let label): label.isEmpty ? "Section" : label
            }
        }
    }

    /// One name; two joined by *and*; a list with *and* below `rangeFrom`; from then on, the first *to* the
    /// last.
    static func joined(_ names: [String], rangeFrom: Int) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case rangeFrom...: "\(names[0]) to \(names[names.count - 1])"
        default: names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    /// *Solo 5 isn't picked, so it stays dark.* Up to three by name, then how many.
    static func darkLine(_ names: [String]) -> String? {
        switch names.count {
        case 0: nil
        case 1: "\(names[0]) isn't picked, so it stays dark."
        case 2, 3: "\(joined(names, rangeFrom: 4)) aren't picked, so they stay dark."
        default: "\(names.count) pieces in it aren't picked, so they stay dark."
        }
    }

    static func bars(_ bars: ClosedRange<Int>) -> String {
        bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
    }

    private static func name(of piece: SongMap.Piece) -> String { piece.name.isEmpty ? "Untitled loop" : piece.name }

    private static func isOnTheNeck(_ piece: SongMap.Piece) -> Bool {
        if case .piece(let counted) = piece.content { return counted.hasFrettedLabels }
        return false
    }

    private static func playsFirst(_ lhs: SongMap.Piece, _ rhs: SongMap.Piece) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.layer != rhs.layer { return lhs.layer < rhs.layer }
        return lhs.uid.uuidString < rhs.uid.uuidString
    }
}
