import Foundation
import SwiftData

/// A **practice exercise** (ADR 0043/0046): "Alternating picking", "Spider" — a named,
/// persistent click-only drill you return to and push faster over time, each with its own
/// working / command tempos, time signature, accents, subdivision, and a native command-ramp
/// training recipe. A list of these is the Practice space's unit list.
///
/// Deliberately **audio/tempo-free** and separate from `Loop`: a `Loop` is bound to an audio
/// file/region, an exercise has no audio source, so overloading `Loop` would leak audio
/// assumptions into a click-only entity. It is a standalone top-level entity in the store —
/// with one **repertoire** association: a user-authored `linkedSongs` edge (ADR 0111) recording
/// which songs a drill is *for*. That edge is plain metadata; the audio/tempo firewall stands
/// (no audio source, no waveform region, absolute-BPM tempos). The old "no relationship to
/// `Song`" absolute (ADR 0043/0046) is narrowed by 0111 to audio/tempo, not association.
///
/// Follows the established model discipline (ADR 0011/0012/0036): a `uid: UUID` business
/// id; **declaration defaults** on every non-optional attribute so SwiftData lightweight
/// migration stays additive (the CoreData 134110 mandatory-attribute rule — `init`-only
/// defaults fail and wipe the store); and any enum stored through a `String` backing
/// field, never as a raw enum attribute (the ADR 0036 enum-attribute rule).
///
/// Tempos are **absolute BPM** (no song to be a fraction of, unlike `Loop.speed`/
/// `commandTempo`). The goal is `targetTempo` and the day-to-day value `currentTempo` —
/// the term "command tempo" stays reserved for `Loop`'s measured achievement and must
/// not be conflated (ADR 0043).
@Model
final class Exercise {
    /// Stable business id — list diffing / selection / undo, like `Loop`/`Marker`.
    var uid: UUID

    /// The exercise name ("Alternating picking", "Spider"). Empty until named.
    var name: String = ""

    /// The **working** tempo (absolute BPM) — the comfortable warm-up floor a session's
    /// ramp begins from (ADR 0045; read through the `workingTempo` alias in new code). The
    /// stored name is `currentTempo` for migration continuity: 0043 used this one number as
    /// the conflated working/owned tempo, and renaming a SwiftData attribute is not
    /// lightweight-additive (the CoreData 134110 store-wipe risk).
    var currentTempo: Int = 80
    /// The **command** tempo (absolute BPM) — the fastest the player can play this exercise
    /// *clean and repeatable* (ADR 0045). The anchor the `targetTempo` reach derives from,
    /// and the ratcheting cross-session achievement. **Optional on purpose**: `nil` ⇒ never
    /// measured, so `command` falls back to the working tempo and the exercise reads like the
    /// old light model until promoted. Mirrors `Loop.commandTempo` (same meaning, absolute
    /// BPM not a song fraction). Optional ⇒ migrates pre-0045 rows to `nil` with no wipe.
    var commandTempo: Int?
    /// **Vestigial** (ADR 0075): historically the recomputed goal tempo, but every reach read
    /// now goes through `reachTempo`/`derivedTarget`, and `promoteCommand` no longer writes it.
    /// Retained un-removed purely for SwiftData migration safety (dropping a stored attribute is
    /// not additive). Do not read it — use `reachTempo`.
    var targetTempo: Int = 120

    /// A **manually pinned reach** (absolute BPM) — the player's own goal above `command`,
    /// overriding the auto-derived `derivedTarget` (ADR 0075). `nil` = use the derived reach
    /// (the default). **Optional with no declaration default** so SwiftData lightweight migration
    /// leaves exercises saved before this as `nil` (auto), the CoreData 134110 rule (ADR 0012)
    /// shared with `commandTempo`. Auto-cleared by `promoteCommand` once the owned command catches
    /// up to it (a reach must stay above command). Read through `reachTempo`, never directly.
    var targetTempoOverride: Int?

    // Time signature: beats per bar (the click count and downbeat grouping) and the note
    // value (denominator — 4, 8, …). The standalone beat generator (slice 1) needs only
    // `beatsPerBar`; `noteValue` is carried so the signature round-trips and reads right.
    var beatsPerBar: Int = 4
    var noteValue: Int = 4

    /// Which beats accent, as 0-based indices within the bar. Default `[0]` — downbeat
    /// only. A scalar `[Int]` stays CloudKit-clean and migrates additively (declaration
    /// default, the CoreData 134110 rule), like `Loop.tags`.
    var accentBeats: [Int] = [0]

