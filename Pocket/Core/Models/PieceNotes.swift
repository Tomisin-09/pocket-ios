import Foundation

/// A piece's notes **in order, without their seconds** (ADR 0235 D9): what the reading view and the tab
/// need, and all a tab written on the neck has. A loop's piece gives one (`PieceTranscription.notes`); a
/// written tab has nothing else. Keeping seconds out means a written tab never has to fake them, and
/// nothing that reads seconds (the song's tab, the map, a snag's note) can be handed one that has none.
///
/// Order only, as `TabLine` is. Pure and SwiftUI-free (AGENTS.md).
struct PieceNotes: Equatable, Sendable {
    /// One per note, `nil` where it's unnamed.
    var labels: [PieceLabel?]
    /// The open strings any fretted label was placed against, highest-first; `nil` when none is fretted.
    var openMidi: [Int]?
    /// How the strings were described when it was written, e.g. "Guitar · Standard".
    var tuningLabel: String?

    init(labels: [PieceLabel?], openMidi: [Int]? = nil, tuningLabel: String? = nil) {
        self.labels = labels
        self.openMidi = openMidi
        self.tuningLabel = tuningLabel
    }

    var count: Int { labels.count }
    var hasFrettedLabels: Bool {
        labels.contains { if case .fretted = $0 { return true } else { return false } }
    }

    /// The names in order, `nil` where a note is unnamed.
    func names(spelling: NoteSpelling) -> [String?] {
        labels.map { $0?.name(openMidi: openMidi ?? [], spelling: spelling) }
    }

    /// The line, *"11 notes. A C D D♯ E"*. A piece whose every answer is a chord counts chords.
    func summary(spelling: NoteSpelling) -> String? {
        let named = labels.compactMap { $0 }
        return TapTally.summary(count: count, names: names(spelling: spelling), perBeat: nil,
                                countsChords: !named.isEmpty && named.allSatisfy(\.isChord))
    }
}

extension PieceTranscription {
    /// Its notes in tap order, the seconds left behind.
    var notes: PieceNotes { PieceNotes(labels: labels, openMidi: openMidi, tuningLabel: tuningLabel) }
}
