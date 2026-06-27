import XCTest
@testable import Pocket

/// The exercise "light progress" model (ADR 0043, slice 7) — the working-tempo-vs-goal bar
/// fraction, remaining-BPM gap, and readout. Pure tempo logic that breaks silently
/// (AGENTS.md), so the clamping, the at-target boundary, and the divide-by-zero guard are
/// all pinned.
final class ExerciseProgressTests: XCTestCase {

    // MARK: fraction

    func testFractionIsCurrentOverTarget() {
        XCTAssertEqual(ExerciseProgress(current: 90, target: 120).fraction, 0.75, accuracy: 1e-9)
    }

    func testFractionClampsAtOneWhenPastTarget() {
        XCTAssertEqual(ExerciseProgress(current: 140, target: 120).fraction, 1, accuracy: 1e-9)
    }

    func testFractionIsZeroForNonPositiveTarget() {
        // Guards divide-by-zero / bad data rather than producing NaN or a negative bar.
        XCTAssertEqual(ExerciseProgress(current: 90, target: 0).fraction, 0, accuracy: 1e-9)
    }

    // MARK: remaining + at-target boundary

    func testRemainingIsTheGapToTarget() {
        XCTAssertEqual(ExerciseProgress(current: 92, target: 120).remaining, 28)
    }

    func testRemainingClampsToZeroOnceMet() {
        XCTAssertEqual(ExerciseProgress(current: 120, target: 120).remaining, 0)
        XCTAssertEqual(ExerciseProgress(current: 130, target: 120).remaining, 0)
    }

    func testIsAtTargetIsInclusive() {
        XCTAssertFalse(ExerciseProgress(current: 119, target: 120).isAtTarget)
        XCTAssertTrue(ExerciseProgress(current: 120, target: 120).isAtTarget)
        XCTAssertTrue(ExerciseProgress(current: 121, target: 120).isAtTarget)
    }

    // MARK: readout strings

    func testReadoutReadsCurrentToTarget() {
        XCTAssertEqual(ExerciseProgress(current: 92, target: 120).readout, "92 → 120 BPM")
    }

    func testStatusCountsDownThenReadsAtTarget() {
        XCTAssertEqual(ExerciseProgress(current: 92, target: 120).status, "28 BPM to go")
        XCTAssertEqual(ExerciseProgress(current: 120, target: 120).status, "At target")
    }

    // MARK: model bridge

    func testExerciseExposesItsProgress() {
        let exercise = Exercise(currentTempo: 100, targetTempo: 130)
        XCTAssertEqual(exercise.progress, ExerciseProgress(current: 100, target: 130))
        XCTAssertEqual(exercise.tempoGap, 30)   // tempoGap still delegates to progress.remaining
    }
}
