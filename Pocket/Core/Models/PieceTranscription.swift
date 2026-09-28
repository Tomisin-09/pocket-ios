import Foundation

/// A loop's **piece** (ADR 0225): where the player tapped, in song time, and what they said each tap was.
/// Stored on the loop as encoded `Data` (`Loop.transcriptionData`) and read through `Loop.transcription`.
///
/// Why this is structured, and not a line of text in the Journal: the song map (`docs/plans/song-map.md`)
/// lays every solved piece of a song on one board, and it needs to know **where** each note sits and
/// **what** it is. Saving again replaces it, and the Journal shows it as one row per loop, drawn from
/// this (ADR 0229), not a line per save. **Edit pieces, never the picture:** nothing else stores a
/// transcription, so nothing can drift from it.
///
/// **Taps are song seconds, never beats.** The beat grid can be wrong (one tempo per song, ADR 0154), and
/// a tap stored as a beat would move every time the grid was corrected. In seconds, a correction re-divides
/// the same taps and nothing has to be rewritten.
struct PieceTranscription: Codable, Equatable, Sendable {

    /// Bumped only if a field changes meaning. Adding a field is not a bump: every field past `taps` is
    /// Optional, so an older build reads a newer piece and simply ignores what it doesn't know.
    static let currentVersion = 1

    var version: Int = currentVersion
    /// One entry per tap, ascending by `seconds`.
    var taps: [Tap]
    /// The open strings any fretted label was placed against, **highest-first** (the fretboard engine's
    /// order, ADR 0116). Recorded rather than looked up, so changing the tuner's tuning later can't
    /// silently re-pitch a saved tab. `nil` when no label is fretted.
    var openMidi: [Int]?
    /// How the tab's strings were described when it was written, e.g. "Guitar · Standard".
    var tuningLabel: String?
    /// When the piece last changed: saved from a pass, or its names edited. Where it sits in the
    /// Journal (ADR 0229). `nil` on a piece saved before that, until `PieceDateBackfill` stamps it.
    var changedAt: Date?

    struct Tap: Codable, Equatable, Sendable {
        /// Where the note is, in seconds from the top of the song.
        var seconds: TimeInterval
        /// What the player named it, or `nil` if they didn't.
        var label: PieceLabel?

        init(seconds: TimeInterval, label: PieceLabel? = nil) {
            self.seconds = seconds
            self.label = label
        }

        /// A label this build can't read decodes as **unnamed**, not as a failed piece: one note losing
        /// its name is recoverable, a whole transcription vanishing is not.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: PieceTapKeys.self)
            seconds = try container.decode(TimeInterval.self, forKey: .seconds)
            label = (try? container.decodeIfPresent(PieceLabel.self, forKey: .label)) ?? nil
        }
    }

    init(taps: [Tap], openMidi: [Int]? = nil, tuningLabel: String? = nil) {
        self.taps = taps.sorted { $0.seconds < $1.seconds }
        self.openMidi = openMidi
        self.tuningLabel = tuningLabel
    }

    var count: Int { taps.count }
    var labels: [PieceLabel?] { taps.map(\.label) }
    var hasFrettedLabels: Bool {
        taps.contains { if case .fretted = $0.label { return true } else { return false } }
    }

    /// The names in tap order, `nil` where a tap is unnamed.
    func names(spelling: NoteSpelling) -> [String?] {
        taps.map { $0.label?.name(openMidi: openMidi ?? [], spelling: spelling) }
    }

    /// The piece's line, *"11 notes. A C D D♯ E"*, as *Saved on this loop* and the Journal both show
    /// it. A piece whose every answer is a chord counts chords.
    func summary(spelling: NoteSpelling) -> String? {
        let named = taps.compactMap(\.label)
        return TapTally.summary(count: count, names: names(spelling: spelling), perBeat: nil,
                                countsChords: !named.isEmpty && named.allSatisfy(\.isChord))
    }

    // MARK: - Storage

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    /// The piece in `data`, or `nil` for no data or data this build can't read at all.
    static func decoded(from data: Data?) -> PieceTranscription? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(PieceTranscription.self, from: data)
    }
}

/// `PieceTranscription.Tap`'s keys, for its lenient decode. At file level only because SwiftLint caps
/// nesting at one level; the synthesised `encode(to:)` writes the same two names.
private enum PieceTapKeys: String, CodingKey { case seconds, label }

// MARK: - On the loop

extension Loop {
    /// The loop's piece, or `nil` if it has none (or one this build can't read). Setting `nil` or an
    /// empty piece removes it.
    var transcription: PieceTranscription? {
        get { PieceTranscription.decoded(from: transcriptionData) }
        set { transcriptionData = newValue.flatMap { $0.taps.isEmpty ? nil : $0.encoded() } }
    }
}
