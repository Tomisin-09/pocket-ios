import XCTest
@testable import Pocket

/// **The song player logs the time its audio sounded** (ADR 0322), split into a run per loop played
/// and one run of Exploring for everything else. What can go wrong is here: a silence that gets
/// counted, a switch between loops that gives one loop the other's time, a quick listen to a new loop
/// that becomes a loop run, Exploring lost when a loop is too short, and a visit logged twice.
///
/// The uptimes are any monotonic seconds, as `PlayClock` takes them; the dates are wall clock and only
/// say when a row starts, so they are deliberately not the uptimes plus a constant.
final class SongPlayerTimeTests: XCTestCase {

    private let evening = Date(timeIntervalSinceReferenceDate: 817_333_197)   // 2026-11-25 20:59:57
    private let verse = UUID()
    private let chorus = UUID()

    private func at(_ seconds: TimeInterval) -> Date { evening.addingTimeInterval(seconds) }

    // MARK: - What counts as sounding

    /// The rule the model reads its state through. A loop armed with no span open is that loop; an open
    /// span is a loop being made or changed, even with a loop armed (Adjust range lifts one into a span);
    /// the song through is Exploring; and nothing is counted while quiet or interrupted.
    func testWhatSoundsIsTheArmedLoopUnlessASpanIsOpen() {
        XCTAssertEqual(SongPlayerTime.sounding(isPlaying: true, silenced: false, armedLoop: verse, spanOpen: false),
                       .loop(verse))
        XCTAssertEqual(SongPlayerTime.sounding(isPlaying: true, silenced: false, armedLoop: verse, spanOpen: true),
                       .exploring, "adjusting a loop's range is changing the loop, not playing it")
        XCTAssertEqual(SongPlayerTime.sounding(isPlaying: true, silenced: false, armedLoop: nil, spanOpen: true),
                       .exploring)
        XCTAssertEqual(SongPlayerTime.sounding(isPlaying: true, silenced: false, armedLoop: nil, spanOpen: false),
                       .exploring, "the song playing through")
        XCTAssertNil(SongPlayerTime.sounding(isPlaying: false, silenced: false, armedLoop: verse, spanOpen: false))
        XCTAssertNil(SongPlayerTime.sounding(isPlaying: true, silenced: true, armedLoop: verse, spanOpen: false),
                     "an interruption silenced the engine under a transport still reading as playing")
    }

    // MARK: - A loop's run

    /// Two minutes on one loop, stopped, then the screen left open for an hour: two minutes, on that
    /// loop, from when it first sounded, and nothing to Exploring.
    func testALoopPlayedIsARunOnThatLoopAndTheSilenceAfterIsNot() throws {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 1_000)
        time.update(nil, at: at(120), uptime: 1_120)

        let runs = time.take(uptime: 1_000 + 3_600)

