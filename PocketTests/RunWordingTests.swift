import XCTest
@testable import Pocket

/// The words Practice Settings and the staircase use for a run (ADR 0221 D1, D5, D10). Generated
/// prose is where a screen goes quietly wrong — a count that disagrees with the bars, `≈ 0 s`,
/// `1 steps` — and every other test still passes when it does.
final class RunWordingTests: XCTestCase {

    // MARK: - D10: the run's length

    func testUnderTenMinutesRoundsToTheNearestFiveSeconds() {
        XCTAssertEqual(RunLength.duration(seconds: 44), "≈ 45 s")
        XCTAssertEqual(RunLength.duration(seconds: 65.2), "≈ 1 min 5 s")
        XCTAssertEqual(RunLength.duration(seconds: 190), "≈ 3 min 10 s")
        XCTAssertEqual(RunLength.duration(seconds: 119), "≈ 2 min")
        XCTAssertEqual(RunLength.duration(seconds: 597), "≈ 9 min 55 s")
    }

    func testFromTenMinutesItIsWholeMinutes() {
        XCTAssertEqual(RunLength.duration(seconds: 598), "≈ 10 min", "rounds up into the band, not 10 min 0 s")
        XCTAssertEqual(RunLength.duration(seconds: 719), "≈ 12 min")
        XCTAssertEqual(RunLength.duration(seconds: 3_600), "≈ 60 min")
    }

    func testItNeverReadsZero() {
        XCTAssertEqual(RunLength.duration(seconds: 0), "≈ 5 s")
        XCTAssertEqual(RunLength.duration(seconds: 2), "≈ 5 s")
        XCTAssertEqual(RunLength.duration(seconds: -4), "≈ 5 s")
        XCTAssertEqual(RunLength.duration(seconds: .nan), "≈ 5 s")
    }

    func testTheCountIsExactAndPluralised() {
        XCTAssertEqual(RunLength.label(seconds: 65, count: 16, unit: .bars), "≈ 1 min 5 s · 16 bars")
        XCTAssertEqual(RunLength.label(seconds: 160, count: 12, unit: .passes), "≈ 2 min 40 s · 12 passes")
        XCTAssertEqual(RunLength.label(seconds: 20, count: 1, unit: .passes), "≈ 20 s · 1 pass")
    }

    /// The exercise line reads `SessionEstimate` and the ramp's own bar count — nothing else.
    func testTheExerciseLineStatesTheRampItIsGiven() {
        // 100 BPM held for four 4-bar intervals in 4/4: 16 bars × 2.4 s = 38.4 s.
        let ramp = CommandRamp(working: 100, command: 100, target: 100, warmupSteps: 0,
                               intervalCount: 4, unit: .bars, dwellIntervals: 4, includeBackoff: false)
        XCTAssertEqual(RunLength.exercise(ramp, beatsPerBar: 4), "≈ 40 s · 16 bars")
        XCTAssertEqual(SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 4), 38.4, accuracy: 0.001)
    }

    // MARK: - D5: the collapsed header

    private func summary(_ shape: RunShape = RunShape(),
                         tempos: RampTempos = RampTempos(working: 51, command: 61, reach: 65, backoff: 57),
                         reachIsAuto: Bool = true) -> RampSummary {
        RampSummary(tempos: tempos, shape: shape, reachIsAuto: reachIsAuto, backoffIsAuto: true,
                    tempoUnit: .bpm, holdUnit: .bars, unitsPerInterval: 4)
    }

    func testTheHeaderNamesOnlyThePhasesThatPlay() {
        XCTAssertEqual(summary(RunShape(includeBackoff: false)).header, "51 → 61 · reach 65 BPM")
        XCTAssertEqual(summary().header, "51 → 61 · reach 65 · back to 57 BPM")
        XCTAssertEqual(summary(RunShape(includeWarmup: false, includeBackoff: false)).header, "61 · reach 65 BPM")
        XCTAssertEqual(summary(RunShape(includeReach: false, includeBackoff: false)).header, "51 → 61 BPM")
    }

    func testACommandOnlyRunReadsSteadyWithItsLength() {
        let shape = RunShape(includeWarmup: false, includeReach: false, includeBackoff: false, dwell: 4)
        XCTAssertEqual(summary(shape).header, "61 BPM, steady · 16 bars")
    }

    func testALoopHeaderReadsInPercent() {
        let loop = RampSummary(tempos: RampTempos(working: 70, command: 85, reach: 95, backoff: 75),
                               shape: RunShape(includeBackoff: false), reachIsAuto: true, backoffIsAuto: true,
                               tempoUnit: .percent, holdUnit: .passes, unitsPerInterval: 1)
        XCTAssertEqual(loop.header, "70% → 85% · reach 95%")
        XCTAssertEqual(loop.row(.command), "85% · 4 passes")
    }

    // MARK: - D1: the phase rows

    func testEachRowSaysWhatItsPhaseWillPlay() {
        let rows = summary(RunShape(warmupSteps: 0, dwell: 2))
        XCTAssertEqual(rows.row(.warmup), "51 → 61 · 1 step · 4 bars each")
        XCTAssertEqual(rows.row(.command), "61 BPM · 8 bars")
        XCTAssertEqual(rows.row(.reach), "65 BPM (auto) · 1 step · 4 bars each")
        XCTAssertEqual(rows.row(.backoff), "57 BPM · 1 step · 4 bars each")
        XCTAssertEqual(summary(reachIsAuto: false).row(.reach), "65 BPM · 1 step · 4 bars each")
    }

    /// The row's count is the rungs drawn — the stride bug's own case reads 3, and plays 3.
    func testTheRowCountIsTheNumberDrawn() {
        let rows = summary(RunShape(warmupSteps: 2, warmupHold: 2))
        XCTAssertEqual(rows.row(.warmup), "51 → 61 · 3 steps · 8 bars each")
        XCTAssertEqual(rows.stepsCaption(.warmup), "about +3 BPM a rung")
        let plateaus = CommandRamp(tempos: rows.tempos, shape: rows.shape, backoffOverride: nil,
                                   intervalCount: 4, unit: .bars).plateaus
        XCTAssertEqual(plateaus.prefix { $0.bpm < 61 }.count, 3)
    }

    func testAnOffRowSaysWhatTheRunDoesWithoutIt() {
        let rows = summary(RunShape(includeWarmup: false, includeReach: false, includeBackoff: false))
        XCTAssertEqual(rows.row(.warmup), "off · the run starts straight at command")
        XCTAssertEqual(rows.row(.reach), "off · the run never goes above command")
        XCTAssertEqual(rows.row(.backoff), "off · the run ends at its highest tempo")
    }

    func testTheCommandHoldSaysWhenASessionFittedIt() {
        let rows = summary(RunShape(dwell: 2))
        XCTAssertEqual(rows.holdCaption(.command), "where the reps count")
        XCTAssertEqual(rows.holdCaption(.command, playedDwell: 2), "where the reps count")
        XCTAssertEqual(rows.holdCaption(.command, playedDwell: 5), "20 bars in this session")
    }

    /// One spelling (D5): the titles and captions say Back off, never Back-off or Back-up.
    func testOneSpellingOfBackOff() {
        let words = RampPhase.allCases.flatMap { [$0.title, $0.caption] }
        XCTAssertTrue(words.contains("Back off"))
        XCTAssertFalse(words.contains { $0.localizedCaseInsensitiveContains("back-") })
    }
}
