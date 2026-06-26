import XCTest
@testable import Pocket

/// Pure time-signature accent logic (ADR 0043, slice 3). The accent pattern is what gives
/// each meter its feel, so the boundaries and the modulo-mapping are pinned (AGENTS.md).
final class TimeSignatureTests: XCTestCase {

    private func signature(_ name: String,
                           file: StaticString = #filePath, line: UInt = #line) -> TimeSignature {
        guard let match = TimeSignature.presets.first(where: { $0.name == name }) else {
            XCTFail("missing preset \(name)", file: file, line: line)
            return .standard
        }
        return match
    }

    // MARK: presets

    func testStandardIsFourFour() {
        XCTAssertEqual(TimeSignature.standard.name, "4/4")
        XCTAssertEqual(TimeSignature.standard.beats, 4)
    }

    func testExpectedMetersArePresent() {
        let names = TimeSignature.presets.map(\.name)
        XCTAssertEqual(names, ["4/4", "3/4", "2/4", "6/8", "12/8", "5/4", "7/8"])
    }

    func testEveryPresetAccentsTheDownbeatAndStaysInRange() {
        for preset in TimeSignature.presets {
            XCTAssertTrue(preset.accentBeats.contains(0), "\(preset.name) must accent the downbeat")
            XCTAssertTrue(preset.accentBeats.allSatisfy { (0..<preset.beats).contains($0) },
                          "\(preset.name) accents must be in 0..<beats")
        }
    }

    // MARK: accent pattern

    func testSimpleMeterAccentsOnlyTheDownbeat() {
        let fourFour = signature("4/4")
        XCTAssertEqual((0..<4).map { fourFour.isAccented(beatInBar: $0) },
                       [true, false, false, false])
    }

    func testCompoundMeterAccentsTheSecondaryPulse() {
        // 6/8 felt in 2 → strong clicks on 1 and 4.
        let sixEight = signature("6/8")
        XCTAssertEqual((0..<6).map { sixEight.isAccented(beatInBar: $0) },
                       [true, false, false, true, false, false])
    }

    func testSlowBluesAccentsFourPulses() {
        // 12/8 felt in 4 → accents on 1, 4, 7, 10.
        let twelveEight = signature("12/8")
        XCTAssertEqual(twelveEight.accentBeats, [0, 3, 6, 9])
        XCTAssertTrue(twelveEight.isAccented(beatInBar: 6))
        XCTAssertFalse(twelveEight.isAccented(beatInBar: 5))
    }

    // MARK: forStored (slice 6 round-trip)

    func testForStoredReturnsTheMatchingPreset() {
        let restored = TimeSignature.forStored(beats: 6, noteValue: 8, accentBeats: [0, 3])
        XCTAssertEqual(restored, signature("6/8"))   // full preset (name + context) comes back
        XCTAssertEqual(restored.context, "Jig · ballad (in 2)")
    }

    func testForStoredFallsBackToConstructedSignature() {
        // A meter that isn't a preset reconstructs from the stored fields.
        let restored = TimeSignature.forStored(beats: 9, noteValue: 8, accentBeats: [0, 3, 6])
        XCTAssertEqual(restored.beats, 9)
        XCTAssertEqual(restored.name, "9/8")
        XCTAssertEqual(restored.accentBeats, [0, 3, 6])
        XCTAssertEqual(restored.context, "Custom")
    }

    func testRunningBeatCounterMapsThroughModulo() {
        // A free-running beat index wraps into the bar: in 4/4, index 8 is a downbeat.
        let fourFour = signature("4/4")
        XCTAssertTrue(fourFour.isAccented(beatInBar: 8))
        XCTAssertTrue(fourFour.isAccented(beatInBar: 12))
        XCTAssertFalse(fourFour.isAccented(beatInBar: 9))
    }
}
