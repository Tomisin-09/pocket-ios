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

    // MARK: - Position-shifting: defaults reproduce today (ADR 0083 S1)

    func testDefaultRunCarriesNoShiftAndReproducesTheOldSequence() {
        // A run built with no shift args must be byte-identical to the pre-0083 expansion.
        let run = FretboardRun(fingers: [1, 3, 2, 4], baseFret: 5, fromString: 5, toString: 4)
        XCTAssertEqual(run.fretShiftPerPass, 0)
        XCTAssertEqual(run.passCount, 1)
        XCTAssertEqual(run.fretShiftPerString, 0)
        XCTAssertEqual(run.returnStyle, .retrace)
        // No note in a default run ever carries a slide.
        XCTAssertTrue(run.sequence.allSatisfy { $0.technique == nil })
    }

    func testChromaticWarmupSequenceIsUnchangedByTheShiftFields() {
        // Byte-identical guard for the shipped preset (S9 / S1 additive promise).
        let run = FretboardRun.chromaticWarmup
        XCTAssertEqual(run.sequence.count, 46)
        XCTAssertTrue(run.sequence.allSatisfy { $0.technique == nil })
    }

    // MARK: - Horizontal climb (per pass) + slide seams (S1, S2)

    func testClimbStacksOnePassPerShiftAndSlidesIntoEachNewPass() {
        // 1-2-3 on the low E, up and back, climbing +2 frets for 3 passes on the one string.
        let run = FretboardRun(fingers: [1, 2, 3], baseFret: 1,
                               fromString: 5, toString: 5, roundTrip: true,
                               fretShiftPerPass: 2, passCount: 3)
        let onePassLength = 4   // ascent 1-2-3 (=3) + retrace descent (drops peak+start) = 1 ⇒ 4
        XCTAssertEqual(run.sequence.count, onePassLength * 3)
        // The first note of passes 2 and 3 is slid into on the same string; nothing else slides.
        let slides = run.sequence.enumerated().filter { $0.element.technique == .slide }
        XCTAssertEqual(slides.map(\.offset), [onePassLength, onePassLength * 2])
        // The seam climbs: pass 2 starts at base fret 1 + 2 = 3.
        XCTAssertEqual(run.sequence[onePassLength], FretNote(string: 5, fret: 3, technique: .slide))
    }

    func testDiagonalCrossingAStringIsNotASlide() {
        // A per-string stagger that lands on a *new* string is a reposition, never a slide (S2).
        let run = FretboardRun(fingers: [1, 2], baseFret: 3,
                               fromString: 5, toString: 3, roundTrip: false, fretShiftPerString: 2)
        XCTAssertTrue(run.sequence.allSatisfy { $0.technique == nil })
        // Each successive string is offset two frets higher.
        XCTAssertEqual(run.sequence, [
            FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 4),   // step 0: anchor 3
            FretNote(string: 4, fret: 5), FretNote(string: 4, fret: 6),   // step 1: anchor 5
            FretNote(string: 3, fret: 7), FretNote(string: 3, fret: 8)    // step 2: anchor 7
        ])
    }

    // MARK: - Pass groups (S2b — pass focus)

    func testPassGroupsTagEachNoteWithItsPass() {
        // 1-2-3 on the low E, up and back, 3 climbing passes: each pass emits `onePassLength` notes,
        // all carrying that pass's index, in order.
        let run = FretboardRun(fingers: [1, 2, 3], baseFret: 1,
                               fromString: 5, toString: 5, roundTrip: true,
                               fretShiftPerPass: 2, passCount: 3)
        let onePassLength = 4
        XCTAssertEqual(run.sequenceWithPasses.passes,
                       Array(repeating: 0, count: onePassLength)
                       + Array(repeating: 1, count: onePassLength)
                       + Array(repeating: 2, count: onePassLength))
    }

    func testPassGroupsAlignOneToOneWithTheSequence() {
        // The two arrays are the same length and index-aligned by construction, and the drill carries
        // them through expansion so the renderer can read them.
        let run = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 3,
                               fromString: 5, toString: 3, roundTrip: false,
                               fretShiftPerPass: 2, passCount: 3)
        let pair = run.sequenceWithPasses
        XCTAssertEqual(pair.passes.count, pair.notes.count)
        XCTAssertEqual(run.expanded().noteGroups, pair.passes)
        XCTAssertEqual(run.expanded().noteGroups?.count, run.expanded().notes.count)
    }

    func testSinglePassRunTagsOneUniformGroupSoNothingDims() {
        // A single-pass run (the default) fills one group of all-zero tags — one distinct group, which
        // the renderer reads as "no dimming."
        let run = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 5, fromString: 5, toString: 4)
        let groups = run.expanded().noteGroups
        XCTAssertEqual(groups, Array(repeating: 0, count: run.sequence.count))
        XCTAssertEqual(Set(groups ?? []).count, 1)
    }

    // MARK: - Come-back fingering (S9)

    func testRestateReplaysTheAscendingPatternPerStringWalkingStringsBack() {
        // 1-2-3 across low E → A, restated on the way back: A skipped (just played at the peak),
        // low E restated 1-2-3 walking home; no home-note double at the loop seam.
        let run = FretboardRun(fingers: [1, 2, 3], baseFret: 1, fromString: 5, toString: 4,
                               roundTrip: true, returnStyle: .restate)
        XCTAssertEqual(run.sequence, [
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2), FretNote(string: 5, fret: 3),
            FretNote(string: 4, fret: 1), FretNote(string: 4, fret: 2), FretNote(string: 4, fret: 3),
            FretNote(string: 5, fret: 1), FretNote(string: 5, fret: 2), FretNote(string: 5, fret: 3)
        ])
        // The loop seam never repeats the same note back-to-back.
        XCTAssertNotEqual(run.sequence.last, run.sequence.first)
    }

    func testRestateDropsTheHomeNoteWhenItWouldDoubleAtTheSeam() {
        // Single finger, three strings: the naive restate would end on the home note the ascent
        // reopens with — it must be dropped so the loop doesn't double-hit it.
        let run = FretboardRun(fingers: [1], baseFret: 5, fromString: 5, toString: 3,
                               roundTrip: true, returnStyle: .restate)
        XCTAssertEqual(run.sequence, [
            FretNote(string: 5, fret: 5), FretNote(string: 4, fret: 5), FretNote(string: 3, fret: 5),
            FretNote(string: 4, fret: 5)   // walk back one string; home note dropped at the seam
        ])
    }

    // MARK: - Neck bounds & pass cap (S10)

    func testGenerationClampsNotesToARealNeck() {
        // A steep climb near the top of the neck clamps rather than running past fret 24.
        let run = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 22,
                               fromString: 5, toString: 5, roundTrip: false,
                               fretShiftPerPass: 4, passCount: 3)
        XCTAssertTrue(run.sequence.allSatisfy { $0.fret <= FretboardRun.maxFret })
    }

    func testMaxPassCountLeavesTheTopPassOnTheBoard() {
        // base 20, +3/pass, top finger 4: the last pass's top finger must still be ≤ 24.
        let run = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 20,
                               fromString: 5, toString: 5, fretShiftPerPass: 3)
        let top = run.baseFret + (run.maxPassCount - 1) * run.fretShiftPerPass + 3
        XCTAssertLessThanOrEqual(top, FretboardRun.maxFret)
    }

    // MARK: - Codable + versioning (T4)

    func testShiftFieldsRoundTripAndDefaultWhenAbsent() throws {
        // Round-trips with the new fields set…
        let shifted = FretboardRun(fingers: [1, 2, 3], baseFret: 1, fromString: 5, toString: 5,
                                   fretShiftPerPass: 2, passCount: 3, fretShiftPerString: 1,
                                   returnStyle: .restate)
        let data = try JSONEncoder().encode(shifted)
        XCTAssertEqual(try JSONDecoder().decode(FretboardRun.self, from: data), shifted)

        // …and a pre-0083 blob (no shift keys) decodes to the additive defaults, no migration.
        let legacyJSON = """
        {"version":1,"fingers":[1,2,3,4],"baseFret":1,"fromString":5,"toString":0,\
        "roundTrip":true,"notesPerBeat":2}
        """
        let decoded = try JSONDecoder().decode(FretboardRun.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.fretShiftPerPass, 0)
        XCTAssertEqual(decoded.passCount, 1)
        XCTAssertEqual(decoded.fretShiftPerString, 0)
        XCTAssertEqual(decoded.returnStyle, .retrace)
    }

    // MARK: - Codable + versioning (T4, cont.)

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
