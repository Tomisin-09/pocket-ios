import SwiftUI

// `FretboardGrid`'s string names and spoken summary, out of the view's file for its length (ADR 0313).

extension FretboardGrid {
    /// The accessibility identifier a board carries for a given string count — the one spelling,
    /// shared with the UI tests so neither side hardcodes the literal.
    static func stringCountIdentifier(_ count: Int) -> String { "fretboard.strings.\(count)" }

    /// Standard 6-string names top-to-bottom (high e … low E); other counts read as "String N".
    static func stringName(_ index: Int, of count: Int) -> String {
        let guitar = ["e", "B", "G", "D", "A", "E"]
        let bass = ["G", "D", "A", "E"]   // standard 4-string bass, highest-first (ADR 0116)
        if count == guitar.count, guitar.indices.contains(index) { return guitar[index] }
        if count == bass.count, bass.indices.contains(index) { return bass[index] }
        return "\(index + 1)"
    }

    /// Every note the board plays, in order, said the way a player would: "G fret 5, root; B fret 5".
    var accessibilitySummary: String {
        drill.notes.compactMap { note -> String? in
            guard let note else { return nil }
            let name = Self.stringName(note.string, of: stringCount)
            let position = note.fret == 0 ? "open" : "fret \(note.fret)"
            let how = note.technique.map { ", \($0.label)" } ?? ""
            let root = isRoot(note) ? ", root" : ""
            return "\(name) \(position)\(root)\(how)"
        }.joined(separator: "; ")
    }
}