    /// **Vestigial** (ADR 0121): historically "how many clicks sound per beat", but it was never
    /// wired — `StandaloneMetronomeEngine.setSubdivision` is only ever called from the standalone
    /// metronome screen, so an exercise's subdivision never reached the click. It was written by the
    /// preset seeder and read by exactly one label. Its *value* was the only rhythm a content-less
    /// drill stated, so 0121 backfills it into `notesPerBeat` and stops writing it. Retained
    /// un-removed purely for SwiftData migration safety (dropping a stored attribute is not
    /// additive), like `targetTempo`. **Do not read it** — use `noteRate`.
    var subdivisionRaw: String = Subdivision.none.rawValue

    /// Typed view over the vestigial `subdivisionRaw`. Read only by the one-time 0121 backfill.
    var subdivision: Subdivision {
        get { Subdivision(rawValue: subdivisionRaw) ?? .none }
        set { subdivisionRaw = newValue.rawValue }
    }

    /// The drill's **own** rhythm — notes played per beat — for a template whose content declares
    /// none (a metronome-rendered warm-up, a chord-changing drill). `nil` ⇒ **no rhythm stated**,
    /// which is a real answer and not a defaulted "quarters": a surface shows a rhythm only when one
    /// exists, so an absent label always means "not stated" (ADR 0121). Content that carries its own
    /// `notesPerBeat` — every fretboard run, every strum pattern — takes precedence; read the
    /// resolved value through `noteRate`, never this directly. Optional with no declaration default,
    /// so the field is additive (CoreData 134110 exempt).
    var notesPerBeat: Int?

    /// The rhythm the **command tempo was measured at** (ADR 0121) — notes per beat at the moment it
    /// was promoted. Without it a command is only half a fact: moving Rhythm from eighths to
    /// sixteenths quadruples the demand while the stored 80 sits unchanged, silently revaluing a
    /// *measured* achievement (ADR 0045). With it, a rhythm change becomes an event the player
    /// answers — keep the same note speed, or re-measure.
    ///
    /// `nil` ⇒ there is nothing bound: either no measured command, or a command measured on a drill
    /// that states no rhythm. It is **never** "legacy/unknown" — the one-time 0121 backfill stamps
    /// every existing measured command, so no call site branches on provenance. Cleared alongside
    /// `commandTempo` by a re-measure. Optional with no declaration default (CoreData 134110 exempt).
    var commandNotesPerBeat: Int?

    /// Backing storage for `template` — the **exercise template** this drill was created from
    /// (ADR 0068, revised). A plain `String`, **not** the enum (the SwiftData enum-attribute
    /// migration rule, ADR 0036). **Declaration default of `.basic`** so every existing exercise
    /// migrates additively into the flexible "Basic" template and is otherwise untouched (the
    /// CoreData 134110 rule); unknown/empty reads as `.basic` (forward compatibility). Chosen once
    /// at creation and never reassigned in the UI — the template is immutable (only its own
    /// settings are editable), so there is no `template` *setter* exposure beyond creation.
    var templateRaw: String = ExerciseTemplate.basic.rawValue

    /// The exercise template — the single user-facing classification axis (Strumming, Scales, …),
    /// typed view over `templateRaw`. Fixes the renderer, the authoring UI, and the library
    /// section. Orthogonal to the tempo ramp: the template never changes the tempo model.
    var template: ExerciseTemplate {
        get { ExerciseTemplate(storage: templateRaw) }
        set { templateRaw = newValue.rawValue }
    }

    /// The **instrument** this drill is for (ADR 0116) — a per-exercise axis fixed at creation,
    /// sibling to `template`, defaulted from the profile's preferred instrument. A plain `String`,
    /// **not** the enum (the SwiftData enum-attribute migration rule, ADR 0036). **Declaration
    /// default of `guitar`** so every existing exercise migrates additively as a guitar drill and is
    /// otherwise untouched (the CoreData 134110 rule); unknown/empty reads as `.guitar` (forward
    /// compatibility). Governs which tuning the fretboard engine renders against and the library's
    /// instrument filter.
    var instrumentRaw: String = Instrument.default.rawValue

