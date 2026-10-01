import Foundation

/// A piece laid out for **reading** (ADR 0234 D8): tab rows that fit the width they're given, so a 98-note
/// piece wraps down the screen instead of running off it as one line, with each row saying which notes it
/// holds. What the neck can't say sits above the strings in its column: a name given by ear, a chord, `·`
/// for an unnamed note, and a count, `(5)`, for four or more unnamed in a row, the way the Journal's line
/// already says them (ADR 0227, after the device check). A piece with nothing on the neck is its names,
/// in fours.
///
/// Drawn from the piece every time, never stored (**edit pieces, never the picture**). Order only, as
/// `TabLine` is: the dots carry the timing. Pure and SwiftUI-free (AGENTS.md).
enum PieceStaff {

    /// A cell on a string: the fret with its marks, and any join from the note before in front (`h7`), the
    /// way the song's Tab view writes it (ADR 0232 D10).
    struct Cell: Equatable, Sendable {
        let string: Int
        let text: String
    }

    /// One column of tab: one tap, or a run of unnamed taps said as one.
    struct Column: Equatable, Sendable {
        /// The first tap it stands for, 0-based, and how many.
        let note: Int
        let span: Int
        /// Above the strings, when the strings don't say it.
        let above: String?
        let cells: [Cell]
        /// Nothing named here (`·`, a count, or `?` for an answer that can't be read): drawn quieter.
        var isQuiet = false
        /// A written tab's bar line (ADR 0235 D4), before note `note`: a column with nothing in it but the
        /// line, so a row is still one run of columns.
        var isBar = false

        /// Unique in a row: a bar line shares its note with the column after it.
        var id: Int { isBar ? -(note + 1) : note }

        /// Its width in characters: its widest cell or word.
        var width: Int { max(1, above?.count ?? 0, cells.map(\.text.count).max() ?? 0) }
    }

    struct Row: Equatable, Sendable {
        let columns: [Column]
        /// The notes it holds, 1-based, for its caption.
        var notes: ClosedRange<Int> {
            let first = (columns.first?.note ?? 0) + 1
            let last = columns.last.map { $0.note + $0.span } ?? first
            return first...max(first, last)
        }
    }

    /// Runs of this many unnamed taps or more are said as a count.
    static let unnamedRun = 4

    /// The columns of a piece, in tap order.
    static func columns(of piece: PieceTranscription, spelling: NoteSpelling) -> [Column] {
        columns(of: piece.notes, spelling: spelling)
    }

    /// The columns of a piece's notes, in order (ADR 0235 D9: a written tab has no seconds).
    static func columns(of notes: PieceNotes, spelling: NoteSpelling) -> [Column] {
        let labels = notes.labels
        let openMidi = notes.openMidi ?? []
        var columns: [Column] = []
        var index = 0
        while index < labels.count {
            guard let label = labels[index] else {
                var end = index
                while end < labels.count, labels[end] == nil { end += 1 }
                let run = end - index
                if run >= unnamedRun {
                    columns.append(Column(note: index, span: run, above: "(\(run))", cells: [], isQuiet: true))
                } else {
                    columns += (index..<end).map { Column(note: $0, span: 1, above: "·", cells: [], isQuiet: true) }
                }
                index = end
                continue
            }
            let join = NeckJoin.symbol(into: index, of: labels) ?? ""
            let cells = label.frettedNotes
                .filter { openMidi.indices.contains($0.string) && $0.fret >= 0 }
                .sorted { $0.string < $1.string }
                .map { Cell(string: $0.string, text: join + TabLine.cell($0)) }
            // A shape of four notes or more is also named above it, the way its chip is.
            let named = cells.isEmpty || cells.count > 3 ? label.name(openMidi: openMidi, spelling: spelling) : nil
            columns.append(Column(note: index, span: 1, above: named ?? (cells.isEmpty ? "?" : nil), cells: cells,
                                  isQuiet: named == nil && cells.isEmpty))
            index += 1
        }
        return columns
    }

    /// The columns in rows no wider than `characters`, with `gap` between columns. A column never splits,
    /// and one too wide for any row gets a row of its own.
    static func rows(_ columns: [Column], fitting characters: Int, gap: Int = 2) -> [Row] {
        var rows: [Row] = []
        var current: [Column] = []
        var used = 0
        for column in columns {
            let needed = column.width + (current.isEmpty ? 0 : gap)
            if !current.isEmpty, used + needed > characters {
                rows.append(Row(columns: current))
                current = []
                used = 0
            }
            used += column.width + (current.isEmpty ? 0 : gap)
            current.append(column)
        }
        if !current.isEmpty { rows.append(Row(columns: current)) }
        return rows
    }

    /// A piece with nothing on the neck: its names in fours, unnamed as `–`, each with its number.
    static func groups(of piece: PieceTranscription, spelling: NoteSpelling) -> [[(note: Int, name: String?)]] {
        groups(of: piece.notes, spelling: spelling)
    }

    static func groups(of notes: PieceNotes, spelling: NoteSpelling) -> [[(note: Int, name: String?)]] {
        let names = notes.names(spelling: spelling)
        return stride(from: 0, to: names.count, by: 4).map { start in
            (start..<min(start + 4, names.count)).map { (note: $0, name: names[$0]) }
        }
    }

    /// The line over a piece: "98 notes · Guitar · Standard · 6 unnamed", or "8 chords", or "16 notes ·
    /// none named yet".
    static func meta(of piece: PieceTranscription) -> String { meta(of: piece.notes) }

    static func meta(of notes: PieceNotes) -> String {
        let named = notes.labels.compactMap { $0 }
        let noun = !named.isEmpty && named.allSatisfy(\.isChord) ? "chord" : "note"
        var parts = ["\(notes.count) \(noun)\(notes.count == 1 ? "" : "s")"]
        if notes.hasFrettedLabels, let tuning = notes.tuningLabel { parts.append(tuning) }
        let unnamed = notes.count - named.count
        if named.isEmpty {
            parts.append("none named yet")
        } else if unnamed > 0 {
            parts.append("\(unnamed) unnamed")
        }
        return parts.joined(separator: " · ")
    }
}
