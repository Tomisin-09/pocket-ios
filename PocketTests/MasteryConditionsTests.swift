import XCTest
@testable import Pocket

/// **A mastery rating records the conditions it was taken under** (ADR 0169) — the stamp, the
/// staleness rule it feeds, and the planner consequence that motivated the whole thing.
///
/// The bug this locks down is a **sequence, not a state**: no assertion on `masteryTerm` alone can
/// catch it, because every value in isolation is correct. Rating 5 is correct. `masteryTerm(5) == 0`
/// is correct. Promoting on a 5 is correct. It is only running them in `commitDone`'s order — rate,
/// then promote, in one commit — that retires the drill at a tempo it has never been rated at. So the
/// central test here replays that order against the models and asserts through the planner.
///
/// Models are built **uninserted** (no `ModelContainer`): none of this needs persistence, and an
/// XCTest host that inserts is the documented footgun (`docs/swiftdata-gotchas.md`).
/// `@MainActor` because `PracticePlanner.candidate(for:)` is — it reads a `@Model`. There is no
/// `setUp` override to keep nonisolated, so isolating the whole class is the simple form and
/// holds under CI's stricter Swift 6 toolchain as well as locally.
@MainActor
final class MasteryConditionsTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - The pure rule

    func testUnstampedRatingIsNotStale() {
        // The upgrade case, and the one that would do most damage if it were wrong: every rating
        // already in the store has no stamp. Unknown conditions are not moved conditions — reading
        // them as stale would demote the player's whole library on first launch after the update.
        XCTAssertFalse(MasteryReading.isStale(ratedAt: nil, ratedRhythm: nil, command: 90, rhythm: 2))
        XCTAssertFalse(MasteryReading.isStale(ratedAt: nil, command: 0.85))
    }

    func testStaleWhenTempoOrRhythmMoves() {
        XCTAssertFalse(MasteryReading.isStale(ratedAt: 90, ratedRhythm: 2, command: 90, rhythm: 2))
        XCTAssertTrue(MasteryReading.isStale(ratedAt: 90, ratedRhythm: 2, command: 110, rhythm: 2))
        // Same BPM, different rhythm: 90 at eighths and 90 at sixteenths are not the same claim
        // (ADR 0121), so the reading is stale even though the number on screen has not moved.
        XCTAssertTrue(MasteryReading.isStale(ratedAt: 90, ratedRhythm: 2, command: 90, rhythm: 4))
        // A drill that stated a rhythm and now states none has also moved.
        XCTAssertTrue(MasteryReading.isStale(ratedAt: 90, ratedRhythm: 2, command: 90, rhythm: nil))
    }

    func testLoopSpeedComparisonToleratesRepresentationError() {
        // Loop commands are written as `percent / 100`, so an exact `!=` would call a reading stale
        // on a `Double` artefact alone. Within tolerance is the same reading; a whole percent is not.
        XCTAssertFalse(MasteryReading.isStale(ratedAt: 0.85, command: Double(85) / 100))
        XCTAssertTrue(MasteryReading.isStale(ratedAt: 0.85, command: 0.86))
    }

    // MARK: - Stamping at the write

    func testRatingAnExerciseStampsTempoAndRhythm() {
        let exercise = Exercise(name: "Spider walk", currentTempo: 60, commandTempo: 90,
                                notesPerBeat: 2)
        exercise.rateMastery(4)
        XCTAssertEqual(exercise.masteryTempo, 90)
        XCTAssertEqual(exercise.masteryNotesPerBeat, 2)
        XCTAssertFalse(exercise.masteryIsStale)
        XCTAssertEqual(exercise.masteryReading?.conditions, "90 BPM · 8ths")
    }

    func testClearingTheRatingClearsTheStamp() {
        let exercise = Exercise(name: "Spider walk", currentTempo: 60, commandTempo: 90)
        exercise.rateMastery(4)
        exercise.rateMastery(nil)
        XCTAssertNil(exercise.masteryTempo)
        XCTAssertNil(exercise.masteryNotesPerBeat)
        XCTAssertNil(exercise.masteryReading)
        // Conditions with nothing to condition are noise; leaving them would let a later re-rate
        // inherit a tempo it was never given at.
        XCTAssertFalse(exercise.masteryIsStale)
    }

    func testRatingALoopStampsItsCommandSpeed() {
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.3, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.rateMastery(5)
        XCTAssertEqual(loop.masteryAtSpeed ?? 0, 0.85, accuracy: 1e-9)
        XCTAssertEqual(loop.masteryReading?.conditions, "85%")
        loop.promoteCommand(to: 0.95)
        XCTAssertTrue(loop.masteryIsStale)
    }

    // MARK: - The sequence: a raise must not retire the drill

    func testAcceptedRaiseResurfacesRatherThanRetires() {
        // `commitDone`'s exact order, which is the whole point: the rating lands first, then the
        // accepted raise moves the command off it.
        let exercise = Exercise(name: "Spider walk", currentTempo: 60, commandTempo: 70,
                                notesPerBeat: 2)
        exercise.lastPracticed = now.addingTimeInterval(-7 * 86_400)
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 90)

        XCTAssertEqual(exercise.mastery, 5, "The player's number is never rewritten (ADR 0070)")
        XCTAssertEqual(exercise.masteryTempo, 70, "…and it still records the tempo it was earned at")
        XCTAssertTrue(exercise.masteryIsStale)

        let candidate = PracticePlanner.candidate(for: exercise)
        XCTAssertTrue(candidate.masteryIsStale, "Staleness must survive the projection to the planner")
        XCTAssertGreaterThan(DueScore.score(candidate, now: now), 0,
                             "A drill promoted on a 5 must come back, not vanish at a tempo it has "
                             + "never been rated at")
    }

    func testAFreshFiveStillRetires() {
        // The other half of the same behaviour, and the guard against over-correcting: rating 5 and
        // *declining* the raise is the player saying they own it here. That still retires the drill.
        let exercise = Exercise(name: "Spider walk", currentTempo: 60, commandTempo: 70)
        exercise.lastPracticed = now.addingTimeInterval(-7 * 86_400)
        exercise.rateMastery(5)

        XCTAssertFalse(exercise.masteryIsStale)
        XCTAssertEqual(DueScore.score(PracticePlanner.candidate(for: exercise), now: now), 0,
                       accuracy: 1e-9)
    }

    func testSettleWasAlreadyCoherentAndStaysSo() {
        // `CommandOffer` only leans `.settle` on mastery 0–2, whose terms are already positive — the
        // bug bit upward only. Settling still marks the reading stale (the command did move), and the
        // floor is a floor, so a low rating's larger term is untouched.
        let exercise = Exercise(name: "Spider walk", currentTempo: 60, commandTempo: 90)
        exercise.rateMastery(1)
        exercise.settleCommand(to: 75)
        XCTAssertTrue(exercise.masteryIsStale)
        XCTAssertEqual(DueScore.masteryTerm(1, isStale: true), DueScore.masteryTerm(1), accuracy: 1e-9)
    }

    // MARK: - The planner term

    func testStaleReadingFloorsAtTheTermAFourEarns() {
        XCTAssertEqual(DueScore.masteryTerm(5, isStale: true), DueScore.staleMasteryFloor, accuracy: 1e-9)
        XCTAssertEqual(DueScore.staleMasteryFloor, DueScore.masteryTerm(4), accuracy: 1e-9,
                       "The floor is a value already in the formula, not a new constant")
        // Only the 5 changes: every other rating's term already clears the floor.
        for rating in 0...4 {
            XCTAssertEqual(DueScore.masteryTerm(rating, isStale: true),
                           DueScore.masteryTerm(rating), accuracy: 1e-9)
        }
    }

    func testStaleFiveStillRanksBelowAFreshFour() {
        // Flooring must not invert the axis: a stale 5 is worth *no more* than a 4, not more.
        XCTAssertLessThanOrEqual(DueScore.masteryTerm(5, isStale: true), DueScore.masteryTerm(4))
    }

    // MARK: - The exercise journal snapshot (ADR 0072 regression)

    func testExerciseEntrySnapshotsItsMastery() {
        // `forExercise` passed `nil` for four months on the strength of a comment that ADR 0072 had
        // already falsified, so an exercise entry recorded its tempo and dropped its rating.
        let entry = JournalEntry.forExercise(text: "Locked it", kind: .note,
                                             commandBpmAtEntry: 90, commandNotesPerBeatAtEntry: 2,
                                             masteryAtEntry: 4)
        XCTAssertEqual(entry.masteryAtEntry, 4)
        XCTAssertEqual(entry.commandBpmAtEntry, 90)
        XCTAssertNil(entry.commandTempoAtEntry, "The song-fraction field stays loop-only (ADR 0058)")
    }
}
