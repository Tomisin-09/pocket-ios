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

    // MARK: - Re-anchoring (ADR 0154)

    /// The whole compatibility claim in one test: the single-anchor entry point is now a
    /// delegation, so it must produce byte-identical grids across a spread of shapes.
    func testSingleAnchorOverloadMatchesTheAnchorsForm() {
        for (bpm, duration, downbeat, perBar) in [(120.0, 10.0, 0.0, 4), (90.0, 12.0, 0.25, 4),
                                                  (128.0, 45.0, 1.3, 3), (76.0, 8.0, 2.0, 1),
                                                  (60.0, 4.0, 0.5, 4)] {
            let single = BeatGrid.beats(bpm: bpm, duration: duration, downbeat: downbeat,
                                        beatsPerBar: perBar)
            let plural = BeatGrid.beats(bpm: bpm, duration: duration, anchors: [downbeat],
                                        beatsPerBar: perBar)
            XCTAssertEqual(single, plural, "bpm \(bpm) downbeat \(downbeat)")
        }
    }

    func testEmptyAnchorsYieldNoGrid() {
        XCTAssertTrue(BeatGrid.beats(bpm: 120, duration: 10, anchors: []).isEmpty)
    }

    /// The reason the feature exists. 60 BPM from t=0 would put beats on every second; a second
    /// anchor at 3.5 restarts the grid there, so the run is 0,1,2,3 then 3.5,4.5,5.5 — the drift
    /// the first anchor accumulated is discarded rather than carried to the end of the song.
    func testASecondAnchorRestartsThePhase() {
        let beats = BeatGrid.beats(bpm: 60, duration: 6, anchors: [0, 3.5])
        assertFractions(beats, [0, 1, 2, 3, 3.5, 4.5, 5.5].map { $0 / 6 })
    }

    /// An anchor *is* a 1: the bar count restarts with it. Carrying the running count would fix
    /// the click and leave the bar lines wrong, which is the worse of the two failures.
    func testBarCountRestartsAtEachAnchor() {
        let beats = BeatGrid.beats(bpm: 60, duration: 8, anchors: [0, 3.5], beatsPerBar: 4)
        //           0     1      2      3     | 3.5   4.5    5.5    6.5   | 7.5
        let expected = [true, false, false, false, true, false, false, false, true]
        XCTAssertEqual(beats.map(\.isDownbeat), expected)
    }

    /// The seam. Without the guard, 60 BPM anchored at 0 puts a beat at 3.0 and an anchor at
    /// 3.2 puts one 200 ms later — heard as a stumble, not a correction. The generated beat
    /// closest to the next anchor is dropped and the anchor's own beat wins.
    func testABeatIsNotEmittedRightBeforeTheNextAnchor() {
        let beats = BeatGrid.beats(bpm: 60, duration: 5, anchors: [0, 3.2])
        assertFractions(beats, [0, 1, 2, 3.2, 4.2].map { $0 / 5 })
        // …and every surviving pair is at least half an interval apart.
        for (earlier, later) in zip(beats, beats.dropFirst()) {
            XCTAssertGreaterThanOrEqual((later.fraction - earlier.fraction) * 5, 0.5 - 1e-9)
        }
    }

    /// The boundary, pinned deliberately on the *keep* side. Half an interval is an eighth-note
    /// gap — a legitimate offbeat, not the stumble the guard exists to prevent — so a beat
    /// landing exactly there survives, and only a closer one is dropped.
    func testABeatExactlyHalfAnIntervalBeforeAnAnchorSurvives() {
        let beats = BeatGrid.beats(bpm: 60, duration: 4, anchors: [0, 2.5])
        assertFractions(beats, [0, 1, 2, 2.5, 3.5].map { $0 / 4 })
    }

    /// Two anchors closer than half an interval are bad data (the UI corrects the nearest rather
    /// than appending). The grid still has to be total: the later one is discarded.
    func testNearDuplicateAnchorsCollapse() {
        let beats = BeatGrid.beats(bpm: 60, duration: 4, anchors: [0, 0.1])
        assertFractions(beats, [0, 1, 2, 3, 4].map { $0 / 4 })
    }

    func testAnchorsNeedNotBeSorted() {
        let unsorted = BeatGrid.beats(bpm: 60, duration: 6, anchors: [3.5, 0])
        let sorted = BeatGrid.beats(bpm: 60, duration: 6, anchors: [0, 3.5])
        XCTAssertEqual(unsorted, sorted)
    }

    func testExactDuplicateAnchorsAreHarmless() {
        let doubled = BeatGrid.beats(bpm: 60, duration: 4, anchors: [0.5, 0.5])
        let single = BeatGrid.beats(bpm: 60, duration: 4, downbeat: 0.5)
        XCTAssertEqual(doubled, single)
    }

    /// Beats still extrapolate backwards from the *first* anchor only — a later anchor never
    /// re-grids the music before it, or correcting bar 40 would silently move bar 2.
    func testOnlyTheFirstAnchorExtrapolatesBackwards() {
        let beats = BeatGrid.beats(bpm: 60, duration: 6, anchors: [2, 4.5])
        assertFractions(beats, [0, 1, 2, 3, 4, 4.5, 5.5].map { $0 / 6 })
    }

    func testAnchorPastTheEndContributesNothing() {
        let beats = BeatGrid.beats(bpm: 60, duration: 3, anchors: [0, 99])
        assertFractions(beats, [0, 1, 2, 3].map { $0 / 3 })
    }

    func testAnchorsStayAscendingAndInRange() {
        let beats = BeatGrid.beats(bpm: 128, duration: 45, anchors: [1.3, 17.9, 31.02])
        XCTAssertFalse(beats.isEmpty)
        XCTAssertEqual(beats.map(\.fraction), beats.map(\.fraction).sorted())
        XCTAssertTrue(beats.allSatisfy { $0.fraction >= 0 && $0.fraction <= 1 })
    }

    func testMaxBeatsGuardStillAppliesAcrossAnchors() {
        XCTAssertTrue(BeatGrid.beats(bpm: 6000, duration: 200, anchors: [0, 100]).isEmpty)
    }
}
