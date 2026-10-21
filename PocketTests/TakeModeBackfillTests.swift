import XCTest
import SwiftData
@testable import Pocket

/// **A take from before ADR 0265 finds its mode in the practice log.** The rule is pure and tested over
/// plain `SessionRecord`s; one store test proves the driver writes what the rule finds, once.
///
/// A wrong answer here is silent: a take given the wrong mode opens the wrong screen from the Journal,
/// which is the bug this backfill exists to fix. So the cases that must answer `nil` matter as much as
/// the ones that find a mode.
final class TakeModeBackfillTests: XCTestCase {

    private let loopUID = UUID()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A 2-minute run on `loopUID` (unless told otherwise), starting at `start`.
    private func run(_ kind: PracticeRunKind, on unit: UUID? = nil, from offset: TimeInterval = 0,
                     seconds: Double = 120) -> SessionRecord {
        SessionRecord(startedAt: start.addingTimeInterval(offset), durationSeconds: seconds,
                      kind: kind, unitUID: unit ?? loopUID)
    }

    private func mode(at offset: TimeInterval, _ runs: [SessionRecord]) -> LoopRunMode? {
        TakeModeBackfill.mode(forTakeAt: start.addingTimeInterval(offset), loopUID: loopUID, runs: runs)
    }

    // MARK: - The rule

    func testEachLoopModesRunNamesTheModeOfATakeInsideIt() {
        XCTAssertEqual(mode(at: 60, [run(.earLoop)]), .ear)
        XCTAssertEqual(mode(at: 60, [run(.improvise)]), .improvise)
        XCTAssertEqual(mode(at: 60, [run(.loop)]), .trainer)
    }

    func testATakeAFewSecondsOutsideTheRunStillBelongsToIt() {
        // The take and the log are written by two `.onDisappear`s that fire in either order.
        XCTAssertEqual(mode(at: 120 + 4, [run(.earLoop)]), .ear, "stopped just after the logged end")
        XCTAssertEqual(mode(at: -4, [run(.earLoop)]), .ear, "stopped just before the logged start")
        XCTAssertNil(mode(at: 120 + 6, [run(.earLoop)]), "past the slack is another sitting")
    }

    func testATakeOutsideEveryRunHasNoMode() {
        XCTAssertNil(mode(at: 3600, [run(.earLoop), run(.loop, from: 600)]))
        XCTAssertNil(mode(at: 60, []), "no log at all")
    }

    func testARunOnAnotherLoopSaysNothingAboutThisOne() {
        XCTAssertNil(mode(at: 60, [run(.earLoop, on: UUID())]))
    }

    func testTwoModesOnTheLoopAroundTheTakeAreTooCloseToCall() {
        // A trainer block ending as an ear block on the same loop begins: the take sits in both spans.
        XCTAssertNil(mode(at: 122, [run(.loop), run(.earLoop, from: 121)]))
    }

    func testTwoRunsInTheSameModeStillAgree() {
        XCTAssertEqual(mode(at: 122, [run(.earLoop), run(.earLoop, from: 121)]), .ear)
    }

    func testAKindThatIsNotALoopModeIsIgnored() {
        // A song or an exercise row carrying the same uid can't name a loop mode, and mustn't veto one.
        XCTAssertNil(mode(at: 60, [run(.song), run(.exercise), run(.metronome), run(.other)]))
        XCTAssertEqual(mode(at: 60, [run(.earLoop), run(.other)]), .ear)
    }

    // MARK: - The driver

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self, Routine.self,
            RoutineItem.self, Goal.self, Recording.self, TakeNote.self, PracticeRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// A throwaway `UserDefaults` suite so the once-key never touches the real domain.
    private func freshDefaults() throws -> UserDefaults {
        let name = "TakeModeBackfillTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testTheStoreRunWritesTheModeOnceAndLeavesARecordedModeAlone() throws {
        let context = try makeContext()
        let defaults = try freshDefaults()
        let loop = Loop(name: "Chords", start: 0.1, end: 0.4, speed: 1, repeats: 1)
        let legacy = Recording(fileName: "a.m4a", duration: 30, createdAt: start.addingTimeInterval(90))
        let recorded = Recording(fileName: "b.m4a", duration: 30, createdAt: start.addingTimeInterval(100))
        context.insert(loop)
        context.insert(legacy)
        context.insert(recorded)
        legacy.loop = loop
        RecordingOwner.loop(loop, .improvise).attach(to: recorded)
        context.insert(PracticeRun(startedAt: start, durationSeconds: 120, kind: .earLoop, unitUID: loop.uid))
        try context.save()

        TakeModeBackfill.runIfNeeded(into: context, defaults: defaults)

        XCTAssertEqual(legacy.loopRunMode, .ear, "the ear-training run around it names the mode")
        XCTAssertEqual(recorded.loopRunMode, .improvise, "a mode written at capture is never overwritten")
        XCTAssertTrue(defaults.bool(forKey: TakeModeBackfill.backfillKey))

        // Once: a second call reads the key and does nothing, even with a mode-less take to fill.
        legacy.loopRunModeRaw = nil
        TakeModeBackfill.runIfNeeded(into: context, defaults: defaults)
        XCTAssertNil(legacy.loopRunModeRaw)
    }

    func testAStoreWithNoModeLessTakeStillMarksItselfDone() throws {
        let context = try makeContext()
        let defaults = try freshDefaults()

        TakeModeBackfill.runIfNeeded(into: context, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: TakeModeBackfill.backfillKey))
    }
}
