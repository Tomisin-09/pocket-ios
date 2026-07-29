import XCTest
@testable import Pocket

/// The **key-first spelling policy** (ADR 0123). The rule under test: a tonal centre spells its own
/// notes; the user's accidental preference is a tiebreaker for the cases nothing else decides. All
/// pure — no Settings, no SwiftUI (M7); the preference arrives as a parameter.
final class NoteSpellingTests: XCTestCase {

    // MARK: - The two name tables

    func testNaturalsAreIdenticalInBothSpellings() {
        for pitchClass in [0, 2, 4, 5, 7, 9, 11] {
            XCTAssertEqual(NoteSpelling.sharps.name(pitchClass: pitchClass),
                           NoteSpelling.flats.name(pitchClass: pitchClass),
                           "a natural note has one spelling")
        }
    }

    func testAccidentalsUseTypographicGlyphs() {
        XCTAssertEqual(NoteSpelling.sharps.name(pitchClass: 1), "C♯")
        XCTAssertEqual(NoteSpelling.flats.name(pitchClass: 1), "D♭")
        XCTAssertEqual(NoteSpelling.sharps.name(pitchClass: 10), "A♯")
        XCTAssertEqual(NoteSpelling.flats.name(pitchClass: 10), "B♭")
        // Never the ASCII '#' the fretboard used to print — the app spells "♭3" already.
        for spelling in NoteSpelling.allCases {
            for pitchClass in 0..<12 {
                XCTAssertFalse(spelling.name(pitchClass: pitchClass).contains("#"),
                               "no ASCII sharp in \(spelling)")
            }
        }
    }

    func testNamesFoldOutOfRangePitchClasses() {
        // MIDI numbers reach these directly (`spelling.name(pitchClass: openMidi + fret)`).
        XCTAssertEqual(NoteSpelling.sharps.name(pitchClass: 64), "E")     // high e
        XCTAssertEqual(NoteSpelling.flats.name(pitchClass: -2), "B♭")
    }

    // MARK: - The circle of fifths

    func testFlatKeysSpellFlats() {
        // D♭ · E♭ · F · A♭ · B♭ major — the flat side of the circle.
        for root in [1, 3, 5, 8, 10] {
            XCTAssertEqual(NoteSpelling.keySpelling(root: root), .flats,
                           "major on pitch class \(root) is a flat key")
        }
    }

    func testSharpKeysSpellSharps() {
        // G · D · A · E · B major — the sharp side.
        for root in [7, 2, 9, 4, 11] {
            XCTAssertEqual(NoteSpelling.keySpelling(root: root), .sharps,
                           "major on pitch class \(root) is a sharp key")
        }
    }

    func testTheTwoUndecidedKeysReturnNil() {
        // C major has no accidentals to follow; F♯/G♭ major is six of each. Neither decides, so both
        // hand the question to the preference — the same fallback a *keyless* surface takes.
        XCTAssertNil(NoteSpelling.keySpelling(root: 0), "C major decides nothing")
        XCTAssertNil(NoteSpelling.keySpelling(root: 6), "F♯/G♭ major is a six-and-six tie")
        XCTAssertEqual(NoteSpelling.forKey(root: 0, preference: .flats), .flats)
        XCTAssertEqual(NoteSpelling.forKey(root: 6, preference: .flats), .flats)
        XCTAssertEqual(NoteSpelling.forKey(root: 6, preference: .sharps), .sharps)
    }

    func testMinorKeysResolveThroughTheirRelativeMajor() {
        // A minor's parent is C — undecided, like C major itself.
        XCTAssertNil(NoteSpelling.keySpelling(root: 9, relativeMajorSemitones: 3))
        // C minor's parent is E♭ → flats; C♯ minor's parent is E → sharps. Spelling the root by the
        // *root's own* major (D♭ → flats) would get C♯ minor backwards, which is why the parent matters.
        XCTAssertEqual(NoteSpelling.keySpelling(root: 0, relativeMajorSemitones: 3), .flats)
        XCTAssertEqual(NoteSpelling.keySpelling(root: 1, relativeMajorSemitones: 3), .sharps)
        // D minor (parent F) → flats; E minor (parent G) → sharps.
        XCTAssertEqual(NoteSpelling.keySpelling(root: 2, relativeMajorSemitones: 3), .flats)
        XCTAssertEqual(NoteSpelling.keySpelling(root: 4, relativeMajorSemitones: 3), .sharps)
    }

