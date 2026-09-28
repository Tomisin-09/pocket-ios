import Foundation

/// A song's **map** (ADR 0232): its loops laid out as pieces on a board, section by section and row by
/// row, in lanes by layer. Everything here is **drawn**, never stored. The only things the map reads that
/// a player sets are the loops, their pieces (ADR 0225), and which markers start a section (D6).
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

    /// A stretch of the song from one section marker to the next (D6).
    struct Section: Equatable, Identifiable, Sendable {
        let heading: SectionHeading
        let start: TimeInterval
        let end: TimeInterval
        let rows: [Row]
        /// The first and last bar numbers the section touches, in bars scale.
        let bars: ClosedRange<Int>?
        var id: TimeInterval { start }
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
        var id: String { "\(layer.rawValue)-\(index)" }
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
    }

    struct LoopInput: Equatable, Sendable {
        var uid: UUID
        var name: String
        var start: TimeInterval
        var end: TimeInterval
        var type: LoopType
        var piece: PieceTranscription?
        var handTagged: Bool
    }
}
