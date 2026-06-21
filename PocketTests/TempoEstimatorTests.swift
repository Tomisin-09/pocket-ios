import XCTest
@testable import Pocket

/// Tempo estimation from an onset envelope (ADR 0004, rung 2). Drives `estimateBPM`
/// with synthetic onset trains so the autocorrelation + tempo-prior math is checked
/// without decoding audio.
final class TempoEstimatorTests: XCTestCase {

    /// An onset envelope with a spike every beat at `bpm`, sampled at `framesPerSecond`,
    /// with the first beat at `offsetFrames` (the phase the downbeat estimator recovers).
    private func impulseTrain(bpm: Double, framesPerSecond: Double = 100,
                              seconds: Double = 40, spike: Double = 1,
                              offsetFrames: Int = 0) -> [Double] {
        let period = 60 * framesPerSecond / bpm
        let count = Int(seconds * framesPerSecond)
        var onsets = [Double](repeating: 0, count: count)
        var position = Double(offsetFrames)
        while Int(position) < count {
            onsets[Int(position)] = spike
            position += period
        }
        return onsets
    }

    // MARK: recovery

    func testRecoversCommonTempo() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 120), framesPerSecond: 100))
        XCTAssertEqual(bpm, 120, accuracy: 2)
    }

    func testRecoversFastTempo() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 150), framesPerSecond: 100))
        XCTAssertEqual(bpm, 150, accuracy: 2)
    }

    func testRecoversSlowTempo() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 95), framesPerSecond: 100))
        XCTAssertEqual(bpm, 95, accuracy: 2)
    }

    /// Sub-frame parabolic interpolation: a tempo whose beat period isn't an integer
    /// number of frames (133 BPM ⇒ 45.1 frames at 100 Hz) should still resolve close,
    /// not snap to the nearest whole-frame BPM.
    func testInterpolatesBetweenFrameLags() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 133), framesPerSecond: 100))
        XCTAssertEqual(bpm, 133, accuracy: 2)
    }

    // MARK: octave handling

    /// On-beats taller than their eighth-note subdivisions: the estimate should lock to
    /// the beat (~100), not its 200 BPM subdivision — the half/double trap ADR 0004 warns of.
    func testPrefersBeatOverSubdivision() throws {
        let beats = impulseTrain(bpm: 100, spike: 1.0)
        let subs = impulseTrain(bpm: 200, spike: 0.4)
        let onsets = zip(beats, subs).map { max($0, $1) }
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: onsets, framesPerSecond: 100))
        XCTAssertEqual(bpm, 100, accuracy: 5)
    }

    // MARK: downbeat phase

    func testDownbeatRecoversZeroPhase() throws {
        let onsets = impulseTrain(bpm: 120, offsetFrames: 0)
        let phase = try XCTUnwrap(TempoEstimator.estimateDownbeat(onsets: onsets,
                                                                  framesPerSecond: 100, bpm: 120))
        XCTAssertEqual(phase, 0, accuracy: 0.02)
    }

    func testDownbeatRecoversOffsetPhase() throws {
        // First beat at frame 17 ⇒ 0.17 s; the comb-filter should land there.
        let onsets = impulseTrain(bpm: 100, offsetFrames: 17)
        let phase = try XCTUnwrap(TempoEstimator.estimateDownbeat(onsets: onsets,
                                                                  framesPerSecond: 100, bpm: 100))
        XCTAssertEqual(phase, 0.17, accuracy: 0.02)
    }

    func testDownbeatFlatSignalReturnsNil() {
        let flat = [Double](repeating: 0, count: 4000)
        XCTAssertNil(TempoEstimator.estimateDownbeat(onsets: flat, framesPerSecond: 100, bpm: 120))
    }

    func testCombinedEstimateReturnsTempoAndDownbeat() throws {
        let onsets = impulseTrain(bpm: 120, offsetFrames: 12)
        let estimate = try XCTUnwrap(TempoEstimator.estimate(onsets: onsets, framesPerSecond: 100))
        XCTAssertEqual(estimate.bpm, 120, accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(estimate.downbeatSeconds), 0.12, accuracy: 0.02)
    }

    // MARK: no confident estimate

    func testFlatSignalReturnsNil() {
        let flat = [Double](repeating: 0.5, count: 4000)
        XCTAssertNil(TempoEstimator.estimateBPM(onsets: flat, framesPerSecond: 100))
    }

    func testTooShortReturnsNil() {
        XCTAssertNil(TempoEstimator.estimateBPM(onsets: [1, 0, 1, 0], framesPerSecond: 100))
    }

    func testNonPositiveFramesPerSecondReturnsNil() {
        XCTAssertNil(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 120), framesPerSecond: 0))
    }

    func testResultStaysInTappableRange() {
        // An absurdly fast train can't push the result past the tappable ceiling.
        let bpm = TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 600), framesPerSecond: 100)
        if let bpm {
            XCTAssertLessThanOrEqual(bpm, TempoMath.maxTapBPM)
            XCTAssertGreaterThanOrEqual(bpm, TempoMath.minTapBPM)
        }
    }
}
