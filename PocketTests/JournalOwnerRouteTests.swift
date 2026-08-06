import XCTest
@testable import Pocket

/// **The owner caption leads somewhere** (ADR 0142, v2 close-out N7). Every item on the Journal feed
/// names its unit; tapping that name now opens it. Which screen it opens is decided here, not in the
/// view, because the interesting cases are the ones nobody taps in a demo: an item whose loop has no
/// playable audio, and a take that belongs to a song.
///
/// A wrong answer here is silent — a caption that leads to a ramp with nothing to anchor it is exactly
/// the class of mistake ADR 0138 had to unpick — so the resolution is asserted rather than eyeballed.
/// Models are built **uninserted**: `route(for:)` reads properties only, and inserting a graph SIGTRAPs
/// in the XCTest host (`docs/swiftdata-gotchas.md`).
final class JournalOwnerRouteTests: XCTestCase {

    private func makeLoop(measured: Bool, source: SongRef.Source? = .localFile,
                          backing: Bool = false) -> Loop {
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.25, speed: 0.9, repeats: 4)
        if measured { loop.commandTempo = 0.9 }
        loop.isBackingTrack = backing
        if let source {
            loop.song = Song(title: "Little Wing", duration: 200,
                             ref: SongRef(id: "s1", source: source, bookmark: nil))
        }
        return loop
    }

    private func loopNote(on loop: Loop) -> JournalTimeline.Item {
        let entry = JournalEntry.forLoop(text: "buzzing on the B string", kind: .struggle,
                                         masteryAtEntry: 3, commandTempoAtEntry: 0.9)
        entry.loop = loop
        return .note(entry)
    }

    // MARK: - Exercises

    func testAnExerciseNoteRoutesToItsExercise() {
        let exercise = Exercise(name: "Alternating picking", currentTempo: 80, commandTempo: 96)
        let entry = JournalEntry.forExercise(text: "held 96 clean", kind: .breakthrough,
                                             commandBpmAtEntry: 96)
        entry.exercise = exercise
        guard case .exercise(let routed)? = JournalOwnerRoute.route(for: .note(entry)) else {
            return XCTFail("an exercise note must route to its exercise")
        }
        XCTAssertEqual(routed.uid, exercise.uid)
    }

    func testAFreeformBlocksNoteRoutesLikeAnyOtherExercise() {
        // `ExerciseRunScreen` routes `.freeform` onward to its own run screen (ADR 0136) — the route
        // has no business knowing that, and must not grow a second exercise case for it.
        let block = Exercise.commandAnchored(name: "Sight-reading", command: 90, template: .freeform)
        let entry = JournalEntry.forExercise(text: "two pages", kind: .note, commandBpmAtEntry: nil)
        entry.exercise = block
        guard case .exercise(let routed)? = JournalOwnerRoute.route(for: .note(entry)) else {
            return XCTFail("a freeform block is an exercise")
        }
        XCTAssertEqual(routed.uid, block.uid)
    }

    // MARK: - Loops route to the mode they qualify for

    func testAMeasuredLoopOpensTheTrainer() {
        guard case .loop(_, let mode)? = JournalOwnerRoute.route(for: loopNote(on: makeLoop(measured: true)))
        else { return XCTFail("a measured loop has a trainer to open") }
        XCTAssertEqual(mode, .trainer)
    }

    func testAnUnmeasuredLoopOpensEarTrainingRatherThanARampWithNoAnchor() {
        // The note may well have been written *during* ear training (ADR 0138): a loop with no
        // command tempo has no staircase, so the caption must not lead to one.
        guard case .loop(_, let mode)? = JournalOwnerRoute.route(for: loopNote(on: makeLoop(measured: false)))
        else { return XCTFail("an audible loop can always be sung back") }
        XCTAssertEqual(mode, .ear)
    }

    func testABackingTrackStillPrefersTheTrainerWhenMeasured() {
        // Precedence is `LoopModeAccess`'s own order, not a second opinion held here.
        let loop = makeLoop(measured: true, backing: true)
        guard case .loop(_, let mode)? = JournalOwnerRoute.route(for: loopNote(on: loop)) else {
            return XCTFail("a measured backing track qualifies for the trainer")
        }
        XCTAssertEqual(mode, .trainer)
    }

    func testALoopWithNoPlayableAudioHasNoDestination() {
        // No song, so no mode qualifies — the caption stays plain text rather than becoming a tap
        // that opens a screen with nothing to play.
        let orphan = makeLoop(measured: false, source: nil)
        XCTAssertNil(JournalOwnerRoute.route(for: loopNote(on: orphan)))
    }

    func testAnAppleMusicLoopWithNoCommandHasNoDestination() {
        // Catalog audio is browse-only (ADR 0001) and there's no ramp to fall back on.
        let catalog = makeLoop(measured: false, source: .appleMusic)
        XCTAssertNil(JournalOwnerRoute.route(for: loopNote(on: catalog)))
    }

    // MARK: - Takes follow the same rules, with one owner more

    func testATakeRoutesToItsExercise() {
        let exercise = Exercise(name: "Spider", currentTempo: 60, commandTempo: 72)
        let take = Recording(fileName: "take.m4a", duration: 30, exercise: exercise)
        guard case .exercise(let routed)? = JournalOwnerRoute.route(for: .take(take)) else {
            return XCTFail("a take on an exercise routes to that exercise")
        }
        XCTAssertEqual(routed.uid, exercise.uid)
    }

    func testASongOwnedTakeHasNoDestination() {
        // Songs never got a standalone run surface (ADR 0069 slice 4), so there is nowhere to go.
        let song = Song(title: "Little Wing", duration: 200,
                        ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        let take = Recording(fileName: "take.m4a", duration: 30, song: song)
        XCTAssertNil(JournalOwnerRoute.route(for: .take(take)))
    }

    // MARK: - Identity is the stable uid

    func testRouteIdentityIsTheUnitsStableUID() {
        // The reason this type exists rather than passing the model straight to
        // `.navigationDestination(item:)`: SwiftData's own identity flips temporary→permanent on the
        // first save, and a destination keyed on it pops itself (ADR 0090).
        let loop = makeLoop(measured: true)
        let first = JournalOwnerRoute.loop(loop, .trainer)
        let second = JournalOwnerRoute.loop(loop, .ear)
        XCTAssertEqual(first.uid, loop.uid)
        XCTAssertEqual(first, second, "the same unit is the same destination")
        XCTAssertEqual(Set([first, second]).count, 1)
    }

    func testDifferentUnitsAreDifferentRoutes() {
        let one = JournalOwnerRoute.exercise(Exercise(name: "A", currentTempo: 80, commandTempo: 90))
        let two = JournalOwnerRoute.exercise(Exercise(name: "B", currentTempo: 80, commandTempo: 90))
        XCTAssertNotEqual(one, two)
    }

    // MARK: - Session unit pills (ADR 0143)

    /// These resolve a **loose id copy** rather than following a relationship — the deletion-safety
    /// trade a session entry makes. So failure is an ordinary outcome here, not an error, and the
    /// `nil` cases below are the ones that actually happen to a player over time.
    func testASessionPillResolvesItsExerciseByUID() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let other = Exercise(name: "Chords", currentTempo: 80, commandTempo: 96)
        let ref = SessionUnitRef(uid: spider.uid, title: "Spider", kind: .exercise)

        let route = JournalOwnerRoute.route(for: ref, exercises: [other, spider], loops: [])

        XCTAssertEqual(route, .exercise(spider))
    }

    func testASessionPillOpensTheModeItsLoopQualifiesFor() {
        let loop = makeLoop(measured: false)   // unmeasured — no staircase to anchor (ADR 0138)
        let ref = SessionUnitRef(uid: loop.uid, title: "Verse riff", kind: .loop)

        let route = JournalOwnerRoute.route(for: ref, exercises: [], loops: [loop])

        XCTAssertNotNil(route)
        if case .loop(_, let mode) = route {
            XCTAssertEqual(mode, LoopModeAccess.modes(for: loop).first,
                           "the same trainer→ear→improvise precedence the owner caption follows")
        } else {
            XCTFail("expected a loop route")
        }
    }

    func testADeletedUnitLeavesThePillWithNowhereToGo() {
        let ref = SessionUnitRef(uid: UUID(), title: "Deleted drill", kind: .exercise)

        XCTAssertNil(JournalOwnerRoute.route(for: ref, exercises: [], loops: []),
                     "the entry survives the unit; the link does not — the pill renders dimmed")
    }

    func testALoopThatQualifiesForNoModeHasNoRoute() {
        let loop = makeLoop(measured: false, source: nil)   // no song, so no audio to run against
        let ref = SessionUnitRef(uid: loop.uid, title: "Verse riff", kind: .loop)

        XCTAssertNil(JournalOwnerRoute.route(for: ref, exercises: [], loops: [loop]))
    }

    /// A ref must be matched **against its own kind**: an exercise and a loop that happen to share a
    /// uid must not cross-resolve.
    func testAKindIsNotResolvedAgainstTheOtherLibrary() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let ref = SessionUnitRef(uid: spider.uid, title: "Spider", kind: .loop)

        XCTAssertNil(JournalOwnerRoute.route(for: ref, exercises: [spider], loops: []))
    }

    // MARK: - The session caption itself (2026-08-06)

    /// The session entry's own caption — the routine name — was the last dead label on the feed: its
    /// unit pills led somewhere and the sitting they belonged to didn't. Resolved the same loose way
    /// the pills are, and failing the same ordinary way.
    private func sessionNote(routineUID: UUID, name: String = "Evening warm-up") -> JournalTimeline.Item {
        .note(JournalEntry.forSession(text: "legato felt cleaner at the top", kind: .note,
                                      routineUID: routineUID, routineName: name, units: []))
    }

    func testASessionNoteRoutesToItsRoutine() {
        let routine = Routine(name: "Evening warm-up")
        let other = Routine(name: "Something else")

        let route = JournalOwnerRoute.route(for: sessionNote(routineUID: routine.uid),
                                            routines: [other, routine])

        XCTAssertEqual(route, .routine(routine))
    }

    func testADeletedRoutineLeavesTheSessionCaptionAsPlainText() {
        let route = JournalOwnerRoute.route(for: sessionNote(routineUID: UUID()), routines: [])

        XCTAssertNil(route, "the entry outlives the routine; the caption stops being a link")
    }

    /// The caption keeps saying what the sitting was called even when it leads nowhere — the snapshot
    /// and the link are independent (ADR 0038/0143).
    func testADeletedRoutineStillLabelsItsEntry() {
        let item = sessionNote(routineUID: UUID(), name: "Evening warm-up")

        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Evening warm-up")
    }

    /// The routines library is only consulted for a session. An exercise note resolves through its
    /// relationship as it always did, with no library passed at all.
    func testAnExerciseNoteStillNeedsNoRoutineLibrary() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let entry = JournalEntry.forExercise(text: "cleaner", kind: .breakthrough, commandBpmAtEntry: 96)
        entry.exercise = spider

        XCTAssertEqual(JournalOwnerRoute.route(for: .note(entry)), .exercise(spider))
    }

    /// A session entry carries a `routineUID` **and** nothing else; an exercise entry can carry a
    /// `routineUID` too (the sitting it was written in). `ownerKind` is what separates them, and
    /// routing must follow it rather than the presence of the id — or a drill note written during a
    /// routine would open the routine instead of the drill.
    func testADrillNoteWrittenInsideASessionStillOpensTheDrill() {
        let spider = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        let routine = Routine(name: "Evening warm-up")
        let entry = JournalEntry.forExercise(text: "cleaner", kind: .breakthrough, commandBpmAtEntry: 96)
        entry.exercise = spider
        entry.routineUID = routine.uid

        XCTAssertEqual(JournalOwnerRoute.route(for: .note(entry), routines: [routine]),
                       .exercise(spider))
    }
}
