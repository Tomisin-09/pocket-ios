import XCTest
@testable import Pocket

/// The **neck-spanning scale layouts** (ADR 0083 S4/S6/S10): verifies the `.extended` diagonal and
/// `.threePerString` generators produce correct, in-scale, strictly-ascending runs that stay on a real
/// neck — and that slides are emitted **only** where the hand walks up one string (S2). The property
/// net that lets these shapes be *generated* rather than hand-drawn. All pure, SwiftUI-free (T5).
final class ScaleLayoutTests: XCTestCase {

    private let openMidi = [64, 59, 55, 50, 45, 40]   // 0 = high e … 5 = low E
    private func midi(_ note: FretNote) -> Int { openMidi[note.string] + note.fret }

    /// Every root, so the generators are proven key-independent.
    private let everyRoot = Array(0..<12)

    // MARK: - Layout availability (musically-honest gating)

    func testLayoutAvailabilityMatchesScaleFamily() {
        for scale in [GuitarScale.minorPentatonic, .majorPentatonic] {
            XCTAssertEqual(scale.supportedLayouts, [.box, .extended], "\(scale) offers the diagonal")
        }
        // The modes join the major and natural minor as 7-tone diatonic scales that take 3-NPS.
        for scale in [GuitarScale.major, .naturalMinor, .dorian, .phrygian, .lydian, .mixolydian, .locrian] {
            XCTAssertEqual(scale.supportedLayouts, [.box, .threePerString], "\(scale) is diatonic")
        }
        // The blues and bebop scales carry a chromatic passing tone the neck-spanning generators don't
        // model — box only.
        for scale in [GuitarScale.blues, .bebopMajor, .bebopDominant] {
            XCTAssertEqual(scale.supportedLayouts, [.box], "\(scale) is box-only")
        }
    }

