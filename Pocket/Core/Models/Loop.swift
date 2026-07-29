import Foundation
import SwiftData

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

    /// A **manually pinned reach** (× of original) — the player's own goal above `command`,
    /// overriding the auto-derived `derivedTargetSpeed` (ADR 0075). `nil` = use the derived
    /// reach (the default). **Optional with no declaration default** so SwiftData lightweight
    /// migration leaves loops saved before this as `nil` (auto), the CoreData 134110 rule
    /// (ADR 0012) shared with `mastery`/`commandTempo`. Auto-cleared by `promoteCommand` once
    /// the owned command catches up to it (a reach must stay above command). Read through the
    /// effective `targetSpeed`, never directly, so a pin shows through everywhere.
    var targetSpeedOverride: Double?

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

    /// A manual **favourite** pin (ADR 0119) — the player's explicit "keep this passage close,"
    /// surfaced by the Loops library's Favourites filter, which across every song's loops gives a
    /// "my key passages" view the per-song browse can't. Distinct from `mastery`/`focus` (the
    /// planner's *need*/*intent* signals) and never a grade (ADR 0070): it feeds no algorithm, only
    /// where the loop is shown. A plain `Bool` with a declaration default so SwiftData lightweight
    /// migration fills pre-0119 loops with `false` — additive, no store wipe (CoreData 134110 rule).
    var isFavorite: Bool = false

    // Automator (ADR 0013): the per-loop speed ramp. Defaults on the *declarations* so
    // SwiftData lightweight migration fills them for loops saved before this — see the
    // ADR 0012 migration note (init-only defaults fail with CoreData 134110). The loop's
    // existing `speed` is the ramp start; these add the target, the step count, and the
    // passes per step.
    var automatorEnabled: Bool = false
    var automatorTargetSpeed: Double = 1.0
    var automatorStepCount: Int = 6
    var automatorLoopsPerStep: Int = 2

    // Run-setup ramp shape (ADR 0057 follow-up): the four staircase controls the Practice
    // loop run-setup exposes — warm-up intermediate stops, reach steps, back-off steps, reps
    // per step. **Deliberately separate** from the ADR-0013 automator above: that's the
    // waveform-screen ramp ("steps to target"), these are the command-anchored run ramp
    // ("intermediate stops between working and command"), with different semantics — coupling
    // the two to save four fields is a bug magnet. Declaration defaults so SwiftData lightweight
    // migration fills loops saved before this without a store wipe (CoreData 134110 rule, ADR
    // 0012), same discipline as the automator fields. `rampRepsPerStep` defaults to
    // `LoopCommandRamp.defaultRepsPerStep` (1); the rest to `0` (no intermediate stops / drop).
    var rampWarmupSteps: Int = 0
    var rampReachSteps: Int = 0
    var rampBackoffSteps: Int = 0
    var rampRepsPerStep: Int = 1
    /// How many intervals the command plateau dwells — the consolidation hold, now user-tunable
    /// (ADR 0078). Defaults to `LoopCommandRamp.defaultDwellIntervals` (4) so loops saved before
    /// this field migrate cleanly via SwiftData lightweight migration, matching the old fixed value.
    var rampDwellIntervals: Int = 4
    /// Whether the ramp **backs off** below command after the summit (user-testing note 6; loop
    /// counterpart of `Exercise.includeBackoff`). Declaration default → additive migration.
    var includeBackoff: Bool = true
    /// A pinned **backoff floor** (× of original), or `nil` to derive it (note 6). Additive optional,
    /// mirroring `targetSpeedOverride`.
    var backoffSpeedOverride: Double?

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

    /// Practice takes recorded against this loop (ADR 0069). **Cascade-owned**, mirroring
    /// `journal`: deleting the loop deletes its takes' rows — their files are then reaped by
    /// `RecordingStore`'s orphan sweep (cascade removes the row, not the on-disk audio).
    /// Declaration default keeps the migration additive (CoreData 134110 rule) for loops
    /// saved before recording shipped.
    @Relationship(deleteRule: .cascade, inverse: \Recording.loop)
    var recordings: [Recording] = []

    /// Journal entries newest-first — the order the journal sheet lists them in.
    var journalByRecent: [JournalEntry] {
        journal.sorted { $0.createdAt > $1.createdAt }
    }

    /// Routine blocks that **reference** this loop (ADR 0066 R4/R5). Inverse of
    /// `RoutineItem.loop`, **nullify** delete rule: deleting the loop clears those blocks'
    /// link (the routine survives; the block is skipped) — it does not delete the routines.
    /// Additive optional relationship (CoreData 134110 rule).
    @Relationship(deleteRule: .nullify, inverse: \RoutineItem.loop)
    var routineItems: [RoutineItem] = []

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

    /// The speed you last **left** this loop at (ADR 0040): the speed you last practised it at, or —
    /// when never practised (`nil`) — its `speed` (creation / automator-start). Still recorded on
    /// leave (the `activeLoopID` `didSet`), but **no longer what a loop arms at** — arming is now
    /// command-anchored via `armingSpeed` (ADR 0089), so this is retained only as the leave record.
    /// Clamped to the speed axis on read (ADR 0124) — the ceiling moved to 1.5×, and a value stored
    /// under the old one must not hand the engine a rate the slider can no longer show.
    var resumeSpeed: Double { TempoMath.clamped(speed: lastPracticedSpeed ?? speed) }

    /// The working speed to **arm** this loop at (ADR 0089): its measured `commandTempo` when set,
    /// else full tempo (`1.0`) — **never** the tempo of the loop you were just on. Arming is
    /// command-anchored: the tempo you own a loop at is the sensible working tempo, so switching to a
    /// loop with no command tempo resets to 100% instead of inheriting the previous loop's rate (the
    /// tempo-bleed bug). Supersedes `resumeSpeed` at every waveform arming site.
    /// Clamped on read for the same reason as `resumeSpeed` (ADR 0124).
    var armingSpeed: Double { TempoMath.clamped(speed: commandTempo ?? 1.0) }

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
    /// (pure `TempoStretch`). The loop analogue of `Exercise.derivedTarget`; the **auto** value, kept
    /// pure so a reset-to-auto affordance can fall back to it. Read `targetSpeed` for the effective reach.
    var derivedTargetSpeed: Double { TempoStretch.targetSpeed(forCommand: command) }

    /// The **effective** reach (×): the pinned `targetSpeedOverride` when set, else the auto
    /// `derivedTargetSpeed` (ADR 0075). Every surface that renders "the goal" reads this so a pin
    /// shows through. Mirrors `Exercise.reachTempo`.
    var targetSpeed: Double { targetSpeedOverride ?? derivedTargetSpeed }

    /// Whether the reach is a manual pin vs the auto derivation — gates the reset-to-auto affordance.
    var hasTargetOverride: Bool { targetSpeedOverride != nil }

    /// Promote a newly-owned speed to `commandTempo` (ADR 0046, Phase B / 0075). The auto reach is
    /// derived, so promotion is a single write — but a **pinned** reach that the new command has
    /// caught up to is auto-cleared (a reach must stay above command), reverting to the auto value.
    func promoteCommand(to speed: Double) {
        commandTempo = speed
        if let pinned = targetSpeedOverride, pinned <= command { targetSpeedOverride = nil }
    }

    /// The command-anchored **training ramp** this loop prescribes (ADR 0046 Phase B) — warm up →
    /// dwell at command → summit at the reach → back off, in percent units, from the saved ramp-shape
    /// fields so the routine player (ADR 0066) runs a stored recipe with no setup UI. Pure/UI-free.
    var ramp: CommandRamp {
        LoopCommandRamp.make(loop: self, warmupSteps: rampWarmupSteps,
                             dwellIntervals: max(1, rampDwellIntervals),
                             reachSteps: rampReachSteps, backoffSteps: rampBackoffSteps,
                             includeBackoff: includeBackoff, backoffOverride: backoffSpeedOverride,
                             repsPerStep: max(1, rampRepsPerStep))
    }
}
