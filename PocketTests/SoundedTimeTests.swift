import XCTest
import SwiftData
@testable import Pocket

/// **Active listening and Improvise log the time the loop sounded** (ADR 0321), not the time their
/// screen was open. The screens are a line of wiring each — take the player's run, hand it to the
/// writer. What can go wrong is here: a silence that gets counted, a second stretch that resets the
/// first, a run handed back twice, and a visit that never played logging anything at all.
///
/// The uptimes are any monotonic seconds, as `PlayClock` takes them; the dates are wall clock and only
/// say which day the row lands on, so they are deliberately not the uptimes plus a constant.
final class SoundedTimeTests: XCTestCase {

    private let evening = Date(timeIntervalSinceReferenceDate: 817_333_197)   // 2026-11-25 20:59:57

    /// The bug, in miniature: the loop played for ten seconds, was stopped, and the app sat in the
    /// background for twelve hours before the screen closed. Ten seconds is what sounded.
    func testASilenceAfterStoppingIsNotCounted() throws {
        var time = SoundedTime()
        time.began(at: evening, uptime: 1_000)
        time.ended(uptime: 1_010)

        let run = try XCTUnwrap(time.take(uptime: 1_000 + 12 * 3_600))

        XCTAssertEqual(run.start, evening)
        XCTAssertEqual(run.duration, 10, accuracy: 1e-9)
    }

    /// Opening the screen and leaving without pressing ▶ is not a run.
    func testAVisitThatNeverSoundedLogsNothing() {
        var time = SoundedTime()
        XCTAssertNil(time.take(uptime: 500))
    }

    /// Stop and play again is one visit: the stretches add up, the gap between them is left out, and
    /// the row starts at the first sound.
    func testStretchesAddUpAndTheGapBetweenThemIsLeftOut() throws {
        var time = SoundedTime()
        time.began(at: evening, uptime: 0)
        time.ended(uptime: 30)
        time.began(at: evening.addingTimeInterval(400), uptime: 100)
        time.ended(uptime: 145)

        let run = try XCTUnwrap(time.take(uptime: 9_000))

        XCTAssertEqual(run.start, evening, "the second stretch moved the row's start")
        XCTAssertEqual(run.duration, 75, accuracy: 1e-9)
    }

    /// The player brings the clock up to date after every change, so a start while sounding and a stop
    /// while quiet both arrive often. Neither may count anything twice or move the start.
    func testARepeatedStartOrStopChangesNothing() throws {
        var time = SoundedTime()
        time.ended(uptime: 0)                                       // quiet, told it's quiet
        time.began(at: evening, uptime: 10)
        time.began(at: evening.addingTimeInterval(5), uptime: 15)   // a slice cut by a newer one
        time.ended(uptime: 20)
        time.ended(uptime: 60)

        let run = try XCTUnwrap(time.take(uptime: 100))

        XCTAssertEqual(run.start, evening)
        XCTAssertEqual(run.duration, 10, accuracy: 1e-9)
    }

    /// A routine block's Done takes the run with the loop still playing, just before the screen goes.
    /// It counts up to that moment.
    func testTakingWhileSoundingCountsUpToThatMoment() throws {
        var time = SoundedTime()
        time.began(at: evening, uptime: 50)

        let run = try XCTUnwrap(time.take(uptime: 290))

        XCTAssertEqual(run.duration, 240, accuracy: 1e-9)
    }

    /// Done, then the screen going: both are seams, and the second must find nothing — including the
    /// stop that tears the screen down after Done took the run.
    func testARunIsHandedBackOnce() {
        var time = SoundedTime()
        time.began(at: evening, uptime: 0)
        XCTAssertNotNil(time.take(uptime: 60))

        time.ended(uptime: 61)

        XCTAssertNil(time.take(uptime: 62), "the visit was logged twice")
    }

    /// After a take the next sound is a new run, starting when it does.
    func testSoundingAfterATakeIsANewRun() throws {
        var time = SoundedTime()
        time.began(at: evening, uptime: 0)
        time.ended(uptime: 20)
        _ = time.take(uptime: 30)

        let later = evening.addingTimeInterval(3_600)
        time.began(at: later, uptime: 3_600)
        time.ended(uptime: 3_612)
        let run = try XCTUnwrap(time.take(uptime: 3_700))

        XCTAssertEqual(run.start, later)
        XCTAssertEqual(run.duration, 12, accuracy: 1e-9)
    }

    /// End to end through the writer: the row is the sounded run, and a tap of ▶ under a second is
    /// still the writer's to drop.
    @MainActor
    func testTheWriterLogsTheSoundedLength() throws {
        let context = ModelContext(try ModelContainer(
            for: PracticeRun.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))

        var heard = SoundedTime()
        heard.began(at: evening, uptime: 0)
        heard.ended(uptime: 95)
        let run = try XCTUnwrap(heard.take(uptime: 45_000))
        XCTAssertTrue(PracticeLogWriter.log(kind: .earLoop, startedAt: run.start, endedAt: run.end,
                                            unitUID: UUID(), into: context))

        var tapped = SoundedTime()
        tapped.began(at: evening, uptime: 0)
        tapped.ended(uptime: 0.4)
        let blip = try XCTUnwrap(tapped.take(uptime: 10))
        XCTAssertFalse(PracticeLogWriter.log(kind: .improvise, startedAt: blip.start, endedAt: blip.end,
                                             unitUID: UUID(), into: context))

        let rows = try context.fetch(FetchDescriptor<PracticeRun>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.kind, .earLoop)
        XCTAssertEqual(rows.first?.startedAt, evening)
        XCTAssertEqual(rows.first?.durationSeconds ?? 0, 95, accuracy: 1e-9)
    }
}
