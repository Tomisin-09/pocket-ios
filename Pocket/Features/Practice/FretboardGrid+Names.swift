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
    /// A board that plays chords (ADR 0313) says each chord once, with its shape, since a chord held for
    /// two bars would otherwise read its three notes over and over: "C, I, together: G fret 5, root, …".
    var accessibilitySummary: String {
        guard let chords = drill.chords else {
            return drill.notes.compactMap { $0.map { spoken($0, root: drill.rootPitchClass) } }.joined(separator: "; ")
        }
        let how = drill.playsTogether ? "together: " : ""
        return chords.indices.map { index in
            let chord = chords[index]
            let name = chord.name(spelling: spelling) + (chord.numeral.map { ", \($0.numeral)" } ?? "")
            let notes = drill.notes(ofChord: index)
            guard !notes.isEmpty else { return "\(name), rests" }
            return "\(name), \(how)" + notes.map { spoken($0, root: chord.root) }.joined(separator: ", ")
        }.joined(separator: "; ")
    }

    /// One note: its string, its fret, and whether it's the root it's read against.
    private func spoken(_ note: FretNote, root: Int?) -> String {
        let name = Self.stringName(note.string, of: stringCount)
        let position = note.fret == 0 ? "open" : "fret \(note.fret)"
        let how = note.technique.map { ", \($0.label)" } ?? ""
        let isRoot = root.map { drill.pitchClass(of: note) == $0 } ?? false
        return "\(name) \(position)\(isRoot ? ", root" : "")\(how)"
    }
}
