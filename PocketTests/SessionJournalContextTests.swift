import XCTest
@testable import Pocket

/// `SessionJournalContext` — **what a finished routine hands the session composer** (ADR 0143).
///
/// The derivation lives off the view precisely so it can be asserted here: it decides what a session
/// entry claims you practised, and a wrong answer is a permanent, immutable snapshot (ADR 0038). The
/// three rules it enforces are all subtractive, which is the kind that goes unnoticed — rests aren't
/// practice, songs have no run screen for a pill to open (ADR 0069 / 0142 J5a), and a warm-up played
/// twice was still one thing you worked on.
///
/// Models are built **uninserted**: the initialiser reads properties only, and inserting a graph
/// SIGTRAPs in the XCTest host (`docs/swiftdata-gotchas.md`).
final class SessionJournalContextTests: XCTestCase {

    private func exerciseStage(_ exercise: Exercise, title: String) -> RoutineStage {
        RoutineStage(id: UUID(), title: title, reps: 1, plannedMinutes: 5,
                     payload: .exercise(exercise))
    }

    private func loopStage(_ loop: Loop, title: String,
                           payload: (Loop) -> RoutineStage.Payload = RoutineStage.Payload.loop) -> RoutineStage {
        RoutineStage(id: UUID(), title: title, reps: 1, plannedMinutes: 5, payload: payload(loop))
    }

    private func restStage() -> RoutineStage {
        RoutineStage(id: UUID(), title: "Rest", reps: 1, plannedMinutes: nil, payload: .rest)
    }

    // MARK: - What it keeps

    func testKeepsExercisesAndLoopsInPlayOrder() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let riff = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 0.9, repeats: 4)
        let routine = Routine(name: "Morning warm-up")

        let context = SessionJournalContext(
            routine: routine,
            stages: [exerciseStage(spider, title: "Spider"), loopStage(riff, title: "Verse riff")])

        XCTAssertEqual(context.units.map(\.title), ["Spider", "Verse riff"])
        XCTAssertEqual(context.units.map(\.kind), [.exercise, .loop])
        XCTAssertEqual(context.units.map(\.uid), [spider.uid, riff.uid],
                       "the unit's uid, never the block's — a block is not the thing you practised")
        XCTAssertEqual(context.routineUID, routine.uid)
    }

    func testEveryLoopModeCountsAsALoop() {
        let loop = Loop(name: "Backing", start: 0, end: 1, speed: 1, repeats: 1)
        let routine = Routine(name: "Mixed")

        let context = SessionJournalContext(
            routine: routine,
            stages: [loopStage(loop, title: "Ear", payload: RoutineStage.Payload.earLoop)])

        XCTAssertEqual(context.units.map(\.kind), [.loop],
                       "ear and improvise blocks are loops too (ADR 0104 / 0135)")
    }

    func testTitlesComeFromTheStageSoEmptyNamesKeepTheirFallback() {
        let unnamed = Exercise(name: "", currentTempo: 80, commandTempo: 96)
        let routine = Routine(name: "Morning warm-up")

        // `RoutineSessionPlayer` already substitutes "Exercise" for an empty name when it builds the
        // stage; the snapshot must read exactly as the block did in the player.
        let context = SessionJournalContext(routine: routine,
                                            stages: [exerciseStage(unnamed, title: "Exercise")])

        XCTAssertEqual(context.units.map(\.title), ["Exercise"])
    }

    // MARK: - What it drops

    func testRestsAreNotPractice() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let routine = Routine(name: "Morning warm-up")

        let context = SessionJournalContext(
            routine: routine,
            stages: [exerciseStage(spider, title: "Spider"), restStage()])

        XCTAssertEqual(context.units.count, 1)
    }

    func testSongsAreDroppedBecauseTheyHaveNowhereToLink() {
        let song = Song(title: "Little Wing", duration: 200,
                        ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        let routine = Routine(name: "Play-along")
        let stage = RoutineStage(id: UUID(), title: "Little Wing", reps: 1, plannedMinutes: 5,
                                 payload: .song(song))

        let context = SessionJournalContext(routine: routine, stages: [stage])

        XCTAssertTrue(context.units.isEmpty,
                      "a song has no standalone run surface (ADR 0069), so a pill could only be dead text")
    }

    func testARepeatedUnitIsListedOnce() {
        let warmup = Exercise(name: "Warm-up", currentTempo: 60, commandTempo: 80)
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let routine = Routine(name: "Bookended")

        let context = SessionJournalContext(
            routine: routine,
            stages: [exerciseStage(warmup, title: "Warm-up"),
                     exerciseStage(spider, title: "Spider"),
                     exerciseStage(warmup, title: "Warm-up")])

        XCTAssertEqual(context.units.map(\.title), ["Warm-up", "Spider"],
                       "deduped by uid, and the *first* appearance keeps its place in play order")
    }

    // MARK: - The name

    func testTheRoutineNameIsSnapshottedRaw() {
        let routine = Routine(name: "")

        let context = SessionJournalContext(routine: routine, stages: [])

        XCTAssertEqual(context.routineName, "",
                       "an empty name stays empty in the snapshot; the fallback wording is the display layer's")
        XCTAssertEqual(JournalOwner.session(context).displayName, "this session",
                       "…and the composer supplies it")
    }
}