    /// The instrument axis — typed view over `instrumentRaw`, unknown/empty ⇒ `.guitar`. Fixed at
    /// creation like `template`; the fretboard renderer reads its tuning through this.
    var instrument: Instrument {
        get { Instrument(rawValue: instrumentRaw) ?? .guitar }
        set { instrumentRaw = newValue.rawValue }
    }

    /// The runtime **renderer** (ADR 0065) — *derived* from the template, never stored separately.
    /// The run screen switches its content surface on this; the strum payload accessor gates on it.
    var kind: ExerciseKind { template.renderer }

    /// The template's content as a versioned `Codable` blob (ADR 0065 T4) — a strum pattern,
    /// a fretboard sequence, … — opaque to SwiftData because it is **never** relationally
    /// queried. **Optional ⇒ additive migration**; `nil` (or an undecodable/unknown payload)
    /// falls back to the metronome renderer (T5). Read/written through the typed per-kind
    /// accessors in `Exercise+Template.swift`, never decoded ad hoc at call sites.
    var templatePayload: Data?

    // Training-routine recipe (ADR 0046) — the persisted `CommandRamp` shape this exercise
    // prescribes, stored **natively** rather than borrowed from the free-play automator (the
    // ADR 0045 shortcut, undone here). Declaration defaults keep migration additive (the
    // CoreData 134110 rule); the three renamed fields carry `@Attribute(originalName:)` so the
    // automator* → ramp* rename is a lightweight, data-preserving migration, not a drop+add.
    /// BPM added at each warm-up step.
    @Attribute(originalName: "automatorStepBPM") var rampStepBPM: Int = 5
    /// How many intervals between steps (e.g. every 4 *bars* or every 30 *seconds*).
    @Attribute(originalName: "automatorIntervalCount") var rampIntervalCount: Int = 4
    /// Backing storage for `rampIntervalUnit` — a plain `String` (the enum-attribute migration
    /// rule, ADR 0036). Empty/unknown reads as `.bars`.
    @Attribute(originalName: "automatorIntervalUnitRaw")
    var rampIntervalUnitRaw: String = MetronomeIntervalUnit.bars.rawValue
    /// How many intervals the command plateau holds — the **dwell** (ADR 0045/0046), where the
    /// bulk of the reps land. Stored natively now (was the fixed `4` the routine assumed).
    var dwellIntervals: Int = 4
    /// Whether the routine **backs off** below command after the summit, so you finish on clean
    /// control rather than the edge (ADR 0045). Stored natively now (was a fixed `true`).
    var includeBackoff: Bool = true
    /// Intermediate stops on the climb from command up to the reach (ADR 0046 run-UI). `0` ⇒ a
    /// single jump to the reach. Declaration default keeps the migration additive (CoreData
    /// 134110 rule).
    var rampReachSteps: Int = 0
    /// Intermediate stops on the descent from the summit down to the backoff floor (ADR 0046
    /// run-UI). `0` ⇒ a single drop. Declaration default, as `rampReachSteps`.
    var rampBackoffSteps: Int = 0
    /// A manually pinned **backoff floor** (BPM) the routine settles the tail to, or `nil` to derive
    /// it from command/reach (user-testing note 6). An ADR-0075-style override — Optional with no
    /// declaration default, so pre-existing exercises migrate to `nil` (CoreData 134110 exempt),
    /// mirroring `targetTempoOverride`.
    var backoffTempoOverride: Int?

    /// Whether the routine steps every N **bars** or every N **seconds** — typed view over
    /// `rampIntervalUnitRaw`.
    var rampIntervalUnit: MetronomeIntervalUnit {
        get { MetronomeIntervalUnit(rawValue: rampIntervalUnitRaw) ?? .bars }
        set { rampIntervalUnitRaw = newValue.rawValue }
    }

    /// Open descriptive tags ("warmup", "picking"), routed through the shared `Labels`
    /// canonicaliser at the write site, like `Loop.tags`. Declaration default keeps
    /// migration additive (CoreData 134110 rule).
    var tags: [String] = []

    /// Optional free-text notes about the exercise. On a **freeform** block this is not a note
    /// *about* the drill — it **is** the drill (ADR 0136 F2): the player's own written instructions,
    /// shown on the run screen and the entire content of the block.
    var notes: String = ""

