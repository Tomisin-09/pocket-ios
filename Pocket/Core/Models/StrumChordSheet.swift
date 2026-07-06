import Foundation

/// A **strum-and-chords drill's** content (ADR 0065): a `StrumPattern` groove draped over a
/// `ChordProgression` — the strumming hand keeps its own repeating figure while the fretting hand
/// changes shape underneath it, exactly like reading a chord chart with strum notation over the
/// staff. Composes the two existing, independently pure/tested timing models rather than inventing
/// a third: `StrumChordsView` reads both off **one shared beat origin** and lets each wrap on its own
/// cycle length (T5) — there is no coupling that resets the strum pattern on a chord change, which
/// would require impure, stateful bookkeeping neither sibling model needs today. In the shipped seed
/// (`.popGroove`) the two cycle lengths happen to align (a 1-bar `.folk` strum under 1-bar-per-chord
/// `.gMajorPop`), so the groove audibly restarts with every chord **by construction**, not by a
/// special-cased reset.
///
/// Persisted as the opaque `Exercise.templatePayload: Data?` blob (never a child `@Model`), carrying
/// its own `version` so the wrapper shape can evolve with a decode-time upgrade and no store
/// migration — mirroring `StrumPattern`/`ChordProgression`, whose own versions travel independently
/// inside it.
struct StrumChordSheet: Codable, Equatable {
    /// The schema version this build writes. Bump when the wrapper's own shape changes (not when
    /// `StrumPattern` or `ChordProgression` change theirs — each upgrades independently).
    static let currentVersion = 1

    var version: Int
    /// The repeating strum groove, laid over the click independently of the chord changes below.
    var strumPattern: StrumPattern
    /// The chord changes the groove plays over.
    var chordProgression: ChordProgression

    init(strumPattern: StrumPattern, chordProgression: ChordProgression,
         version: Int = StrumChordSheet.currentVersion) {
        self.version = version
        self.strumPattern = strumPattern
        self.chordProgression = chordProgression
    }
}

// MARK: - Curated preset (T8 — common-practice vocabulary, authored in-house)

extension StrumChordSheet {
    /// A seeded starter: the folk **D · D U · U D U** groove (one 4/4 bar) under the **G · D · Em · C**
    /// pop turnaround (one bar per chord) — the groove completes exactly once per chord.
    static let popGroove = StrumChordSheet(strumPattern: .folk, chordProgression: .gMajorPop)
}
