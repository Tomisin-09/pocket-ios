import XCTest
@testable import Pocket

/// **The Triads recipe** (ADR 0313 D4 to D7, D10): where the chords come from, where they're played, how
/// long each lasts, and the payload an older build meets. Pure, SwiftUI-free.
final class TriadRunTests: XCTestCase {

    private func frets(_ run: TriadRun) -> [[Int]?] { run.placed().map { $0.shape?.frets } }

    private func progression(_ name: String, _ steps: [ProgressionStep]) -> TriadRun.Progression {
        TriadRun.Progression(name: name, steps: steps)
    }

    // MARK: - The payload

    func testATriadsRunRoundTripsThroughThePayload() throws {
        let run = TriadRun(tonic: 10, isMinor: true, strings: .adg, source: .progression,
                           progression: progression("Mine", [.init(0, .minor, bars: 2), .init(5, .dom7)]),
                           placement: .upTheNeck, lowFret: 4, highFret: 9, climbInversion: 2,
                           notesPerBeat: 3, roundTrip: true)
        let data = try JSONEncoder().encode(FretboardContent.triads(run))
        XCTAssertEqual(try JSONDecoder().decode(FretboardContent.self, from: data), .triads(run))
    }

    /// A build without the case can't read the blob: not as `FretboardContent`, whose kinds it doesn't
    /// know, and not as the bare `FretboardDrill` an older payload was. So it reads as nothing, the run
    /// plays a click, and the guard keeps its editors off it (D4).
    func testATriadsBlobDecodesAsNothingOnABuildWithoutTheCase() throws {
        let data = try JSONEncoder().encode(FretboardContent.triads(.starter))
        XCTAssertThrowsError(try JSONDecoder().decode(FretboardContentBeforeTriads.self, from: data))
        XCTAssertThrowsError(try JSONDecoder().decode(FretboardDrill.self, from: data))
    }

    /// An unknown string set, source or placement reads as the starter's, and missing keys take its values,
    /// so a run written by a newer build still plays here.
    func testDecodeToleratesUnknownValuesAndMissingKeys() throws {
        let json = #"{"version":2,"tonic":7,"strings":"eab","source":"fromASong","placement":"spread"}"#
        let run = try JSONDecoder().decode(TriadRun.self, from: Data(json.utf8))
        XCTAssertEqual(run.tonic, 7)
        XCTAssertEqual(run.strings, .gbe)
        XCTAssertEqual(run.source, .keysSeven)
        XCTAssertEqual(run.placement, .stayInFrets)
        XCTAssertEqual(run.fretRange, 3...7)
        XCTAssertEqual(run.version, 2)
    }

