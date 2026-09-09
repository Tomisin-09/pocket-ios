import Foundation

/// What the Oracle is given to read (ADR 0187 D5) — a purpose-built value tree, built by
/// `OracleContextBuilder` under the seven rules of D6.
///
/// **This is not `PracticeArchive`, and must never become it.** ADR 0092 §B2 forbids sending a
/// serialised SwiftData graph in terms; the archive is a *backup format* with a frozen
/// `schemaVersion` whose contract must not move when a token budget changes; and it carries song
/// titles, artist names, file names and `templatePayload` blobs the Oracle has no use for.
/// `ArchiveSource.everything(in:)` is unbounded by design, which is right for a backup and wrong
/// for a request body.
///
/// What *is* copied from the export is its architecture: source → `@MainActor` read → `Sendable`
/// value → off-main encode, total determinism, and `Date.ISO8601FormatStyle` rather than
/// `ISO8601DateFormatter` (`ArchiveBuilder.swift:92-97` records the CI burn that taught that).
///
/// ### What the safety of this feature actually rests on
///
/// Not on this type being thin. D1 is explicit that the context is deliberately *not* minimised to
/// the point of uselessness, because a reflection with no material is not a reflection. The
/// guarantee lives on the **output** side — D7's proposal that can only name units the client
/// sent, D8's clamped minutes, D11's discarded tempo, D12's wholesale prose rejection. Read this
/// type as "what a reflection needs", not as "what we dared to send".
struct OracleContext: Codable, Equatable, Sendable {

    /// The DTO's own version, bumped when a field changes meaning rather than when one is added —
    /// the `PracticeArchive.currentSchemaVersion` rule, for the same reason: a fixture recorded
    /// against an older shape must be able to say so rather than be guessed at from which keys
    /// happen to be present.
    static let currentVersion = 1

    var version: Int = OracleContext.currentVersion

    /// Which prompt this context was built to be read by (ADR 0187 D17). It travels in the payload
    /// so an eval fixture can name the prompt it was recorded against, and so a reading produced
    /// under a retired prompt is identifiable after the fact.
    var promptVersion: String

    var generatedAt: Date

    /// The period the reading covers (D15 — *the reading is periodic because it reads a period*).
    /// Sent because a model that cannot see the window would otherwise infer one from the oldest
    /// note it was handed, and narrate a gap that is really the edge of the request.
    var windowStart: Date
    var windowEnd: Date

    var units: [Unit] = []
    var notes: [Note] = []
    var goals: [GoalLine] = []
    var effort: Effort = Effort()

    /// Set when D6 R4's budget forced whole notes to be dropped. The model is told the excerpt is
    /// partial rather than left to read a truncated month as a quiet one — the same instinct as
    /// `TempoTrajectory.otherRhythmRuns`, which exists so a partial history admits it.
    var droppedNotes: Int = 0
}

extension OracleContext {

    /// A drill or a loop, behind a **per-request handle** (D6 R1).
    ///
    /// `handle` is `u1`, `u2`, … minted fresh for this request, with the map back to real `uid`s
    /// held client-side. Two things fall out: proxy-side logging is harmless, because a handle
    /// means nothing an hour later; and rejecting a hallucinated unit in a proposal is a dictionary
    /// lookup rather than a judgement call (D7).
    struct Unit: Codable, Equatable, Sendable {
        let handle: String
        /// Truncated to `OracleContextBudget.unitNameCap`. Player-written, so it is free text and
        /// obeys R4 like any other.
        let name: String
        let kind: UnitKind
        /// `ExerciseTemplate.rawValue` — a **closed** vocabulary (ADR 0187 D9), never free text.
        /// `nil` for a loop, which has no template.
        let template: String?
        /// The player's own self-rating (ADR 0016), which is a fact they stated rather than a
        /// measurement anybody took. `nil` when they have not rated it.
        let mastery: Int?
        /// Never a bare BPM series (D6 R7).
        let tempo: Tempo?
        let runs: Int
        let minutes: Int
        /// The day it was last practised, or `nil`. A **date**, never a days-since (D6 R6): the
        /// difference between "last practised on the 3rd" and "neglected for 19 days" is the
        /// difference between a fact and an accusation, and only one of them is this app's job.
        let lastPractisedOn: Date?
        // The three below are `var`s with defaults, unlike everything above them, so the memberwise
        // init defaults them — a test fixture about tempo or handles should not have to state that a
        // unit has no marks. The default is also the **safe** direction: a future field that forgot
        // to pass them under-sends rather than over-sends, which is the only way round this DTO is
        // allowed to be wrong.
        /// Where this loop's snags fall inside its **current** span (ADR 0204 D1). Always empty
        /// for an exercise, which has no timeline to mark.
        var snags: [SnagMark] = []
        /// Marks that did not fit `OracleContextBudget.maxSnagsPerUnit`. A snag set is a **map**,
        /// so a capped one has to say it is partial — the `droppedNotes` rule, for the same reason
        /// (D6 R4): a truncated map that looks complete is read as complete.
        var droppedSnags: Int = 0
        /// What this loop's span has done over time (ADR 0204 D2). Always empty for an exercise.
        var spans: [SpanEdit] = []
    }

