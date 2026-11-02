import XCTest
@testable import Pocket

/// The beat map's pure half (ADR 0281): taps into a map, a tap onto a hit, and a map read as a whole
/// song. The cleaning rules decide where every bar line after them falls, so each one is pinned.
final class BeatMapTests: XCTestCase {

    /// Evenly spaced beats, `gap` apart from `start`.
    private func even(_ count: Int, gap: TimeInterval, from start: TimeInterval = 0) -> [TimeInterval] {
        (0..<count).map { start + Double($0) * gap }
    }

    private func assertTimes(_ actual: [TimeInterval], _ expected: [TimeInterval],
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "beat count \(actual)", file: file, line: line)
        for (got, want) in zip(actual, expected) {
            XCTAssertEqual(got, want, accuracy: 1e-9, file: file, line: line)
        }
    }

    // MARK: - Reading a map

    func testAMapNeedsFourBeats() {
        XCTAssertFalse(BeatMap.isMap(even(3, gap: 0.5)))
        XCTAssertTrue(BeatMap.isMap(even(4, gap: 0.5)))
    }

    func testTheHeadlineTempoIsTheMedianGap() throws {
        // Gaps 0.5, 0.5, 0.6, 0.5: one slow gap doesn't move the median.
        let bpm = try XCTUnwrap(BeatMap.medianBPM([0, 0.5, 1.0, 1.6, 2.1]))
        XCTAssertEqual(bpm, 120, accuracy: 1e-9)
    }

    func testTheRangeReadsBarsNotSingleGaps() throws {
        // A steady 120 with one tap 40 ms late. Gap by gap that reads 111 to 130 BPM; over a bar the
        // 40 ms is spread across four gaps, so the range stays within about 2.5 BPM of 120.
        var beats = even(12, gap: 0.5)
        beats[6] += 0.04
        let range = try XCTUnwrap(BeatMap.tempoRange(beats))
        XCTAssertGreaterThan(range.lowerBound, 117)
        XCTAssertLessThan(range.upperBound, 123)
    }

    func testTheRangeFollowsADrift() throws {
        // Two bars at 90 BPM, then two at 100.
        let slow = even(9, gap: 60.0 / 90)
        let fast = even(9, gap: 60.0 / 100, from: try XCTUnwrap(slow.last)).dropFirst()
        let range = try XCTUnwrap(BeatMap.tempoRange(slow + fast))
        XCTAssertEqual(range.lowerBound, 90, accuracy: 1e-6)
        XCTAssertEqual(range.upperBound, 100, accuracy: 1e-6)
    }

    // MARK: - From taps

    func testTapsAreSorted() {
        // A loop that wrapped puts later taps earlier.
        assertTimes(BeatMap.fromTaps([1.5, 2.0, 0.0, 0.5, 1.0]), [0, 0.5, 1.0, 1.5, 2.0])
    }

    func testAFumbleKeepsTheFirstTap() {
        // A second tap 60 ms after the first on beat 2 is a fumble, not a beat.
        assertTimes(BeatMap.fromTaps([0, 0.5, 0.56, 1.0, 1.5, 2.0]), [0, 0.5, 1.0, 1.5, 2.0])
    }

    func testTwoPassesOfALoopMakeOneMap() {
        // The same four bars tapped twice, the second pass 20 ms late throughout.
        let pass = even(8, gap: 0.5, from: 10)
        let map = BeatMap.fromTaps(pass + pass.map { $0 + 0.02 })
        assertTimes(map, pass)
    }

    func testAMissedBeatIsFilled() {
        // Beat 3 of 7 wasn't tapped.
        assertTimes(BeatMap.fromTaps([0, 0.5, 1.0, 2.0, 2.5, 3.0]), [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
    }

    func testTwoMissedBeatsAreFilledEvenly() {
        assertTimes(BeatMap.fromTaps([0, 0.5, 1.0, 2.5, 3.0, 3.5]),
                    [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5])
    }

    /// A song that slows for its bridge isn't a song that skipped a beat: each gap is judged against
    /// the gaps around it, not against the song's tempo.
    func testASteadySlowdownIsNotFilled() {
        var beats: [TimeInterval] = [0]
        for step in 0..<16 { beats.append(beats[beats.count - 1] + 0.5 + Double(step) * 0.03) }
        assertTimes(BeatMap.fromTaps(beats), beats)
    }

    /// The backlog's case: a song that drops from 150 to 92 BPM for its bridge. Against the song's
    /// median every slow gap looks like a beat and a half; against its neighbours it's the new tempo.
    func testATempoChangeAtASectionIsNotFilled() {
        let verse = even(11, gap: 0.4)
        let bridge = (1...7).map { 4.0 + Double($0) * 0.65 }
        assertTimes(BeatMap.fromTaps(verse + bridge), verse + bridge)
    }

    func testNoTapsOrOneTapIsNoMap() {
        XCTAssertEqual(BeatMap.fromTaps([]), [])
        XCTAssertEqual(BeatMap.fromTaps([3]), [3])
        XCTAssertFalse(BeatMap.isMap(BeatMap.fromTaps([3, 3, 3, 3])))
    }

    // MARK: - Snapping a tap onto a hit

    /// 100 frames a second, a low floor with a hit at each frame in `hits`.
    private func envelope(hits: [Int: Double], frames: Int = 300, floor: Double = 0.1) -> BeatMap.Onsets {
        var values = (0..<frames).map { floor + 0.02 * Double($0 % 3) }
        for (frame, height) in hits { values[frame] = height }
        return BeatMap.Onsets(values: values, framesPerSecond: 100)
    }

    func testATapMovesOntoAClearHitNearIt() {
        // The hit is at 1.00 s; the tap came 30 ms late.
        assertTimes(BeatMap.snapped([1.03], to: envelope(hits: [100: 1.0])), [1.0])
    }

    func testAHitPastTheWindowLeavesTheTap() {
        // 80 ms is further than a careful tap misses by.
        assertTimes(BeatMap.snapped([1.08], to: envelope(hits: [100: 1.0])), [1.08])
    }

    func testAPeakThatDoesntStandOutLeavesTheTap() {
        // A peak a third above the level around it is as likely the hi-hat as the beat.
        assertTimes(BeatMap.snapped([1.01], to: envelope(hits: [100: 0.16])), [1.01])
    }

    func testTheLouderOfTwoHitsWins() {
        // A ghost note at 0.97 s and the beat at 1.03 s, the tap between them.
        assertTimes(BeatMap.snapped([1.0], to: envelope(hits: [97: 0.6, 103: 1.0])), [1.03])
    }

    func testTheRisingEdgeOfAHitOutsideTheWindowIsNotAPeak() {
        // The envelope climbs to a hit at 1.07 s; the window ends at 1.05 s, mid-climb.
        var values = [Double](repeating: 0.1, count: 300)
        for (offset, frame) in (100...107).enumerated() { values[frame] = 0.2 + 0.1 * Double(offset) }
        let onsets = BeatMap.Onsets(values: values, framesPerSecond: 100)
        assertTimes(BeatMap.snapped([1.0], to: onsets), [1.0])
    }

    func testNoEnvelopeLeavesEveryTap() {
        let taps: [TimeInterval] = [0.5, 1.0]
        assertTimes(BeatMap.snapped(taps, to: BeatMap.Onsets(values: [], framesPerSecond: 100)), taps)
    }

    // MARK: - The whole song

    func testAMapIsCarriedToBothEndsAtTheTempoThere() throws {
        // Tapped from 1.0 s at 0.5 s gaps, slowing to 0.6 s gaps at the end, in a 6 s song.
        let map: [TimeInterval] = [1.0, 1.5, 2.0, 2.5, 3.1, 3.7, 4.3]
        let whole = try XCTUnwrap(BeatMap.extended(map, through: 6, limit: 100))
        // Back at the head's 0.5: 0.5 and 0.0. On at the tail's 0.6: 4.9 and 5.5.
        assertTimes(whole, [0.0, 0.5] + map + [4.9, 5.5])
    }

    func testBeatsPastTheSongAreDropped() throws {
        let whole = try XCTUnwrap(BeatMap.extended([0, 1, 2, 3, 4, 5, 6], through: 4.5, limit: 100))
        assertTimes(whole, [0, 1, 2, 3, 4])
    }

    func testABeatThatDoesntComeAfterTheLastIsDropped() throws {
        let whole = try XCTUnwrap(BeatMap.extended([0, 1, 1, 2, 3, 2.5], through: 3, limit: 100))
        assertTimes(whole, [0, 1, 2, 3])
    }

    func testTooFewBeatsOrTooManyIsNil() {
        XCTAssertNil(BeatMap.extended([0, 1, 2], through: 10, limit: 100))
        XCTAssertNil(BeatMap.extended([0, 0.01, 0.02, 0.03], through: 600, limit: 1_000))
    }

    func testTheNearestBeatWinsAndATieGoesEarlier() {
        let beats: [TimeInterval] = [1, 2, 3]
        XCTAssertEqual(BeatMap.nearestIndex(to: 0, in: beats), 0)
        XCTAssertEqual(BeatMap.nearestIndex(to: 2.4, in: beats), 1)
        XCTAssertEqual(BeatMap.nearestIndex(to: 2.6, in: beats), 2)
        XCTAssertEqual(BeatMap.nearestIndex(to: 2.5, in: beats), 1)
        XCTAssertEqual(BeatMap.nearestIndex(to: 9, in: beats), 2)
        XCTAssertNil(BeatMap.nearestIndex(to: 1, in: []))
    }
}
