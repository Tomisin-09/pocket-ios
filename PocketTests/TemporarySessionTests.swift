import XCTest
import SwiftData
@testable import Pocket

/// **Temporary sessions** (ADR 0243): which routines a surface shows, which ones a Start replaces,
/// what a temporary session is called, and that saving one afterwards loses nothing.
///
/// The rules run on plain uninserted models. The delete and the save run against a real in-memory
/// store and are read back through a **second** context, the way `AddToRoutineTests` reads its
/// appends: the screens that show the result each open their own.
final class TemporarySessionTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - The field (D7)

    /// Every routine made before 0243, and every one made since outside the planner, is saved.
    func testARoutineIsSavedUnlessSomethingSaysOtherwise() {
        XCTAssertFalse(Routine().isTemporary)
        XCTAssertFalse(Routine(name: "Morning").isTemporary)
    }

    // MARK: - Which routines a surface shows (D2)

    func testSavedLeavesOutTheTemporarySessionAndNothingElse() {
        let kept = Routine(name: "Morning")
        let favourite = Routine(name: "Picked")
        favourite.isFavorite = true
        let session = temporary("2 Oct Quick Session")
        XCTAssertEqual(Routine.saved([kept, session, favourite]).map(\.uid), [kept.uid, favourite.uid])
    }

    // MARK: - Which ones a Start replaces (D3)

    /// **Every other** temporary session, so a stray left by a crash between the two writes goes too.
    func testAStartReplacesEveryOtherTemporarySessionAndNoSavedOne() {
        let saved = Routine(name: "Morning")
        let previous = temporary("1 Oct Quick Session")
        let stray = temporary("30 Sep Quick Session")
        let current = temporary("2 Oct Quick Session")
        let replaced = Routine.temporariesReplaced(by: current.uid, in: [saved, previous, stray, current])
        XCTAssertEqual(Set(replaced.map(\.uid)), [previous.uid, stray.uid])
    }

    /// Running the same session again is another run of it, so it replaces nothing.
    func testRunningTheSameTemporarySessionAgainReplacesNothing() {
        let only = temporary("2 Oct Quick Session")
        XCTAssertTrue(Routine.temporariesReplaced(by: only.uid, in: [only, Routine(name: "Morning")]).isEmpty)
    }

    // MARK: - Names (D4)

    /// Not numbered until it is saved — so it runs under exactly the name on the review screen.
    func testATemporarySessionRunsUnderTheNameItWasGiven() {
        XCTAssertEqual(QuickSessionNaming.temporaryName(requested: " Tuesday ", existing: ["Tuesday"],
                                                        date: date),
                       "Tuesday")
    }

    func testABlankNameFallsBackToTheDatedDefault() {
        XCTAssertEqual(QuickSessionNaming.temporaryName(requested: "  ", existing: [], date: date),
                       QuickSessionNaming.defaultName(existing: [], date: date))
    }

    /// The rule the review screen's Save has always used, now shared with every later save.
    func testSavingNumbersTheNameAgainstTheSavedNames() {
        XCTAssertEqual(QuickSessionNaming.savedName(requested: "Tuesday", existing: ["Tuesday"], date: date),
                       "Tuesday 2")
        let base = QuickSessionNaming.defaultName(existing: [], date: date)
        XCTAssertEqual(QuickSessionNaming.savedName(requested: "", existing: [base], date: date), "\(base) 2")
    }

    // MARK: - Through the store

    /// D3: the replaced session goes with its blocks; saved routines, the new session and the drills
    /// the blocks pointed at all stay.
    func testDeletingTemporariesTakesTheirBlocksAndLeavesEverythingElse() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let drill = Exercise(name: "Spider")
        let saved = Routine(name: "Morning")
        saved.items = [RoutineItem.item(drill, order: 0)]
        let previous = temporary("1 Oct Quick Session")
        previous.items = [RoutineItem.item(drill, order: 0), RoutineItem.rest(order: 1)]
        let current = temporary("2 Oct Quick Session")
        current.items = [RoutineItem.item(drill, order: 0)]
        context.insert(drill)
        context.insert(saved)
        context.insert(previous)
        context.insert(current)
        try context.save()

        Routine.deleteTemporaries(replacedBy: current.uid, in: context)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(Set(try fresh.fetch(FetchDescriptor<Routine>()).map(\.uid)), [saved.uid, current.uid])
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<RoutineItem>()).count, 2,
                       "the replaced session's two blocks went with it")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Exercise>()).count, 1,
                       "a block's drill is never deleted with the block")
    }

    /// D3, the case that went wrong: the new session shares a drill with the one it replaces, and
    /// its block has to stay linked to it.
    ///
    /// The new session is made in the review screen's sandbox and the old one is deleted **there**,
    /// in the same save. Built first with the delete in the main context instead, the app unlinked
    /// every shared block on the simulator (`Routine.deleteTemporaries` has the account). This setup
    /// gives the main context the same stale view the app's had — it inserted the old session, so it
    /// holds the drill's `routineItems` from before the new block existed — and the main-context
    /// version of it fails here too. The in-memory store is not a faithful judge of everything a
    /// stale main context does later (ADR 0243 D3), so this pins the order of writes,
    /// and `TemporarySessionUITests` checks the result in the app.
    func testReplacingInTheNewSessionsOwnContextKeepsItsSharedBlocksLinked() throws {
        let container = try makeContainer()
        let main = ModelContext(container)
        let drill = Exercise(name: "Legato")
        let previous = temporary("1 Oct Quick Session")
        previous.items = [RoutineItem.item(drill, order: 0)]
        main.insert(drill)
        main.insert(previous)
        try main.save()

        let sandbox = ModelContext(container)
        let local = try XCTUnwrap(try sandbox.fetch(FetchDescriptor<Exercise>()).first)
        let current = temporary("2 Oct Quick Session")
        sandbox.insert(current)
        let block = RoutineItem.item(local, order: 0)
        block.routine = current
        sandbox.insert(block)
        Routine.deleteTemporaries(replacedBy: current.uid, in: sandbox)
        try sandbox.save()

        let fresh = ModelContext(container)
        let routines = try fresh.fetch(FetchDescriptor<Routine>())
        XCTAssertEqual(routines.map(\.uid), [current.uid], "the previous session should be gone")
        XCTAssertEqual(routines.first?.items.first?.exercise?.name, "Legato",
                       "replacing a temporary session unlinked the new one's shared block")
    }

    /// D6: saving flips the flag and keeps the `uid` every run and note was written with. The name is
    /// numbered against **saved** routines only — a stray temporary one with the same name is not a
    /// reason to rename it.
    func testSavingKeepsTheUIDAndNumbersAgainstSavedRoutinesOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = temporary("2 Oct Quick Session")
        let uid = session.uid
        context.insert(Routine(name: "2 Oct Quick Session"))
        context.insert(temporary("2 Oct Quick Session 2"))
        context.insert(session)
        try context.save()

        session.saveTemporary(in: context, now: date)

        let fresh = ModelContext(container)
        let stored = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Routine>()).first { $0.uid == uid })
        XCTAssertFalse(stored.isTemporary)
        XCTAssertEqual(stored.name, "2 Oct Quick Session 2")
    }

    /// Saving is for a temporary session. On a saved routine it changes nothing — not even the name.
    func testSavingASavedRoutineChangesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let routine = Routine(name: "Morning")
        context.insert(Routine(name: "Morning"))
        context.insert(routine)
        try context.save()

        routine.saveTemporary(in: context, now: date)

        XCTAssertEqual(routine.name, "Morning")
        XCTAssertFalse(routine.isTemporary)
    }

    // MARK: - The archive (D8)

    /// A backup holds what you saved. The format carries no flag, so a temporary session written in
    /// would restore as a saved routine.
    @MainActor
    func testTheArchiveLeavesATemporarySessionOut() {
        let kept = Routine(name: "Morning")
        let session = temporary("2 Oct Quick Session")
        let archive = ArchiveBuilder.snapshot(from: ArchiveSource(routines: [kept, session]),
                                              appVersion: "1.3 (7)", includesTakeAudio: false,
                                              exportedAt: date)
        XCTAssertEqual(archive.routines.map(\.uid), [kept.uid])
    }

    // MARK: - Helpers

    private func temporary(_ name: String) -> Routine {
        let routine = Routine(name: name)
        routine.isTemporary = true
        return routine
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