    /// One snag, as a **position inside the loop it sits in** (ADR 0204 D1).
    ///
    /// Never an absolute point in a song, and never a count. `atSeconds` is measured from the
    /// loop's current start, so the value means something without the song it came from — which is
    /// also what keeps D6 R2 intact: there is no title here for an offset to be an offset *into*.
    ///
    /// The date travels because *when* the marks were made separates two readings that the
    /// positions alone cannot: four marks in one sitting is a passage fought over once, four marks
    /// across three weeks is one that keeps coming back. What must not be derived from it is a
    /// rate — see D3, which is a rule about the prompt, not about this type.
    struct SnagMark: Codable, Equatable, Sendable {
        /// Seconds from the start of the loop's current span.
        let atSeconds: TimeInterval
        let markedOn: Date
        /// The playback speed in force at the tap, or `nil` when it could not be read. A snag at
        /// 0.6× and a snag at full tempo are not the same admission (ADR 0200).
        let speed: Double?
    }

    /// One recorded edit to a loop's span (ADR 0204 D2), in seconds.
    ///
    /// Both widths travel, so a row is self-contained exactly as `LoopSpanChange` is: narrowing
    /// from 34s to 6s is one fact, and reconstructing it from a neighbouring row's value would
    /// break the moment a row was dropped by the cap.
    ///
    /// **The classification does not travel.** `SpanHistory.Kind` — narrowed, widened, moved — is
    /// derived, and D6 R5 keeps derived values on this side of the wire. The two numbers say the
    /// same thing without the app having put an adjective on it first.
    struct SpanEdit: Codable, Equatable, Sendable {
        let changedOn: Date
        /// The span's width before the edit.
        let fromSeconds: TimeInterval
        /// The span's width after it.
        let toSeconds: TimeInterval
        /// The playback speed in force when the edit was made, or `nil`. Stored because the
        /// narrowing and the slowing are one behaviour, not two facts (ADR 0199).
        let speed: Double?
    }

    /// Nested one level under `OracleContext` rather than inside `Unit`: SwiftLint caps nesting at
    /// one, and the namespace is what was worth keeping.
    enum UnitKind: String, Codable, Equatable, Sendable, CaseIterable {
        case exercise
        case loop
    }

    /// A unit's tempo history at **one** note rate (D6 R7, ADR 0121).
    ///
    /// 90 in sixteenths and 90 in quarters are different tempos. Hand a model a bare BPM series and
    /// it will narrate a rhythm change as progress that never happened — or read a move from
    /// eighths to sixteenths as a collapse. So the rate travels with the points, and the runs set
    /// aside at other rhythms are counted rather than silently dropped.
    ///
    /// Built from `TempoTrajectory.Reading`, whose doc comment already says *"a trajectory that
    /// goes down is not reported as a regression"* — feeding the Oracle that type rather than raw
    /// `tempoBPM` columns inherits the discipline instead of re-deriving it. Its computed
    /// `change`, `first`, `latest`, `lowest` and `highest` are **left behind** on purpose: a
    /// difference is a derived judgement and R5/R6 keep those on this side of the wire.
    struct Tempo: Codable, Equatable, Sendable {
        /// Oldest first, capped at `OracleContextBudget.maxTempoPoints` by dropping the oldest —
        /// a trajectory reads from where it is now, so the recent end is the end worth keeping.
        let points: [TempoPoint]
        /// The rate every point was measured in. `nil` means the drill states no rhythm (a
        /// chord-changing drill), which is its own honest answer and not a default of quarters.
        let notesPerBeat: Int?
        let otherRhythmRuns: Int
    }

    /// One logged tempo. A bare date and a bare BPM — the rate that makes it meaningful lives on
    /// the `Tempo` that owns it, so a point can never be read on its own (D6 R7).
    struct TempoPoint: Codable, Equatable, Sendable {
        let date: Date
        let bpm: Int
    }

