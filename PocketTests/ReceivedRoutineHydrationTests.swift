import XCTest
@testable import Pocket

/// What a received routine **becomes** (ADR 0188 S2, D1/D4/D5) — the shape that crosses, the history
/// that does not, and the ids that are minted rather than trusted.
///
/// Asserted on the **uninserted** graph `materialize` returns, which is the contract that makes any
/// of this testable: inserting a full object graph in this host traps
/// (`docs/swiftdata-gotchas.md`), so a builder that wrote to a `ModelContext` could only ever be
/// checked by hand on a device.
///
/// Whether a file is opened at all is `ReceivedRoutineBuilderTests`; fixtures are shared through
/// `ReceivedRoutineFixture`.
@MainActor
final class ReceivedRoutineHydrationTests: XCTestCase {

    private typealias Fixture = ReceivedRoutineFixture

    private func landed(_ payload: SharedPractice) throws -> HydratedRoutine {
        ReceivedRoutineBuilder.materialize(try Fixture.received(payload))
    }

    // MARK: - The routine and its blocks

    func testTheRoutineAndItsBlocksArrive() throws {
        let landing = try landed(Fixture.shared(Fixture.routine().routine))
        let (routine, exercises, items) = (landing.routine, landing.exercises, landing.items)

        XCTAssertEqual(routine.name, "Morning warm-up")
        XCTAssertEqual(routine.notes, "The bits of week 3 that actually needed work.")
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.map(\.order), [0, 1, 2], "Blocks are renumbered from zero, in play order")
        XCTAssertEqual(exercises.map(\.name), ["Spider Walk"])

