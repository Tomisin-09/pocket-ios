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

    // MARK: timing many beats (ADR 0282)

    /// A stand-in autocorrelation: a peak of `height` at every multiple of `period` frames,
    /// falling to nothing two frames either side.
    private func peaks(every period: Double, height: Double = 1) -> (Int) -> Double {
        { lag in
            let beats = (Double(lag) / period).rounded()
            guard beats >= 1 else { return 0 }
            return max(0, height * (1 - abs(Double(lag) - beats * period) / 2))
        }
    }

    /// 83 BPM is 72.3 frames a beat, so its spikes land 72 or 73 frames apart. One beat's lag
    /// can't tell the tempo closer than that; eighty seconds of beats can.
    func testAWholeSongGivesTheTempoToAHundredth() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: impulseTrain(bpm: 83, seconds: 80),
                                                           framesPerSecond: 100))
        XCTAssertEqual(bpm, 83, accuracy: 0.01)
    }

    /// The last seconds of *Binta* are a guitar fill with no beat under it. The rest of the song
    /// outvotes it.
    func testAFillOffTheBeatDoesNotMoveTheTempo() throws {
        var onsets = impulseTrain(bpm: 83, seconds: 80)
        var seed: UInt64 = 7
        for index in 7_400..<onsets.count {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            onsets[index] = seed >> 60 == 0 ? 1 : 0
        }
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: onsets, framesPerSecond: 100))
        XCTAssertEqual(bpm, 83, accuracy: 0.01)
    }

    /// *Binta*'s one-beat reading was 71.5 frames against 72.3.
    func testRefiningCorrectsABeatReadMostOfAFrameShort() {
        let lag = TempoEstimator.refined(beatLag: 71.52, frameCount: 8_000, autocorr: peaks(every: 72.29))
        XCTAssertEqual(lag, 72.29, accuracy: 0.01)
    }

    /// With eight beats the longest span, whole frames alone would leave the beat 0.04 frames out.
    /// The parabola between frames reads closer.
    func testRefiningReadsBetweenFrames() {
        let lag = TempoEstimator.refined(beatLag: 71.52, frameCount: 1_200, autocorr: peaks(every: 72.29))
        XCTAssertEqual(lag, 72.29, accuracy: 0.02)
    }

    /// A song in three repeats strongly only every bar of three beats. Doubling spans (2, 4, 8…)
    /// never land on one; growing by a half or a third does.
    func testABarOfThreeIsAmongTheSpans() {
        let lag = TempoEstimator.refined(beatLag: 71.52, frameCount: 8_000, autocorr: peaks(every: 3 * 72.29))
        XCTAssertEqual(lag, 72.29, accuracy: 0.01)
    }

    /// Two beats on from a beat read 2.2 frames long, the true peak is past the window's edge. The
    /// reading has drifted too far to follow, so it stands. Searching on would, at 32 beats, find
    /// the 33rd beat's peak and confirm the wrong tempo.
    func testRefiningLeavesTheReadingWhenThePeakIsOutOfReach() {
        let lag = TempoEstimator.refined(beatLag: 74.5, frameCount: 8_000, autocorr: peaks(every: 72.29))
        XCTAssertEqual(lag, 74.5)
    }

    /// A repeat too faint to trust at one beat is too faint at many.
    func testRefiningIgnoresAPeakBelowConfidence() {
        let faint = peaks(every: 72.79, height: TempoEstimator.minConfidence / 2)
        let lag = TempoEstimator.refined(beatLag: 72.29, frameCount: 8_000, autocorr: faint)
        XCTAssertEqual(lag, 72.29)
    }

    /// At least half the envelope always overlaps itself, and no lag is below one frame.
    func testRefiningAsksOnlyForLagsInsideTheEnvelope() throws {
        var asked: [Int] = []
        let shape = peaks(every: 50)
        _ = TempoEstimator.refined(beatLag: 50, frameCount: 1_000) { asked.append($0); return shape($0) }
        XCTAssertLessThanOrEqual(try XCTUnwrap(asked.max()), 500)

        asked = []
        _ = TempoEstimator.refined(beatLag: 1, frameCount: 1_000) { asked.append($0); return shape($0) }
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(asked.min()), 1)
    }

    /// The starter track holds 83 BPM from start to end (a steady grid fitted to the whole song
    /// reads 83.00, and so does each half). A 0.02 BPM error is 20 ms by its last beat.
    func testBintaReadsItsTempoExactly() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: StarterTrack.resourceName,
                                                           withExtension: StarterTrack.resourceExtension))
        let envelope = try XCTUnwrap(WaveformExtractor.extractOnsetEnvelope(from: url))
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: envelope.onsets,
                                                           framesPerSecond: envelope.framesPerSecond))
        XCTAssertEqual(bpm, 83, accuracy: 0.02)
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