    func testAnExerciseReadsATriadsRunAndPlaysItInItsOwnBar() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("Two", [.init(0), .init(7)]), notesPerBeat: 2)
        let exercise = Exercise(name: "Triads", template: .arpeggios)
        exercise.beatsPerBar = 3
        exercise.setFretboardContent(.triads(run))
        XCTAssertEqual(exercise.fretboardContent, .triads(run))
        XCTAssertFalse(exercise.hasUnreadableContent)
        XCTAssertEqual(exercise.fretboardDrill?.noteCount, 2 * 3 * 2, "two chords, a 3/4 bar each, in eighths")
        XCTAssertEqual(exercise.fretboardContent?.notesPerBeat, 2)
    }

    // MARK: - What a new run opens on (D10)

    func testTheStarterIsTheTeachersStepThree() {
        let run = TriadRun.starter
        XCTAssertEqual(run.tonic, 0)
        XCTAssertFalse(run.readsAsMinor)
        XCTAssertEqual(run.strings, .gbe)
        XCTAssertEqual(run.source, .keysSeven)
        XCTAssertEqual(run.placement, .stayInFrets)
        XCTAssertEqual(run.fretRange, 3...7)
        XCTAssertEqual(run.notesPerBeat, 3, "triplets (ADR 0317)")
        XCTAssertFalse(run.roundTrip)
        XCTAssertTrue(run.chordsWithNoShape().isEmpty, "frets 3 to 7 holds every chord of C on G-B-e")
        XCTAssertEqual(run.title(), "Triads in C major")
        XCTAssertEqual(run.caption(), "G-B-e · frets 3–7")
    }

    func testSwitchingFromABoxCarriesItsKey() {
        let dMinor = TriadRun.starter.carryingKey(from: ArpeggioRun(quality: .minorSeventh, rootPitchClass: 2))
        XCTAssertEqual(dMinor.tonic, 2)
        XCTAssertTrue(dMinor.isMinor)
        let dominant = TriadRun.starter.carryingKey(from: ArpeggioRun(quality: .dominantSeventh, rootPitchClass: 7))
        XCTAssertEqual(dominant.tonic, 7)
        XCTAssertFalse(dominant.isMinor)
        XCTAssertEqual(dominant.fretRange, TriadRun.starter.fretRange, "only the key moves")
    }

    func testTheRangeIsClampedOntoTheNeck() {
        XCTAssertEqual(TriadRun(tonic: 0, lowFret: 5, highFret: 5).fretRange, 5...7, "three frets at least")
        XCTAssertEqual(TriadRun(tonic: 0, lowFret: 2, highFret: 20).fretRange, 2...11, "ten frets at most")
        XCTAssertEqual(TriadRun(tonic: 0, lowFret: -3, highFret: 4).fretRange, 0...4)
        XCTAssertEqual(TriadRun(tonic: 0, lowFret: 22, highFret: 30).fretRange, 20...22)
    }

    // MARK: - Where the chords come from (D5)

    func testTheKeysSevenIncludeTheDiminishedChordAndEndOnTheTonic() {
        XCTAssertEqual(TriadRun(tonic: 0).chords().map(\.name), ["C", "Dm", "Em", "F", "G", "Am", "Bdim", "C"])
        XCTAssertEqual(TriadRun(tonic: 9, isMinor: true).chords().map(\.name),
                       ["Am", "Bdim", "C", "Dm", "Em", "F", "G", "Am"])
        XCTAssertEqual(TriadRun(tonic: 10).chords().map(\.name), ["B♭", "Cm", "Dm", "E♭", "F", "Gm", "Adim", "B♭"],
                       "spelled by the key")
    }

    func testOneChordIsTheKeysOwn() {
        XCTAssertEqual(TriadRun(tonic: 2, isMinor: true, source: .oneChord).chords().map(\.name), ["Dm"])
        XCTAssertEqual(TriadRun(tonic: 2, source: .oneChord).title(), "D on three strings")
    }

    func testBiggerChordsPlayAsTheirTriadAndSusAsWritten() {
        let cadence = ProgressionTemplate.catalog.first { $0.id == "two-five-one" }?.steps ?? []
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("ii–V–I", cadence + [.init(7, .sus4)]))
        XCTAssertEqual(run.chords().map(\.name), ["Dm7", "G7", "Cmaj7", "Gsus4"])
        XCTAssertEqual(run.chords().map(\.playsAs), ["Dm", "G", "C", nil])
        XCTAssertEqual(run.chords().map(\.bars), [1, 1, 2, 1])
    }

    /// Major or minor follows the progression, as the builder reads it.
    func testAProgressionReadsItsOwnMinor() {
        let minorLoop = progression("i–VII–VI", [.init(0, .minor), .init(10), .init(8)])
        let run = TriadRun(tonic: 9, isMinor: false, source: .progression, progression: minorLoop)
        XCTAssertTrue(run.readsAsMinor)
        XCTAssertEqual(run.chords().map(\.name), ["Am", "G", "F"])
        XCTAssertEqual(run.title(), "i–VII–VI in A minor")
    }

    func testAMissingProgressionPlaysTheKeysSeven() {
        let run = TriadRun(tonic: 0, source: .progression, progression: nil)
        XCTAssertEqual(run.chords().count, 8)
        XCTAssertEqual(run.title(), "Triads in C major")
    }

    // MARK: - Where they're played (D6)

    /// I – V – vi – IV in C between frets 3 and 7 on G-B-e: each change takes the one shape that fits.
    func testAProgressionInFretsTakesTheShapesThatFit() {
        let run = TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression)
        XCTAssertEqual(frets(run), [[5, 5, 3], [4, 3, 3], [5, 5, 5], [5, 6, 5]])
    }

    /// Of the shapes that fit, each chord takes the one nearest the chord before.
    func testEachChordInFretsTakesTheNearestShape() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–V–I", [.init(0), .init(7), .init(0)]),
                           lowFret: 0, highFret: 9)
        // C opens on its lowest shape in 0–9, [0,1,0]. G's nearest is [4,3,3] (cost 9) over [7,8,7] (21).
        // C then comes back as [5,5,3] (cost 3), not the [0,1,0] it started on (cost 9).
        XCTAssertEqual(frets(run), [[0, 1, 0], [4, 3, 3], [5, 5, 3]])
    }

    func testOneChordUpTheNeckPlaysEveryShapeFromTheNut() {
        let run = TriadRun(tonic: 0, source: .oneChord, placement: .upTheNeck)
        XCTAssertEqual(frets(run), [[0, 1, 0], [5, 5, 3], [9, 8, 8], [12, 13, 12]])
        XCTAssertEqual(run.caption(), "G-B-e · every shape, frets 0–13")
    }

    func testTheKeysSevenClimbInOneInversion() {
        for inversion in 0...2 {
            let run = TriadRun(tonic: 0, placement: .upTheNeck, climbInversion: inversion)
            let shapes = run.placed().compactMap(\.shape)
            XCTAssertEqual(shapes.count, 8, "inversion \(inversion)")
            XCTAssertTrue(shapes.allSatisfy { $0.inversion == inversion })
            let basses = shapes.map { $0.pitches[0] }
            XCTAssertEqual(basses, basses.sorted())
            XCTAssertEqual(Set(basses).count, basses.count, "each chord climbs")
        }
        XCTAssertEqual(frets(TriadRun(tonic: 0, placement: .upTheNeck)).first, [5, 5, 3])
    }

    /// Three passes, each from the next shape of the first chord, and the board fades the passes not being
    /// played.
    func testAProgressionUpTheNeckPlaysThreePassesAPositionApart() {
        let run = TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression,
                           placement: .upTheNeck)
        let placed = run.placed()
        XCTAssertEqual(placed.count, 12)
        XCTAssertEqual(placed.map(\.pass), [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2])
        let starts = placed.filter { $0.chord.name == "C" }.compactMap { $0.shape?.frets }
        XCTAssertEqual(starts, [[0, 1, 0], [5, 5, 3], [9, 8, 8]])
        XCTAssertTrue(placed.allSatisfy { $0.shape != nil })
        let drill = run.expanded(beatsPerBar: 4)
        XCTAssertEqual(Set(drill.noteGroups ?? []), [0, 1, 2])
        XCTAssertEqual(run.caption(), "G-B-e · 3 times, each from a shape of C")
    }

    // MARK: - A range that can't hold a chord (D6)

    func testAChordWithNoShapeIsNamedAndTheNearestRangesHoldThemAll() {
        let run = TriadRun(tonic: 0, lowFret: 4, highFret: 8)
        let missing = run.chordsWithNoShape()
        XCTAssertFalse(missing.isEmpty, "frets 4 to 8 can't hold all seven of C on G-B-e")
        XCTAssertTrue(missing.allSatisfy { name in run.chords().contains { $0.name == name } })
        let ranges = run.rangesThatHoldEveryChord()
        XCTAssertFalse(ranges.isEmpty)
        for range in ranges {
            XCTAssertTrue(run.holdsEveryChord(in: range))
            XCTAssertLessThanOrEqual(range.count, TriadRun.maxFretSpan)
        }
        XCTAssertTrue(ranges.contains(3...7), "the same width, one lower")
        XCTAssertTrue(ranges.allSatisfy { $0.count == 5 })
    }

    func testOffersAWiderRangeWhenNoRangeOfTheSameWidthHoldsThem() {
        // Three frets can hold no key's seven anywhere on A-D-G.
        let run = TriadRun(tonic: 0, strings: .adg, lowFret: 5, highFret: 7)
        let ranges = run.rangesThatHoldEveryChord()
        XCTAssertEqual(ranges.count, 1)
        XCTAssertGreaterThan(ranges.first?.count ?? 0, 3)
        XCTAssertTrue(ranges.allSatisfy(run.holdsEveryChord(in:)))
    }

    func testNothingIsMissingWhenTheRunClimbs() {
        XCTAssertTrue(TriadRun(tonic: 0, placement: .upTheNeck, lowFret: 4, highFret: 6).chordsWithNoShape().isEmpty)
    }

    // MARK: - How long each chord lasts (D5, D7)

    /// With no bars, each chord plays its three notes once, low string to high.
    func testBrokenPlaysEachChordLowStringToHigh() {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.noteCount, 8 * 3)
        XCTAssertEqual(Array(drill.notes.prefix(3)),
                       [FretNote(string: 2, fret: 5), FretNote(string: 1, fret: 5), FretNote(string: 0, fret: 3)])
        XCTAssertEqual(drill.notesPerBeat, 3)
        XCTAssertEqual(drill.rootPitchClass, 0)
        XCTAssertEqual(drill.shadedFrets, 3...7)
        XCTAssertNil(drill.noteGroups, "one pass: nothing fades")
    }

    // MARK: - Triplets (ADR 0317)

    /// In triplets each chord of the key's seven is one beat, so all eight, back to the tonic, fill two
    /// bars of 4/4 exactly and the run loops on the bar line. In eighths a chord was a beat and a half.
    func testANewRunGivesEachChordOfTheKeysSevenOneBeat() {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.noteCount, 8 * drill.notesPerBeat, "one beat a chord")
        XCTAssertEqual(drill.noteCount, 2 * 4 * drill.notesPerBeat, "two whole bars of 4/4")
    }

    /// A progression's chord in a new run fills its bar with whole triads: every group of three starts on
    /// a beat, and the bar ends on the triad's top note rather than cutting it off (in eighths a 4/4 bar
    /// was 8 notes, R 3 5 R 3 5 R 3).
    func testANewProgressionRunFillsEachBarWithWholeTriads() {
        let run = TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression)
        let drill = run.expanded(beatsPerBar: 4)
        let chords = drill.chords ?? []
        XCTAssertEqual(chords.count, 4)
        for chord in chords {
            let notes = drill.notes[chord.slots].compactMap { $0 }
            XCTAssertEqual(notes.count, 4 * 3, "\(chord.root): one 4/4 bar of triplets")
            let triad = Array(notes.prefix(3))
            XCTAssertEqual(notes, triad + triad + triad + triad, "\(chord.root): four whole triads")
        }
    }

    /// A run saved before ADR 0317 keeps the eighths it was saved with: the rhythm is stored with the run,
    /// so a new default reaches only runs made after it. The JSON is what 1.6 writes.
    func testASavedRunKeepsItsEighths() throws {
        let json = #"{"version":1,"tonic":0,"isMinor":false,"strings":"gbe","source":"keysSeven","#
            + #""placement":"stayInFrets","lowFret":3,"highFret":7,"climbInversion":0,"playAs":"broken","#
            + #""notesPerBeat":2,"roundTrip":false}"#
        let run = try JSONDecoder().decode(TriadRun.self, from: Data(json.utf8))
        XCTAssertEqual(run.notesPerBeat, 2)
        XCTAssertEqual(run.expanded(beatsPerBar: 4).notesPerBeat, 2)
    }

    /// A progression's chord holds for its bars, and Broken repeats its three notes upward to fill them.
    func testAProgressionChordFillsItsBarsRepeatingUpward() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I", [.init(0, bars: 2)]), notesPerBeat: 3)
        let drill = run.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.noteCount, 2 * 4 * 3)
        let shape = run.placed().first?.shape?.notes ?? []
        XCTAssertEqual(drill.notes, (0..<24).map { Optional(shape[$0 % 3]) }, "triplets fill each beat exactly")
    }

    /// A power chord has no triad, and a chord with no shape in the range has none either: each rests for
    /// its whole length, so the run keeps time with the click and the form doesn't get shorter.
    func testAChordWithNoShapeRestsForItsWholeLength() {
        let run = TriadRun(tonic: 0, source: .progression,
                           progression: progression("I–I5", [.init(0), .init(0, .fifth)]), notesPerBeat: 2)
        let drill = run.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.noteCount, 16)
        XCTAssertTrue(drill.notes.prefix(8).allSatisfy { $0 != nil })
        XCTAssertTrue(drill.notes.suffix(8).allSatisfy { $0 == nil })
        XCTAssertTrue(run.chordsWithNoShape().isEmpty, "a power chord isn't a range's fault")

        let narrow = TriadRun(tonic: 0, lowFret: 4, highFret: 8)
        let restingChords = narrow.placed().filter { $0.shape == nil }.count
        XCTAssertEqual(narrow.expanded(beatsPerBar: 4).notes.filter { $0 == nil }.count, restingChords * 3)
    }

    func testABluesKeepsItsTwelveBarsInAnyMeter() {
        let blues = ProgressionTemplate.catalog.first { $0.id == "twelve-bar-blues" }?.steps ?? []
        let run = TriadRun(tonic: 9, source: .progression, progression: progression("12-bar blues", blues),
                           notesPerBeat: 2)
        XCTAssertEqual(run.expanded(beatsPerBar: 4).noteCount, 12 * 4 * 2)
        XCTAssertEqual(run.expanded(beatsPerBar: 3).noteCount, 12 * 3 * 2)
    }

    /// The board keeps a shaded range in view with a fret of neck either side, so frets 3 to 7 reads as a
    /// place on the neck, and the range is never written into a payload.
    func testTheBoardShowsTheShadedRangeWithAFretEitherSide() throws {
        let drill = TriadRun.starter.expanded(beatsPerBar: 4)
        XCTAssertEqual(drill.displayWindow(activeIndex: nil), FretWindow(lowestFret: 2, span: 7))
        let open = TriadRun(tonic: 0, lowFret: 0, highFret: 4).expanded(beatsPerBar: 4)
        XCTAssertEqual(open.displayWindow(activeIndex: nil).lowestFret, 1, "a range from the nut starts at fret 1")
        XCTAssertNil(TriadRun(tonic: 0, placement: .upTheNeck).expanded(beatsPerBar: 4).shadedFrets)
        let decoded = try JSONDecoder().decode(FretboardDrill.self, from: JSONEncoder().encode(drill))
        XCTAssertNil(decoded.shadedFrets, "transient, like noteGroups")
    }

    func testUpAndBackIsForOneChordAndTheKeysSevenOnly() {
        let seven = TriadRun(tonic: 0, roundTrip: true)
        XCTAssertEqual(seven.placed().map(\.chord.name),
                       ["C", "Dm", "Em", "F", "G", "Am", "Bdim", "C", "Bdim", "Am", "G", "F", "Em", "Dm"])
        let loop = TriadRun(tonic: 0, source: .progression, progression: TriadRun.defaultProgression, roundTrip: true)
        XCTAssertEqual(loop.placed().count, 4, "a progression's order is the music")
    }
}

/// `FretboardContent`'s decode as a build before Triads had it: the same keys, without the case.
private enum FretboardContentBeforeTriads: Decodable {
    case run(FretboardRun), scale(ScaleRun), arpeggio(ArpeggioRun), custom(FretboardDrill)

    private enum CodingKeys: String, CodingKey { case kind, run, scale, arpeggio, drill }
    private enum Kind: String, Decodable { case run, scale, arpeggio, custom }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .run: self = .run(try container.decode(FretboardRun.self, forKey: .run))
        case .scale: self = .scale(try container.decode(ScaleRun.self, forKey: .scale))
        case .arpeggio: self = .arpeggio(try container.decode(ArpeggioRun.self, forKey: .arpeggio))
        case .custom: self = .custom(try container.decode(FretboardDrill.self, forKey: .drill))
        }
    }
}