        let block = try XCTUnwrap(items.first)
        XCTAssertEqual(block.kind, .focused)
        XCTAssertEqual(block.reps, 3)
        XCTAssertEqual(block.plannedMinutes, 12)
        XCTAssertTrue(block.recordsTake)
        XCTAssertIdentical(block.exercise, exercises.first,
                           "The block points at the drill that travelled in the same file")
    }

    /// D1's trust asymmetry, and it costs no code: `Exercise.init` and `Routine.init` mint a fresh
    /// `uid` unconditionally, so a received row is a new thing rather than a claim on an existing one.
    func testEveryReceivedRowMintsItsOwnID() throws {
        let fixture = Fixture.routine()
        let value = try Fixture.received(Fixture.shared(fixture.routine))
        let landing = ReceivedRoutineBuilder.materialize(value)
        let (routine, exercises) = (landing.routine, landing.exercises)

        XCTAssertNotEqual(routine.uid, fixture.routine.uid)
        XCTAssertNotEqual(exercises.first?.uid, fixture.exercise.uid)
        XCTAssertNotEqual(exercises.first?.uid, value.exercises.first?.uid,
                          "The file's uid is a join key inside the payload, never the new row's id")
    }

    /// Receiving is additive and never deduped (D1): the same file opened twice is two routines, on
    /// purpose.
    func testTheSameFileTwiceProducesTwoDifferentRoutines() throws {
        let value = try Fixture.received(Fixture.shared(Fixture.routine().routine))

        let first = ReceivedRoutineBuilder.materialize(value)
        let second = ReceivedRoutineBuilder.materialize(value)

        XCTAssertNotEqual(first.routine.uid, second.routine.uid)
        XCTAssertNotEqual(first.exercises.first?.uid, second.exercises.first?.uid)
    }

    /// Blocks arrive in play order even when the file's `order` values have drifted or been
    /// hand-edited — `Routine.duplicated(named:)`'s renumbering rule, applied at the door.
    func testDriftedBlockOrdersArriveClean() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        var record = try XCTUnwrap(payload.routine)
        record.items = record.items.map {
            var block = $0
            block.order = 100 - block.order * 10
            return block
        }
        payload.routine = record

        let items = try landed(payload).items

        XCTAssertEqual(items.map(\.order), [0, 1, 2])
        XCTAssertEqual(items.first?.kind, .rest, "The file's last block sorted first, and stayed first")
    }

    // MARK: - The drill (D5)

    /// The drill's whole shape crosses — this is what a teacher is actually handing over.
    func testTheDrillsShapeCrossesIntact() throws {
        let exercises = try landed(Fixture.shared(Fixture.routine().routine)).exercises
        let drill = try XCTUnwrap(exercises.first)

        XCTAssertEqual(drill.currentTempo, 96)
        XCTAssertEqual(drill.targetTempo, 144)
        XCTAssertEqual(drill.targetTempoOverride, 160)
        XCTAssertEqual(drill.beatsPerBar, 6)
        XCTAssertEqual(drill.noteValue, 8)
        XCTAssertEqual(drill.accentBeats, [0, 3])
        XCTAssertEqual(drill.notesPerBeat, 3)
        XCTAssertEqual(drill.template, .scales)
        XCTAssertEqual(drill.instrument, .bass)
        XCTAssertEqual(drill.rampStepBPM, 7)
        XCTAssertEqual(drill.rampIntervalCount, 8)
        XCTAssertEqual(drill.rampIntervalUnit, .seconds)
        XCTAssertEqual(drill.dwellIntervals, 6)
        XCTAssertFalse(drill.includeBackoff)
        XCTAssertEqual(drill.rampReachSteps, 2)
        XCTAssertEqual(drill.rampBackoffSteps, 1)
        XCTAssertEqual(drill.backoffTempoOverride, 70)
        XCTAssertEqual(drill.tags, ["picking"])
        XCTAssertEqual(drill.notes, "Keep the thumb behind the neck.")
        XCTAssertTrue(drill.clickEnabled)
        XCTAssertEqual(drill.clickBPM, 54)
        XCTAssertTrue(drill.awayFromInstrument)
    }

    /// The teacher's *achievement* does not (D5). The sender already strips these; the receiving side
    /// drops them again, because this is the untrusted door and the file may have been written by a
    /// hand or by a build that has not shipped.
    func testTheSendersHistoryDoesNotArriveEvenWhenTheFileCarriesIt() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        // Put back everything `SharedPracticeBuilder` cleared, as a hand-edited file could.
        payload.exercises = payload.exercises.map {
            var record = $0
            record.mastery = 5
            record.masteryTempo = 132
            record.masteryNotesPerBeat = 4
            record.commandTempo = 128
            record.commandNotesPerBeat = 4
            record.lastPracticed = Fixture.fixedDate
            record.isFavorite = true
            record.presetSlug = "spider-walk"
            return record
        }
        payload.routine?.lastPracticed = Fixture.fixedDate
        payload.routine?.isFavorite = true
        payload.routine?.presetSlug = "morning-warm-up"

        let landing = try landed(payload)
        let (routine, exercises) = (landing.routine, landing.exercises)
        let drill = try XCTUnwrap(exercises.first)

        XCTAssertNil(drill.mastery)
        XCTAssertNil(drill.masteryTempo)
        XCTAssertNil(drill.masteryNotesPerBeat)
        XCTAssertNil(drill.commandTempo, "A measured achievement is not inherited (ADR 0045/0070)")
        XCTAssertNil(drill.commandNotesPerBeat)
        XCTAssertNil(drill.lastPracticed)
        XCTAssertFalse(drill.isFavorite)
        XCTAssertNil(drill.presetSlug, "A received drill is not a seeded preset")
        XCTAssertTrue(drill.linkedSongs.isEmpty)
        XCTAssertNil(routine.lastPracticed)
        XCTAssertFalse(routine.isFavorite)
        XCTAssertNil(routine.presetSlug)
    }

    /// A drill used by three blocks is written to the file once, so all three blocks have to come back
    /// pointing at the **same** new drill rather than at three copies of it.
    func testADrillUsedTwiceArrivesOnceAndBothBlocksPointAtIt() throws {
        let routine = Routine(name: "Doubled", dateAdded: Fixture.fixedDate)
        let drill = Fixture.exercise()
        routine.items = [RoutineItem.item(drill, order: 0), RoutineItem.item(drill, order: 1)]

        let landing = try landed(Fixture.shared(routine))
        let (exercises, items) = (landing.exercises, landing.items)

        XCTAssertEqual(exercises.count, 1)
        XCTAssertIdentical(items.first?.exercise, items.last?.exercise)
    }

    /// The authored content goes back into the opaque column it came out of. A strum pattern that
    /// survived the file and then died at hydration would be the point of the share, lost.
    func testTheAuthoredContentPayloadSurvivesTheRoundTrip() throws {
        let routine = Routine(name: "Strummer", dateAdded: Fixture.fixedDate)
        let drill = Fixture.exercise(named: "Down-up")
        let payload = Data(#"{"version":1,"beats":[1,0,1,1]}"#.utf8)
        drill.templatePayload = payload
        routine.items = [RoutineItem.item(drill, order: 0)]

        let exercises = try landed(Fixture.shared(routine)).exercises
        let arrived = try XCTUnwrap(exercises.first?.templatePayload)

        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: arrived),
                       try JSONDecoder().decode(JSONValue.self, from: payload),
                       "The blob is re-encoded, so compare the JSON rather than the bytes")
    }

    // MARK: - What cannot cross (D4)

    /// A loop or song block arrives in its place in the sitting, as the orphan the routine screen
    /// already knows how to draw. Dropping it would hand over a quietly shorter routine.
    func testALoopBlockArrivesAsAnOrphanInItsPlace() throws {
        let items = try landed(Fixture.shared(Fixture.routine().routine)).items

        let loopBlock = try XCTUnwrap(items.first { $0.order == 1 })
        XCTAssertNil(loopBlock.exercise)
        XCTAssertNil(loopBlock.loop)
        XCTAssertNil(loopBlock.song)
        XCTAssertTrue(loopBlock.isOrphaned)

        let rest = try XCTUnwrap(items.first { $0.order == 2 })
        XCTAssertEqual(rest.kind, .rest)
        XCTAssertFalse(rest.isOrphaned, "A rest carries no unit by design")
    }

    /// The label is kept, not just previewed (ADR 0188 S2 follow-up). Without `orphanLabel` the
    /// sender's words were shown once, before the routine landed, and the block then read *Unit
    /// removed* for the rest of its life.
    func testAnUnresolvableBlockKeepsTheNameItArrivedWith() throws {
        let items = try landed(Fixture.shared(Fixture.routine().routine)).items

        let loopBlock = try XCTUnwrap(items.first { $0.order == 1 })
        XCTAssertTrue(loopBlock.isOrphaned)
        XCTAssertEqual(loopBlock.orphanLabel, "Chorus — Slow Bend")

        XCTAssertNil(items.first { $0.order == 0 }?.orphanLabel,
                     "A block that resolved its drill has nothing to be named instead")
        XCTAssertNil(items.first { $0.order == 2 }?.orphanLabel, "A rest names nothing")
    }

    /// A label only ever lands on a block that resolved nothing. A well-formed file never names an
    /// exercise block, but this door reads files the app did not write, and a label on a block that
    /// *does* resolve would be a stored fact that is not true.
    func testALabelIsNotWrittenOntoABlockThatResolves() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        let drillBlock = try XCTUnwrap(payload.routine?.items.first { $0.exerciseUID != nil })
        payload.placeholders.append(SharedBlockPlaceholder(itemUID: drillBlock.uid,
                                                           label: "Not a real placeholder"))

        let landing = try landed(payload)
        let block = try XCTUnwrap(landing.items.first { $0.exercise != nil })

        XCTAssertNil(block.orphanLabel)
    }

    /// An archive has no placeholder list, so the record's own `orphanLabel` is the fallback — and
    /// the only source S3 will have.
    func testTheRecordsOwnLabelIsUsedWhenNoPlaceholderNamesTheBlock() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        payload.placeholders = []
        var record = try XCTUnwrap(payload.routine)
        record.items = record.items.map {
            var block = $0
            if block.exerciseUID == nil && block.kindRaw != RoutineItemKind.rest.rawValue {
                block.orphanLabel = "Bridge — Some Song"
            }
            return block
        }
        payload.routine = record

        let items = try landed(payload).items

        XCTAssertEqual(items.first { $0.order == 1 }?.orphanLabel, "Bridge — Some Song")
    }

    // MARK: - Forward compatibility

    /// The four enum columns are written raw, never through their typed setters — those resolve with a
    /// `?? default`, so a template from a later build would arrive normalised to "Basic" carrying a
    /// payload nothing can read.
    func testAnUnrecognisedEnumValueSurvivesInsteadOfBeingNormalised() throws {
        var payload = Fixture.shared(Fixture.routine().routine)
        payload.exercises = payload.exercises.map {
            var record = $0
            record.templateRaw = "polyrhythm"
            record.instrumentRaw = "sitar"
            record.rampIntervalUnitRaw = "phrases"
            return record
        }
        var record = try XCTUnwrap(payload.routine)
        record.items = record.items.map {
            var block = $0
            if block.exerciseUID != nil { block.kindRaw = "sightreading" }
            return block
        }
        payload.routine = record

        let landing = try landed(payload)
        let (exercises, items) = (landing.exercises, landing.items)
        let drill = try XCTUnwrap(exercises.first)

        XCTAssertEqual(drill.templateRaw, "polyrhythm")
        XCTAssertEqual(drill.instrumentRaw, "sitar")
        XCTAssertEqual(drill.rampIntervalUnitRaw, "phrases")
        XCTAssertEqual(items.first(where: { $0.exercise != nil })?.kindRaw, "sightreading")
    }

    // MARK: - The two slices meet

    /// S1 writes the file; S2 reads it. Every other test here builds a payload in memory — this one
    /// goes out through the real encoder and back in through the real decoder, which is the only test
    /// that would notice the two slices disagreeing about the format.
    func testARealSharedFileRoundTripsBackIntoARoutine() throws {
        let fixture = Fixture.routine()
        let bytes = try ArchiveCoding.encode(
            SharedPracticeBuilder.routine(fixture.routine, appVersion: "1.2 (7)",
                                          exportedAt: Fixture.fixedDate))

        guard case let .success(value) = ReceivedRoutineBuilder.evaluate(data: bytes) else {
            return XCTFail("A file this app just wrote could not be read back")
        }
        let landing = ReceivedRoutineBuilder.materialize(value)

        XCTAssertEqual(landing.routine.name, fixture.routine.name)
        XCTAssertEqual(landing.items.count, fixture.routine.items.count)
        XCTAssertEqual(landing.exercises.count, 1)
        XCTAssertEqual(value.exportedAt, Fixture.fixedDate,
                       "Dates survive to the millisecond, both ways")
    }
}
