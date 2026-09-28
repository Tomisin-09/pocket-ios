import Foundation

/// **One line of tab** from a piece's answers on the neck (ADR 0225), drawn as text for a fixed-width font:
///
///     e|---------------|
///     B|-5h7--8~-------|
///     G|----------7b9--|
///
/// A column per tap, in order, with no durations: the timing lives in the dots. Since ADR 0227 D5 the
/// marks are written the usual way: `7b9` a bend, `7~` vibrato, and a join between two columns as `h`,
/// `p`, `/` or `\`. A shape stacks in one column. It is always **drawn from the piece**, never stored, so
/// it can't be edited apart from it.
///
/// Pure and SwiftUI-free (AGENTS.md).
enum TabLine {

    /// One column: the notes one tap placed, and the join written into it from the column before.
    struct Column: Equatable {
        let notes: [FrettedNote]
        let join: String?
    }

    /// The columns of a pass: its answers on the neck in tap order, with any join that fits. Taps named by
    /// ear or unnamed are skipped, and so is a note on a string the tuning doesn't have, rather than
    /// drawn on the wrong line.
    static func columns(of labels: [PieceLabel?], openMidi: [Int]) -> [Column] {
        labels.indices.compactMap { index in
            let notes = (labels[index]?.frettedNotes ?? []).filter {
                openMidi.indices.contains($0.string) && $0.fret >= 0
            }
            guard !notes.isEmpty else { return nil }
            return Column(notes: notes, join: NeckJoin.symbol(into: index, of: labels))
        }
    }

    /// The tab as one line per string, thinnest string first, or `nil` when there is nothing to draw.
    /// Each column is as wide as its widest cell, so a 10th fret or a bend widens only its own column.
    static func render(_ labels: [PieceLabel?], openMidi: [Int]) -> String? {
        render(columns: columns(of: labels, openMidi: openMidi), openMidi: openMidi)
    }

    static func render(columns: [Column], openMidi: [Int]) -> String? {
        guard !columns.isEmpty else { return nil }
        var lines = stringNames(openMidi: openMidi).map { $0 + "|-" }
        for (position, column) in columns.enumerated() {
            let cells = lines.indices.map { string in column.notes.first { $0.string == string }.map(cell) }
            let width = cells.compactMap { $0?.count }.max() ?? 1
            for string in lines.indices {
                if position > 0 {
                    // A join takes the place of the two dashes between columns, on the strings it joins.
                    if let join = column.join {
                        lines[string] += cells[string] == nil ? "-" : join
                    } else {
                        lines[string] += "--"
                    }
                }
                let text = cells[string] ?? ""
                lines[string] += text + String(repeating: "-", count: width - text.count)
            }
        }
        return lines.map { $0 + "--|" }.joined(separator: "\n")
    }

    /// A note as tab writes it: the fret, then `b` and the fret it bends to, then `~` for vibrato.
    static func cell(_ note: FrettedNote) -> String {
        "\(note.fret)" + (note.bend > 0 ? "b\(note.fret + note.bend)" : "") + (note.vibrato ? "~" : "")
    }

    /// The string names down the left edge, thinnest first and padded to one width so the bars line up.
    /// Always sharp-spelled, as the tuner names open strings (ADR 0123: an open string is named for the
    /// chord it sounds). The top string is lower-cased when it shares its name with the bottom one, the
    /// way tab tells the two E strings apart.
    static func stringNames(openMidi: [Int]) -> [String] {
        var names = openMidi.map { GuitarScale.noteName(forPitchClass: (($0 % 12) + 12) % 12) }
        if names.count > 1, let first = names.first, first == names.last {
            names[0] = first.lowercased()
        }
        let width = names.map(\.count).max() ?? 0
        return names.map { $0 + String(repeating: " ", count: width - $0.count) }
    }
}
