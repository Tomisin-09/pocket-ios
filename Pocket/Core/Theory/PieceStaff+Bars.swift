import Foundation

/// A written tab laid out for reading (ADR 0235 D5): **each section on rows of its own**, under its heading,
/// and **whole bars kept on a row** while they fit. A bar too long for any row breaks at the edge, as a
/// column-by-column row does. Bar lines are columns of their own (`Column.isBar`), so a row is still one
/// run of columns and draws the way every piece's row does.
///
/// Only for notes with bar lines or sections (`PieceNotes.hasStructure`): a loop's piece has neither and
/// keeps `rows(_:fitting:gap:)`, untouched. Pure and SwiftUI-free.
extension PieceStaff {

    /// A section, laid out: its heading, if it has one, and its rows.
    struct System: Equatable, Sendable {
        let heading: String?
        let rows: [Row]
    }

    /// What a bar line costs a row, in characters, before the gap after it.
    static let barWidth = 1

    static func systems(of notes: PieceNotes, spelling: NoteSpelling, fitting characters: Int,
                        gap: Int = 2) -> [System] {
        let columns = columns(of: notes, spelling: spelling)
        let bars = Set(notes.bars)
        return sectionRanges(of: notes).map { range in
            let inSection = columns.filter { range.notes.contains($0.note) }
            // A new bar where a bar line stands before a column, except at the section's start: the heading
            // is that bar.
            var measures: [[Column]] = []
            for column in inSection {
                if measures.isEmpty || (column.note > range.notes.lowerBound && bars.contains(column.note)) {
                    measures.append([])
                }
                measures[measures.count - 1].append(column)
            }
            return System(heading: range.heading, rows: pack(measures, fitting: characters, gap: gap))
        }
    }

    /// The notes each section holds, in order, with notes before the first heading as a section with none.
    /// A heading waiting for the next note written holds none, and isn't drawn.
    static func sectionRanges(of notes: PieceNotes) -> [(heading: String?, notes: Range<Int>)] {
        let starts = notes.sections.filter { $0.start < notes.count }.sorted { $0.start < $1.start }
        var ranges: [(heading: String?, from: Int)] = []
        if starts.first.map({ $0.start > 0 }) ?? true { ranges.append((nil, 0)) }
        ranges += starts.map { ($0.name, $0.start) }
        return ranges.enumerated().compactMap { index, range in
            let end = index + 1 < ranges.count ? ranges[index + 1].from : notes.count
            return range.from < end ? (range.heading, range.from..<end) : nil
        }
    }

    /// Whole bars on a row while they fit, with a bar line between them; a bar too wide for a row is broken
    /// column by column, and what's left of it starts the next row.
    private static func pack(_ measures: [[Column]], fitting characters: Int, gap: Int) -> [Row] {
        var rows: [Row] = []
        var current: [Column] = []
        var used = 0
        func cost(_ columns: [Column]) -> Int { columns.reduce(0) { $0 + $1.width + gap } }
        func flush() {
            if !current.isEmpty { rows.append(Row(columns: current)) }
            current = []
            used = 0
        }
        for measure in measures {
            let bar = current.isEmpty ? 0 : barWidth + gap
            let width = cost(measure)
            if width > characters {
                flush()
                for part in Self.rows(measure, fitting: characters, gap: gap) {
                    flush()
                    current = part.columns
                    used = cost(part.columns)
                }
                continue
            }
            if !current.isEmpty, used + bar + width > characters { flush() }
            if let first = measure.first, !current.isEmpty {
                current.append(Column(note: first.note, span: 0, above: nil, cells: [], isBar: true))
                used += barWidth + gap
            }
            current += measure
            used += width
        }
        flush()
        return rows
    }
}
