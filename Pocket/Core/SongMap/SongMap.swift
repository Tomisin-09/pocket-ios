import Foundation

/// A song's **map** (ADR 0232): its loops laid out as pieces on a board, section by section and row by
/// row, in lanes by layer. Everything here is **drawn**, never stored. The only things the map reads that
/// a player sets are the loops, their pieces (ADR 0225), which markers start a section (D6) and repeat an
/// earlier one (D8), and which loops repeat to the end of their section (D14).
///
/// Built from plain values by `SongMapLayout`, pure and SwiftUI-free (AGENTS.md), so where a piece sits,
/// which lane it takes and where a row breaks are unit-tested rather than trusted to a screenshot.
struct SongMap: Equatable, Sendable {

    /// Bars when the song has a grid and shows it, seconds otherwise (D5).
    enum Scale: Equatable, Sendable { case bars, seconds }

    /// Which layer a piece is on (D3). Melodies play over chords, so chords are drawn above notes.
    enum Layer: Int, CaseIterable, Comparable, Sendable {
        case chords, notes
        static func < (lhs: Layer, rhs: Layer) -> Bool { lhs.rawValue < rhs.rawValue }

        /// What the lane is called on the board, and what a piece made in it is named after (D9).
        var name: String {
            switch self {
            case .chords: "Chords"
            case .notes: "Notes"
            }
        }
    }

    let scale: Scale
    let sections: [Section]
    /// Every loop on the board, by uid.
    let pieces: [UUID: Piece]
    /// The grid bars were drawn from, or `nil` in seconds scale.
    let grid: SongMapInput.Grid?

    /// Where a piece sits, in bars when the map has them: the bar it starts in to the bar it ends in.
    /// `nil` in seconds scale.
    func bars(of piece: Piece) -> ClosedRange<Int>? {
        grid.flatMap { SongMapLayout.barRange(from: piece.start, to: piece.end, in: $0) }
    }

    /// True when a marker starts a section: without one, the song is one strip, and a repeat runs to the
    /// song's end rather than a section's (D14).
    var hasSections: Bool { sections.contains { $0.heading != .none } }

    /// A stretch of the song from one section marker to the next (D6).
    struct Section: Equatable, Identifiable, Sendable {
        let heading: SectionHeading
        let start: TimeInterval
        let end: TimeInterval
        let rows: [Row]
        /// The first and last bar numbers the section touches, in bars scale.
        let bars: ClosedRange<Int>?
        /// The earlier section this one repeats, *as Verse 1* (D8): the first of a chain. `nil` reads plain.
        var sameAs: SectionRef?
        var id: TimeInterval { start }
    }

    /// A section named by another: where *as Verse 1* points.
    struct SectionRef: Equatable, Sendable {
        let uid: UUID
        let label: String
        /// Where the named section starts on the board, to go to it.
        let start: TimeInterval
    }

    /// What heads a section.
    enum SectionHeading: Equatable, Sendable {
        /// No marker starts a section: the song is one continuous strip.
        case none
        /// The stretch before the first section.
        case start
        /// A section a marker starts.
        case marker(uid: UUID, label: String)
    }

    /// One line of the board: 8 bars, or 16 seconds (D2).
    struct Row: Equatable, Identifiable, Sendable {
        let start: TimeInterval
        let end: TimeInterval
        /// The row's share of a full row's width, so a section's short last row draws short.
        let widthFraction: Double
        let ticks: [Tick]
        let pins: [Pin]
        let lanes: [Lane]
        var id: TimeInterval { start }

        /// Where `time` falls across the row, 0 at its start and 1 at its end.
        func position(of time: TimeInterval) -> Double {
            guard end > start else { return 0 }
            return (time - start) / (end - start)
        }
    }

    /// A bar line with its number, or a time mark.
    struct Tick: Equatable, Sendable {
        let time: TimeInterval
        /// The bar number, counted from the first downbeat in the song; `nil` in seconds scale.
        let bar: Int?
    }

    /// A marker that doesn't start a section (D2).
    struct Pin: Equatable, Identifiable, Sendable {
        let uid: UUID
        let time: TimeInterval
        let label: String
        var id: UUID { uid }
    }

    /// One lane of one layer in one row.
    struct Lane: Equatable, Identifiable, Sendable {
        let layer: Layer
        /// 0 for the layer's first lane; higher when pieces in the layer overlap.
        let index: Int
        let placements: [Placement]
        /// The parts of repeats that fall in this lane and row (D14).
        var bands: [Band] = []
        /// The stretches of this layer with nothing on them, where a piece can be made (D9). On the
        /// layer's first lane only, and whole: a gap crossing rows is the same gap in each.
        var gaps: [Gap] = []
        var id: String { "\(layer.rawValue)-\(index)" }
    }

    /// The part of one loop's repeats that falls in one row (D14): drawn lighter than the piece, from its
    /// end to its section's end, and never as copies.
    struct Band: Equatable, Identifiable, Sendable {
        let uid: UUID
        let start: TimeInterval
        let end: TimeInterval
        /// The repeats began in an earlier row, or carry on into a later one.
        let continuesBefore: Bool
        let continuesAfter: Bool
        /// How many times the loop plays, counting the one worked out.
        let passes: Int
        var id: UUID { uid }
    }

    /// A stretch of one layer with no piece and no repeat on it (D9), bounded by its section, or by its row
    /// when the song has no sections. *Make a piece here* fills it exactly.
    struct Gap: Equatable, Identifiable, Sendable {
        let layer: Layer
        let start: TimeInterval
        let end: TimeInterval
        /// What a piece made here is called: *Chorus chords*, or *Chords, bars 9–12* outside a section.
        let name: String
        var id: String { "\(layer.rawValue)-\(start)" }
    }

