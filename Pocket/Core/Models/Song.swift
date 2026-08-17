import Foundation
import SwiftData

/// The practice-data aggregate, persisted with SwiftData (and CloudKit-syncable in
/// Phase 4): a `Song` — an imported file identified by its `SongRef` — with its
/// `Loop`s and `Marker`s. Transient UI state (capture drafts, the live playhead,
/// zoom) is *not* here; it lives on `WaveformPracticeModel`. See ADR 0011.
@Model
final class Song {
    var title: String
    var artist: String
    // Defaults on the *declarations* (not just `init`) so SwiftData lightweight
    // migration can fill these for songs saved before ADR 0012 — without a
    // declaration default a non-optional attribute is "mandatory" and the in-place
    // migration fails (CoreData 134110), wiping the existing store.
    var album: String = ""
    /// Free-text genre, entered in the edit sheet (manual-only — ADR 0035). Empty ⇒
    /// "Unknown Genre" when the library groups by genre. Declaration default so
    /// SwiftData lightweight migration fills pre-0035 songs (like `album`).
    var genre: String = ""
    /// `nil` when the release year is unknown — a normal state, like `bpm`.
    var year: Int?
    /// Raw musical-key storage. Kept a `String` so the SwiftData attribute is unchanged
    /// (no migration / store-wipe risk); read and write it through `musicalKey` for the
    /// typed, validated view (ADR 0036).
    var key: String
    /// `nil` when the tempo is unknown — a normal state (ADR 0004). This is the
    /// **rounded display mirror** of the tempo; the precise value lives in
    /// `preciseBPM` and drives the beat grid (ADR 0024). Kept as the canonical
    /// display field so existing readouts (`displayedBPM`, the edit sheet) are unchanged.
    var bpm: Int?
    /// The full-precision tempo (BPM) from tap-tempo or metadata, when known.
    /// `bpm` rounds this for display, but the beat grid uses the precise value so it
    /// doesn't drift ~1 beat across a multi-minute song (ADR 0024). Optional with no
    /// declaration default, like `bpm`/`year`/`downbeatSeconds`, so SwiftData
    /// lightweight migration fills pre-0026 songs with nil (additive field, no store wipe).
    var preciseBPM: Double?
    /// Seconds at which a bar-1 **downbeat** lands — the phase anchor for the beat
    /// grid (ADR 0022). `bpm` fixes the beat interval; this fixes where the grid sits,
    /// so a song with lead-in silence still lines up. `nil` ⇒ no grid is drawn or
    /// snapped to (we don't guess the phase). Optional, like `bpm`/`year`, so SwiftData
    /// lightweight migration fills pre-0022 songs with nil — no declaration default needed.
    var downbeatSeconds: TimeInterval?
    /// **Corrections** to the phase anchor further into the song (ADR 0154) — extra places the
    /// player has said "the 1 is *here*". One tempo and one anchor describe a straight line, and
    /// a straight line is wrong for music whose pulse actually moves: phase error accumulates as
    /// ∫(played tempo − stored tempo)·dt away from the anchor, so a click set against a
    /// hand-played, unquantised beat locks, slides out, then slides back. Each extra anchor
    /// restarts the grid — and the bar count — from that point, so the error can never
    /// accumulate past the section being practised.
    ///
    /// Empty for every song with a steady tempo, which is nearly all of them. A
    /// declaration-default `[Double]`, exactly like `collections`/`tags` — primitives, no stored
    /// enum, no `@Model` promotion — so SwiftData lightweight migration fills pre-0154 songs
    /// additively (the CoreData 134110 mandatory-attribute rule). Never read directly: the grid
    /// reads `downbeatAnchors`, which is `nil`-safe about the primary.
    var extraDownbeatSeconds: [TimeInterval] = []
    /// Time signature (ADR 0051): `beatsPerBar` groups the beat grid into bars — every
    /// `beatsPerBar`-th beat from the downbeat is a bar line — and `noteValue` is the
    /// denominator (4, 8, …), carried so the signature round-trips and reads right. Both
    /// **declaration-default 4/4** so SwiftData lightweight migration fills pre-0051 songs
    /// additively (the CoreData 134110 mandatory-attribute rule), like the exercise's meter.
    var beatsPerBar: Int = 4
    var noteValue: Int = 4
    /// Whether the beat grid is drawn on this song's waveform (ADR 0051) — a **per-song**
    /// view preference, on by default. Only takes effect once a grid exists (tempo + downbeat).
    var showsGridlines: Bool = true
    var collections: [String]
    /// A free-form note about the song (the edit sheet's "Notes" field).
    var comment: String = ""
    var duration: TimeInterval
    /// Per-bar amplitudes for the detail waveform (0...1), extracted at import.
    var amplitudes: [Double]
    /// When the song was imported — the "Recently Added" sort/group key (ADR 0035).
    /// `nil` for songs saved before this field (lightweight migration) and the bundled
    /// demo; those bucket as "Earlier". Optional with no declaration default, like `bpm`.
    var dateAdded: Date?
    /// When this song was last practised — the "recently practised" sort key (home + library)
    /// and a direct planner input (ADR 0014/0036). Stamped on practice-screen entry (ADR 0044).
    /// `nil` until the first practice session is recorded. Optional with no declaration default,
    /// like `bpm`/`dateAdded`, so SwiftData lightweight migration fills pre-0036 songs with nil
    /// (additive field, no store wipe).
    var lastPracticed: Date?
    /// The full-song playback speed (× of original) you last practised at — restored when you
    /// reopen the song so it resumes at your working tempo, not always 1× (ADR 0044). The
    /// **song-level** analogue of `Loop.lastPracticedSpeed`: it tracks the speed only while no
    /// loop is armed (a loop's speed never leaks in — see `WaveformPracticeModel`). `nil` until
    /// first practised → `resumeSpeed` falls back to 1×. Optional with no declaration default,
    /// so pre-0044 songs migrate to `nil` without a store wipe (CoreData 134110 exempt).
    var lastPracticedSpeed: Double?

