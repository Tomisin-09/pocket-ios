import Foundation

/// Which of a song's own marker labels read as a section (ADR 0232 D7): what *Use your markers as
/// sections?* ticks before the player has said anything. Only the player's words, never the audio, and
/// nothing changes until they confirm, so a wrong tick costs one tap.
enum SectionWords {

    /// The words a chart heads its sections with. *Pre-chorus* is folded to one word before matching.
    static let words: Set<String> = ["intro", "verse", "prechorus", "chorus", "bridge", "solo", "break", "outro"]

    /// True when any word of the label is a section word: *Verse 2*, *Chorus x2*, *Guitar solo*,
    /// *Pre-chorus*. A word only counts whole, so *Breakdown* and *Versed* don't.
    static func readsAsSection(_ label: String) -> Bool {
        let folded = label.lowercased()
            .replacingOccurrences(of: "pre-chorus", with: "prechorus")
            .replacingOccurrences(of: "pre chorus", with: "prechorus")
        return folded.components(separatedBy: CharacterSet.letters.inverted).contains { words.contains($0) }
    }

    /// The markers a song could use as sections, earliest first, each with whether it's ticked to begin
    /// with. Markers outside the song are left out, as the map leaves them out.
    static func suggestions(_ markers: [SongMapInput.MarkerInput],
                            duration: TimeInterval) -> [(marker: SongMapInput.MarkerInput, ticked: Bool)] {
        markers.filter { $0.seconds >= 0 && $0.seconds < duration }
            .sorted { $0.seconds < $1.seconds }
            .map { ($0, readsAsSection($0.label)) }
    }

    /// Whether to offer *Use your markers as sections?* at all: the song has markers on it and none of them
    /// starts a section yet. Whether it's been offered before is the caller's (`AppSettings`).
    static func shouldOffer(_ markers: [SongMapInput.MarkerInput], duration: TimeInterval) -> Bool {
        let inside = markers.filter { $0.seconds >= 0 && $0.seconds < duration }
        return !inside.isEmpty && !inside.contains(where: \.startsSection)
    }
}
