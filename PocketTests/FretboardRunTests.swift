import XCTest
@testable import Pocket

/// The **generative fretboard run** (ADR 0065 build 2): the pure shape→notes expansion the editor and
/// renderer only skin, plus the `FretboardContent` payload wrapper and its back-compat decode. All
/// SwiftUI-free logic that breaks silently otherwise (AGENTS.md), so it's exhaustively unit-tested.
final class FretboardRunTests: XCTestCase {

    // MARK: - Finger → fret (movable base)

    func testFingerNumbersAnchorToTheMovableBaseFret() {
        let run = FretboardRun(fingers: [1, 3, 2, 4], baseFret: 5, fromString: 5, toString: 4)
        XCTAssertEqual(run.fret(forFinger: 1), 5)   // finger 1 sits on the base
        XCTAssertEqual(run.fret(forFinger: 2), 6)
        XCTAssertEqual(run.fret(forFinger: 3), 7)
        XCTAssertEqual(run.fret(forFinger: 4), 8)
    }

    func testBaseFretAndNotesPerBeatClampToAtLeastOne() {
        let run = FretboardRun(fingers: [1], baseFret: 0, fromString: 0, toString: 0, notesPerBeat: 0)
        XCTAssertEqual(run.baseFret, 1)
        XCTAssertEqual(run.notesPerBeat, 1)
    }

    // MARK: - Expansion across a span

    func testAscendingRunLaysThePatternOnEachStringLowToHigh() {
        // 1-3-2-4 at the 5th fret, low E → A, no return trip.
        let run = FretboardRun(fingers: [1, 3, 2, 4], baseFret: 5,
                               fromString: 5, toString: 4, roundTrip: false)
        XCTAssertEqual(run.sequence, [
            FretNote(string: 5, fret: 5), FretNote(string: 5, fret: 7),
            FretNote(string: 5, fret: 6), FretNote(string: 5, fret: 8),
            FretNote(string: 4, fret: 5), FretNote(string: 4, fret: 7),
            FretNote(string: 4, fret: 6), FretNote(string: 4, fret: 8)
        ])
    }

    func testRunTravelsHighToLowWhenFromStringIsAboveToString() {
        let run = FretboardRun(fingers: [1], baseFret: 1, fromString: 0, toString: 2, roundTrip: false)
        XCTAssertEqual(run.sequence.map(\.string), [0, 1, 2])   // high e → G, in order
    }

    func testRoundTripAddsASmoothDescentWithoutDoublingThePeakOrSeam() {
        // Three fingers on one string, up and back: the descent omits the shared peak and start so a
        // looping cycle never hits the same note twice in a row (a smooth up-down-up triangle).
        let run = FretboardRun(fingers: [1, 2, 3], baseFret: 1,
                               fromString: 5, toString: 5, roundTrip: true)
        XCTAssertEqual(run.sequence, [
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2),
            FretNote(string: 5, fret: 3),                       // peak, once
            FretNote(string: 5, fret: 2)                        // back down; loops to fret 1
        ])
    }

    func testRoundTripIsANoOpForATwoNoteRun() {
        // Too short to form a triangle — nothing to mirror, so it stays the ascent.
        let run = FretboardRun(fingers: [1, 2], baseFret: 1,
                               fromString: 5, toString: 5, roundTrip: true)
        XCTAssertEqual(run.sequence.count, 2)
    }

    func testEmptyFingerPatternExpandsToAnEmptyDrill() {
        let run = FretboardRun(fingers: [], baseFret: 1, fromString: 5, toString: 0)
        XCTAssertTrue(run.sequence.isEmpty)
        XCTAssertTrue(run.expanded().notes.isEmpty)
    }

    func testExpandedDrillCarriesTheSubdivisionAndNotesAsNonRests() {
        let run = FretboardRun(fingers: [1, 2], baseFret: 3,
                               fromString: 5, toString: 5, roundTrip: false, notesPerBeat: 3)
        let drill = run.expanded()
        XCTAssertEqual(drill.notesPerBeat, 3)
        XCTAssertEqual(drill.notes, [FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 4)])
        XCTAssertEqual(drill.stringCount, 6)
    }

    // MARK: - Chromatic warm-up default

    func testChromaticWarmupWalksEveryStringOneFingerPerFretAndBack() {
        let run = FretboardRun.chromaticWarmup
        XCTAssertEqual(run.fingers, [1, 2, 3, 4])
        XCTAssertEqual(run.notesPerBeat, 2)
        // 6 strings × 4 fingers ascending = 24, plus a 22-note descent (peak + start omitted).
        XCTAssertEqual(run.sequence.count, 46)
        XCTAssertEqual(run.sequence.first, FretNote(string: 5, fret: 1))   // low E, finger 1
        XCTAssertEqual(run.sequence[23], FretNote(string: 0, fret: 4))     // high e, finger 4 (peak)
    }

    // MARK: - Codable + versioning (T4)

    func testRunRoundTripsThroughCodable() throws {
        let original = FretboardRun(fingers: [1, 3, 2, 4], baseFret: 7,
                                    fromString: 5, toString: 1, roundTrip: false, notesPerBeat: 4)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(FretboardRun.self, from: data), original)
    }

    func testNewRunCarriesCurrentVersion() {
        XCTAssertEqual(FretboardRun.chromaticWarmup.version, FretboardRun.currentVersion)
    }

    // MARK: - FretboardContent wrapper

    func testContentDrillExpandsARunAndPassesACustomDrillThrough() {
        XCTAssertEqual(FretboardContent.run(.chromaticWarmup).drill,
                       FretboardRun.chromaticWarmup.expanded())
        XCTAssertEqual(FretboardContent.custom(.spiderWalk).drill, .spiderWalk)
    }

    func testContentAccessorsUnwrapTheirCase() {
        XCTAssertEqual(FretboardContent.run(.chromaticWarmup).runValue, .chromaticWarmup)
        XCTAssertNil(FretboardContent.run(.chromaticWarmup).customValue)
        XCTAssertEqual(FretboardContent.custom(.spiderWalk).customValue, .spiderWalk)
        XCTAssertNil(FretboardContent.custom(.spiderWalk).runValue)
    }

    func testContentRoundTripsThroughCodableForBothCases() throws {
        for content in [FretboardContent.run(.chromaticWarmup), .custom(.spiderWalk)] {
            let data = try JSONEncoder().encode(content)
            XCTAssertEqual(try JSONDecoder().decode(FretboardContent.self, from: data), content)
        }
    }

    /// A pre-generative payload was a bare `FretboardDrill` (no `kind` discriminator), so it must not
    /// decode as a `FretboardContent` — the `Exercise` accessor's fallback is what rescues it.
    func testBareDrillBlobDoesNotDecodeAsContent() throws {
        let data = try JSONEncoder().encode(FretboardDrill.spiderWalk)
        XCTAssertThrowsError(try JSONDecoder().decode(FretboardContent.self, from: data))
    }

    /// The `Exercise` accessor best-effort decodes a legacy bare-drill blob into `.custom`, so a
    /// fretboard exercise saved before generative authoring still renders (back-compat).
    func testExerciseAccessorRescuesALegacyBareDrillBlob() throws {
        let exercise = Exercise(name: "Legacy", currentTempo: 60, commandTempo: 90, template: .scales)
        exercise.templatePayload = try JSONEncoder().encode(FretboardDrill.spiderWalk)
        XCTAssertEqual(exercise.fretboardContent, .custom(.spiderWalk))
        XCTAssertEqual(exercise.fretboardDrill, .spiderWalk)
    }
}
