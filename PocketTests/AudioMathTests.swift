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
}