    // Import identity (`SongRef`), flattened for storage. `bookmark == nil` marks
    // the generated demo sample (no real file behind it).
    var sourceID: String
    var sourceRaw: String
    var bookmark: Data?

    /// Leaf name of **Pocket's own copy** of the audio, in `SongFileStore`'s directory (ADR 0148).
    /// This is the primary way a song's audio is found; `bookmark` is the fallback for songs
    /// imported before 0148 and the provenance record of where the file came from.
    ///
    /// Not on `SongRef`: that type is *identity*, and this is storage — a song keeps its loops and
    /// markers when its audio moves, is relinked, or goes missing entirely (ADR 0148 §4). `nil`
    /// means no copy is held yet, either because the song predates 0148 or because it is the
    /// generated demo sample. Optional with no declaration default, so existing songs migrate to
    /// `nil` without a store wipe (CoreData 134110 exempt).
    var audioFileName: String?

    @Relationship(deleteRule: .cascade, inverse: \Loop.song) var loops: [Loop] = []
    @Relationship(deleteRule: .cascade, inverse: \Marker.song) var markers: [Marker] = []
    /// Practice takes recorded against this song (ADR 0069) — e.g. during a play-along.
    /// **Nullified, not cascaded** (ADR 0151), unlike `loops`/`markers`: removing a song from the
    /// library must not destroy recordings of the player, which are the one artifact here that can't
    /// be remade. The caption survives via `ownerLabelAtTake`; see `Loop.recordings`. Declaration
    /// default keeps the migration additive (CoreData 134110 rule).
    @Relationship(deleteRule: .nullify, inverse: \Recording.song) var recordings: [Recording] = []

