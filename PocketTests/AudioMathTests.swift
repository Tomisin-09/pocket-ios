import XCTest
@testable import Pocket

final class AudioMathTests: XCTestCase {

    func testDownsampleReturnsRequestedBarCount() {
        let samples = [Float](repeating: 0.5, count: 1000)
        XCTAssertEqual(AudioMath.downsample(samples, to: 120).count, 120)
    }

    func testDownsampleTakesPeakPerBinAndNormalises() {
        // Two bins: first peaks at 1.0, second peaks at 0.5 → normalised to [1, 0.5].
        let samples: [Float] = [0, 0.5, 1, 0.5, 0, 0.25, 0.5, 0.25]
        XCTAssertEqual(AudioMath.downsample(samples, to: 2), [1.0, 0.5])
    }

    func testDownsampleUsesAbsoluteValue() {
        let samples: [Float] = [-1, -0.5, 0.25, 0.5]
        let result = AudioMath.downsample(samples, to: 2)
        XCTAssertEqual(result[0], 1.0)      // |-1| is the peak, normalises to 1
        XCTAssertEqual(result[1], 0.5)      // |0.5| / 1.0
    }

    func testDownsampleEmptyInput() {
        XCTAssertTrue(AudioMath.downsample([], to: 10).isEmpty)
    }

    // MARK: mixToMono

    func testMixToMonoEmptyInput() {
        XCTAssertTrue(AudioMath.mixToMono([]).isEmpty)
    }

    func testMixToMonoSingleChannelPassesThrough() {
        XCTAssertEqual(AudioMath.mixToMono([[0.1, -0.2, 0.3]]), [0.1, -0.2, 0.3])
    }

    func testMixToMonoAveragesChannels() {
        // L and R average per frame: (1+0)/2, (-1+1)/2, (0.5+0.5)/2.
        XCTAssertEqual(AudioMath.mixToMono([[1, -1, 0.5], [0, 1, 0.5]]), [0.5, 0, 0.5])
    }

    func testMixToMonoTruncatesToShortestChannel() {
        XCTAssertEqual(AudioMath.mixToMono([[1, 1, 1], [0, 0]]), [0.5, 0.5])
    }

    func testSecondsFramesRoundTrip() {
        XCTAssertEqual(AudioMath.secondsToFrames(1.0, sampleRate: 44_100), 44_100)
        XCTAssertEqual(AudioMath.framesToSeconds(44_100, sampleRate: 44_100), 1.0, accuracy: 1e-9)
    }

    func testFramesToSecondsGuardsZeroSampleRate() {
        XCTAssertEqual(AudioMath.framesToSeconds(100, sampleRate: 0), 0)
    }

    // MARK: loopSegment

    func testLoopSegmentBasic() {
        // 1s–3s at 44.1k → start 44100, count 2*44100.
        let seg = AudioMath.loopSegment(start: 1, end: 3, sampleRate: 44_100, totalFrames: 441_000)
        XCTAssertEqual(seg.startFrame, 44_100)
        XCTAssertEqual(seg.frameCount, 88_200)
    }

    func testLoopSegmentOrdersReversedBounds() {
        let seg = AudioMath.loopSegment(start: 3, end: 1, sampleRate: 44_100, totalFrames: 441_000)
        XCTAssertEqual(seg.startFrame, 44_100)
        XCTAssertEqual(seg.frameCount, 88_200)
    }

    func testLoopSegmentClampsPastEnd() {
        // end beyond the file (10s) clamps to totalFrames.
        let seg = AudioMath.loopSegment(start: 4, end: 10, sampleRate: 44_100, totalFrames: 220_500) // 5s file
        XCTAssertEqual(seg.startFrame, 176_400)            // 4s
        XCTAssertEqual(seg.frameCount, 220_500 - 176_400)  // 4s → 5s
    }

