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
        XCTAssertEqual(ExerciseTemplate.chords.renderer, .chords)
        XCTAssertEqual(ExerciseTemplate.strumChords.renderer, .strumChords)

        let fretboardFamily: Set<ExerciseTemplate> =
            [.scales, .arpeggios, .picking, .legato, .fingerstyle, .warmup]
        for template in fretboardFamily {
            XCTAssertEqual(template.renderer, .fretboard, "\(template) should render on the fretboard")
        }

        let bespoke: Set<ExerciseTemplate> = fretboardFamily.union([.strumming, .chords, .strumChords])
        for template in ExerciseTemplate.allCases where !bespoke.contains(template) {
            XCTAssertEqual(template.renderer, .metronome, "\(template) should render on the metronome")
        }
    }

    func testBespokeEditorAndDefaultsAreTemplateSpecific() {
        // Editors are template-specific even though several share the fretboard renderer: Strumming
        // edits a StrumPattern (folk); the warm-up families declare a FretboardRun (generated
        // chromatic warm-up); Scales picks a ScaleRun from the library (A minor pentatonic default);
        // metronome-underlay templates have no editor.
        XCTAssertEqual(ExerciseTemplate.strumming.bespokeEditor, .strumming)
        XCTAssertEqual(ExerciseTemplate.strumming.defaultStrumPattern, .folk)
        XCTAssertNil(ExerciseTemplate.strumming.defaultFretboardContent)

        let runFamily: Set<ExerciseTemplate> = [.warmup, .picking, .legato, .fingerstyle]
        for template in runFamily {
            XCTAssertEqual(template.bespokeEditor, .run, "\(template) declares a run")
            XCTAssertEqual(template.defaultFretboardContent, .run(.chromaticWarmup))
            XCTAssertNil(template.defaultStrumPattern, "\(template) should ship no strum pattern")
        }

        XCTAssertEqual(ExerciseTemplate.scales.bespokeEditor, .scale)
        XCTAssertEqual(ExerciseTemplate.scales.defaultFretboardContent, .scale(.aMinorPentatonic))

        XCTAssertEqual(ExerciseTemplate.arpeggios.bespokeEditor, .arpeggio)
        XCTAssertEqual(ExerciseTemplate.arpeggios.defaultFretboardContent, .arpeggio(.aMinorSeventh))

        XCTAssertEqual(ExerciseTemplate.chords.bespokeEditor, .chords)
        // A new Chords exercise now starts empty — the editor opens on just "Add chord" (2026-07-13).
        XCTAssertEqual(ExerciseTemplate.chords.defaultChordProgression, .empty)
        XCTAssertEqual(ExerciseTemplate.chords.defaultChordProgression?.changeCount, 0)
        XCTAssertNil(ExerciseTemplate.chords.defaultFretboardContent, "chords isn't fretboard content")

        XCTAssertEqual(ExerciseTemplate.strumChords.bespokeEditor, .strumChords)
        // A new Strum & Chords exercise now starts empty too — a rest-only groove over no chords (ADR 0086).
        XCTAssertEqual(ExerciseTemplate.strumChords.defaultStrumChordSheet, .empty)
        XCTAssertEqual(ExerciseTemplate.strumChords.defaultStrumChordSheet?.chordProgression.changeCount, 0)
        XCTAssertEqual(ExerciseTemplate.strumChords.defaultStrumChordSheet?.strumPattern.slots.allSatisfy {
            $0.direction == .rest
        }, true)
        XCTAssertNil(ExerciseTemplate.strumChords.defaultStrumPattern, "sheet isn't a bare strum pattern")
        XCTAssertNil(ExerciseTemplate.strumChords.defaultChordProgression, "sheet isn't a bare progression")
        XCTAssertNil(ExerciseTemplate.strumChords.defaultFretboardContent)

        // Freeform's editor is a **text field** (ADR 0136 F2a) — the first template whose payload is
        // prose rather than musical structure, which is why it has a bespoke editor and yet none of
        // the musical defaults below.
        XCTAssertEqual(ExerciseTemplate.freeform.bespokeEditor, .freeform)
        XCTAssertNil(ExerciseTemplate.freeform.defaultFretboardContent)
        XCTAssertNil(ExerciseTemplate.freeform.defaultChordProgression)
        XCTAssertNil(ExerciseTemplate.freeform.defaultStrumChordSheet)
        XCTAssertNil(ExerciseTemplate.freeform.defaultStrumPattern)

        let editing = runFamily.union([.strumming, .scales, .arpeggios, .chords, .strumChords,
                                       .freeform])
        for template in ExerciseTemplate.allCases where !editing.contains(template) {
            XCTAssertNil(template.bespokeEditor, "\(template) should have no bespoke editor")
            XCTAssertFalse(template.hasBespokeEditor)
            XCTAssertNil(template.defaultStrumPattern)
            XCTAssertNil(template.defaultFretboardContent)
            XCTAssertNil(template.defaultChordProgression)
            XCTAssertNil(template.defaultStrumChordSheet)
        }
    }

    func testCreatablePickerOrderAndRetiredTemplates() {
        // The create picker (ADR 0087): Basic first, then Warm-up, in the agreed order — and it no
        // longer offers the retired Fingerstyle / Rhythm templates, nor the ex-"Coming Soon" Ear
        // Training / Theory rows (removed 2026-07-22; ear training shipped as a loop mode, ADR 0104).
        // **Freeform is last** (ADR 0136): it is the answer to "my practice isn't in this list", so
        // it reads best after the list it is the escape from, and putting it earlier would invite it
        // to become the default for drills that deserve a real surface.
        XCTAssertEqual(ExerciseTemplate.creatable,
                       [.basic, .warmup, .strumming, .picking, .scales, .chords, .strumChords,
                        .arpeggios, .legato, .freeform])
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.fingerstyle))
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.rhythm))
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.earTraining))
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.theory))
    }

    func testDisplayOrderCoversEveryTemplateForGrouping() {
        // Grouping order stays complete — every case, including the retired ones — so drills already
        // made under Fingerstyle / Rhythm still bucket under their section.
        XCTAssertEqual(Set(ExerciseTemplate.displayOrder), Set(ExerciseTemplate.allCases))
        XCTAssertEqual(ExerciseTemplate.displayOrder.count, ExerciseTemplate.allCases.count)
        XCTAssertEqual(ExerciseTemplate.displayOrder.first, .basic)
        // The picker list is a subset of the grouping order, same relative order.
        XCTAssertEqual(ExerciseTemplate.creatable,
                       ExerciseTemplate.displayOrder.filter(ExerciseTemplate.creatable.contains))
    }

    func testEarTrainingAndTheoryAreNotCreatable() {
        // Their "Coming Soon" rows were removed 2026-07-22 (ear training shipped as a loop mode,
        // ADR 0104) — the create picker no longer offers them, though the enum cases live on for
        // the planner's SkillFamilyMap.
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.earTraining))
        XCTAssertFalse(ExerciseTemplate.creatable.contains(.theory))
        XCTAssertEqual(ExerciseTemplate.strumChords.displayName, "Chords & Strum")
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
