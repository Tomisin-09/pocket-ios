import XCTest
@testable import Pocket

/// Pure pitch detection (ADR 0115). The autocorrelation core is UI-free math, so its accuracy on
/// known tones, its octave-safety on harmonic-rich inputs, and its silence/noise rejection are pinned
/// here (AGENTS.md: pure logic gets tests — "the logic that breaks silently otherwise").
final class PitchDetectorTests: XCTestCase {

    private let sampleRate = 44_100.0
    private let detector = PitchDetector()

    // MARK: helpers

    /// A pure sine of `frequency` Hz, `count` samples long at `sampleRate`.
    private func sine(_ frequency: Double, count: Int = 4_096) -> [Float] {
        (0..<count).map { Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    /// Cents error between a detected frequency and the expected one.
    private func centsError(_ detected: Double, _ expected: Double) -> Double {
        1_200 * log2(detected / expected)
    }

    // MARK: accuracy

    func testDetectsGuitarOpenStringFrequencies() throws {
        // E2 A2 D3 G3 B3 E4 — standard tuning open strings.
        for frequency in [82.41, 110.0, 146.83, 196.0, 246.94, 329.63] {
            let detected = try XCTUnwrap(detector.detect(sine(frequency), sampleRate: sampleRate),
                                         "no pitch for \(frequency) Hz")
            XCTAssertLessThan(abs(centsError(detected, frequency)), 5,
                              "\(frequency) Hz detected as \(detected) Hz")
        }
    }

    func testDetectsLowBassString() throws {
        // Bass low E1 ≈ 41.2 Hz — the region FFT handles worst and autocorrelation handles best. Needs
        // a longer window (a couple of periods of a ~41 Hz tone) to correlate.
        let detected = try XCTUnwrap(detector.detect(sine(41.2, count: 8_192), sampleRate: sampleRate))
        XCTAssertLessThan(abs(centsError(detected, 41.2)), 5, "bass E1 detected as \(detected) Hz")
    }

    // MARK: octave safety

    func testHarmonicRichToneReturnsFundamentalNotAnOctave() throws {
        // A2 (110 Hz) with strong 2nd and 3rd harmonics — a naive autocorrelation would be tempted to
        // lock onto the octave (220 Hz). The first-strong-peak pick must return the fundamental.
        let fundamental = 110.0
        let buffer: [Float] = (0..<4_096).map { index in
            let time = Double(index) / sampleRate
            let value = 0.6 * sin(2 * .pi * fundamental * time)
                      + 0.3 * sin(2 * .pi * 2 * fundamental * time)
                      + 0.2 * sin(2 * .pi * 3 * fundamental * time)
            return Float(value)
        }
        let detected = try XCTUnwrap(detector.detect(buffer, sampleRate: sampleRate))
        XCTAssertLessThan(abs(centsError(detected, fundamental)), 8,
                          "harmonic tone detected as \(detected) Hz, expected ~\(fundamental)")
    }

    // MARK: rejection

    func testSilenceReturnsNil() {
        XCTAssertNil(detector.detect([Float](repeating: 0, count: 4_096), sampleRate: sampleRate))
    }

    func testBelowSilenceThresholdReturnsNil() {
        // A real tone but far too quiet to trust — should gate out, not chase.
        let whisper = sine(196.0).map { $0 * 0.001 }
        XCTAssertNil(detector.detect(whisper, sampleRate: sampleRate))
    }

    func testBroadbandNoiseReturnsNil() {
        // Deterministic white-ish noise (LCG) has no clear period → the clarity floor rejects it.
        var state: UInt64 = 0x1234_5678
        let noise: [Float] = (0..<4_096).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(state >> 11) * (1.0 / 9_007_199_254_740_992.0)   // [0,1)
            return Float(unit * 2 - 1)
        }
        XCTAssertNil(detector.detect(noise, sampleRate: sampleRate))
    }

    func testEmptyAndDegenerateBuffersReturnNil() {
        XCTAssertNil(detector.detect([], sampleRate: sampleRate))
        XCTAssertNil(detector.detect([0.5], sampleRate: sampleRate))
        XCTAssertNil(detector.detect(sine(196.0), sampleRate: 0))
    }

    // MARK: determinism

    func testDeterministic() {
        let buffer = sine(146.83)
        XCTAssertEqual(detector.detect(buffer, sampleRate: sampleRate),
                       detector.detect(buffer, sampleRate: sampleRate))
    }
}
