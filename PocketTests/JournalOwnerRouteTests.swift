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
}