    /// The part of one piece that falls in one row.
    struct Placement: Equatable, Identifiable, Sendable {
        let uid: UUID
        let start: TimeInterval
        let end: TimeInterval
        /// The piece carries on before this row, or after it.
        let continuesBefore: Bool
        let continuesAfter: Bool
        /// The piece's taps that fall in this part, in song seconds.
        let taps: [TimeInterval]
        var id: UUID { uid }
    }

    /// A loop as the board holds it.
    struct Piece: Equatable, Sendable {
        let uid: UUID
        let name: String
        let start: TimeInterval
        let end: TimeInterval
        let layer: Layer
        let lane: Int
        let content: Content
        /// Where the section it sits in ends, or the song when there are none: as far as it can repeat.
        var sectionEnd: TimeInterval
        /// The player said it repeats to the end of its section (D14), whether or not there's room.
        var repeatsDeclared = false
        /// How far the player said it repeats (D15), as it reads now: a section named that's gone, or that
        /// no longer ends later than its own, reads as its own section.
        var repeatsTo: RepeatsTo = .sectionEnd
        /// Its repeats, when declared and there's room for them.
        var repeats: Repeat?

        /// Where it stops holding its lane: the end of its repeats, or its own end.
        var reach: TimeInterval { repeats?.end ?? end }

        /// It holds a counted piece, so there's something for *Copy to…* to write (D16).
        var canCopy: Bool {
            if case .piece(let counted) = content { return !counted.taps.isEmpty }
            return false
        }
    }

    /// A loop's repeats (D14): from its end to the end of its section, or as far as the player said (D15).
    struct Repeat: Equatable, Sendable {
        let end: TimeInterval
        /// How many times the loop plays, counting the one worked out, to the nearest whole pass.
        let passes: Int
    }

    /// How far a loop's repeats run (D15). Stored on the loop as `stored`, a String, never as this enum
    /// (ADR 0189): a build that doesn't know a value reads it as the loop's own section.
    enum RepeatsTo: Hashable, Sendable {
        /// To the end of the section it sits in (D14).
        case sectionEnd
        /// On through a later section, to that section's end: by the marker that starts it.
        case through(UUID)
        /// To the end of the song.
        case songEnd

        init(stored: String?) {
            switch stored {
            case "song": self = .songEnd
            case let text?: self = UUID(uuidString: text).map(RepeatsTo.through) ?? .sectionEnd
            case nil: self = .sectionEnd
            }
        }

        /// What `Loop.repeatsTo` keeps: `nil` for its own section, so a loop that never chose reads as
        /// D14's.
        var stored: String? {
            switch self {
            case .sectionEnd: nil
            case .through(let uid): uid.uuidString
            case .songEnd: "song"
            }
        }
    }

    /// One way a piece's repeats can run, as its hold menu offers it (D15).
    struct RepeatChoice: Equatable, Sendable {
        let to: RepeatsTo
        /// *To the end of the section*, *Through Chorus*, *To the end of the song*.
        let title: String
        /// How many times the loop would play, counting the one worked out.
        let passes: Int

        /// The title as a sentence: *Repeats to the end of the section*, *Repeats through Chorus*.
        var phrase: String { "Repeats " + title.prefix(1).lowercased() + title.dropFirst() }
    }

    /// How far a piece's repeats can run from where it is (D15), nearest first.
    func repeatChoices(for piece: Piece) -> [RepeatChoice] {
        SongMapLayout.repeatChoices(for: piece, in: self)
    }

    /// *Repeats through Chorus, 6 times in all.*, for the piece's tab sheet. `nil` when it isn't drawn
    /// repeating.
    func repeatLine(for piece: Piece) -> String? {
        guard let repeats = piece.repeats,
              let choice = repeatChoices(for: piece).first(where: { $0.to == piece.repeatsTo }) else { return nil }
        return "\(choice.phrase), \(repeats.passes) times in all."
    }

    /// What a loop holds (D4). Drawn as it is, never as a status.
    enum Content: Equatable, Sendable {
        /// No piece saved, and no note tagged 🧩.
        case empty
        /// A note tagged 🧩 *Transcribed* by hand, with no piece saved (ADR 0229).
        case handTagged
        /// The loop's saved piece.
        case piece(PieceTranscription)
    }
}

/// What `SongMapLayout` reads: plain values, so it can be built in a test without a model container.
struct SongMapInput: Equatable, Sendable {
    var duration: TimeInterval
    /// The song's grid, when bars are drawn from it (D5). `nil` draws seconds.
    var grid: Grid?
    var markers: [MarkerInput]
    var loops: [LoopInput]

    struct Grid: Equatable, Sendable {
        /// Every downbeat in the song, in seconds, ascending.
        var downbeats: [TimeInterval]
        /// How long a bar lasts at the song's tempo: a full row is eight of them.
        var barSeconds: TimeInterval
    }

    struct MarkerInput: Equatable, Sendable {
        var uid: UUID
        var seconds: TimeInterval
        var label: String
        var startsSection: Bool
        /// The earlier section's marker this one repeats (D8).
        var sameAsUID: UUID?
    }

    struct LoopInput: Equatable, Sendable {
        var uid: UUID
        var name: String
        var start: TimeInterval
        var end: TimeInterval
        var type: LoopType
        var piece: PieceTranscription?
        var handTagged: Bool
        /// It repeats to the end of its section (D14)…
        var repeatsToSectionEnd = false
        /// …or as far as this, when it repeats at all (D15).
        var repeatsTo: SongMap.RepeatsTo = .sectionEnd
    }
}
