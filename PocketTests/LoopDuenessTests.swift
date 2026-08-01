import SwiftData
import XCTest
@testable import Pocket

/// **Dueness comes from the log** (ADR 0137).
///
/// `Loop` has no stored `lastPracticed`, and the projector hard-coded `nil` for every loop it
/// produced — so `DueScore`'s time term sat pinned at maximum and the formula collapsed to
/// `goalWeight × (1 − mastery/5)`. A loop practised this morning ranked exactly level with one
/// untouched for a year, and no amount of practice ever moved it.
///
/// The repair is silent in both directions if it regresses: a dropped map leaves loops permanently
/// max-due (the old bug, invisible), and a map wrongly applied to exercises changes a live ranking
/// nobody asked to change (D5). Both are asserted here rather than eyeballed on a planner screen.
final class LoopDuenessTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    private func makeLoop(_ name: String, mastery: Int? = nil) -> Loop {
        let loop = Loop(name: name, start: 0.1, end: 0.2, speed: 1, repeats: 4)
        loop.mastery = mastery
        return loop
    }

    // MARK: - The projection carries the log's recency

    @MainActor
    func testLoopProjectionTakesLastPracticedFromTheMap() {
        let loop = makeLoop("Chorus lick")
        let practisedAt = daysAgo(3)
        let library = PracticePlanner.library(exercises: [], loops: [loop],
                                              lastPracticed: [loop.uid: practisedAt])
        XCTAssertEqual(library.loops.count, 1)
        XCTAssertEqual(library.loops[0].lastPracticed, practisedAt)
    }

    @MainActor
    func testALoopMissingFromTheMapStaysColdStartMaxDue() {
        // The cold-start answer must survive the change: never practised ⇒ `nil` ⇒ dueness 1.0.
        // This is also the behaviour every caller that passes no map at all inherits.
        let loop = makeLoop("Never touched")
        let library = PracticePlanner.library(exercises: [], loops: [loop], lastPracticed: [:])
        XCTAssertNil(library.loops[0].lastPracticed)
        XCTAssertEqual(DueScore.dueness(lastPracticed: library.loops[0].lastPracticed, now: now), 1.0)
    }

    @MainActor
    func testOmittingTheMapEntirelyLeavesEveryCallerUnchanged() {
        // The parameter is defaulted so existing call sites and tests compile and behave as before.
        let loop = makeLoop("Chorus lick")
        XCTAssertNil(PracticePlanner.library(exercises: [], loops: [loop]).loops.first?.lastPracticed)
    }

    @MainActor
    func testExercisesKeepTheirStoredValueEvenWhenTheMapNamesThem() {
        // D5 — exercises are deliberately NOT switched to the derived value here. Theirs means "a run
        // started"; the log's means "a run completed". A guard against a later "tidy-up" unifying them
        // by accident, which would silently change ranking for every existing install.
        let exercise = Exercise(name: "A minor run", template: .picking)
        let stored = daysAgo(9)
        exercise.lastPracticed = stored
        let library = PracticePlanner.library(exercises: [exercise], loops: [],
                                              lastPracticed: [exercise.uid: daysAgo(1)])
        XCTAssertEqual(library.exercises.first?.lastPracticed, stored)
    }

    // MARK: - The ranking it exists to fix

    func testTwoEqualMasteryLoopsRankByRecency() {
        // The ADR's own verification: same song, same mastery, different recency. Before this change
        // both scored identically, because both projected `lastPracticed: nil`.
        let songUID = UUID()
        let recent = PlannerLoop(uid: UUID(), songUID: songUID, mastery: 2,
                                 lastPracticed: daysAgo(1), estimatedMinutes: 5)
        let stale = PlannerLoop(uid: UUID(), songUID: songUID, mastery: 2,
                                lastPracticed: daysAgo(30), estimatedMinutes: 5)
        let library = PlannerLibrary(loops: [recent, stale],
                                     songs: [PlannerSong(uid: songUID, lastPracticed: nil,
                                                         estimatedMinutes: 200)])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [PlannerGoal(skillIDs: ["rep.learn-song"], targetSongUID: songUID)],
            library: library)

        guard let recentCandidate = candidates.first(where: { $0.unit.uid == recent.uid }),
              let staleCandidate = candidates.first(where: { $0.unit.uid == stale.uid })
        else { return XCTFail("both loops should surface as candidates for their song's goal") }
        XCTAssertGreaterThan(DueScore.score(staleCandidate, now: now),
                             DueScore.score(recentCandidate, now: now))
    }

    func testAnEarTrainingRunMakesTheSameLoopLessDueAsATrainer() {
        // D2a end-to-end at the value layer: the log doesn't distinguish the mode, so an `.earLoop`
        // row is the loop's recency for trainer ranking too.
        let loop = UUID()
        let map = PracticeLog.lastPracticedByUnit([
            SessionRecord(startedAt: daysAgo(20), durationSeconds: 300, kind: .loop, unitUID: loop),
            SessionRecord(startedAt: daysAgo(1), durationSeconds: 300, kind: .earLoop, unitUID: loop)
        ])
        XCTAssertEqual(map[loop], daysAgo(1))
        XCTAssertLessThan(DueScore.dueness(lastPracticed: map[loop], now: now),
                          DueScore.dueness(lastPracticed: daysAgo(20), now: now))
    }

    func testALoopRatedFiveStaysRetiredHoweverStaleItGets() {
        // The ADR changes only the time half. A self-rated 5 keeps its `(1 − 5/5) = 0` term, so
        // nothing here re-surfaces something the player has declared owned (ADR 0070).
        let candidate = PlannerCandidate(unit: PlannerUnitRef(UUID(), .loop), priority: 1,
                                         mastery: 5, lastPracticed: daysAgo(365),
                                         estimatedMinutes: 5)
        XCTAssertEqual(DueScore.score(candidate, now: now), 0)
    }
}
