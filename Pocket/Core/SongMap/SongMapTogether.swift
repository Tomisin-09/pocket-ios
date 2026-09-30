import Foundation

/// *Put it together* (ADR 0232 D11): pieces selected on the board, read as one of two shapes, and the routine
/// each shape makes. **In a row** practises each piece, then the stretch from the first piece to it (A, B,
/// A to B, C, A to C…). **A line over its chords** practises the line, then plays the chords as a backing
/// to play it over (ADR 0135).
///
/// Pure and SwiftUI-free (AGENTS.md): which selections make a shape, and which blocks follow from one, are
/// exactly what breaks silently. `SongMapWriter` makes the joined loops and the routine from a `Plan`.
enum SongMapTogether {

    /// How far out a loop can be drawn and still count: a piece in a row may start this far before the one
    /// ahead of it ends, and chords may start this far into the line they play under, or stop this far short
    /// of its end.
    static let leeway: TimeInterval = 1

    enum Shape: Equatable, Sendable {
        /// Pieces on one layer, in the order they play.
        case inARow([UUID])
        /// A notes piece, and the chords piece that plays under it.
        case lineOverChords(line: UUID, chords: UUID)
    }

    /// What a selection makes, or why it makes nothing.
    enum Reading: Equatable, Sendable {
        case shape(Shape)
        /// One piece, or none: nothing to put together yet.
        case tooFew
        /// Pieces on one layer, but two overlap, or one sits inside another.
        case overlapping
        /// A line, and a chords piece that doesn't play under all of it.
        case notUnder
        /// Three or more pieces, across both layers.
        case mixed
    }

    /// The shape `selected` makes on `map`. It follows from what's selected, so there's nothing to choose:
    /// pieces on one layer are in a row, and one piece on each layer is a line over the chords under it.
    static func read(_ selected: Set<UUID>, in map: SongMap) -> Reading {
        let pieces = selected.compactMap { map.pieces[$0] }.sorted(by: playsFirst)
        guard pieces.count >= 2 else { return .tooFew }
        if Set(pieces.map(\.layer)).count == 1 {
            return followOn(pieces) ? .shape(.inARow(pieces.map(\.uid))) : .overlapping
        }
        guard pieces.count == 2, let line = pieces.first(where: { $0.layer == .notes }),
              let chords = pieces.first(where: { $0.layer == .chords }) else { return .mixed }
        return plays(chords, under: line) ? .shape(.lineOverChords(line: line.uid, chords: chords.uid)) : .notUnder
    }

    /// Each starts and ends later than the one before, and starts no more than `leeway` before it ends. A
    /// gap between them is fine: the joined stretches play it.
    private static func followOn(_ pieces: [SongMap.Piece]) -> Bool {
        zip(pieces, pieces.dropFirst()).allSatisfy { before, next in
            next.start > before.start + SongMapLayout.tolerance && next.end > before.end + SongMapLayout.tolerance
                && next.start >= before.end - leeway
        }
    }

    /// The chords, with their repeats, play under the whole line, give or take `leeway` at either end. The
    /// backing goes round the chords, so a line that carries on past them would land on the wrong ones.
    private static func plays(_ chords: SongMap.Piece, under line: SongMap.Piece) -> Bool {
        chords.start <= line.start + leeway && chords.reach >= line.end - leeway
    }

