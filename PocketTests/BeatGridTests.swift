import XCTest
@testable import Pocket

/// Pure beat-grid math (ADR 0022). The stepping, phase anchoring, and downbeat
/// grouping are exactly the kind of arithmetic that breaks silently without coverage
/// (AGENTS.md), so they're pinned here.
final class BeatGridTests: XCTestCase {

    private func assertFractions(_ beats: [BeatGrid.Beat], _ expected: [Double],
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(beats.count, expected.count, "beat count", file: file, line: line)
        for (beat, want) in zip(beats, expected) {
            XCTAssertEqual(beat.fraction, want, accuracy: 1e-9, file: file, line: line)
        }
    }

    // MARK: guards

    func testEmptyForNonPositiveBPM() {
        XCTAssertTrue(BeatGrid.beats(bpm: 0, duration: 10, downbeat: 0).isEmpty)
        XCTAssertTrue(BeatGrid.beats(bpm: -120, duration: 10, downbeat: 0).isEmpty)
    }

    func testEmptyForNonPositiveDuration() {
        XCTAssertTrue(BeatGrid.beats(bpm: 120, duration: 0, downbeat: 0).isEmpty)
        XCTAssertTrue(BeatGrid.beats(bpm: 120, duration: -5, downbeat: 0).isEmpty)
    }

    func testEmptyWhenGridExceedsMaxBeats() {
        // 6000 BPM over 200 s ⇒ ~20k beats, past the runaway guard ⇒ no grid.
        XCTAssertTrue(BeatGrid.beats(bpm: 6000, duration: 200, downbeat: 0).isEmpty)
    }

    // MARK: positions

    func testBeatsAtSongStartAnchor() {
        // 60 BPM ⇒ a beat every second; a 4 s song anchored at 0 has beats at 0…4 s.
        let beats = BeatGrid.beats(bpm: 60, duration: 4, downbeat: 0)
        assertFractions(beats, [0, 0.25, 0.5, 0.75, 1.0])
    }

    func testDownbeatEveryFourthBeatFromAnchor() {
        let beats = BeatGrid.beats(bpm: 60, duration: 4, downbeat: 0)   // 5 beats, k = 0…4
        XCTAssertEqual(beats.map(\.isDownbeat), [true, false, false, false, true])
    }

    func testTimeSignatureGroupsBarLines() {
        // Per-song meter (ADR 0051): 3/4 ⇒ a bar line every third beat, not every fourth.
        let beats = BeatGrid.beats(bpm: 60, duration: 6, downbeat: 0, beatsPerBar: 3)
        XCTAssertEqual(beats.map(\.isDownbeat), [true, false, false, true, false, false, true])
    }

    func testPhaseAnchorShiftsTheWholeGrid() {
        // Anchor at 0.5 s ⇒ beats at 0.5, 1.5, 2.5, 3.5 s (no beat before 0.5).
        let beats = BeatGrid.beats(bpm: 60, duration: 4, downbeat: 0.5)
        assertFractions(beats, [0.125, 0.375, 0.625, 0.875])
        XCTAssertEqual(beats.first?.isDownbeat, true)   // the anchor itself is a downbeat
    }

    func testBeatsStepBackwardFromAnchorWithCorrectDownbeat() {
        // Anchor mid-song (2.0 s): beats fill outward to 0…4 s, but only the anchor
        // (k = 0, fraction 0.5) is the bar start — negative k must group correctly.
        let beats = BeatGrid.beats(bpm: 60, duration: 4, downbeat: 2.0)
        assertFractions(beats, [0, 0.25, 0.5, 0.75, 1.0])
        let downbeats = beats.filter(\.isDownbeat).map(\.fraction)
        XCTAssertEqual(downbeats.count, 1)
        XCTAssertEqual(downbeats.first ?? -1, 0.5, accuracy: 1e-9)
    }

    func testBeatsPerBarGrouping() {
        // 3/4: downbeats every 3rd beat from the anchor.
        let beats = BeatGrid.beats(bpm: 60, duration: 6, downbeat: 0, beatsPerBar: 3)
        let downbeats = beats.filter(\.isDownbeat).map(\.fraction)
        XCTAssertEqual(downbeats.count, 3)
        for (got, want) in zip(downbeats, [0.0, 0.5, 1.0]) {
            XCTAssertEqual(got, want, accuracy: 1e-9)
        }
    }

    func testBeatsPerBarBelowOneIsTreatedAsOne() {
        // Degenerate beatsPerBar ⇒ every beat is its own bar (all downbeats).
        let beats = BeatGrid.beats(bpm: 60, duration: 3, downbeat: 0, beatsPerBar: 0)
        XCTAssertEqual(beats.count, 4)
        XCTAssertTrue(beats.allSatisfy(\.isDownbeat))
    }

    func testFractionalBPMKeepsPrecision() {
        // 90.0 BPM ⇒ 1.5 s spacing; 90.06 BPM places beats fractionally tighter.
        // An Int-rounded tempo would collapse 90.06 → 90 and lose the offset (ADR 0024).
        let interval = 60.0 / 90.06
        let beats = BeatGrid.beats(bpm: 90.06, duration: 4, downbeat: 0)
        XCTAssertEqual(beats.first?.fraction ?? -1, 0, accuracy: 1e-9)
        // Second beat sits at one interval / duration — distinct from the 90.0 case.
        XCTAssertEqual(beats[1].fraction, interval / 4, accuracy: 1e-9)
        XCTAssertNotEqual(beats[1].fraction, (60.0 / 90.0) / 4, accuracy: 1e-6)
    }

    func testBeatFractionsMatchBeats() {
        let fractions = BeatGrid.beatFractions(bpm: 90, duration: 12, downbeat: 0.25)
        let beats = BeatGrid.beats(bpm: 90, duration: 12, downbeat: 0.25).map(\.fraction)
        XCTAssertEqual(fractions, beats)
    }

    func testFractionsAreAscendingAndInRange() {
        let beats = BeatGrid.beats(bpm: 128, duration: 45, downbeat: 1.3)
        XCTAssertFalse(beats.isEmpty)
        XCTAssertEqual(beats.map(\.fraction), beats.map(\.fraction).sorted())
        XCTAssertTrue(beats.allSatisfy { $0.fraction >= 0 && $0.fraction <= 1 })
    }
}
