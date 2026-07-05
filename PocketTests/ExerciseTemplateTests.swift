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

    func testTemplateRenderersMapToTheirSurfaces() {
        // Strumming has its arrow lane; the fretboard family shares the one animated board (build 2);
        // everything else still falls to the metronome underlay until its own renderer ships.
        XCTAssertEqual(ExerciseTemplate.strumming.renderer, .strumming)

        let fretboardFamily: Set<ExerciseTemplate> = [.scales, .picking, .legato, .fingerstyle, .warmup]
        for template in fretboardFamily {
            XCTAssertEqual(template.renderer, .fretboard, "\(template) should render on the fretboard")
        }

        for template in ExerciseTemplate.allCases
        where template != .strumming && !fretboardFamily.contains(template) {
            XCTAssertEqual(template.renderer, .metronome, "\(template) should render on the metronome")
        }
    }

    func testBespokeEditorAndDefaultsAreTemplateSpecific() {
        // Editors are template-specific even though several share the fretboard renderer: Strumming
        // edits a StrumPattern (folk); the warm-up families declare a FretboardRun (generated
        // chromatic warm-up); Scales still uses the custom grid (spider-walk custom drill) until its
        // scale-library editor ships; metronome-underlay templates have no editor.
        XCTAssertEqual(ExerciseTemplate.strumming.bespokeEditor, .strumming)
        XCTAssertEqual(ExerciseTemplate.strumming.defaultStrumPattern, .folk)
        XCTAssertNil(ExerciseTemplate.strumming.defaultFretboardContent)

        let runFamily: Set<ExerciseTemplate> = [.warmup, .picking, .legato, .fingerstyle]
        for template in runFamily {
            XCTAssertEqual(template.bespokeEditor, .run, "\(template) declares a run")
            XCTAssertEqual(template.defaultFretboardContent, .run(.chromaticWarmup))
            XCTAssertNil(template.defaultStrumPattern, "\(template) should ship no strum pattern")
        }

        XCTAssertEqual(ExerciseTemplate.scales.bespokeEditor, .fretboardGrid)
        XCTAssertEqual(ExerciseTemplate.scales.defaultFretboardContent, .custom(.spiderWalk))

        let editing = runFamily.union([.strumming, .scales])
        for template in ExerciseTemplate.allCases where !editing.contains(template) {
            XCTAssertNil(template.bespokeEditor, "\(template) should have no bespoke editor")
            XCTAssertFalse(template.hasBespokeEditor)
            XCTAssertNil(template.defaultStrumPattern)
            XCTAssertNil(template.defaultFretboardContent)
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
