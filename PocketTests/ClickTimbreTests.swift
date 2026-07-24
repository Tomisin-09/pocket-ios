import XCTest
@testable import Pocket

/// Pure metronome-timbre synthesis (ADR 0114). The PCM sample generation is UI-free math, so its
/// frame counts, amplitude bounds, and — crucially — the guarantee that the default `.click` stays
/// byte-for-byte what shipped before timbres existed are pinned here (AGENTS.md: pure logic gets tests).
final class ClickTimbreTests: XCTestCase {

    private let sampleRate = 44_100.0

    // MARK: catalog

    func testCatalogStableAndLabelled() {
        XCTAssertEqual(ClickTimbre.default, .click)
        XCTAssertEqual(ClickTimbre.allCases.count, 4)
        // Raw values are the persisted keys — a rename would silently reset users' choices.
        XCTAssertEqual(ClickTimbre.allCases.map(\.rawValue), ["click", "woodBlock", "rim", "beep"])
        for timbre in ClickTimbre.allCases {
            XCTAssertFalse(timbre.displayName.isEmpty, "\(timbre) display name")
            XCTAssertFalse(timbre.blurb.isEmpty, "\(timbre) blurb")
            XCTAssertEqual(timbre.id, timbre.rawValue)
        }
    }

    // MARK: sample geometry & bounds

    func testEveryVoiceProducesBoundedAudibleSamples() {
        for timbre in ClickTimbre.allCases {
            for level in ClickLevel.allCases {
                let samples = timbre.samples(for: level, sampleRate: sampleRate)
                XCTAssertFalse(samples.isEmpty, "\(timbre)/\(level) produced no samples")
                let peak = samples.map(abs).max() ?? 0
                XCTAssertGreaterThan(peak, 0, "\(timbre)/\(level) is silent")
                // Convex tone/noise blend under a ≤1 envelope × amplitude ⇒ never clips.
                XCTAssertLessThanOrEqual(peak, 1.0, "\(timbre)/\(level) clips at \(peak)")
            }
        }
    }

    func testFrameCountMatchesDurationTimesSampleRate() {
        // `.click` accent is a 25 ms burst → truncated 44_100 · 0.025 = 1102 frames.
        XCTAssertEqual(ClickTimbre.click.samples(for: .accent, sampleRate: sampleRate).count, 1102)
        // The subdivision tick is quieter but the same 25 ms geometry for `.click`.
        XCTAssertEqual(ClickTimbre.click.samples(for: .subdivision, sampleRate: sampleRate).count, 1102)
    }

    // MARK: default sound is unchanged (regression guard)

    /// `.click` must reproduce the exact pre-timbre `makeClick` formula: a sine burst with an
    /// `exp(-90·t)` decay at the level's frequency/amplitude. If this drifts, every existing user's
    /// metronome silently changes character — hence the tight tolerance.
    func testDefaultClickMatchesLegacyFormula() {
        assertLegacyClick(level: .accent, frequency: 1_200, amplitude: 0.6)
        assertLegacyClick(level: .beat, frequency: 900, amplitude: 0.6)
        assertLegacyClick(level: .subdivision, frequency: 700, amplitude: 0.28)
    }

    private func assertLegacyClick(level: ClickLevel, frequency: Double, amplitude: Double,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let samples = ClickTimbre.click.samples(for: level, sampleRate: sampleRate)
        for frame in stride(from: 0, to: samples.count, by: 137) {   // sample across the burst
            let time = Double(frame) / sampleRate
            let expected = Float(sin(2 * .pi * frequency * time) * exp(-90.0 * time) * amplitude)
            XCTAssertEqual(samples[frame], expected, accuracy: 1e-6, file: file, line: line)
        }
    }

    // MARK: determinism (noisy voices)

    func testNoisyVoiceIsDeterministic() {
        // The rim voice blends in noise; a deterministic source means two renders are identical,
        // so the sound is stable and the tests above are reproducible.
        let first = ClickTimbre.rim.samples(for: .accent, sampleRate: sampleRate)
        let second = ClickTimbre.rim.samples(for: .accent, sampleRate: sampleRate)
        XCTAssertEqual(first, second)
    }

    // MARK: settings resolution

    func testResolvedClickTimbreFallsBackToDefault() {
        XCTAssertEqual(AppSettings.resolvedClickTimbre(storedValue: nil), .click)
        XCTAssertEqual(AppSettings.resolvedClickTimbre(storedValue: "nonsense"), .click)
        XCTAssertEqual(AppSettings.resolvedClickTimbre(storedValue: "woodBlock"), .woodBlock)
        XCTAssertEqual(AppSettings.resolvedClickTimbre(storedValue: "beep"), .beep)
    }
}