    /// One journal entry or take note, excerpted.
    struct Note: Codable, Equatable, Sendable {
        let writtenOn: Date
        /// Truncated to `OracleContextBudget.noteTextCap` (D6 R4).
        let text: String
        /// The unit it was written against, as a handle, or `nil` — which covers both a note
        /// written from the journal itself and one whose unit has since been deleted. ADR 0190 D6
        /// records that the two are indistinguishable today (`ownerKind` returns `.orphan` for
        /// both), so this does not pretend to tell them apart.
        let unitHandle: String?
        /// `JournalEntry.EntryKind.rawValue` — closed vocabulary.
        let kind: String
        /// Whether `text` is an excerpt. A model told a note is complete when it is not will read
        /// a cut-off sentence as a trailing thought.
        let wasTruncated: Bool
    }

    /// A goal, as the player wrote it.
    struct GoalLine: Codable, Equatable, Sendable {
        /// Truncated to `OracleContextBudget.goalTitleCap` (D6 R4).
        let title: String
        /// `LongTermGoal.order` — the rank that drives visit order (ADR 0171). `nil` for a session
        /// goal, which has a weight rather than a rank, and the weight is a planner input the
        /// Oracle has no business reading as importance.
        let rank: Int?
        let isMet: Bool
        let horizon: GoalHorizon
    }

    enum GoalHorizon: String, Codable, Equatable, Sendable, CaseIterable {
        case session
        case longTerm
    }

    /// The `kind` a take's note carries in `notes`. Take notes have no `EntryKind` of their own —
    /// the model stores prose on the `Recording` — so they join the feed under a name of their own
    /// rather than borrowing `.note`, which would make them indistinguishable from something typed
    /// into the journal.
    static let takeNoteKind = "take"

    /// Aggregated effort — **counts, minutes and dates, and nothing else** (D6 R6).
    ///
    /// `PracticeLog.swift:10-13` already refuses to compute *"a target, a denominator or a
    /// streak"*, and ADR 0117 holds those with the deferred streak work. This type must not be
    /// where they get reinvented on the way out of the app: no streak, no consistency score, no
    /// days-since, no delta, no ratio, no average. `daysPractised` is a **list of days**, not a
    /// count of consecutive ones, and the difference is the whole of ADR 0070.
    ///
    /// This is the ADR 0117 clause made mechanical — *aggregated effort as context, never as a
    /// grade*.
    struct Effort: Codable, Equatable, Sendable {
        var runs: Int = 0
        var minutes: Int = 0
        /// The distinct days, oldest first, that practice happened on inside the window.
        var daysPractised: [Date] = []
        /// Sittings as `PracticeLog` counts them (a 30-minute gap starts a new one), which is a
        /// fact about the log rather than a verdict on how it was spread.
        var sittings: Int = 0
    }
}

/// The caps D6 R4 requires to be *stated* rather than assumed.
///
/// They are here, in one enum, because a cap that lives at its use site is a cap the next author
/// changes without noticing they have changed a rule. Every one of them is asserted by a test.
enum OracleContextBudget {

    /// Per-note excerpt, in characters. Long enough for a real practice note — most are one or two
    /// sentences — and short enough that sixty of them do not dominate the payload.
    static let noteTextCap = 400
    static let goalTitleCap = 120
    static let unitNameCap = 80

    /// The ceiling on all free text in one context, in characters, across notes, goal titles and
    /// unit names. **Over budget, whole notes are dropped oldest-first** — never clipped silently,
    /// which would leave the set looking complete while the sentences inside it stopped mid-word.
    static let totalFreeTextBudget = 8_000

    static let maxNotes = 60
    static let maxUnits = 40
    /// Enough of a trajectory to see a shape; the oldest points beyond it are dropped, because a
    /// trajectory is read from the recent end.
    static let maxTempoPoints = 12

    /// Marks per loop. Generous, because the shape of a snag set — clustered at one move, or spread
    /// across the passage — is the entire signal, and a set cut down to a handful loses it. Over the
    /// cap the **oldest** are dropped and `Unit.droppedSnags` says how many.
    static let maxSnagsPerUnit = 30

    /// Span edits per loop, dropped from the **old** end like `maxTempoPoints` and unlike
    /// `maxSnagsPerUnit`. The asymmetry is deliberate and is the difference between the two things:
    /// a span history is a *trajectory*, read from where it is now, so the recent end is the end
    /// worth keeping; a snag set is a *map*, where completeness is the axis and a silent trim would
    /// misdescribe the terrain.
    static let maxSpanEditsPerUnit = 10
}
