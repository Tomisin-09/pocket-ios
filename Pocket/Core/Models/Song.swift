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

    /// The full-song speed to resume at on reopen (ADR 0044): the speed you last practised the
    /// song at, or 1× when never practised (`nil`). Mirrors `Loop.resumeSpeed` at the song level.
    var resumeSpeed: Double { lastPracticedSpeed ?? 1.0 }

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
    /// Distinct from `lastPracticedSpeed` (where the loop resumes) and `commandTempo`
    /// (the fastest tempo owned) — three different loop tempos (ADR 0040).
    var speed: Double
    var repeats: Int
    var song: Song?

    /// The playback speed you last practised this loop at (× of original) — restored when
    /// you re-arm the loop, so a loop you slowed to 0.7× reopens at 0.7× (ADR 0040). Written
    /// when you **leave** the loop, not per slider tick. `nil` = never practised → resume
    /// falls back to `speed` (the creation / automator-start speed). Optional with no
    /// declaration default, so pre-0040 loops migrate to `nil` without a store wipe (CoreData
    /// 134110 exempt). Kept separate from `speed` so practice never clobbers the ramp start.
    var lastPracticedSpeed: Double?

    /// How cleanly the player owns this loop, 0–5 — or `nil` when never rated (ADR 0039).
    /// The source the song's derived `mastery` rolls up from. **Optional on purpose**: a
    /// non-optional `0` default reads as "can't play it at all," a claim rather than the
    /// absence of one, and would render a fake rating on the glanceable row. Optional is
    /// exempt from the CoreData 134110 mandatory-attribute rule, so pre-0039 loops migrate
    /// to `nil` (= never touched) with no store wipe — which is exactly the truth.
    var mastery: Int?

    /// Deliberate practice intent — `1` Backburner · `2` Active · `3` Sharpening — or `nil`
    /// when never triaged (ADR 0036 / 0039). Kept separate from `mastery` (the planner reads
    /// mastery as *need*, focus as *intent*). Optional like `mastery`/`commandTempo` so all
    /// three judgment fields share one "unset" concept and the planner (V2) gets a real
    /// "never triaged" signal instead of an ambiguous `1`; migrates pre-0039 loops to `nil`.
    var focus: Int?

    /// The fastest tempo the player owns this loop at, as a fraction of original — or `nil`
    /// when never measured (ADR 0036 / 0039). Distinct from `speed`, the *current* practice
    /// playback rate. `1.0` = full tempo ("you command this at 85%" → `0.85`). **Optional on
    /// purpose**: a `1.0` default literally claims full-tempo mastery, so an untouched loop
    /// would badge 100%. Migrates pre-0039 loops to `nil` (CoreData 134110 exempt).
    var commandTempo: Double?

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

    /// The loop's practice journal — dated, context-snapshotting entries (ADR 0038).
    /// Cascade-owned like `Song`'s loops/markers: deleting the loop deletes its journal.
    /// Declaration default keeps SwiftData lightweight migration additive (CoreData
    /// 134110 rule, ADR 0012) for loops saved before journalling shipped.
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.loop)
    var journal: [JournalEntry] = []

    /// Journal entries newest-first — the order the journal sheet lists them in.
    var journalByRecent: [JournalEntry] {
        journal.sorted { $0.createdAt > $1.createdAt }
    }

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

    /// The speed to resume this loop at when you arm it (ADR 0040): the speed you last
    /// practised it at, or — when never practised (`nil`) — its `speed` (creation /
    /// automator-start), so migrated and brand-new loops still resume sensibly.
    var resumeSpeed: Double { lastPracticedSpeed ?? speed }

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

    // Command-anchored progression (ADR 0046, Phase B) — the loop analogue of `Exercise`'s
    // working / command / reach, but in `×`-of-original (not absolute BPM). The loop is the
    // **trainable unit** Practice surfaces once it has a measured command; the warm-up floor is
    // its `speed` (start ×) and the reach derives from the command via the unit-generic
    // `TempoStretch` (`×`-unit clamps). No stored fields are added — `speed` and `commandTempo`
    // already exist — so `Loop`'s ADR 0011/0012 migration discipline is untouched.

    /// The **effective** command speed (×): the measured `commandTempo` once set, else the
    /// loop's `speed` — so an un-measured loop's reach still computes and reads like the old
    /// light model. Mirrors `Exercise.command`.
    var command: Double { commandTempo ?? speed }

    /// Whether a command speed has been measured yet (vs falling back to `speed`). The gate for
    /// a loop appearing as a trainable Practice unit (ADR 0046, Phase B).
    var hasMeasuredCommand: Bool { commandTempo != nil }

    /// The reach (×) derived from the current `command` — proportional + clamped to `+0.02…+0.10×`
    /// (pure `TempoStretch`). The loop analogue of `Exercise.derivedTarget`; surfaced so the
    /// run screen can preview the reach above the owned command.
    var derivedTargetSpeed: Double { TempoStretch.targetSpeed(forCommand: command) }

    /// Promote a newly-owned speed to `commandTempo` (ADR 0046, Phase B). The reach is derived,
    /// not stored, so promotion is a single write — the loop analogue of `Exercise.promoteCommand`.
    func promoteCommand(to speed: Double) { commandTempo = speed }
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

/// A single dated entry in a loop's practice journal (ADR 0038). It **snapshots the
/// loop's context** — mastery and command tempo — at the moment of writing, so the
/// entry stays a truthful record of where things stood even as the loop keeps moving.
/// The snapshot and timestamp are immutable; only `text` and `kind` are editable.
@Model
final class JournalEntry {
    /// Stable business id — list diffing / undo, like `Loop`/`Marker`.
    var uid: UUID
    /// When the entry was written. Entries list newest-first.
    var createdAt: Date
    /// The user's annotation — the only free-text field, and editable after creation.
    var text: String

    /// Context snapshot — the loop's `mastery` copied at creation and never updated; `nil`
    /// when the loop was unrated at the time (ADR 0039). Denormalised on purpose (ADR 0038):
    /// the entry must not drift as the loop improves. Optional so an entry written against an
    /// unrated loop records "unrated," not a defaulted `0`. (Pre-0039 entries keep their
    /// stored value — they were genuinely written under the old defaulted semantics.)
    var masteryAtEntry: Int?
    /// Context snapshot — the loop's `commandTempo` copied at creation, never updated; `nil`
    /// when never measured at the time (ADR 0039). Optional for the same reason as
    /// `masteryAtEntry`.
    var commandTempoAtEntry: Double?

    /// Backing storage for `kind` — a plain `String`, **not** the enum itself (the
    /// SwiftData enum-attribute migration rule; see `Loop.loopTypeRaw`). Empty/unknown
    /// reads as `.note`. Declaration default so the column always has a value.
    var kindRaw: String = EntryKind.default.rawValue

    /// Typed view over `kindRaw`; unrecognised/empty reads as the default (`.note`).
    var kind: EntryKind {
        get { EntryKind(raw: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    /// The loop this entry belongs to (cascade-owned by `Loop.journal`).
    var loop: Loop?

    init(text: String, kind: EntryKind, masteryAtEntry: Int?, commandTempoAtEntry: Double?,
         createdAt: Date = Date()) {
        self.uid = UUID()
        self.createdAt = createdAt
        self.text = text
        self.kindRaw = kind.rawValue
        self.masteryAtEntry = masteryAtEntry
        self.commandTempoAtEntry = commandTempoAtEntry
    }
}