    func testLoopSegmentClampsNegativeStart() {
        let seg = AudioMath.loopSegment(start: -2, end: 1, sampleRate: 44_100, totalFrames: 441_000)
        XCTAssertEqual(seg.startFrame, 0)
        XCTAssertEqual(seg.frameCount, 44_100)
    }

    func testLoopSegmentGuardsEmptyFile() {
        XCTAssertEqual(AudioMath.loopSegment(start: 0, end: 1, sampleRate: 44_100, totalFrames: 0).frameCount, 0)
        XCTAssertEqual(AudioMath.loopSegment(start: 0, end: 1, sampleRate: 0, totalFrames: 100).frameCount, 0)
    }

    // MARK: loopedPlayhead

    func testLoopedPlayheadAtStartOfLoop() {
        // No time elapsed → sit at the loop start.
        XCTAssertEqual(AudioMath.loopedPlayhead(elapsed: 0, loopStart: 1, loopLength: 2), 1, accuracy: 1e-9)
    }

    func testLoopedPlayheadMidLoop() {
        // 1.5s into a 2s loop starting at 1s → 2.5s.
        XCTAssertEqual(AudioMath.loopedPlayhead(elapsed: 1.5, loopStart: 1, loopLength: 2), 2.5, accuracy: 1e-9)
    }

    func testLoopedPlayheadWrapsAtBoundary() {
        // Exactly one loop length elapsed wraps back to the start.
        XCTAssertEqual(AudioMath.loopedPlayhead(elapsed: 2, loopStart: 1, loopLength: 2), 1, accuracy: 1e-9)
    }

    func testLoopedPlayheadWrapsMultipleTimes() {
        // 1.5 loops in (3s of a 2s loop) → halfway through the loop again.
        XCTAssertEqual(AudioMath.loopedPlayhead(elapsed: 3, loopStart: 1, loopLength: 2), 2, accuracy: 1e-9)
    }

    func testLoopedPlayheadGuardsZeroLength() {
        XCTAssertEqual(AudioMath.loopedPlayhead(elapsed: 5, loopStart: 1.25, loopLength: 0), 1.25, accuracy: 1e-9)
    }

    // MARK: crossfadeGains

    func testCrossfadeGainsStartIsAllTail() {
        // At the seam start the head is silent and the tail is full.
        let gains = AudioMath.crossfadeGains(position: 0, length: 100)
        XCTAssertEqual(gains.fadeIn, 0, accuracy: 1e-6)
        XCTAssertEqual(gains.fadeOut, 1, accuracy: 1e-6)
    }

    func testCrossfadeGainsEndIsAllHead() {
        let gains = AudioMath.crossfadeGains(position: 100, length: 100)
        XCTAssertEqual(gains.fadeIn, 1, accuracy: 1e-6)
        XCTAssertEqual(gains.fadeOut, 0, accuracy: 1e-6)
    }

    func testCrossfadeGainsMidpointIsEqualPower() {
        let gains = AudioMath.crossfadeGains(position: 50, length: 100)
        XCTAssertEqual(gains.fadeIn, Float(2).squareRoot() / 2, accuracy: 1e-6)   // ≈0.707
        XCTAssertEqual(gains.fadeOut, Float(2).squareRoot() / 2, accuracy: 1e-6)
    }

    func testCrossfadeGainsAreConstantPower() {
        // fadeIn² + fadeOut² == 1 everywhere (no level dip across the fade).
        for position in stride(from: 0, through: 100, by: 10) {
            let gains = AudioMath.crossfadeGains(position: position, length: 100)
            XCTAssertEqual(gains.fadeIn * gains.fadeIn + gains.fadeOut * gains.fadeOut, 1, accuracy: 1e-5)
        }
    }

    func testCrossfadeGainsGuardsZeroLength() {
        let gains = AudioMath.crossfadeGains(position: 5, length: 0)
        XCTAssertEqual(gains.fadeIn, 1, accuracy: 1e-6)
        XCTAssertEqual(gains.fadeOut, 0, accuracy: 1e-6)
    }
}
