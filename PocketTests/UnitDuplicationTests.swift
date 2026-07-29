import XCTest
@testable import Pocket

/// Duplicating a practice unit (Slice 3): the copy-naming rule, and what a copy carries vs. resets.
///
/// The `@Model`s are exercised as plain **uninserted** objects — inserting one in the XCTest host
/// traps (`docs/swiftdata-gotchas.md`), and none of this logic needs a store.
final class UnitDuplicationTests: XCTestCase {

    // MARK: - Copy naming

    func testFirstCopyAppendsCopy() {
        XCTAssertEqual(CopyNaming.copyName(of: "Spider", existing: ["Spider"]), "Spider copy")
    }

    func testSecondCopyCountsRatherThanRepeatingTheWord() {
        let existing = ["Spider", "Spider copy"]
        XCTAssertEqual(CopyNaming.copyName(of: "Spider", existing: existing), "Spider copy 2")
    }

    /// Duplicating a *copy* re-uses the stem, so you get "copy 2", never "copy copy".
    func testDuplicatingACopyReusesTheStem() {
        let existing = ["Spider", "Spider copy"]
        XCTAssertEqual(CopyNaming.copyName(of: "Spider copy", existing: existing), "Spider copy 2")
        XCTAssertEqual(CopyNaming.copyName(of: "Spider copy 2",
                                           existing: existing + ["Spider copy 2"]),
                       "Spider copy 3")
    }

    func testCountingSkipsNamesAlreadyTaken() {
        let existing = ["Spider", "Spider copy", "Spider copy 2", "Spider copy 3"]
        XCTAssertEqual(CopyNaming.copyName(of: "Spider", existing: existing), "Spider copy 4")
    }