    /// **The player's statement that this block needs no instrument** (ADR 0139 O6) — what lets an
    /// "Away from your instrument" session be more than three ear blocks: transcription, note-name
    /// drilling, songwriting, a teacher's listening assignment.
    ///
    /// **Declared, never inferred.** ADR 0136 F8 holds exactly as written — the app knows nothing
    /// about a freeform block's content and does not guess from its prose, which would be quiet,
    /// undebuggable and mildly insulting when wrong. A player ticking the box is a statement.
    ///
    /// Only a freeform block can carry it (read through `declaresAwayFromInstrument`, never raw): on
    /// every other template the content *is* modelled, and every one of them wants the instrument in
    /// your hands. Declaration default keeps the migration additive (CoreData 134110 rule).
    var awayFromInstrument: Bool = false

    /// How cleanly the player owns this exercise, 0–5 — or `nil` when never rated. The
    /// **self-rating** the V2 planner's dueScore reads as *need* (ADR 0070 no-grading wall:
    /// the app never measures how well you played; you set this). Mirrors `Loop.mastery`
    /// (ADR 0039) exactly — **optional on purpose** so an untouched exercise reads "never
    /// rated" rather than a fake `0` ("can't play it at all"). Optional is exempt from the
    /// CoreData 134110 mandatory-attribute rule, so pre-planner exercises migrate to `nil`
    /// with no store wipe. Never auto-decayed — time-driven resurfacing is `lastPracticed`'s
    /// job, not this number's (the planner never silently lowers a rating the player set).
    var mastery: Int?

    /// When this exercise was last practised (a run started) — or `nil` when never run.
    /// Feeds the planner on **two** axes from one field: *dueness* on the focused axis (an
    /// exercise resurfaces as time passes since it was practised) and least-recently-used
    /// *rotation* on the warm-up axis. Mirrors `Song.lastPracticed`. Optional with no
    /// declaration default so pre-planner exercises migrate to `nil` (CoreData 134110 exempt)
    /// — which is exactly the truth: never practised.
    var lastPracticed: Date?

    /// When the exercise was created — the default library sort key.
    var dateAdded: Date = Date.now

    /// A manual **favourite** pin (ADR 0119) — the player's explicit "keep this close," surfaced by the
    /// Exercises library's Favourites filter (a "show only starred" toggle). Not `mastery` (a *derived*
    /// proficiency, ADR 0036) and not a grade (ADR 0070): it feeds no algorithm, only where the item
    /// is shown. A plain `Bool` with a declaration default so SwiftData lightweight migration fills
    /// pre-0119 exercises with `false` — additive, no store wipe (CoreData 134110 rule).
    var isFavorite: Bool = false

    /// **Provenance**: the stable slug of the seeded preset this exercise was created from (ADR 0112,
    /// e.g. `"a-minor-pentatonic"`) — `nil` for a user-authored drill. A plain optional `String`, not
    /// an enum, so the add is a **lightweight, non-lossy** migration: rows saved before this field
    /// decode to `nil` (CoreData 134110 rule, ADR 0012/0036). It records *where the drill came from*,
    /// never a Pro flag — access stays computed live from `isPro` (ADR 0112 "gate at read time"). Its
    /// only monetization use is the free-taste **run** allowance (`AccessPolicy.isFreeTaste`): a free
    /// user may run the curated seeded presets even on a Pro-family template. **Never** filter it in a
    /// `#Predicate` (`presetSlug != nil` starves the main thread — the optional-predicate freeze);
    /// read it per-object in memory at the gate.
    var presetSlug: String?

