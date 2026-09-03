import Foundation
import SwiftData

/// Why a `.redmoonpractice` file could not be opened, in the four ways it can fail (ADR 0188 S2).
///
/// Each carries its own sentence, and that is the point. "Couldn't read the file" for a payload this
/// build simply does not know about would be a lie about a file that is perfectly well formed, and
/// D9's whole argument is that the player is told what was found *before* anything happens.
///
/// `Error` because it is a `Result`'s failure type, which Swift requires; nothing throws it. The
/// message is read off the case rather than `localizedDescription`, so the copy stays in this file
/// where it can be read as copy.
enum ReceiveFailure: Error, Equatable {

    /// Not JSON, or not this shape. The only genuinely opaque case.
    case corrupt

    /// Written by a newer build (D2). Carries `SchemaVersionGate`'s sentence rather than composing
    /// its own, so the two doors refuse in the same words.
    case futureVersion(message: String)

    /// A payload kind this build has never heard of — an exercise share from a later version, most
    /// likely. `SharedPractice.kindRaw` is a `String` precisely so this is reportable instead of
    /// arriving as a decode failure.
    case unsupportedKind

    /// The file says it holds a routine and holds none. Distinct from `.corrupt`: the JSON parsed,
    /// the version agreed, and the contents still contradict the header.
    case incomplete

    /// What the player is told.
    var message: String {
        switch self {
        case .corrupt:
            return "This doesn’t look like a Red Moon practice file."
        case let .futureVersion(message):
            return message
        case .unsupportedKind:
            return "This file holds something this version of Red Moon can’t open yet."
        case .incomplete:
            return "This file says it holds a routine, but the routine is missing."
        }
    }
}

/// A `.redmoonpractice` file that has been read, checked, and **not yet written anywhere**
/// (ADR 0188 D9).
///
/// The type exists to make the preview and the write read the same thing. Its `routine` is
/// non-optional — `SharedPractice.routine` is optional so an unknown payload still decodes far enough
/// to be reported, and this is the shape on the far side of that check, so nothing downstream has to
/// re-ask whether the routine is there.
///
/// Every count and label the preview sheet shows is computed here rather than in the view: what lands
/// and what the player was told must come from one place, or the preview becomes a second opinion.
struct ReceivedRoutine: Equatable {
    var routine: RoutineRecord
    var exercises: [ExerciseRecord]
    var placeholders: [SharedBlockPlaceholder]

    /// The build and the moment the sender wrote it. On the untrusted door this is the only
    /// provenance there is, which is exactly why it is shown rather than merely stored.
    var appVersion: String
    var exportedAt: Date

    /// What to call it on screen. Falls back the way `RoutineDetailView+Share.shareTitle` does — a
    /// routine can legitimately be saved unnamed, and an empty heading reads as a broken file.
    var displayName: String {
        let name = routine.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Practice routine" : name
    }

    /// How many blocks the sitting has, placeholders included — the count is of the routine that was
    /// *sent*, and D4's argument for carrying unresolvable blocks is that the receiver gets the same
    /// shape rather than a quietly shorter one.
    var blockCount: Int { routine.items.count }

    /// The drills travelling inline. Fewer than `blockCount` whenever a drill is used twice, which is
    /// why both numbers are shown.
    var exerciseCount: Int { exercises.count }

    /// What the sender's loop and song blocks pointed at, in their words (D4). Empty on a
    /// routine of pure exercise and rest blocks, and the preview then says nothing at all.
    var placeholderLabels: [String] { placeholders.map(\.label) }
}

/// The models a received routine becomes, **uninserted** (ADR 0188 S2).
///
/// A type rather than the tuple `Routine.duplicated(named:)` returns, because there are three parts
/// and the order they are assembled in is not obvious: drills first, then the routine, then its
/// blocks — a `RoutineItem` is a `@Model` in its own right, so its parent has to be in the context
/// before it is attached. `insert(into:)` is that order, written once.
struct HydratedRoutine {
    var routine: Routine
    var exercises: [Exercise]
    var items: [RoutineItem]

    /// Write the whole graph into `context`, in the one order that works.
    ///
    /// The same sequence `RoutineLibraryView.duplicate(_:)` uses for a duplicate, with the drills
    /// added because a received routine brings its own rather than pointing at the library's.
    @MainActor
    func insert(into context: ModelContext) {
        exercises.forEach(context.insert)
        context.insert(routine)
        routine.items = items
    }
}

/// Turns a `.redmoonpractice` file back into models (ADR 0188 S2) — the mirror of
/// `SharedPracticeBuilder`, and the reason that one exists as a value-returning function.
///
/// `@MainActor` for the same reason as its sending counterpart and no other: a `@Model` is
/// main-actor work and neither a model nor a `ModelContext` is `Sendable`. The two functions that
/// touch no model (`evaluate`, and the checks inside it) inherit the isolation harmlessly — a
/// decode is cheap and both doors call it from a view action anyway.
///
/// ### Nothing here inserts
///
/// `materialize` returns an **uninserted** object graph, exactly the contract
/// `Routine.duplicated(named:)` already has. That is not tidiness: inserting a full graph inside the
/// XCTest host traps (`docs/swiftdata-gotchas.md`), so a builder that inserted could not be tested at
/// all, and the receiving path is the one place in this app where the input is a file somebody else
/// wrote.
@MainActor
enum ReceivedRoutineBuilder {