    func testUnsupportedLayoutCoercesToBox() {
        // A pentatonic asked for 3-NPS, or a diatonic asked for extended, falls back to the box.
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, layout: .threePerString).layout,
                       .box)
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 9, layout: .extended).layout, .box)
    }

    func testOnlyBoxUsesOctaves() {
        XCTAssertTrue(ScaleLayout.box.usesOctaves)
        XCTAssertFalse(ScaleLayout.extended.usesOctaves)
        XCTAssertFalse(ScaleLayout.threePerString.usesOctaves)
    }

    // MARK: - Shared invariants (in-scale, ascending, on the neck) — every layout, root, position

    func testNeckLayoutsAreInScaleAscendingAndOnTheNeck() {
        for scale in GuitarScale.allCases {
            for layout in scale.supportedLayouts where layout != .box {
                for root in everyRoot {
                    for position in 1...ScaleRun.positionCount(for: layout, scale: scale) {
                        let run = ScaleRun(scale: scale, rootPitchClass: root,
                                           position: position, layout: layout, version: 1)
                        let notes = run.ascendingNotes
                        let context = "\(scale) \(layout) root \(root) pos \(position)"
                        XCTAssertFalse(notes.isEmpty, "\(context) produced no notes")

                        let allowed = scale.pitchClasses(root: root)
                        var previous = Int.min
                        for note in notes {
                            XCTAssertTrue(allowed.contains(GuitarScale.pitchClass(string: note.string,
                                                                                 fret: note.fret)),
                                          "\(context): \(note) not in scale")
                            XCTAssertGreaterThan(midi(note), previous, "\(context) must ascend strictly")
                            XCTAssertGreaterThanOrEqual(note.fret, 0, "\(context) fell behind the nut")
                            XCTAssertLessThanOrEqual(note.fret, ScaleNeckLayout.maxFret,
                                                     "\(context) ran off the neck")
                            previous = midi(note)
                        }
                    }
                }
            }
        }
    }

    /// S2: a slide may articulate **only** a same-string step up. No slide may sit on a string cross,
    /// and every same-string seam that carries a slide really does climb the string.
    func testSlidesOnlyArticulateSameStringSteps() {
        for scale in [GuitarScale.minorPentatonic, .majorPentatonic] {
            for root in everyRoot {
                for position in 1...ScaleRun.positionCount(for: .extended, scale: scale) {
                    let notes = ScaleRun(scale: scale, rootPitchClass: root,
                                         position: position, layout: .extended).ascendingNotes
                    for (index, note) in notes.enumerated() where note.technique == .slide {
                        XCTAssertGreaterThan(index, 0, "a run can't open on a slide")
                        let previous = notes[index - 1]
                        XCTAssertEqual(note.string, previous.string,
                                       "\(scale) root \(root): a slide must stay on one string")
                        XCTAssertGreaterThan(note.fret, previous.fret,
                                             "\(scale) root \(root): a slide must climb the string")
                    }
                    XCTAssertEqual(notes.filter { $0.technique == .slide }.count, 2,
                                   "\(scale) root \(root): the extended diagonal slides once per seam string")
                }
            }
        }
    }

    /// 3-NPS crosses to a new string every three notes — no note is ever a slide, and each string
    /// carries exactly three tones.
    func testThreePerStringCrossesStringsWithNoSlides() {
        for scale in [GuitarScale.major, .naturalMinor, .dorian, .phrygian, .lydian, .mixolydian, .locrian] {
            for root in everyRoot {
                for position in 1...scale.positionCount {
                    let notes = ScaleRun(scale: scale, rootPitchClass: root,
                                         position: position, layout: .threePerString).ascendingNotes
                    XCTAssertEqual(notes.count, 18, "\(scale) root \(root): three tones on each of six strings")
                    XCTAssertFalse(notes.contains { $0.technique == .slide },
                                   "\(scale) root \(root): 3-NPS never slides")
                    for string in 0...5 {
                        XCTAssertEqual(notes.filter { $0.string == string }.count, 3,
                                       "\(scale) root \(root): string \(string) should carry three tones")
                    }
                }
            }
        }
    }

    // MARK: - Reference shape locks (the player's two confirmed diagrams — regression)

    /// The flagship A-minor extended (shape 1, A-G slide): a diagonal climbing frets 3→10, sliding up a
    /// **whole step** on the A string (4) and G string (2) to stitch three boxes into one run.
    func testAMinorExtendedPentatonicIsTheReferenceDiagonal() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 1, layout: .extended)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 3), FretNote(string: 5, fret: 5),
            FretNote(string: 4, fret: 3), FretNote(string: 4, fret: 5),
            FretNote(string: 4, fret: 7, technique: .slide),
            FretNote(string: 3, fret: 5), FretNote(string: 3, fret: 7),
            FretNote(string: 2, fret: 5), FretNote(string: 2, fret: 7),
            FretNote(string: 2, fret: 9, technique: .slide),
            FretNote(string: 1, fret: 8), FretNote(string: 1, fret: 10),
            FretNote(string: 0, fret: 8), FretNote(string: 0, fret: 10)
        ])
    }

    /// **Shape 1** (A-G slide) of A **major** pentatonic — the well-known diagram (Image 1): frets 12→19,
    /// slides on the A and G strings. Locks the player's confirmed reference exactly.
    func testAMajorExtendedShapeOneMatchesTheWellKnownDiagram() {
        let run = ScaleRun(scale: .majorPentatonic, rootPitchClass: 9, position: 1, layout: .extended)
        XCTAssertEqual(run.extendedShape, .agSlide)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 12), FretNote(string: 5, fret: 14),
            FretNote(string: 4, fret: 12), FretNote(string: 4, fret: 14),
            FretNote(string: 4, fret: 16, technique: .slide),
            FretNote(string: 3, fret: 14), FretNote(string: 3, fret: 16),
            FretNote(string: 2, fret: 14), FretNote(string: 2, fret: 16),
            FretNote(string: 2, fret: 18, technique: .slide),
            FretNote(string: 1, fret: 17), FretNote(string: 1, fret: 19),
            FretNote(string: 0, fret: 17), FretNote(string: 0, fret: 19)
        ])
    }

    /// **Shape 2** (D-B slide) of A **major** pentatonic — the *corrected* diagram (Image 2): the slides
    /// move onto the D and B strings, which the old always-A-G rule got wrong. Locks the confirmed fix.
    func testAMajorExtendedShapeTwoMatchesTheCorrectedDiagram() {
        let run = ScaleRun(scale: .majorPentatonic, rootPitchClass: 9, position: 2, layout: .extended)
        XCTAssertEqual(run.extendedShape, .dbSlide)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 7), FretNote(string: 5, fret: 9),
            FretNote(string: 4, fret: 7), FretNote(string: 4, fret: 9),
            FretNote(string: 3, fret: 7), FretNote(string: 3, fret: 9),
            FretNote(string: 3, fret: 11, technique: .slide),
            FretNote(string: 2, fret: 9), FretNote(string: 2, fret: 11),
            FretNote(string: 1, fret: 10), FretNote(string: 1, fret: 12),
            FretNote(string: 1, fret: 14, technique: .slide),
            FretNote(string: 0, fret: 12), FretNote(string: 0, fret: 14)
        ])
    }

    // MARK: - Two shapes only, selected by position (ADR 0083 refinement)

    func testExtendedOffersExactlyTwoShapesAndClampsThePosition() {
        for scale in [GuitarScale.minorPentatonic, .majorPentatonic] {
            XCTAssertEqual(ScaleRun.positionCount(for: .extended, scale: scale), 2)
            // A run carried over from a five-position box layout is capped at the two shapes.
            let clamped = ScaleRun(scale: scale, rootPitchClass: 0, position: 5, layout: .extended)
            XCTAssertEqual(clamped.position, 2)
            XCTAssertEqual(clamped.extendedShape, .dbSlide)
            XCTAssertEqual(ScaleRun(scale: scale, rootPitchClass: 0, position: 1, layout: .extended)
                            .extendedShape, .agSlide)
        }
    }

    /// Both seam slides are clean whole-steps in every key and shape — the tell that these are the two
    /// canonical fingerings (a wrong anchor would produce an awkward three-fret slide).
    func testEverySeamSlideIsAWholeStep() {
        for scale in [GuitarScale.minorPentatonic, .majorPentatonic] {
            for root in everyRoot {
                for position in 1...2 {
                    let notes = ScaleRun(scale: scale, rootPitchClass: root,
                                         position: position, layout: .extended).ascendingNotes
                    for (index, note) in notes.enumerated() where note.technique == .slide {
                        XCTAssertEqual(note.fret - notes[index - 1].fret, 2,
                                       "\(scale) root \(root) shape \(position): seam slide is a whole-step")
                    }
                }
            }
        }
    }

    func testPositionLabelReadsAsARootAnchorNotACAGEDLetter() {
        // Box: the root anchor is the primary label (ADR 0091) — the famous fret-5 box reads by where
        // the hand goes, not "E shape"; the CAGED letter is demoted to a caption elsewhere.
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 5).positionLabel,
                       "root on low E · fret 5")
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 1).positionLabel,
                       "root on D · fret 7")
        // Extended: the two fingerings carry their own mnemonic.
        XCTAssertEqual(ScaleRun(scale: .majorPentatonic, rootPitchClass: 9, position: 1,
                                layout: .extended).positionLabel, "A shape")
        XCTAssertEqual(ScaleRun(scale: .majorPentatonic, rootPitchClass: 9, position: 2,
                                layout: .extended).positionLabel, "D shape")
        // 3-NPS isn't a CAGED box, so it reads as a pattern number.
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 9, position: 3,
                                layout: .threePerString).positionLabel, "Pattern 3")
    }

    // MARK: - Box focus groups (S2b) carried through expansion

    func testExtendedCarriesThreeBoxGroupsMirroredAcrossTheRoundTrip() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 1,
                           roundTrip: true, layout: .extended)
        let (notes, groups) = run.sequenceWithGroups
        XCTAssertEqual(groups?.count, notes.count, "groups stay index-aligned with notes")
        XCTAssertEqual(Set(groups ?? []), [0, 1, 2], "the diagonal spans three boxes")
        XCTAssertNotNil(run.expanded().noteGroups, "an extended run expands with box groups for focus")
    }

    func testBoxAndThreePerStringCarryNoGroups() {
        XCTAssertNil(ScaleRun.aMinorPentatonic.sequenceWithGroups.groups)
        XCTAssertNil(ScaleRun.aMinorPentatonic.expanded().noteGroups)
        let threeNps = ScaleRun(scale: .major, rootPitchClass: 9, layout: .threePerString)
        XCTAssertNil(threeNps.sequenceWithGroups.groups)
    }

    // MARK: - Round trip carries the layout notes

    func testRoundTripMirrorsAnExtendedRunWithoutDoublingPeakOrSeam() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 1,
                           roundTrip: true, layout: .extended)
        let ascentCount = run.ascendingNotes.count
        XCTAssertEqual(run.sequence.count, 2 * ascentCount - 2)
        for pair in zip(run.sequence, run.sequence.dropFirst()) {
            XCTAssertNotEqual(pair.0, pair.1, "no note should repeat back-to-back")
        }
    }

    // MARK: - Codable: additive, decode-time default (T4 — no store migration)

    func testLayoutRoundTripsThroughCodable() throws {
        let original = ScaleRun(scale: .major, rootPitchClass: 2, position: 3,
                                roundTrip: false, notesPerBeat: 3, layout: .threePerString)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ScaleRun.self, from: data), original)
    }

    /// A blob written before the layout axis existed (no `layoutRaw`) decodes to the box layout and
    /// generates exactly as it used to — the whole point of the additive, decode-time-defaulted field.
    func testBlobMissingLayoutDecodesToBox() throws {
        let legacy = """
        {"version":1,"scaleRaw":"minorPentatonic","rootPitchClass":9,"position":1,\
        "octaves":2,"roundTrip":true,"notesPerBeat":2}
        """
        let run = try JSONDecoder().decode(ScaleRun.self, from: Data(legacy.utf8))
        XCTAssertEqual(run.layout, .box)
        // The blob pins position 1, so compare against an explicit position-1 box (the default seed now
        // opens on the flagship position 5 — ADR 0091 — so it's no longer the right yardstick here).
        XCTAssertEqual(run.ascendingNotes,
                       ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 1, octaves: 2)
                           .ascendingNotes)
    }
}