        XCTAssertEqual(runs.loops.map(\.loopUID), [verse])
        let run = try XCTUnwrap(runs.loops.first)
        XCTAssertEqual(run.interval.start, evening)
        XCTAssertEqual(run.interval.duration, 120, accuracy: 1e-9)
        XCTAssertNil(runs.exploring)
    }

    /// Cycling between two loops, which is how the song player is used: each loop gets its own time,
    /// the stretches on one loop add up, and its run starts when it first sounded.
    func testCyclingBetweenLoopsGivesEachLoopItsOwnTime() throws {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 0)
        time.update(.loop(chorus), at: at(40), uptime: 40)
        time.update(.loop(verse), at: at(100), uptime: 100)
        time.update(nil, at: at(130), uptime: 130)

        let runs = time.take(uptime: 500)

        XCTAssertEqual(runs.loops.map(\.loopUID), [verse, chorus], "earliest first")
        guard runs.loops.count == 2 else { return }
        XCTAssertEqual(runs.loops[0].interval.start, evening)
        XCTAssertEqual(runs.loops[0].interval.duration, 70, accuracy: 1e-9, "40 + 30")
        XCTAssertEqual(runs.loops[1].interval.start, at(40))
        XCTAssertEqual(runs.loops[1].interval.duration, 60, accuracy: 1e-9)
        XCTAssertNil(runs.exploring)
    }

    /// The floor is the loop's total on the visit, not each stretch: twenty seconds, a stop, and
    /// fifteen more is thirty-five seconds of that loop, and a run.
    func testTheFloorIsTheVisitsTotalOnALoopNotEachStretch() {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 0)
        time.update(nil, at: at(20), uptime: 20)
        time.update(.loop(verse), at: at(60), uptime: 60)
        time.update(nil, at: at(75), uptime: 75)

        let runs = time.take(uptime: 100)

        XCTAssertEqual(runs.loops.map(\.interval.duration), [35])
        XCTAssertNil(runs.exploring)
    }

    // MARK: - Exploring

    /// Making a loop: the song playing while the span is found and set, then the new loop heard a few
    /// times to check it, which saving it does by itself. The listen is under the floor, so it is part
    /// of the making: one Exploring run of both, from the first sound, and no loop run.
    func testAShortListenToANewLoopIsPartOfMakingIt() throws {
        var time = SongPlayerTime()
        time.update(.exploring, at: evening, uptime: 0)            // the song, then the span open
        time.update(.loop(verse), at: at(90), uptime: 90)          // saved: it plays at once
        time.update(nil, at: at(102), uptime: 102)

        let runs = time.take(uptime: 200)

        XCTAssertTrue(runs.loops.isEmpty, "twelve seconds to hear a loop is not a run of it")
        let explored = try XCTUnwrap(runs.exploring)
        XCTAssertEqual(explored.start, evening)
        XCTAssertEqual(explored.duration, 102, accuracy: 1e-9)
    }

    /// A short loop listen that came **before** any Exploring still starts the run, and the gap between
    /// it and the later Exploring is not counted.
    func testAFoldedListenMovesExploringsStartButNotItsLength() throws {
        var time = SongPlayerTime()
        time.update(.loop(chorus), at: evening, uptime: 0)
        time.update(nil, at: at(10), uptime: 10)
        time.update(.exploring, at: at(300), uptime: 300)
        time.update(nil, at: at(360), uptime: 360)

        let explored = try XCTUnwrap(time.take(uptime: 400).exploring)

        XCTAssertEqual(explored.start, evening)
        XCTAssertEqual(explored.duration, 70, accuracy: 1e-9, "10 + 60, not the 360 from first to last")
    }

    /// Practising one loop and making another on the same visit: the loop's run stands, and the making
    /// is Exploring beside it.
    func testALoopRunAndExploringOnOneVisitAreSeparate() throws {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 0)
        time.update(.exploring, at: at(300), uptime: 300)
        time.update(nil, at: at(420), uptime: 420)

        let runs = time.take(uptime: 500)

        XCTAssertEqual(runs.loops.map(\.interval.duration), [300])
        XCTAssertEqual(try XCTUnwrap(runs.exploring).duration, 120, accuracy: 1e-9)
    }

    // MARK: - The visit

    /// Opening a song and leaving without pressing play is nothing.
    func testAVisitThatNeverSoundedLogsNothing() {
        var time = SongPlayerTime()
        time.update(nil, at: evening, uptime: 0)
        XCTAssertEqual(time.take(uptime: 600), SongPlayerTime.Runs())
    }

    /// The model brings the count up to date after every change, so it is often told what it already
    /// knows. That must count nothing twice and move no start.
    func testBeingToldTheSameThingTwiceChangesNothing() throws {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 0)
        time.update(.loop(verse), at: at(20), uptime: 20)
        time.update(nil, at: at(40), uptime: 40)
        time.update(nil, at: at(90), uptime: 90)

        let run = try XCTUnwrap(time.take(uptime: 100).loops.first)
        XCTAssertEqual(run.interval.start, evening)
        XCTAssertEqual(run.interval.duration, 40, accuracy: 1e-9)
    }

    /// Taken while still sounding (the screen closing over a playing loop), it counts up to the take.
    /// And it is taken once: the second take finds nothing, so the screen's two seams can't log twice.
    func testATakeCountsUpToNowAndIsHandedBackOnce() throws {
        var time = SongPlayerTime()
        time.update(.loop(verse), at: evening, uptime: 0)

        let first = time.take(uptime: 45)
        XCTAssertEqual(try XCTUnwrap(first.loops.first).interval.duration, 45, accuracy: 1e-9)
        XCTAssertEqual(time.take(uptime: 90), SongPlayerTime.Runs())
    }
}
