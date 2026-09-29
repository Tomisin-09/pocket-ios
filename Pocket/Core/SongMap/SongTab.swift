import Foundation

/// A song's **tab** (ADR 0232 D10): the same song as the map's board, drawn as a chart instead of as
/// pieces. Chord symbols sit at their taps, notes read as tab where they were placed on the neck and as
/// names where they were named by ear, and a tap with no name is a slash: rhythm with no pitch (D4).
///
/// **Drawn, never authored.** It is built from the pieces every time by `SongTabLayout`, and nothing here
/// can be edited: to change a bar, re-solve its piece (0225 D10). Pure and SwiftUI-free (AGENTS.md).
struct SongTab: Equatable, Sendable {
    let scale: SongMap.Scale
    let sections: [Section]

    /// True when no piece in the song has a tap to draw: every row is a gap.
    var isEmpty: Bool { sections.allSatisfy { $0.rows.allSatisfy(\.lines.isEmpty) } }

    /// The same sections as the board (D6), in shorter rows.
    struct Section: Equatable, Identifiable, Sendable {
        let heading: SongMap.SectionHeading
        let start: TimeInterval
        let end: TimeInterval
        let bars: ClosedRange<Int>?
        let rows: [Row]
        /// The earlier section this one repeats (D8). It reads *as Verse 1*.
        var sameAs: SongMap.SectionRef?
        var id: TimeInterval { start }

        /// A section that repeats another and has nothing of its own is written as a chart writes it:
        /// its heading and *as Verse 1*, with no empty rows under it. One with pieces of its own draws them,
        /// because a variation beats "same as" (D8).
        var showsRows: Bool { sameAs == nil || rows.contains { !$0.lines.isEmpty } }
    }

    /// One line of the chart: 4 bars, or 8 seconds.
    struct Row: Equatable, Identifiable, Sendable {
        let start: TimeInterval
        let end: TimeInterval
        /// The row's share of a full row's width, so a section's short last row draws short.
        let widthFraction: Double
        let ticks: [SongMap.Tick]
        /// Chords above notes, a line per lane that has something to draw here. None is a gap.
        let lines: [Line]
        /// The pieces that drew the row, earliest first: where tapping it goes on the board.
        let pieces: [UUID]
        var id: TimeInterval { start }

        /// Where `time` falls across the row, 0 at its start and 1 at its end.
        func position(of time: TimeInterval) -> Double {
            guard end > start else { return 0 }
            return (time - start) / (end - start)
        }
    }

    /// One lane's taps in one row. A loop that repeats has its taps written again on every pass (D18).
    struct Line: Equatable, Identifiable, Sendable {
        let layer: SongMap.Layer
        let lane: Int
        /// The string names down the left edge, thinnest first, when the line is tab. Empty for a line of
        /// names and slashes.
        let strings: [String]
        let columns: [Column]
        var id: String { "\(layer.rawValue)-\(lane)" }

        var isTab: Bool { !strings.isEmpty }
        /// A tab line with names, slashes or a repeat sign as well carries them in a row above the strings.
        var hasWordsAboveTab: Bool { isTab && columns.contains { !$0.mark.isFrets } }
    }

    /// One tap, or the sign where a loop's repeats begin, drawn at its time.
    struct Column: Equatable, Sendable {
        let time: TimeInterval
        let piece: UUID
        let mark: Mark
        /// What VoiceOver reads for it: the tap's name, or what repeats. `nil` for a tap that wasn't named.
        let name: String?

        /// How many characters wide it draws.
        var width: Int {
            switch mark {
            case .name(let name): max(name.count, 1)
            case .slash: 1
            case .frets(let cells): cells.map(\.text.count).max() ?? 1
            // The count, and room for the board's repeat symbol in front of it.
            case .repeats(let passes): "×\(passes)".count + 3
            }
        }

        /// The same tap, where a later pass of its loop plays it (D18).
        func moved(to time: TimeInterval) -> Column {
            Column(time: time, piece: piece, mark: mark, name: name)
        }
    }

    enum Mark: Equatable, Sendable {
        /// A chord symbol, or a note named by ear.
        case name(String)
        /// A tap with no name.
        case slash
        /// Notes on the neck, a cell per string, as tab writes them (`TabLine.cell`).
        case frets([FretCell])
        /// Where a loop's repeats begin (D14): *↻ ×8*, counting the pass worked out.
        case repeats(Int)

        var isFrets: Bool {
            if case .frets = self { return true }
            return false
        }
    }

    struct FretCell: Equatable, Sendable {
        /// Thinnest first, as the piece stores it.
        let string: Int
        let text: String
    }
}