    /// Read a file's bytes and decide whether there is anything to offer the player (D2, D9).
    ///
    /// Pure over `Data`, so every branch below is reachable from a test without a picker, a document
    /// type or a simulator.
    static func evaluate(data: Data) -> Result<ReceivedRoutine, ReceiveFailure> {
        guard let payload = try? ArchiveCoding.decode(SharedPractice.self, from: data) else {
            return .failure(.corrupt)
        }
        // Version first, before anything else is believed about the contents (D2). A file from the
        // future may well decode — the records are additive — and the fields this build cannot see
        // are precisely the ones that would make the import wrong.
        if case let .refuse(message) = SchemaVersionGate.evaluate(fileVersion: payload.schemaVersion) {
            return .failure(.futureVersion(message: message))
        }
        guard payload.kind == .routine else { return .failure(.unsupportedKind) }
        guard let routine = payload.routine else { return .failure(.incomplete) }
        return .success(ReceivedRoutine(routine: routine,
                                        exercises: payload.exercises,
                                        placeholders: payload.placeholders,
                                        appVersion: payload.appVersion,
                                        exportedAt: payload.exportedAt))
    }

    /// Build the models a received routine becomes — **uninserted**, for `HydratedRoutine.insert` to
    /// assemble.
    static func materialize(_ received: ReceivedRoutine) -> HydratedRoutine {
        let drills = received.exercises.map { ($0.uid, exercise(from: $0)) }
        // Keyed by the **file's** uid, which is a join key inside this payload and nothing else
        // (`SharedPracticeBuilder.shareable(_:)` says so where it decides to keep it). It is never
        // written to the new `Exercise.uid`: D1's "mint a new one" is what `Exercise.init` does
        // unconditionally, so the trust asymmetry costs no code here at all.
        let byFileUID = Dictionary(drills, uniquingKeysWith: { first, _ in first })

        let routine = Routine(name: received.routine.name)
        // Carried because it is what the session is *for* (ADR 0177) — the teacher's own words about
        // the sitting. `lastPracticed`, `isFavorite` and `presetSlug` are not, and are not cleared
        // here either: they are simply never assigned, so the model's own defaults hold. The sender
        // already strips them (D4); this side does not depend on that, because the file may have been
        // written by anything.
        routine.notes = received.routine.notes

        // The sender's words for the blocks that cannot cross (D4), keyed by the file's item uid so
        // each block can be handed its own. Preview-only until the S2 follow-up gave `RoutineItem`
        // somewhere to keep them.
        let labels = Dictionary(received.placeholders.map { ($0.itemUID, $0.label) },
                                uniquingKeysWith: { first, _ in first })

        let items = ordered(received.routine.items).enumerated().map { index, record in
            block(from: record, order: index, exercises: byFileUID, labels: labels)
        }
        return HydratedRoutine(routine: routine, exercises: drills.map(\.1), items: items)
    }

    // MARK: - Blocks

    /// The file's blocks in play order.
    ///
    /// Sorted and then **renumbered from zero** by the caller, for `Routine.duplicated(named:)`'s
    /// reason: a routine whose `order` values have drifted — or a file somebody hand-edited — arrives
    /// clean rather than carrying the drift into a new library. Ties break on the file's uid, matching
    /// `Routine.ordered`, so the result is stable rather than whatever the JSON array happened to hold.
    private static func ordered(_ records: [RoutineItemRecord]) -> [RoutineItemRecord] {
        records.sorted { lhs, rhs in
            lhs.order == rhs.order ? lhs.uid.uuidString < rhs.uid.uuidString : lhs.order < rhs.order
        }
    }

