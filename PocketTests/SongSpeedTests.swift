import XCTest
@testable import Pocket

/// `SongSpeed` — the speed a song can be played at, read off its loops (ADR 0250 D8): the slowest
/// measured loop, beside the mastery dots and never folded into them.
final class SongSpeedTests: XCTestCase {

    private func part(_ name: String, _ command: Double?, backing: Bool = false) -> SongSpeed.Part {
        .init(name: name, command: command, isBackingTrack: backing)
    }

    func testNothingMeasuredReadsNothing() {
        XCTAssertNil(SongSpeed.reading([]))
        XCTAssertNil(SongSpeed.reading([part("Verse", nil), part("Chorus", nil)]),
                     "An unmeasured loop claims no speed, so a song of them has none to show")
    }

    func testTheSlowestMeasuredLoopSetsIt() {
        let reading = SongSpeed.reading([part("Intro", 0.6), part("Verse", 0.85), part("Solo", nil)])
        XCTAssertEqual(reading?.percent, 60)
        XCTAssertEqual(reading?.loopName, "Intro")
        XCTAssertEqual(reading?.stripLabel, "slowest 60%")
        XCTAssertEqual(reading?.accessibilityLabel, "Slowest loop at 60 percent")
    }

    func testATieGoesToTheFirstInSongOrder() {
        XCTAssertEqual(SongSpeed.reading([part("Verse", 0.7), part("Bridge", 0.7)])?.loopName, "Verse")
    }

    func testFullSpeedAtAndAboveTheRecord() {
        let exactly = SongSpeed.reading([part("Verse", 1.0), part("Solo", 1.25)])
        XCTAssertEqual(exactly?.isFullSpeed, true)
        XCTAssertEqual(exactly?.stripLabel, "full speed")
        XCTAssertEqual(exactly?.accessibilityLabel, "All loops at full speed")
        XCTAssertEqual(SongSpeed.reading([part("Verse", 0.95)])?.isFullSpeed, false)
    }

    func testFullSpeedIsJudgedOnTheBadgesRoundedPercent() {
        // A loop whose badge reads 100% is at full speed, and one whose badge reads 99% is not.
        XCTAssertTrue(SongSpeed.isFullSpeed(0.996))
        XCTAssertFalse(SongSpeed.isFullSpeed(0.994))
        XCTAssertEqual(SongSpeed.reading([part("Verse", 0.996)])?.stripLabel, "full speed")
    }

    func testABackingTrackIsLeftOut() {
        // You play along to a backing track, you don't practise it, so its speed isn't yours.
        let reading = SongSpeed.reading([part("Jam bed", 0.5, backing: true), part("Riff", 0.8)])
        XCTAssertEqual(reading?.percent, 80)
        XCTAssertNil(SongSpeed.reading([part("Jam bed", 0.5, backing: true)]))
    }
}