    /// Routine blocks that **reference** this song for a repertoire run-through (ADR 0066
    /// R4/R5). Inverse of `RoutineItem.song`, **nullify** delete rule: deleting the song
    /// clears those blocks' link (the routine survives; the block is skipped) — it does
    /// not delete the routines. Additive optional relationship (CoreData 134110 rule).
    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.song)
    var routineItems: [RoutineItem] = []

    /// The exercises that **serve** this song (ADR 0111) — the inverse of `Exercise.linkedSongs`,
    /// which the later "build a routine for this song" generator reads. This is the **plain** side
    /// of the store's first many-to-many: the `@Relationship(inverse:)` lives on `Exercise` alone,
    /// so this side carries no annotation — SwiftData infers the inverse and gives a to-many inverse
    /// the `.nullify` delete rule for free (deleting an exercise just removes it from this set; the
    /// song survives). Additive optional (default `[]`) so pre-edge songs migrate to an empty set
    /// with no store wipe (CoreData 134110 rule).
    var linkedExercises: [Exercise] = []

    /// Where the player learned this song (ADR 0167) — a transcription, a tab page, a cover
    /// breakdown. **`.cascade` like `loops`/`markers`, not `.nullify` like `recordings`**: a
    /// pointer to where this song came from is a fact about the song, not an artifact of the
    /// player, so it goes when the song does. Additive (CoreData 134110 rule).
    @Relationship(deleteRule: .cascade, inverse: \ReferenceLink.song)
    var references: [ReferenceLink] = []

    init(title: String, artist: String = "", album: String = "", genre: String = "",
         year: Int? = nil,
         key: String = "", bpm: Int? = nil, preciseBPM: Double? = nil,
         downbeatSeconds: TimeInterval? = nil,
         collections: [String] = [], comment: String = "",
         duration: TimeInterval, amplitudes: [Double] = [], dateAdded: Date? = nil,
         lastPracticed: Date? = nil,
         ref: SongRef, audioFileName: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.key = key
        self.bpm = bpm
        self.preciseBPM = preciseBPM
        self.downbeatSeconds = downbeatSeconds
        self.collections = collections
        self.comment = comment
        self.duration = duration
        self.amplitudes = amplitudes
        self.dateAdded = dateAdded
        self.lastPracticed = lastPracticed
        self.sourceID = ref.id
        self.sourceRaw = ref.source.rawValue
        self.bookmark = ref.bookmark
        self.audioFileName = audioFileName
    }

    /// Whether this song stands for a real imported file rather than the generated demo sample.
    ///
    /// Was `bookmark != nil` at every call site until ADR 0148 added the owned copy: a song can
    /// now have audio without a usable bookmark (relinked, or the bookmark died with an old
    /// installation), so the test is "either source is recorded" — **not** "either source
    /// currently resolves", which is `SongAudioResolver`'s job and a different question.
    var hasImportedAudio: Bool { audioFileName != nil || bookmark != nil }

    /// The import identity. `bookmark == nil` ⇒ the generated demo sample.
    var ref: SongRef {
        SongRef(id: sourceID, source: SongRef.Source(rawValue: sourceRaw) ?? .localFile, bookmark: bookmark)
    }

    /// The full-precision tempo to drive the beat grid: `preciseBPM` when set, else
    /// the rounded `bpm` promoted to `Double` (so a song that only ever had an integer
    /// tempo still grids), else `nil` when the tempo is unknown (ADR 0024).
    var tempoBPM: Double? { preciseBPM ?? bpm.map(Double.init) }

    /// Every phase anchor in time order — the primary `downbeatSeconds` plus any corrections
    /// (ADR 0154). Empty when no 1 has been placed, which is the same "no grid, we don't guess
    /// the phase" condition ADR 0022 established: a correction without a primary is meaningless,
    /// so `extraDownbeatSeconds` alone never grids a song.
    var downbeatAnchors: [TimeInterval] {
        guard let primary = downbeatSeconds else { return [] }
        return ([primary] + extraDownbeatSeconds).sorted()
    }

    /// The full-song speed to resume at on reopen (ADR 0044): the speed you last practised the
    /// song at, or 1× when never practised (`nil`). Mirrors `Loop.resumeSpeed` at the song level.
    /// Clamped to the speed axis on read (ADR 0124) — see `Loop.resumeSpeed`.
    var resumeSpeed: Double { TempoMath.clamped(speed: lastPracticedSpeed ?? 1.0) }

    /// Derived practice mastery (0–5): the rounded average of this song's loops'
    /// `mastery`, or `nil` when the song has no loops (shown as "unrated"). A loop-centric
    /// app tracks mastery where practice happens — on loops — and rolls it up (ADR 0036),
    /// so there is no stored song-level proficiency. Pure-derived, no manual override.
    var mastery: Int? { MasteryRollup.rollup(loops.map(\.mastery)) }

    /// The typed, validated view of `key` (ADR 0036): parses the stored string on read and
    /// rewrites it canonically on set, folding legacy free text (`"A minor"`, flats) onto the
    /// closed `MusicalKey` vocabulary. `.unknown` for unset or unrecognised values.
    var musicalKey: MusicalKey {
        get { MusicalKey.parse(key) }
        set { key = newValue.rawValue }
    }

    var loopsByStart: [Loop] { loops.sorted { $0.start < $1.start } }
    var markersByTime: [Marker] { markers.sorted { $0.seconds < $1.seconds } }

    /// Total practice annotations on this song — loops plus markers. Surfaced as a
    /// stat in the edit sheet; journal entries will join this once journaling ships.
    var annotationCount: Int { loops.count + markers.count }
}
