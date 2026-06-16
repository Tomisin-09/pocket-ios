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
}