    /// One block, pointing at the inline drill it names — or at nothing.
    ///
    /// A block whose `exerciseUID` names no drill in the file, and every loop and song block (whose
    /// ids `SharedPracticeBuilder` deliberately never writes), lands with all three unit
    /// relationships `nil`. That is precisely `RoutineItem.isOrphaned`, which the routine screen
    /// already draws as a skipped block — D4's "exactly what the app already knows how to draw",
    /// reached by writing no drawing code.
    ///
    /// It also lands **named**, when the file said what it was. The placeholder wins over the
    /// record's own `orphanLabel` because it is what *this* sender could not send; the record is the
    /// fallback, and the only source an archive restore (S3) will have.
    private static func block(from record: RoutineItemRecord, order: Int,
                              exercises: [UUID: Exercise],
                              labels: [UUID: String]) -> RoutineItem {
        let item = RoutineItem(order: order)
        // The raw column verbatim, not `RoutineItemKind(raw:)`. The typed setter would fold a kind
        // this build does not recognise into `.rest` and write that, turning a drill block from a
        // later version into a silent gap; stored raw, the value survives for a build that knows it.
        item.kindRaw = record.kindRaw
        item.reps = record.reps
        item.plannedMinutes = record.plannedMinutes
        item.usesAuthoredLength = record.usesAuthoredLength
        item.recordsTake = record.recordsTake
        item.loopRunModeRaw = record.loopRunModeRaw
        if let uid = record.exerciseUID { item.exercise = exercises[uid] }
        // Only onto a block that resolved nothing. A well-formed file never names an exercise block
        // here, but this door's input is a file somebody else wrote: a label stored on a block that
        // *does* resolve would be a fact about the block that is not true, sitting there waiting for
        // a future reader to trust it.
        if item.exercise == nil {
            item.orphanLabel = labels[record.uid] ?? record.orphanLabel
        }
        return item
    }

    // MARK: - Drills

    /// One received drill (D5) — the same **shape**, none of the sender's **history**.
    ///
    /// The drops are `Exercise.duplicated(named:)`'s, plus the two a duplicate correctly keeps and a
    /// share must not: `commandTempo` and `commandNotesPerBeat` are a *measured* achievement
    /// (ADR 0045), and inheriting them would hand the receiver a grade with somebody else's name on
    /// it — which ADR 0070 forbids the app itself from inventing. `linkedSongIDs` names songs by
    /// `sourceID`, which are files on the sender's phone (ADR 0148), so there is nothing here for
    /// them to point at.
    ///
    /// Those fields are dropped by **not being assigned** — `Exercise.init` defaults every one of
    /// them to the empty answer. `SharedPracticeBuilder` already clears them on the way out, and this
    /// side deliberately does not rely on that: this is the untrusted door, and the file may have
    /// been written by a hand, an older build, or a build that has not shipped yet.
    private static func exercise(from record: ExerciseRecord) -> Exercise {
        let drill = Exercise(name: record.name,
                             currentTempo: record.currentTempo,
                             targetTempo: record.targetTempo,
                             beatsPerBar: record.beatsPerBar,
                             noteValue: record.noteValue,
                             accentBeats: record.accentBeats,
                             notesPerBeat: record.notesPerBeat,
                             templatePayload: templateData(record.template),
                             rampStepBPM: record.rampStepBPM,
                             rampIntervalCount: record.rampIntervalCount,
                             dwellIntervals: record.dwellIntervals,
                             includeBackoff: record.includeBackoff,
                             rampReachSteps: record.rampReachSteps,
                             rampBackoffSteps: record.rampBackoffSteps,
                             backoffTempoOverride: record.backoffTempoOverride,
                             tags: record.tags,
                             notes: record.notes)
        // A pinned reach is a goal the author set, not a number anybody measured, so it crosses —
        // the same call `Exercise.duplicated(named:)` makes.
        drill.targetTempoOverride = record.targetTempoOverride
        // The freeform block's own settings (ADR 0136 F3/O6): a declared "no instrument needed" and
        // an optional plain click. Part of the drill's shape, and `clickBPM` is explicitly not a
        // command tempo, which is what makes carrying it safe.
        drill.awayFromInstrument = record.awayFromInstrument
        drill.clickEnabled = record.clickEnabled
        drill.clickBPM = record.clickBPM
        // **The four enum columns are assigned raw, not through their typed setters.** Only
        // `RoutineItemKind`, `LoopRunMode` and `EntryKind` have an `init(raw:)`; `ExerciseTemplate`,
        // `Instrument`, `Subdivision` and `MetronomeIntervalUnit` resolve with a `?? default` inside
        // their getters, so a value this build does not recognise would be normalised on the way in
        // and written back as the default — a drill authored on a future template arriving as
        // "Basic", carrying a payload nothing can read. Stored verbatim, it survives intact for the
        // build that understands it: the same forward compatibility `JSONValue` exists for on the way
        // out.
        drill.templateRaw = record.templateRaw
        drill.instrumentRaw = record.instrumentRaw
        drill.subdivisionRaw = record.subdivisionRaw
        drill.rampIntervalUnitRaw = record.rampIntervalUnitRaw
        return drill
    }

    /// The drill's authored content, back in the opaque column it came out of.
    ///
    /// Re-encoded from `JSONValue` with a plain `JSONEncoder`, because that is what wrote it: the
    /// column is read by `JSONValue.decoding(_:)` with a plain `JSONDecoder`, and
    /// `ArchiveCoding`'s date strategy applies to the archive's own timestamps, not to a nested blob
    /// that has none. `nil` for a drill whose template carries no content, and `nil` again if the
    /// re-encode somehow fails — the same degrade-don't-fail rule the read side follows, and a
    /// template with no payload falls back to the metronome renderer rather than breaking.
    private static func templateData(_ value: JSONValue?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }
}