    func testMatchingIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(CopyNaming.copyName(of: "Spider", existing: ["  SPIDER COPY "]),
                       "Spider copy 2")
    }

    /// A trailing number is only a copy counter when it sits on a " copy" — otherwise the name's
    /// own number would be eaten ("Exercise 2" must not duplicate as "Exercise copy").
    func testTrailingNumberIsNotMistakenForACopyCounter() {
        XCTAssertEqual(CopyNaming.copyName(of: "Exercise 2", existing: []), "Exercise 2 copy")
        XCTAssertEqual(CopyNaming.stem(of: "Exercise 2"), "Exercise 2")
    }

    func testUnrelatedUseOfTheWordCopyIsLeftAlone() {
        XCTAssertEqual(CopyNaming.stem(of: "Copy of the master"), "Copy of the master")
    }

    func testAnUnnamedUnitCopiesAsUntitled() {
        XCTAssertEqual(CopyNaming.copyName(of: "", existing: []), "Untitled copy")
        XCTAssertEqual(CopyNaming.copyName(of: "   ", existing: ["Untitled copy"]), "Untitled copy 2")
    }

    // MARK: - Exercise

    func testDuplicateCarriesTheDrillsShape() {
        let source = Exercise(name: "Spider", currentTempo: 72, commandTempo: 96,
                              beatsPerBar: 6, noteValue: 8, accentBeats: [0, 3],
                              subdivision: .triplets, template: .picking, instrument: .bass,
                              templatePayload: Data([1, 2, 3]),
                              rampStepBPM: 7, rampIntervalCount: 3, rampIntervalUnit: .seconds,
                              dwellIntervals: 6, includeBackoff: false,
                              rampReachSteps: 2, rampBackoffSteps: 1, backoffTempoOverride: 60,
                              tags: ["picking"], notes: "keep the wrist loose")
        source.targetTempoOverride = 150

        let copy = source.duplicated(named: "Spider copy")

        XCTAssertEqual(copy.name, "Spider copy")
        XCTAssertEqual(copy.currentTempo, 72)
        XCTAssertEqual(copy.commandTempo, 96)
        XCTAssertEqual(copy.beatsPerBar, 6)
        XCTAssertEqual(copy.noteValue, 8)
        XCTAssertEqual(copy.accentBeats, [0, 3])
        XCTAssertEqual(copy.subdivision, .triplets)
        XCTAssertEqual(copy.template, .picking)
        XCTAssertEqual(copy.instrument, .bass)
        XCTAssertEqual(copy.templatePayload, Data([1, 2, 3]))
        XCTAssertEqual(copy.rampStepBPM, 7)
        XCTAssertEqual(copy.rampIntervalCount, 3)
        XCTAssertEqual(copy.rampIntervalUnit, .seconds)
        XCTAssertEqual(copy.dwellIntervals, 6)
        XCTAssertFalse(copy.includeBackoff)
        XCTAssertEqual(copy.rampReachSteps, 2)
        XCTAssertEqual(copy.rampBackoffSteps, 1)
        XCTAssertEqual(copy.backoffTempoOverride, 60)
        XCTAssertEqual(copy.targetTempoOverride, 150)
        XCTAssertEqual(copy.tags, ["picking"])
        XCTAssertEqual(copy.notes, "keep the wrist loose")
        // The ramp is derived from the recipe, so carrying the recipe carries the staircase.
        XCTAssertEqual(copy.ramp, source.ramp)
    }

    /// A copy is unrated, unpractised, unpinned and user-authored — history and provenance are the
    /// original's, not the fork's.
    func testDuplicateResetsHistoryAndProvenance() {
        let source = Exercise(name: "A minor pentatonic", template: .scales,
                              mastery: 4, lastPracticed: Date(timeIntervalSince1970: 1_000))
        source.isFavorite = true
        source.presetSlug = "a-minor-pentatonic"

        let copy = source.duplicated(named: "A minor pentatonic copy")

        XCTAssertNil(copy.mastery)
        XCTAssertNil(copy.lastPracticed)
        XCTAssertFalse(copy.isFavorite)
        XCTAssertNil(copy.presetSlug, "a fork of a free-taste preset must not inherit its run allowance")
        XCTAssertTrue(copy.journal.isEmpty)
        XCTAssertTrue(copy.recordings.isEmpty)
        XCTAssertNotEqual(copy.uid, source.uid)
    }

    /// Dropping the preset slug is what closes the paywall bypass: the copy is judged by its
    /// template alone, so a free player's fork of a Pro-template freebie is locked.
    func testForkOfAFreeTastePresetIsNotItselfFreeTaste() {
        let source = Exercise(name: "A minor pentatonic", template: .scales)
        source.presetSlug = "a-minor-pentatonic"
        XCTAssertTrue(AccessPolicy.canRun(source.template, isPro: false,
                                          isFreeTastePreset: AccessPolicy.isFreeTaste(slug: source.presetSlug)))

        let copy = source.duplicated(named: "A minor pentatonic copy")
        XCTAssertFalse(AccessPolicy.canRun(copy.template, isPro: false,
                                           isFreeTastePreset: AccessPolicy.isFreeTaste(slug: copy.presetSlug)))
    }

    // MARK: - Routine

    func testDuplicateRoutineClonesBlocksInOrderPointingAtTheSameUnits() {
        let drill = Exercise(name: "Spider")
        let source = Routine(name: "Morning warm-up")
        let first = RoutineItem.item(drill, kind: .warmup, order: 5)
        first.reps = 3
        source.items = [RoutineItem.rest(order: 9), first]

        let (copy, blocks) = source.duplicated(named: "Morning warm-up copy")

        XCTAssertEqual(copy.name, "Morning warm-up copy")
        XCTAssertNotEqual(copy.uid, source.uid)
        XCTAssertEqual(blocks.count, 2)
        // Cloned in **play** order (`order` 5 then 9, whatever the relationship array's order)
        // and renumbered from 0, so drifted `order` values copy clean.
        XCTAssertEqual(blocks.map(\.order), [0, 1])
        XCTAssertEqual(blocks[0].kind, .warmup)
        XCTAssertEqual(blocks[0].reps, 3)
        XCTAssertEqual(blocks[1].kind, .rest)
        // The units are shared, not forked — duplicating a session must not fork the library.
        XCTAssertIdentical(blocks[0].exercise, drill)
    }

    func testDuplicateRoutineResetsHistoryAndProvenance() {
        let source = Routine(name: "Demo")
        source.isFavorite = true
        source.presetSlug = "morning-warm-up"
        source.lastPracticed = Date(timeIntervalSince1970: 1_000)

        let (copy, _) = source.duplicated(named: "Demo copy")

        XCTAssertFalse(copy.isFavorite)
        XCTAssertNil(copy.presetSlug, "a fork of the free demo is a user-authored routine")
        XCTAssertNil(copy.lastPracticed)
    }
}