    /// The exercise's practice journal — dated, context-snapshotting entries (ADR 0038/0058),
    /// mirroring `Loop.journal`. Cascade-owned: deleting the exercise deletes its entries.
    /// Declaration default keeps SwiftData lightweight migration additive (CoreData 134110
    /// rule, ADR 0012) for exercises saved before journalling reached them.
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.exercise)
    var journal: [JournalEntry] = []

    /// Practice takes recorded against this exercise (ADR 0069). **Cascade-owned**, mirroring
    /// `journal`: deleting the exercise deletes its takes' rows; the files are reaped by
    /// `RecordingStore`'s orphan sweep. Declaration default keeps the migration additive
    /// (CoreData 134110 rule) for exercises saved before recording shipped.
    @Relationship(deleteRule: .cascade, inverse: \Recording.exercise)
    var recordings: [Recording] = []

    /// Journal entries newest-first — the order the journal lists them in (mirrors `Loop`).
    var journalByRecent: [JournalEntry] {
        journal.sorted { $0.createdAt > $1.createdAt }
    }

    /// Routine blocks that **reference** this exercise (ADR 0066 R4/R5). Inverse of
    /// `RoutineItem.exercise`, with a **nullify** delete rule: deleting the exercise
    /// clears those blocks' link (the routine survives; the block becomes orphaned and
    /// the player skips it) — it does **not** delete the routines. Additive optional
    /// relationship (CoreData 134110 rule) for exercises saved before routines shipped.
    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []

    /// The songs this drill is **for** (ADR 0111) — a user-authored repertoire edge, the
    /// inverse of `Song.linkedExercises`. The store's **first many-to-many**: the `@Relationship`
    /// (with its `inverse:` key path) is declared on this side only; `Song.linkedExercises` is a
    /// plain array whose inverse SwiftData infers (declaring `inverse:` on both sides is a
    /// circular-reference error). **`.nullify`, no cascade** — deleting a song just removes it from
    /// this set; the exercise (a standalone unit) survives, and vice versa. Additive optional
    /// relationship (declaration default `[]`) so SwiftData lightweight migration fills exercises
    /// saved before the edge with an empty set — no store wipe (CoreData 134110 rule). Pure
    /// metadata: never an audio or tempo input, so the exercise's audio/tempo firewall is intact.
    @Relationship(deleteRule: .nullify, inverse: \Song.linkedExercises)
    var linkedSongs: [Song] = []

    init(name: String = "",
         currentTempo: Int = 80,
         commandTempo: Int? = nil,
         targetTempo: Int = 120,
         beatsPerBar: Int = 4,
         noteValue: Int = 4,
         accentBeats: [Int] = [0],
         subdivision: Subdivision = .none,
         notesPerBeat: Int? = nil,
         commandNotesPerBeat: Int? = nil,
         template: ExerciseTemplate = .basic,
         instrument: Instrument = .guitar,
         templatePayload: Data? = nil,
         rampStepBPM: Int = 5,
         rampIntervalCount: Int = 4,
         rampIntervalUnit: MetronomeIntervalUnit = .bars,
         dwellIntervals: Int = 4,
         includeBackoff: Bool = true,
         rampReachSteps: Int = 0,
         rampBackoffSteps: Int = 0,
         backoffTempoOverride: Int? = nil,
         tags: [String] = [],
         notes: String = "",
         mastery: Int? = nil,
         lastPracticed: Date? = nil,
         dateAdded: Date = .now) {
        self.uid = UUID()
        self.name = name
        self.currentTempo = currentTempo
        self.commandTempo = commandTempo
        self.targetTempo = targetTempo
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
        self.accentBeats = accentBeats
        self.subdivisionRaw = subdivision.rawValue
        self.notesPerBeat = notesPerBeat.map { max(1, $0) }
        self.commandNotesPerBeat = commandNotesPerBeat.map { max(1, $0) }
        self.templateRaw = template.rawValue
        self.instrumentRaw = instrument.rawValue
        self.templatePayload = templatePayload
        self.rampStepBPM = rampStepBPM
        self.rampIntervalCount = rampIntervalCount
        self.rampIntervalUnitRaw = rampIntervalUnit.rawValue
        self.dwellIntervals = dwellIntervals
        self.includeBackoff = includeBackoff
        self.rampReachSteps = rampReachSteps
        self.rampBackoffSteps = rampBackoffSteps
        self.backoffTempoOverride = backoffTempoOverride
        self.tags = tags
        self.notes = notes
        self.mastery = mastery
        self.lastPracticed = lastPracticed
        self.dateAdded = dateAdded
    }

    /// Mark this exercise practised **now** — stamps `lastPracticed` so the planner's dueness
    /// (focused axis) and LRU rotation (warm-up axis) both advance. Called from the run path
    /// when a run actually starts; deliberately does *not* touch `mastery` (self-rated only).
    func markPracticed(_ date: Date = .now) { lastPracticed = date }

    /// Whether this unit can honestly be practised with nothing in your hands (ADR 0139 O6). Gated on
    /// the template as well as the flag, so a value left behind on an exercise whose template somehow
    /// isn't freeform can never leak into a constrained session — the declaration is meaningful only
    /// where the app doesn't model the content.
    var declaresAwayFromInstrument: Bool { template == .freeform && awayFromInstrument }

    /// The time signature as a display string ("4/4", "6/8").
    var timeSignatureLabel: String { "\(beatsPerBar)/\(noteValue)" }
}
