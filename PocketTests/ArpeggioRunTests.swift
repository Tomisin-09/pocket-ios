import XCTest
@testable import Pocket

/// The **arpeggio library generator** (ADR 0065 build 2, Slice 3): verifies the shared CAGED box,
/// filtered to each quality's chord tones, produces correct, ascending, one-hand runs for every
/// quality, position and octave count. All pure, SwiftUI-free (T5).
final class ArpeggioRunTests: XCTestCase {

    /// Open-string MIDI notes, standard tuning, by our string index (0 = high e … 5 = low E).
    private let openMidi = [64, 59, 55, 50, 45, 40]
    private func midi(_ note: FretNote) -> Int { openMidi[note.string] + note.fret }

    // MARK: - Generator correctness (the whole point)

    func testEveryBoxIsInTheChordAscendingAndFitsOneHand() {
        for quality in ArpeggioQuality.allCases {
            for position in 1...CAGEDShape.allCases.count {
                for octaves in 1...2 {
                    let run = ArpeggioRun(quality: quality, rootPitchClass: 9,
                                          position: position, octaves: octaves, roundTrip: false)
                    let notes = run.ascendingNotes
                    let context = "\(quality) pos \(position) oct \(octaves)"
                    XCTAssertFalse(notes.isEmpty, "\(context) produced no notes")

                    let allowed = Set(quality.intervals.map { (((9 + $0) % 12) + 12) % 12 })
                    var previous = Int.min
                    for note in notes {
                        XCTAssertTrue(allowed.contains(GuitarScale.pitchClass(string: note.string,
                                                                             fret: note.fret)),
                                      "\(context): \(note) not a chord tone")
                        XCTAssertGreaterThan(midi(note), previous, "\(context) should ascend strictly")
                        previous = midi(note)
                    }
                    XCTAssertTrue(notes.contains { GuitarScale.pitchClass(string: $0.string,
                                                                         fret: $0.fret) == 9 },
                                  "\(context) should contain the tonic")
                    let frets = notes.map(\.fret)
                    XCTAssertLessThanOrEqual((frets.max() ?? 0) - (frets.min() ?? 0), 7,
                                             "\(context) fret span too wide")
                }
            }
        }
    }

    /// Locks a flagship shape: A major arpeggio, position 1 (E-shape), two octaves is R-3-5 climbing
    /// A → C# → E → A → C# → E → A across the box.
    func testMajorArpeggioPositionOneIsTheEShapeTriad() {
        let run = ArpeggioRun(quality: .major, rootPitchClass: 9,
                              position: 1, octaves: 2, roundTrip: false)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 5), FretNote(string: 4, fret: 4), FretNote(string: 4, fret: 7),
            FretNote(string: 3, fret: 7), FretNote(string: 2, fret: 6),
            FretNote(string: 1, fret: 5), FretNote(string: 0, fret: 5)
        ])
    }

    /// The dominant seventh borrows the major a fourth up (its V7 parent), so its ♭7 and 3 both sit in
    /// the box — a note the diatonic minor/major boxes couldn't both hold.
    func testDominantSeventhContainsAllFourChordTones() {
        let run = ArpeggioRun(quality: .dominantSeventh, rootPitchClass: 9, position: 1)
        let classes = Set(run.ascendingNotes.map { GuitarScale.pitchClass(string: $0.string,
                                                                          fret: $0.fret) })
        XCTAssertEqual(classes, [9, 1, 4, 7])   // A C# E G  (R 3 5 ♭7)
    }

    // MARK: - Metadata + clamping

    func testFiveCagedPositionsAndClamping() {
        XCTAssertEqual(ArpeggioRun.aMinorSeventh.positionCount, 5)
        XCTAssertEqual(ArpeggioRun(quality: .major, rootPitchClass: 9, position: 99).position, 5)
        XCTAssertEqual(ArpeggioRun(quality: .major, rootPitchClass: 9, position: 0).position, 1)
        XCTAssertEqual(ArpeggioRun(quality: .major, rootPitchClass: 9, octaves: 5).octaves, 2)
        XCTAssertEqual(ArpeggioRun(quality: .major, rootPitchClass: -3).rootPitchClass, 9)
    }

    func testTitleReadsRootThenQuality() {
        XCTAssertEqual(ArpeggioRun.aMinorSeventh.title, "A Minor 7")
        XCTAssertEqual(ArpeggioRun(quality: .dominantSeventh, rootPitchClass: 4).title, "E Dominant 7")
    }

    // MARK: - Codable + content

    func testArpeggioRunRoundTripsThroughCodable() throws {
        let original = ArpeggioRun(quality: .majorSeventh, rootPitchClass: 2,
                                   position: 3, octaves: 1, roundTrip: false, notesPerBeat: 3)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ArpeggioRun.self, from: data), original)
    }

    func testUnknownQualityRawFallsBackToMinorSeventh() {
        XCTAssertEqual(ArpeggioQuality(storage: "diminished"), .minorSeventh)
    }

    func testContentArpeggioExpandsAndRoundTrips() throws {
        let content = FretboardContent.arpeggio(.aMinorSeventh)
        XCTAssertEqual(content.drill, ArpeggioRun.aMinorSeventh.expanded())
        XCTAssertEqual(content.arpeggioValue, .aMinorSeventh)
        XCTAssertNil(content.scaleValue)
        let data = try JSONEncoder().encode(content)
        XCTAssertEqual(try JSONDecoder().decode(FretboardContent.self, from: data), content)
    }
}
