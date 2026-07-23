import XCTest
@testable import Pocket

/// The curated built-in strum grooves surfaced in the editor's preset menu (device feedback
/// 2026-07-23). Kept in its own file so `StrumPatternTests` stays under the body-length limit.
final class StrumPatternPresetsTests: XCTestCase {
    func testPresetsAreNonEmptyWithUniqueNames() {
        XCTAssertFalse(StrumPattern.presets.isEmpty)
        let names = StrumPattern.presets.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "preset names must be unique for the menu")
    }

    func testEveryPresetIsAPlayableBar() {
        for preset in StrumPattern.presets {
            XCTAssertGreaterThanOrEqual(preset.pattern.slotsPerBeat, 1, "\(preset.name)")
            XCTAssertFalse(preset.pattern.slots.isEmpty, "\(preset.name) has no slots")
            XCTAssertFalse(preset.pattern.slots.allSatisfy { $0.direction == .rest },
                           "\(preset.name) is all rests — not a useful preset")
        }
    }

    func testPresetResizesToAThreeBeatMeterWithoutCrashing() {
        // The editor drops a 4-beat preset into whatever meter the exercise uses.
        let folk = StrumPattern.folk
        let inThree = folk.resized(slotsPerBeat: folk.slotsPerBeat, beatsPerBar: 3)
        XCTAssertEqual(inThree.slots.count, folk.slotsPerBeat * 3)
    }
}
