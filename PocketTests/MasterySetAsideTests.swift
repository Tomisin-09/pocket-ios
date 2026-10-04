import XCTest
@testable import Pocket

/// **When the command moves, the rating is set aside** (ADR 0250): the unit reads unrated at its new
/// tempo, and the old rating survives as `previousMastery`, captioned "Last rated…".
///
/// The failure this exists for is a **sequence**, like ADR 0169's: rate 5, accept the raise, and on
/// the *next* run tap Continue without touching the dots. Before 0250 that re-stamped the old 5 at the
/// new tempo and retired the drill. Each value along the way was correct in isolation, so the central
/// test replays the order against the models and asserts through the planner.
///
/// Models are built **uninserted** (no `ModelContainer`) — the house rule for model tests in this host.
/// `@MainActor` because `PracticePlanner.candidate(for:)` and the archive builder read `@Model`s; no
/// `setUp` override, so isolating the whole class holds under CI's Swift 6 toolchain too.
@MainActor
final class MasterySetAsideTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func drill(command: Int = 70) -> Exercise {
        Exercise(name: "Spider walk", currentTempo: 60, commandTempo: command, notesPerBeat: 2)
    }

    // MARK: - The move

    func testARaiseSetsTheRatingAside() {
        let exercise = drill()
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 80)

        XCTAssertNil(exercise.mastery, "Unrated at the new tempo")
        XCTAssertEqual(exercise.previousMastery, 5, "…and the old rating is kept, not wiped")
        XCTAssertEqual(exercise.masteryTempo, 70, "The stamp now describes the set-aside rating")
        XCTAssertFalse(exercise.masteryIsStale, "A set-aside rating is history, not a claim about now")
        XCTAssertEqual(exercise.masteryReading?.caption, "Last rated 5 at 70 BPM · 8ths")
    }

    func testASettleSetsTheRatingAsideToo() {
        let exercise = drill(command: 90)
        exercise.rateMastery(1)
        exercise.settleCommand(to: 75)
        XCTAssertNil(exercise.mastery)
        XCTAssertEqual(exercise.previousMastery, 1)
    }

    func testAWriteThatLandsWhereItWasSetsNothingAside() {
        // `ExerciseRunView.persist` promotes on every Save and Start, at whatever command is on screen.
        let exercise = drill()
        exercise.rateMastery(4)
        exercise.promoteCommand(to: 70)
        XCTAssertEqual(exercise.mastery, 4)
        XCTAssertNil(exercise.previousMastery)

        // A first promote turns the fallback (`currentTempo`) into a measured command at the same value.
        let unmeasured = Exercise(name: "Chromatic", currentTempo: 60, notesPerBeat: 2)
        unmeasured.rateMastery(3)
        unmeasured.promoteCommand(to: 60)
        XCTAssertEqual(unmeasured.mastery, 3)
    }

    func testAnUnstampedRatingIsSetAsideOnlyByARealMove() {
        // Pre-0169 ratings carry no stamp. Staleness can't see them, so the move itself decides.
        let exercise = drill()
        exercise.mastery = 3
        exercise.promoteCommand(to: 70)
        XCTAssertEqual(exercise.mastery, 3, "No move, nothing set aside")
        exercise.promoteCommand(to: 85)
        XCTAssertNil(exercise.mastery)
        XCTAssertEqual(exercise.previousMastery, 3)
        XCTAssertEqual(exercise.masteryReading?.caption, "Last rated 3",
                       "Known rating, never-known tempo: the caption says only what is known")
    }

    // MARK: - A rhythm change

    func testKeepingTheNoteSpeedKeepsTheRating() {
        // Same notes, same speed, new units: the rating is still true, restated beside the command.
        let exercise = drill(command: 80)
        exercise.promoteCommand(to: 80)   // binds the command to its rhythm (ADR 0121)
        exercise.rateMastery(5)
        exercise.keepNoteSpeed(movingTo: 4, range: 20...300)

        XCTAssertEqual(exercise.mastery, 5)
        XCTAssertNil(exercise.previousMastery)
        XCTAssertEqual(exercise.masteryTempo, exercise.command)
        XCTAssertEqual(exercise.masteryNotesPerBeat, exercise.noteRate?.perBeat)
        XCTAssertFalse(exercise.masteryIsStale)
    }

    func testReMeasuringSetsTheRatingAside() {
        let exercise = drill(command: 80)
        exercise.promoteCommand(to: 80)
        exercise.rateMastery(5)
        exercise.reMeasureCommand(movingTo: 4, range: 20...300)
        XCTAssertNil(exercise.mastery, "Nothing is measured at the new rhythm, so nothing is rated there")
        XCTAssertEqual(exercise.previousMastery, 5)
    }

    // MARK: - Rating

    func testAnUnchangedRatingWritesNothing() {
        let exercise = drill()
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 80)
        // The Done screen hands back its blank row on Continue whether or not it was touched.
        exercise.rateMastery(nil)
        XCTAssertEqual(exercise.previousMastery, 5, "A blank row must not wipe the set-aside rating")
        XCTAssertEqual(exercise.masteryTempo, 70, "…or its stamp")
    }

    func testANewRatingSupersedesTheSetAsideOne() {
        let exercise = drill()
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 80)
        exercise.rateMastery(3)
        XCTAssertEqual(exercise.mastery, 3)
        XCTAssertNil(exercise.previousMastery)
        XCTAssertEqual(exercise.masteryTempo, 80, "Stamped at the tempo it was given at")
        XCTAssertEqual(exercise.masteryReading?.caption, "Rated at 80 BPM · 8ths")
    }

    // MARK: - The sequence

    func testContinuingPastAnUntouchedRowAfterARaiseKeepsTheDrillInRotation() {
        // Run 1 at 70: rated 5, raise accepted — `commitDone`'s order.
        let exercise = drill()
        exercise.lastPracticed = now.addingTimeInterval(-7 * 86_400)
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 80)

        // Run 2 at 80: the Done screen pre-fills the stored rating, and Continue hands it straight back.
        let prefilled = exercise.mastery
        XCTAssertNil(prefilled, "The row opens blank at the new tempo")
        XCTAssertEqual(CommandOffer.preferredStance(mastery: prefilled), .open,
                       "…so the offer leans neither way, instead of toward yet another raise")
        exercise.rateMastery(prefilled)

        XCTAssertNil(exercise.mastery, "The old 5 must not come back stamped at 80")
        XCTAssertEqual(exercise.previousMastery, 5)
        XCTAssertGreaterThan(DueScore.score(PracticePlanner.candidate(for: exercise), now: now), 0,
                             "The raised drill must stay in rotation, not retire at a tempo never rated")
    }

    // MARK: - Loops

    func testALoopRaiseSetsItsRatingAsideWithinTolerance() {
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.3, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.rateMastery(5)
        loop.promoteCommand(to: Double(85) / 100)
        XCTAssertEqual(loop.mastery, 5, "A percent written back as a fraction is not a move")

        loop.promoteCommand(to: 0.95)
        XCTAssertNil(loop.mastery)
        XCTAssertEqual(loop.previousMastery, 5)
        XCTAssertEqual(loop.masteryReading?.caption, "Last rated 5 at 85%")
    }

    func testAnUnmeasuredLoopKeepsItsRatingWhenOnlyItsWarmUpMoves() {
        // `LoopRunView.persist` writes `speed` before promoting. An unmeasured loop's command falls back
        // to `speed`, so a bare before/after compare would see a move the rating never saw.
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.7, repeats: 0)
        loop.rateMastery(4)   // stamped at the fallback, 0.7
        loop.speed = 0.6
        loop.promoteCommand(to: 0.7)
        XCTAssertEqual(loop.mastery, 4, "Rated at 70%, command now 70%: nothing moved off the rating")
    }

    func testTheEditorAsksTheSameRuleAheadOfTheWrite() {
        let loop = Loop(name: "Chorus", start: 0.1, end: 0.3, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        XCTAssertFalse(loop.ratingWouldBeSetAside(movingTo: 0.95), "No rating, nothing to set aside")
        loop.rateMastery(4)
        XCTAssertTrue(loop.ratingWouldBeSetAside(movingTo: 0.95))
        XCTAssertFalse(loop.ratingWouldBeSetAside(movingTo: 0.85))
        // What it predicts is what the write does.
        loop.moveCommand(to: 0.95)
        XCTAssertEqual(loop.previousMastery, 4)
    }

    // MARK: - The caption rule

    func testACaptionDescribesOnlyTheDotsItBelongsUnder() {
        let current = MasteryReading.Display(rating: 4, conditions: "85%", isStale: false)
        XCTAssertTrue(current.describes(4))
        XCTAssertFalse(current.describes(3), "Walked dots must not keep the stored rating's caption")
        let previous = MasteryReading.Display(rating: 5, conditions: "85%", isStale: false,
                                              isPrevious: true)
        XCTAssertTrue(previous.describes(nil), "A set-aside rating captions the blank row the move left")
        XCTAssertFalse(previous.describes(5), "…and goes once the unit is rated again")
    }

    // MARK: - The backfill

    func testTheBackfillSetsAsideStaleRatingsOnly() {
        // The ADR 0169 shape: rated at 70, then the command moved with the rating left in place.
        let stale = drill()
        stale.rateMastery(5)
        stale.commandTempo = 80
        XCTAssertTrue(stale.masteryIsStale)
        XCTAssertTrue(MasteryStaleBackfill.apply(to: stale))
        XCTAssertNil(stale.mastery)
        XCTAssertEqual(stale.previousMastery, 5)
        XCTAssertFalse(MasteryStaleBackfill.apply(to: stale), "A re-run writes nothing")

        let unstamped = drill()
        unstamped.mastery = 4
        unstamped.commandTempo = 90
        XCTAssertFalse(MasteryStaleBackfill.apply(to: unstamped), "Unknown conditions are not moved ones")
        XCTAssertEqual(unstamped.mastery, 4)

        let loop = Loop(name: "Chorus", start: 0.1, end: 0.3, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.rateMastery(5)
        loop.commandTempo = 0.95
        XCTAssertTrue(MasteryStaleBackfill.apply(to: loop))
        XCTAssertEqual(loop.previousMastery, 5)
    }

    // MARK: - The archive

    func testTheSetAsideRatingCrossesTheArchive() throws {
        let exercise = drill()
        exercise.rateMastery(5)
        exercise.promoteCommand(to: 80)
        let snapshot = ArchiveBuilder.snapshot(from: ArchiveSource(exercises: [exercise]),
                                               appVersion: "1.3 (8)", includesTakeAudio: false,
                                               exportedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snapshot.exercises.first?.previousMastery, 5)

        let json = try XCTUnwrap(String(bytes: ArchiveBuilder.encode(snapshot), encoding: .utf8))
        XCTAssertTrue(json.contains("\"previousMastery\""), "Positive control: the key is written")
        XCTAssertEqual(try ArchiveBuilder.decode(Data(json.utf8)).exercises.first?.previousMastery, 5)

        // An archive written before ADR 0250 has no such key, and must still decode.
        let older = json.replacingOccurrences(of: #""previousMastery""#,
                                              with: #""previousMasteryWasNotAKeyYet""#)
        let decoded = try ArchiveBuilder.decode(Data(older.utf8))
        XCTAssertEqual(decoded.exercises.count, 1)
        XCTAssertNil(decoded.exercises.first?.previousMastery)
    }
}
