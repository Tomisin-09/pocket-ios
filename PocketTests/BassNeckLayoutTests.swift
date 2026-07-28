import XCTest
@testable import Pocket

/// The **bass placement rule** (ADR 0116 Slice 3) — verifies the 2-octave `BassNeckLayout` box is a real,
/// in-scale, ascending run on the four strings, and that threading an instrument through the run generators
/// leaves **guitar byte-identical** while producing correct 4-string content for bass. Pure, SwiftUI-free.
final class BassNeckLayoutTests: XCTestCase {

    /// Standard 4-string bass in the engine's highest-first order (G D A E) — the reversal of the tuner's
    /// lowest-first `[28,33,38,43]`, pinned here so the box tests don't silently follow a tuning change.
    private let bassOpenMidi = [43, 38, 33, 28]

    private func midi(_ note: FretNote) -> Int { bassOpenMidi[note.string] + note.fret }
    private func pitchClass(_ note: FretNote) -> Int { ((midi(note) % 12) + 12) % 12 }

    // MARK: - notes-per-string schedule

    func testScheduleSpreadsTwoOctavesRemainderOnLowerStrings() {
        // Pentatonic (5 tones) → 11 notes over 4 strings → [3,3,3,2]; diatonic (7) → 15 → [4,4,4,3].
        XCTAssertEqual(BassNeckLayout.notesPerString(offsetCount: 5, strings: 4), [3, 3, 3, 2])
        XCTAssertEqual(BassNeckLayout.notesPerString(offsetCount: 7, strings: 4), [4, 4, 4, 3])
        // A triad (3) → 7 → [2,2,2,1]; a seventh (4) → 9 → [3,2,2,2].
        XCTAssertEqual(BassNeckLayout.notesPerString(offsetCount: 3, strings: 4), [2, 2, 2, 1])
        XCTAssertEqual(BassNeckLayout.notesPerString(offsetCount: 4, strings: 4), [3, 2, 2, 2])
    }

    // MARK: - Box correctness (the whole point)

    func testBoxIsInScaleAscendingOnNeckAndOnFourStrings() {
        for scale in GuitarScale.allCases {
            let offsets = ScaleNeckLayout.toneOffsets(scale)
            for root in 0..<12 {
                let notes = BassNeckLayout.box(offsets: offsets, root: root, openMidi: bassOpenMidi)
                XCTAssertFalse(notes.isEmpty, "\(scale) root \(root) produced no notes")

                // Every note is a scale tone.
                for note in notes {
                    let degree = (((pitchClass(note) - root) % 12) + 12) % 12
                    XCTAssertTrue(offsets.contains(degree),
                                  "\(scale) root \(root): note \(note) degree \(degree) not in scale")
                }
                // Strictly ascending by pitch — no clamping distortion crept in.
                let midis = notes.map(midi)
                XCTAssertEqual(midis, midis.sorted(), "\(scale) root \(root) not ascending")
                XCTAssertEqual(Set(midis).count, midis.count, "\(scale) root \(root) repeats a pitch")

                // Only the four bass strings, every fret on a real neck.
                for note in notes {
                    XCTAssertTrue((0..<4).contains(note.string), "string \(note.string) off the bass")
                    XCTAssertTrue((0...BassNeckLayout.maxFret).contains(note.fret),
                                  "fret \(note.fret) off the neck")
                }
                // Roughly two octaves — opens on the tonic, spans ~2 octaves.
                guard let first = notes.first, let low = midis.first, let high = midis.last else {
                    XCTFail("\(scale) root \(root) produced no notes"); continue
                }
                XCTAssertEqual(pitchClass(first), root, "\(scale) root \(root) not rooted on tonic")
                let span = high - low
                XCTAssertTrue((11...26).contains(span), "\(scale) root \(root) span \(span) not ~2 octaves")
            }
        }
    }

    func testBoxAlwaysRootsOnTheLowestString() {
        // The 2-octave box anchors its tonic on the lowest string (low E, index 3), climbing from there —
        // so E opens on the open string (fret 0) and every other key roots at that key's fret on low E.
        let offsets = ScaleNeckLayout.toneOffsets(.minorPentatonic)
        for (root, expectedFret) in [(4, 0), (9, 5), (2, 10), (7, 3)] {
            let notes = BassNeckLayout.box(offsets: offsets, root: root, openMidi: bassOpenMidi)
            XCTAssertEqual(notes.first?.string, 3, "root \(root) should anchor on the low string")
            XCTAssertEqual(notes.first?.fret, expectedFret, "root \(root) low-E fret")
        }
    }

    func testRootAnchorReadsOpenLowE() {
        let offsets = ScaleNeckLayout.toneOffsets(.minorPentatonic)
        let notes = BassNeckLayout.box(offsets: offsets, root: 4, openMidi: bassOpenMidi)   // E
        XCTAssertEqual(BassNeckLayout.rootAnchor(in: notes, root: 4, openMidi: bassOpenMidi),
                       "Root: open E")
    }

    func testStringNamesAreBassStandard() {
        XCTAssertEqual((0..<4).map { BassNeckLayout.stringName($0, of: 4) }, ["G", "D", "A", "E"])
    }

    // MARK: - Guitar stays byte-identical (proves the refactor changes nothing for guitar)

    func testScaleRunGuitarOverloadMatchesNoArg() {
        for run in [ScaleRun.aMinorPentatonic, .gMajorThreePerString, .aMinorPentatonicExtended,
                    .gMajorInThirds] {
            XCTAssertEqual(run.expanded(instrument: .guitar), run.expanded())
        }
    }

    func testArpeggioRunGuitarOverloadMatchesNoArg() {
        XCTAssertEqual(ArpeggioRun.aMinorSeventh.expanded(instrument: .guitar),
                       ArpeggioRun.aMinorSeventh.expanded())
    }

    func testFretboardRunGuitarOverloadMatchesNoArg() {
        XCTAssertEqual(FretboardRun.chromaticWarmup.expanded(instrument: .guitar),
                       FretboardRun.chromaticWarmup.expanded())
    }

    // MARK: - Bass content renders on four strings

    func testScaleRunBassExpandsToFourStrings() {
        let drill = ScaleRun.eMinorPentatonicBass.expanded(instrument: .bass)
        XCTAssertEqual(drill.stringCount, 4)
        for note in drill.notes.compactMap({ $0 }) {
            XCTAssertTrue((0..<4).contains(note.string))
        }
    }

    func testArpeggioRunBassExpandsToFourStrings() {
        let drill = ArpeggioRun.eMinorSeventhBass.expanded(instrument: .bass)
        XCTAssertEqual(drill.stringCount, 4)
        for note in drill.notes.compactMap({ $0 }) {
            XCTAssertTrue((0..<4).contains(note.string))
        }
    }

    func testFretboardRunBassClampsStringSpanToFour() {
        // The shipped chromatic warm-up spans low E → high e (strings 5…0); on bass it must clamp to 3…0.
        let drill = FretboardRun.chromaticWarmup.expanded(instrument: .bass)
        XCTAssertEqual(drill.stringCount, 4)
        for note in drill.notes.compactMap({ $0 }) {
            XCTAssertTrue((0..<4).contains(note.string), "string \(note.string) off the bass")
        }
    }

    func testScaleRunPositionCountIsOneForBass() {
        XCTAssertEqual(ScaleRun.eMinorPentatonicBass.positionCount(for: .bass), 1)
        XCTAssertEqual(ArpeggioRun.eMinorSeventhBass.positionCount(for: .bass), 1)
    }
}
