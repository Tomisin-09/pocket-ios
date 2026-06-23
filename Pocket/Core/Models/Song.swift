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
    /// When this song was last practised — the "recently practised" sort key and a direct
    /// planner input (ADR 0014/0036). `nil` until the first practice session is recorded.
    /// Optional with no declaration default, like `bpm`/`dateAdded`, so SwiftData lightweight
    /// migration fills pre-0036 songs with nil (additive field, no store wipe).
    var lastPracticed: Date?

    // Import identity (`SongRef`), flattened for storage. `bookmark == nil` marks
    // the generated demo sample (no real file behind it).
    var sourceID: String
    var sourceRaw: String
    var bookmark: Data?

    @Relationship(deleteRule: .cascade, inverse: \Loop.song) var loops: [Loop] = []
    @Relationship(deleteRule: .cascade, inverse: \Marker.song) var markers: [Marker] = []

    init(title: String, artist: String = "", album: String = "", genre: String = "",
         year: Int? = nil,
         key: String = "", bpm: Int? = nil, preciseBPM: Double? = nil,
         downbeatSeconds: TimeInterval? = nil,
         collections: [String] = [], comment: String = "",
         duration: TimeInterval, amplitudes: [Double] = [], dateAdded: Date? = nil,
         lastPracticed: Date? = nil,
         ref: SongRef) {
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
    }

    /// The import identity. `bookmark == nil` ⇒ the generated demo sample.
    var ref: SongRef {
        SongRef(id: sourceID, source: SongRef.Source(rawValue: sourceRaw) ?? .localFile, bookmark: bookmark)
    }

    /// The full-precision tempo to drive the beat grid: `preciseBPM` when set, else
    /// the rounded `bpm` promoted to `Double` (so a song that only ever had an integer
    /// tempo still grids), else `nil` when the tempo is unknown (ADR 0024).
    var tempoBPM: Double? { preciseBPM ?? bpm.map(Double.init) }

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

@Model
final class Loop {
    /// Stable business id — used for active/selection tracking in the view (the
    /// SwiftData `persistentModelID` is unstable before insert).
    var uid: UUID
    /// User-given name; falls back to the time range when empty.
    var name: String
    /// Bounds as fractions of the song (0...1), edited on the waveform in Fine mode.
    var start: Double
    var end: Double
    /// The loop's playback speed — also the **start** of its automator ramp (ADR 0013).
    var speed: Double
    var repeats: Int
    var song: Song?

    /// How cleanly the player owns this loop, 0–5 (ADR 0036). The source the song's
    /// derived `mastery` rolls up from. Declaration default (not init-only) so SwiftData
    /// lightweight migration fills pre-0036 loops without a store wipe (CoreData 134110).
    var mastery: Int = 0

    /// Deliberate practice intent, 1–3 (ADR 0036): `1` Backburner (not actively working
    /// it) · `2` Active (in current rotation) · `3` Sharpening (pushing it now / gig prep).
    /// Kept separate from `mastery` — a well-played loop can still be high intent and a
    /// rough one low intent; the planner reads mastery as *need* and focus as *intent*.
    /// Declaration default fills pre-0036 loops (CoreData 134110).
    var focus: Int = 1

    /// The fastest tempo the player owns this loop at, as a fraction of original (ADR 0036)
    /// — distinct from `speed`, the *current* practice playback rate. `1.0` = full tempo
    /// ("you command this at 85%" → `0.85`). Declaration default fills pre-0036 loops.
    var commandTempo: Double = 1.0

    /// Backing storage for `loopType` — a plain `String` raw value, **not** the enum
    /// itself. A custom enum attribute does not survive SwiftData lightweight migration:
    /// pre-0036 loop rows have no value to decode and fault → crash when the attribute is
    /// first read. Storing the `String` lets migration fill old rows with `""` (= `.unset`)
    /// without a store wipe, mirroring `Song.key`/`MusicalKey` and `SongRef.sourceRaw`
    /// (the ADR 0012 / CoreData 134110 rule). Default `""` so the column has a value.
    var loopTypeRaw: String = ""

    /// What kind of material the loop is — lick / riff / chords, single-select (ADR 0036).
    /// Typed view over `loopTypeRaw`; unrecognised/empty reads as `.unset`.
    var loopType: LoopType {
        get { LoopType(rawValue: loopTypeRaw) ?? .unset }
        set { loopTypeRaw = newValue.rawValue }
    }

    /// The loop-level descriptive annotation axis (ADR 0034): open `[String]` tags
    /// ("solo", "needs-work", "chorus") routed through the shared `Labels` canonicaliser,
    /// the loop analogue of `Song.collections`. Declaration default (not init-only) so
    /// SwiftData lightweight migration fills pre-0034 loops without a store wipe — the
    /// CoreData 134110 rule (ADR 0012), same as `mastery`/`focus`/`collections`. A scalar
    /// array stays CloudKit-clean. Promotion to a `LoopTag` `@Model` stays out of scope.
    var tags: [String] = []

    // Automator (ADR 0013): the per-loop speed ramp. Defaults on the *declarations* so
    // SwiftData lightweight migration fills them for loops saved before this — see the
    // ADR 0012 migration note (init-only defaults fail with CoreData 134110). The loop's
    // existing `speed` is the ramp start; these add the target, the step count, and the
    // passes per step.
    var automatorEnabled: Bool = false
    var automatorTargetSpeed: Double = 1.0
    var automatorStepCount: Int = 6
    var automatorLoopsPerStep: Int = 2

    /// Manual identity-colour override: an index into `PocketColor.loopPalette`, or
    /// `nil` to derive the colour from start-order (ADR 0023 / 0031). Optional, so
    /// SwiftData lightweight migration leaves loops saved before this as `nil` (auto).
    var colorIndex: Int?
    /// A free custom colour as `#RRGGBB`, set from the colour wheel (ADR 0031). Takes
    /// precedence over `colorIndex` / derived when present; `nil` means no custom colour.
    var customColorHex: String?

    init(name: String, start: Double, end: Double, speed: Double, repeats: Int) {
        self.uid = UUID()
        self.name = name
        self.start = start
        self.end = end
        self.speed = speed
        self.repeats = repeats
    }

    var startSeconds: TimeInterval { (song?.duration ?? 0) * start }
    var endSeconds: TimeInterval { (song?.duration ?? 0) * end }

    /// The loop's speed-ramp config (pure value type). `speed` is the ramp start; the
    /// rest are the automator-specific fields. Setting it writes them back through.
    var automator: AutomatorConfig {
        get {
            AutomatorConfig(startSpeed: speed, targetSpeed: automatorTargetSpeed,
                            stepCount: automatorStepCount, loopsPerStep: automatorLoopsPerStep,
                            enabled: automatorEnabled)
        }
        set {
            speed = newValue.startSpeed
            automatorTargetSpeed = newValue.targetSpeed
            automatorStepCount = newValue.stepCount
            automatorLoopsPerStep = newValue.loopsPerStep
            automatorEnabled = newValue.enabled
        }
    }
}

@Model
final class Marker {
    var uid: UUID
    var seconds: TimeInterval
    var label: String
    var song: Song?

    init(seconds: TimeInterval, label: String) {
        self.uid = UUID()
        self.seconds = seconds
        self.label = label
    }
}