    // MARK: - The rule applied to the app's tonal centres

    func testFMajorAlwaysReadsBFlat() {
        // The rule stated: the preference never overrides a key. The fourth degree of F major is B♭
        // whichever way the player set Settings.
        for preference in NoteSpelling.allCases {
            let spelling = NoteSpelling.forKey(root: 5, preference: preference)
            XCTAssertEqual(spelling.name(pitchClass: 10), "B♭", "F major spells its fourth B♭")
        }
    }

    func testScaleRunsSpellTheirOwnRoot() {
        // B♭ minor pentatonic (parent D♭) reads B♭, never A♯ — the device note that started this.
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 10).rootName, "B♭")
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 10).rootName, "B♭")
        // E♭ major reads E♭; D♯ has no business being a major key here.
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 3).rootName, "E♭")
        // C♯ minor pentatonic (parent E, a sharp key) keeps its sharp.
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 1).rootName, "C♯")
    }

    func testModesResolveThroughTheirParentMajor() {
        // D Dorian's parent is C — undecided, so the default sharp reading stands and D is D either way.
        XCTAssertNil(ScaleRun(scale: .dorian, rootPitchClass: 2).keySpelling)
        // G Dorian's parent is F → flats, so its ♭3 reads B♭.
        let gDorian = ScaleRun(scale: .dorian, rootPitchClass: 7)
        XCTAssertEqual(gDorian.keySpelling, .flats)
        XCTAssertEqual((gDorian.keySpelling ?? .default).name(pitchClass: 10), "B♭")
    }

    func testArpeggiosResolveThroughTheKeyTheyBelongTo() {
        // A dominant 7 belongs to the major a fourth up: B♭7 lives in E♭ major → flats.
        XCTAssertEqual(ArpeggioRun(quality: .dominantSeventh, rootPitchClass: 10).rootName, "B♭")
        // A major-7 is its own major: A♯maj7 is nobody's chord — B♭maj7 is.
        XCTAssertEqual(ArpeggioRun(quality: .majorSeventh, rootPitchClass: 10).rootName, "B♭")
        // A minor-7 resolves through its relative major: C♯m7 (parent E) stays sharp.
        XCTAssertEqual(ArpeggioRun(quality: .minorSeventh, rootPitchClass: 1).rootName, "C♯")
    }

    func testMusicalKeySpellsItsOwnLabelButStoresSharps() {
        // The stored raw value is the schema (ADR 0036) and stays sharp; only the label reads by key.
        XCTAssertEqual(MusicalKey.aSharpMajor.rawValue, "A#")
        XCTAssertEqual(MusicalKey.aSharpMajor.displayName, "B♭ major")
        XCTAssertEqual(MusicalKey.dSharpMajor.displayName, "E♭ major")
        XCTAssertEqual(MusicalKey.cSharpMinor.displayName, "C♯ minor")   // parent E, a sharp key
        XCTAssertEqual(MusicalKey.aSharpMinor.displayName, "B♭ minor")   // parent D♭, a flat key
        XCTAssertEqual(MusicalKey.cMajor.displayName, "C major")
        XCTAssertEqual(MusicalKey.unknown.displayName, "")
    }

    func testAKeyLabelStillParsesBackToItsOwnCase() {
        // The label now carries a ♭ glyph, so the ADR 0036 mapping pass must still fold it home.
        for key in MusicalKey.allCases where key != .unknown {
            XCTAssertEqual(MusicalKey.parse(key.displayName), key, "\(key.displayName) round-trips")
        }
    }

    // MARK: - Keyless surfaces take the preference

    func testTunerReadingSpellsByThePreferenceItWasGiven() {
        // A detected pitch has no key at all — the clearest case for the tiebreaker.
        let sharp = TunerReading.nearest(toFrequency: 466.16, spelling: .sharps)
        let flat = TunerReading.nearest(toFrequency: 466.16, spelling: .flats)
        XCTAssertEqual(sharp?.noteName, "A♯")
        XCTAssertEqual(flat?.noteName, "B♭")
        XCTAssertEqual(flat?.pitchLabel, "B♭4")
        XCTAssertEqual(sharp?.midiNote, flat?.midiNote, "spelling changes the name, never the pitch")
    }

    func testChordNamerSpellsByThePreferenceItWasGiven() {
        // A hand-built shape declares no key (ADR 0086), so the identifier follows the preference.
        let bFlat = ChordGrip.aShapeMajor.voicing(rootPitchClass: 10)
        XCTAssertEqual(ChordNamer.bestName(for: bFlat, spelling: .flats), "B♭")
        XCTAssertEqual(ChordNamer.bestName(for: bFlat, spelling: .sharps), "A♯")
    }

    func testMovableGripNamesItselfInThePreferredSpelling() {
        XCTAssertEqual(ChordGrip.eShapeDom7.voicing(rootPitchClass: 10, spelling: .flats).name, "B♭7")
        XCTAssertEqual(ChordGrip.eShapeDom7.voicing(rootPitchClass: 10, spelling: .sharps).name, "A♯7")
    }

    func testCustomVoicingNoteLabelsFollowThePreference() {
        // The placer's Display → Note captions, on a shape with no key behind it.
        let labels = ChordGrip.aShapeMajor.voicing(rootPitchClass: 10).noteLabels(spelling: .flats)
        XCTAssertEqual(labels.compactMap { $0 }.first, "F", "high e sounds the 5th of B♭")
        XCTAssertTrue(labels.compactMap { $0 }.contains("B♭"), "the root reads B♭, not A♯")
    }

    // MARK: - Drills carry their key to the board; rootless ones don't

    func testAGeneratedRunStampsItsKeyOntoTheDrill() {
        let drill = ScaleRun(scale: .minorPentatonic, rootPitchClass: 10).expanded()
        XCTAssertEqual(drill.keySpelling, .flats, "the board inherits the run's key")
        // The preference can't override it — that's the whole policy.
        XCTAssertEqual(drill.spelling(preference: .sharps), .flats)
    }

    func testARootlessDrillFallsThroughToThePreference() {
        XCTAssertNil(FretboardDrill.spiderWalk.keySpelling, "a spider walk names no key")
        XCTAssertEqual(FretboardDrill.spiderWalk.spelling(preference: .flats), .flats)
        XCTAssertEqual(FretboardDrill.spiderWalk.spelling(preference: .sharps), .sharps)
    }

    func testTheStampedSpellingIsTransientAndNeverEncoded() {
        // Same contract as `openMidi` / `noteGroups` — a render artifact, so no persisted-shape change
        // and no store migration. A decoded drill comes back `nil` and re-derives on the next expand.
        let drill = ScaleRun(scale: .major, rootPitchClass: 10).expanded()
        let data = try? JSONEncoder().encode(drill)
        let decoded = data.flatMap { try? JSONDecoder().decode(FretboardDrill.self, from: $0) }
        XCTAssertNotNil(decoded)
        XCTAssertNil(decoded?.keySpelling, "keySpelling never round-trips through the store")
        XCTAssertEqual(decoded?.notes, drill.notes, "everything persisted is unchanged")
    }

    // MARK: - Settings resolution

    func testStoredPreferenceResolvesWithASharpDefault() {
        XCTAssertEqual(AppSettings.resolvedSpelling(storedValue: nil), .sharps, "unset ⇒ sharps")
        XCTAssertEqual(AppSettings.resolvedSpelling(storedValue: "flats"), .flats)
        XCTAssertEqual(AppSettings.resolvedSpelling(storedValue: "quarter-tones"), .sharps,
                       "an unrecognised value falls back rather than crashing")
    }
}
