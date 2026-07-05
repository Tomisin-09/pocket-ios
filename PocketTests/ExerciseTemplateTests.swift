import XCTest
@testable import Pocket

/// The **exercise template** axis (ADR 0068, revised): a closed curated set, each mapping to a
/// runtime renderer, chosen at creation and immutable after. Pure, so it's tested without SwiftUI.
final class ExerciseTemplateTests: XCTestCase {

    func testUnknownRawDecodesToBasic() {
        // Forward compatibility: an older build opening a newer template runs it as a plain drill.
        XCTAssertEqual(ExerciseTemplate(storage: "hologram"), .basic)
        XCTAssertEqual(ExerciseTemplate(storage: ""), .basic)
    }

    func testKnownRawDecodesToItsCase() {
        XCTAssertEqual(ExerciseTemplate(storage: "strumming"), .strumming)
        XCTAssertEqual(ExerciseTemplate(storage: "scales"), .scales)
    }

    func testOnlyStrummingHasABespokeRendererToday() {
        // Strumming is the one bespoke surface; every other template falls to the metronome underlay.
        XCTAssertEqual(ExerciseTemplate.strumming.renderer, .strumming)
        for template in ExerciseTemplate.allCases where template != .strumming {
            XCTAssertEqual(template.renderer, .metronome, "\(template) should render on the metronome")
        }
    }

    func testOnlyStrummingHasABespokeEditorAndDefaultPattern() {
        XCTAssertTrue(ExerciseTemplate.strumming.hasBespokeEditor)
        XCTAssertEqual(ExerciseTemplate.strumming.defaultStrumPattern, .folk)
        for template in ExerciseTemplate.allCases where template != .strumming {
            XCTAssertFalse(template.hasBespokeEditor, "\(template) should have no bespoke editor")
            XCTAssertNil(template.defaultStrumPattern, "\(template) should ship no strum pattern")
        }
    }

    func testCreatableListsEveryTemplateWithBasicFirst() {
        // The create picker offers every template, Basic (the default catch-all) first.
        XCTAssertEqual(Set(ExerciseTemplate.creatable), Set(ExerciseTemplate.allCases))
        XCTAssertEqual(ExerciseTemplate.creatable.count, ExerciseTemplate.allCases.count)
        XCTAssertEqual(ExerciseTemplate.creatable.first, .basic)
        XCTAssertEqual(ExerciseTemplate.creatable.dropFirst().first, .strumming)
    }

    func testEveryTemplateHasNonEmptyDisplayNameBlurbAndIcon() {
        for template in ExerciseTemplate.allCases {
            XCTAssertFalse(template.displayName.isEmpty, "\(template) needs a display name")
            XCTAssertFalse(template.blurb.isEmpty, "\(template) needs a blurb")
            XCTAssertFalse(template.iconName.isEmpty, "\(template) needs an icon")
        }
    }

    func testRawValueRoundTripsForStorage() {
        for template in ExerciseTemplate.allCases {
            XCTAssertEqual(ExerciseTemplate(storage: template.rawValue), template)
        }
    }
}
