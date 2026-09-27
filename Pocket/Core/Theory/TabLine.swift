import Foundation

/// **One line of tab** from a piece's fretted notes (ADR 0225), drawn as text for a fixed-width font:
///
///     e|-----------|
///     B|-5--8------|
///     G|-------7---|
///
/// It stops where 0225 stops the tab: one note per column, in order, with no durations and no technique
/// marks. Timing lives in the dots and bends in the Journal text. It is always **drawn from the piece**,
/// never stored, so it can't be edited apart from it.
///
/// Pure and SwiftUI-free (AGENTS.md).
enum TabLine {

    /// A note on the neck: `string` highest-first (0 = the thinnest), as `PieceLabel.fretted` stores it.
    struct Note: Equatable, Sendable {
        let string: Int
        let fret: Int
    }

    /// The tab as one line per string, thinnest string first, or `nil` when there is nothing to draw.
    /// Each column is as wide as its own fret, so a 10th fret widens only its column. A note on a string
    /// the tuning doesn't have is skipped rather than drawn on the wrong line.
    static func render(_ notes: [Note], openMidi: [Int]) -> String? {
        let placed = notes.filter { openMidi.indices.contains($0.string) && $0.fret >= 0 }
        guard !placed.isEmpty else { return nil }
        var lines = stringNames(openMidi: openMidi).map { $0 + "|" }
        for note in placed {
            let cell = String(note.fret)
            for index in lines.indices {
                lines[index] += "-" + (index == note.string ? cell : String(repeating: "-", count: cell.count)) + "-"
            }
        }
        return lines.map { $0 + "-|" }.joined(separator: "\n")
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
