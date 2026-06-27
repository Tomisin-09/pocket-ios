import Foundation
import SwiftData

/// A **practice exercise** (ADR 0043/0046): "Alternating picking", "Spider" — a named,
/// persistent click-only drill you return to and push faster over time, each with its own
/// working / command tempos, time signature, accents, subdivision, and a native command-ramp
/// training recipe. A list of these is the Practice space's unit list.
///
/// Deliberately **audio-free** and separate from `Loop`: a `Loop` is bound to an audio
/// file/region, an exercise has no audio source, so overloading `Loop` would leak audio
/// assumptions into a click-only entity. It is a standalone top-level entity in the
/// store (no relationship to `Song`).
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
    /// The **goal** tempo (absolute BPM) you reach for — `command` + a proportional stretch
    /// once promoted (ADR 0045), recomputed on each promotion; also the automator's summit.
    var targetTempo: Int = 120

    // Time signature: beats per bar (the click count and downbeat grouping) and the note
    // value (denominator — 4, 8, …). The standalone beat generator (slice 1) needs only
    // `beatsPerBar`; `noteValue` is carried so the signature round-trips and reads right.
    var beatsPerBar: Int = 4
    var noteValue: Int = 4

    /// Which beats accent, as 0-based indices within the bar. Default `[0]` — downbeat
    /// only. A scalar `[Int]` stays CloudKit-clean and migrates additively (declaration
    /// default, the CoreData 134110 rule), like `Loop.tags`.
    var accentBeats: [Int] = [0]

    /// Backing storage for `subdivision` — a plain `String`, **not** the enum (the
    /// SwiftData enum-attribute migration rule; see `Loop.loopTypeRaw`). Empty reads as
    /// `.none`. Declaration default so the column always has a value.
    var subdivisionRaw: String = Subdivision.none.rawValue

    /// How many clicks sound per beat — typed view over `subdivisionRaw`.
    var subdivision: Subdivision {
        get { Subdivision(rawValue: subdivisionRaw) ?? .none }
        set { subdivisionRaw = newValue.rawValue }
    }

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

    /// Optional free-text notes about the exercise.
    var notes: String = ""

    /// When the exercise was created — the default library sort key.
    var dateAdded: Date = Date.now

    init(name: String = "",
         currentTempo: Int = 80,
         commandTempo: Int? = nil,
         targetTempo: Int = 120,
         beatsPerBar: Int = 4,
         noteValue: Int = 4,
         accentBeats: [Int] = [0],
         subdivision: Subdivision = .none,
         rampStepBPM: Int = 5,
         rampIntervalCount: Int = 4,
         rampIntervalUnit: MetronomeIntervalUnit = .bars,
         dwellIntervals: Int = 4,
         includeBackoff: Bool = true,
         rampReachSteps: Int = 0,
         rampBackoffSteps: Int = 0,
         tags: [String] = [],
         notes: String = "",
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
        self.rampStepBPM = rampStepBPM
        self.rampIntervalCount = rampIntervalCount
        self.rampIntervalUnitRaw = rampIntervalUnit.rawValue
        self.dwellIntervals = dwellIntervals
        self.includeBackoff = includeBackoff
        self.rampReachSteps = rampReachSteps
        self.rampBackoffSteps = rampBackoffSteps
        self.tags = tags
        self.notes = notes
        self.dateAdded = dateAdded
    }

    /// The warm-up **floor** — the comfortable tempo a session's ramp begins from (ADR
    /// 0045). A clarity alias over the `currentTempo` storage (kept for migration); new
    /// code should prefer this name.
    var workingTempo: Int {
        get { currentTempo }
        set { currentTempo = newValue }
    }

    /// The **effective** command tempo: the measured `commandTempo` once promoted, else the
    /// working tempo (ADR 0045) — an un-promoted exercise's command is taken as where it's
    /// currently practised, so the reach still computes and the UI degrades to the old
    /// light model gracefully.
    var command: Int { commandTempo ?? currentTempo }

    /// Whether a command tempo has been measured/promoted yet (vs falling back to working).
    var hasMeasuredCommand: Bool { commandTempo != nil }

    /// The reach derived from the current `command` (ADR 0045): proportional + clamped.
    /// What `targetTempo` is set to on promotion; surfaced so the UI can preview the reach.
    var derivedTarget: Int { TempoStretch.targetBPM(forCommand: command) }

    /// The command-anchored **training routine** this exercise prescribes (ADR 0045/0046):
    /// warm up from the working floor to the owned command, dwell there, summit briefly at the
    /// derived reach, then back off below command. The single pure seam Practice launches a run
    /// from — `engine.run(ramp:)` drives this `CommandRamp` directly instead of routing through
    /// the automator setters. Built entirely from the saved **native** recipe (`rampStepBPM` /
    /// interval / unit / `dwellIntervals` / `includeBackoff`). Pure and UI-free, so the plateau
    /// math stays unit-tested per AGENTS.md.
    var ramp: CommandRamp {
        CommandRamp(working: workingTempo, command: command, target: derivedTarget,
                    stepBPM: max(1, rampStepBPM), intervalCount: max(1, rampIntervalCount),
                    unit: rampIntervalUnit, dwellIntervals: max(1, dwellIntervals),
                    includeBackoff: includeBackoff,
                    reachSteps: max(0, rampReachSteps), backoffSteps: max(0, rampBackoffSteps))
    }

    /// Promote a newly-owned tempo to `command` and recompute the `target` reach above it
    /// (ADR 0045, Phase 1 — manual "I own this"). Phase 1 overwrites `targetTempo` from the
    /// new command; a Phase 2 milestone record and pinned-target flag are out of scope here.
    func promoteCommand(to tempo: Int) {
        commandTempo = tempo
        targetTempo = TempoStretch.targetBPM(forCommand: tempo)
    }

    /// The Italian tempo marking for the current working tempo (ADR 0043, slice 1) —
    /// "Andante", "Allegro", … Pure derived from `currentTempo`.
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(currentTempo)) }

    /// The "light progress" gap: BPM still to climb from `currentTempo` to `targetTempo`,
    /// 0 once the working tempo has reached or passed the goal. Thin alias over the pure
    /// `progress` (ADR 0043, slice 7), kept for call sites that just want the number.
    var tempoGap: Int { progress.remaining }

    /// The time signature as a display string ("4/4", "6/8").
    var timeSignatureLabel: String { "\(beatsPerBar)/\(noteValue)" }
}