    private static func playsFirst(_ lhs: SongMap.Piece, _ rhs: SongMap.Piece) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        return lhs.uid.uuidString < rhs.uid.uuidString
    }

    // MARK: - The routine

    /// A stretch from the first piece in a row to a later one: a loop Put it together makes. It holds no
    /// piece of its own, since its parts hold the notes, and a copy would write them twice in the tab.
    struct Join: Equatable, Sendable {
        /// The pieces it joins, in the order they play.
        let parts: [UUID]
        let name: String
        let start: TimeInterval
        let end: TimeInterval
        /// Its parts' layer, which it's typed to stay on: it has no names of its own to decide it (D3).
        let layer: SongMap.Layer
    }

    /// What a block runs.
    enum Unit: Equatable, Sendable {
        case piece(UUID)
        /// A joined stretch, by its place in `Plan.joins`: it has no loop until one is made.
        case join(Int)
    }

    /// One block of the routine.
    enum Block: Equatable, Sendable {
        /// A Practice block, with the speed ramp.
        case practise(Unit)
        /// The chords as a backing, to play the line over (ADR 0135).
        case improvise(UUID)
    }

    struct Plan: Equatable, Sendable {
        /// *Slow Bend: Intro lick over Intro chords*.
        let name: String
        let joins: [Join]
        /// In the order they run.
        let blocks: [Block]
        /// The selected pieces that run as Practice blocks, which need a command tempo (ADR 0138).
        let practised: [UUID]
        /// The loop whose Backing track switch is turned on, for a line over its chords.
        let backing: UUID?
    }

    /// The routine `shape` makes. Joined loops are named *Verse notes to Verse notes 2*, clear of
    /// `existingNames` and of each other.
    static func plan(_ shape: Shape, in map: SongMap, songTitle: String, existingNames: [String]) -> Plan {
        switch shape {
        case .inARow(let uids):
            let pieces = uids.compactMap { map.pieces[$0] }
            guard let first = pieces.first, let last = pieces.last else {
                return Plan(name: songTitle, joins: [], blocks: [], practised: [], backing: nil)
            }
            var joins: [Join] = []
            var blocks: [Block] = []
            for (index, piece) in pieces.enumerated() {
                blocks.append(.practise(.piece(piece.uid)))
                guard index > 0 else { continue }
                let name = SongMapLayout.unusedName("\(first.name) to \(piece.name)",
                                                    among: existingNames + joins.map(\.name))
                joins.append(Join(parts: pieces.prefix(index + 1).map(\.uid), name: name,
                                  start: first.start, end: piece.end, layer: first.layer))
                blocks.append(.practise(.join(joins.count - 1)))
            }
            return Plan(name: titled("\(first.name) to \(last.name)", songTitle), joins: joins, blocks: blocks,
                        practised: pieces.map(\.uid), backing: nil)
        case .lineOverChords(let line, let chords):
            let name = "\(map.pieces[line]?.name ?? "Line") over \(map.pieces[chords]?.name ?? "Chords")"
            return Plan(name: titled(name, songTitle), joins: [], blocks: [.practise(.piece(line)), .improvise(chords)],
                        practised: [line], backing: chords)
        }
    }

    /// A block as the routine holds it: a loop, and the mode it runs in.
    struct Run: Equatable, Sendable {
        let uid: UUID
        let mode: LoopRunMode
    }

    /// The plan's blocks once its joined loops are made, `joined` in the order of `plan.joins`.
    static func runs(_ plan: Plan, joined: [UUID]) -> [Run] {
        plan.blocks.compactMap { block in
            switch block {
            case .practise(.piece(let uid)): Run(uid: uid, mode: .trainer)
            case .practise(.join(let index)):
                joined.indices.contains(index) ? Run(uid: joined[index], mode: .trainer) : nil
            case .improvise(let uid): Run(uid: uid, mode: .improvise)
            }
        }
    }

    private static func titled(_ name: String, _ songTitle: String) -> String {
        songTitle.isEmpty ? name : "\(songTitle): \(name)"
    }

    // MARK: - Words

    /// What the selection bar says: what the selection makes, or why it can't be put together.
    static func line(for reading: Reading, in map: SongMap) -> String {
        switch reading {
        case .shape(.inARow(let uids)):
            return "In a row: \(uids.count) pieces, each on its own, then joined. \(uids.count * 2 - 1) blocks."
        case .shape(.lineOverChords(let line, let chords)):
            return "\(map.pieces[line]?.name ?? "The line") on its own, then over "
                + "\(map.pieces[chords]?.name ?? "its chords") as a backing."
        case .tooFew: return "Tap the next piece in the row, or the chords under a line."
        case .overlapping: return "Pieces in a row can't overlap."
        case .notUnder: return "The chords have to play under the whole line."
        case .mixed: return "Pick chords or notes to put in a row, or one line and the chords under it."
        }
    }
}

extension SongMapTogether.Reading {
    /// The shape it makes, or `nil` when it makes none.
    var shape: SongMapTogether.Shape? {
        if case .shape(let shape) = self { return shape }
        return nil
    }
}
