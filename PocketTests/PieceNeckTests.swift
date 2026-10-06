import XCTest
@testable import Pocket

/// *Watch it on the neck* (ADR 0254): what the map holds, what lights, what the line says, when the board
/// moves, and which loops get a door.
final class PieceNeckTests: XCTestCase {

    /// Standard tuning, highest-first.
    private let standard = [64, 59, 55, 50, 45, 40]

    private func spot(_ string: Int, _ fret: Int) -> NeckSpot { NeckSpot(string: string, fret: fret) }
    private func note(_ string: Int, _ fret: Int, bend: Int = 0, vibrato: Bool = false,
                      leadIn: LeadIn? = nil) -> FrettedNote {
        FrettedNote(string: string, fret: fret, bend: bend, vibrato: vibrato, leadIn: leadIn)
    }

    /// A G minor lick with one of everything: a bend, a lead-in, a tap named by ear, one not named, and a
    /// Gm7 to finish.
    private var lick: [PieceLabel?] {
        [.fretted(string: 3, fret: 3),
         .fretted([note(1, 6, bend: 2)], into: nil),
         .pitchClass(5),
         nil,
         .fretted([note(2, 10, leadIn: LeadIn(from: .fret(7), join: .slide))], into: nil),
         .fretted([note(4, 10), note(3, 12), note(2, 10), note(1, 11), note(0, 10)], into: nil)]
    }

    // MARK: - The map and the light

    func testTheMapIsEverySpotPlacedAndNothingElse() {
        XCTAssertEqual(PieceNeck.spots(of: lick),
                       [spot(3, 3), spot(1, 6), spot(2, 10), spot(4, 10), spot(3, 12), spot(1, 11), spot(0, 10)],
                       "a bend's landing (B8) and a lead-in's start (G7) aren't spots, and a name by ear has none")
        XCTAssertEqual(PieceNeck.spots(of: []), [])
        XCTAssertEqual(PieceNeck.spots(of: [.pitchClass(2), nil]), [])
    }

    func testOnlyTheTapBeingHeardLights() {
        XCTAssertEqual(PieceNeck.heardSpots(nil, of: lick), [], "nothing is heard while stopped")
        XCTAssertEqual(PieceNeck.heardSpots(1, of: lick), [spot(1, 6)])
        XCTAssertEqual(PieceNeck.heardSpots(2, of: lick), [], "named by ear: nothing on the neck lights")
        XCTAssertEqual(PieceNeck.heardSpots(3, of: lick), [], "not named")
        XCTAssertEqual(PieceNeck.heardSpots(5, of: lick).count, 5, "a chord lights every note")
        XCTAssertEqual(PieceNeck.heardSpots(9, of: lick), [], "past the end")
    }

    func testATapsFretsTakeInItsBendAndItsLeadIn() {
        XCTAssertEqual(PieceNeck.frets(of: 0, in: lick), 3...3)
        XCTAssertEqual(PieceNeck.frets(of: 1, in: lick), 6...8, "to where the bend lands")
        XCTAssertEqual(PieceNeck.frets(of: 4, in: lick), 7...10, "from where the slide started")
        XCTAssertEqual(PieceNeck.frets(of: 5, in: lick), 10...12)
        XCTAssertNil(PieceNeck.frets(of: 2, in: lick), "named by ear")
        XCTAssertNil(PieceNeck.frets(of: 3, in: lick), "not named")
        XCTAssertEqual(PieceNeck.frets(of: 0, in: [.fretted([note(1, 21, bend: 3)], into: nil)]), 21...22,
                       "a bend stops at the last fret")
    }

    func testTheSpanIsTheWholeLickAndItsMiddleIsWhereTheBoardOpens() {
        XCTAssertEqual(PieceNeck.span(of: lick), 3...12)
        XCTAssertEqual(PieceNeck.centre(of: 3...12), 7)
        XCTAssertNil(PieceNeck.span(of: []), "an empty piece")
        XCTAssertNil(PieceNeck.span(of: [.chord(root: 7, suffix: "m"), nil]), "nothing on the neck")
    }

    // MARK: - The gate

    func testADoorShowsOnlyWithSomethingOnTheNeckAndAudioThatPlays() {
        XCTAssertTrue(PieceNeck.canWatch(hasFrettedLabels: true, audioResolves: true))
        XCTAssertFalse(PieceNeck.canWatch(hasFrettedLabels: false, audioResolves: true), "named by ear only")
        XCTAssertFalse(PieceNeck.canWatch(hasFrettedLabels: true, audioResolves: false), "no audio here")
        XCTAssertFalse(PieceNeck.canWatch(hasFrettedLabels: false, audioResolves: false))
    }

    /// A loop holding `labels` as its piece, uninserted (docs/swiftdata-gotchas.md), on a song from `source`.
    private func loop(_ labels: [PieceLabel?], source: SongRef.Source? = .localFile) -> Loop {
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.2, speed: 0.8, repeats: 3)
        if let source {
            loop.song = Song(title: "Test", duration: 120, ref: SongRef(id: "s1", source: source, bookmark: nil))
        }
        let taps = labels.enumerated().map { PieceTranscription.Tap(seconds: Double($0.offset), label: $0.element) }
        loop.transcription = PieceTranscription(taps: taps, openMidi: standard)
        return loop
    }

    func testEveryDoorAsksTheLoopTheSameQuestion() {
        XCTAssertTrue(PieceNeck.canWatch(loop(lick)))
        XCTAssertFalse(PieceNeck.canWatch(loop([.pitchClass(5), nil])), "named by ear only: nothing to light")
        XCTAssertFalse(PieceNeck.canWatch(loop([])), "no piece")
        XCTAssertFalse(PieceNeck.canWatch(loop(lick, source: .appleMusic)), "Apple Music audio can't play here")
        XCTAssertFalse(PieceNeck.canWatch(loop(lick, source: nil)), "no song, no audio")

        let held = loop(lick)
        XCTAssertTrue(PieceNeck.canWatch(held.transcription, on: held), "the Journal's form, with the piece decoded")
        XCTAssertFalse(PieceNeck.canWatch(nil, on: held))
    }

    // MARK: - In words

    func testTheLineSaysWhereAndHowEachTapWasPlayed() {
        let words = { (index: Int, labels: [PieceLabel?]) in
            PieceNeck.words(for: index, of: labels, openMidi: self.standard, spelling: .flats)
        }
        XCTAssertEqual(words(0, lick), "D string, fret 3")
        XCTAssertEqual(words(1, lick), "B string, fret 6, bent a whole step")
        XCTAssertEqual(words(2, lick), "F, named by ear")
        XCTAssertEqual(words(3, lick), "Not named yet")
        XCTAssertEqual(words(4, lick), "G string, fret 10, slid from 7")
        XCTAssertEqual(words(0, [.fretted(string: 2, fret: 0)]), "G string, open")
        XCTAssertEqual(words(0, [.fretted([note(1, 3, vibrato: true)], into: nil)]), "B string, fret 3, with vibrato")
        XCTAssertEqual(words(0, [.fretted([note(2, 9, leadIn: LeadIn(from: .below, join: .slide))], into: nil)]),
                       "G string, fret 9, slid in from below")

        let joined: [PieceLabel?] = [.fretted(string: 3, fret: 3), .fretted([note(3, 5)], into: .legato),
                                     .fretted([note(3, 3)], into: .legato), .fretted([note(3, 0)], into: .legato),
                                     .fretted([note(3, 2)], into: .legato)]
        XCTAssertEqual(words(1, joined), "D string, fret 5, hammered on from 3")
        XCTAssertEqual(words(2, joined), "D string, fret 3, pulled off from 5")
        XCTAssertEqual(words(3, joined), "D string, open, pulled off from 3")
        XCTAssertEqual(words(4, joined), "D string, fret 2, hammered on from the open string")
    }

    func testAChordSaysItsNameAndTheFretsItCovers() {
        let line = PieceNeck.words(for: 5, of: lick, openMidi: standard, spelling: .flats)
        let name = lick[5]?.name(openMidi: standard, spelling: .flats)
        XCTAssertNotNil(name)
        XCTAssertEqual(line, "\(name ?? ""), frets 10 to 12")
        XCTAssertEqual(PieceNeck.words(for: 0, of: [.fretted([note(2, 5), note(1, 5)], into: nil)],
                                       openMidi: standard, spelling: .flats).suffix(8), ", fret 5")
    }

    // MARK: - Following

    func testTheBoardsFretsInViewStopAtEitherEnd() {
        // 319 points: the board's width beside the string names on a 375-point phone.
        XCTAssertEqual(NeckFollow.window(centre: 1, width: 319), 0...8, "it can't scroll before the nut")
        XCTAssertEqual(NeckFollow.window(centre: 10, width: 319), 6...14)
        XCTAssertEqual(NeckFollow.window(centre: 22, width: 319), 14...22, "or past the last fret")
        XCTAssertNil(NeckFollow.window(centre: 5, width: 20), "not one fret fits")
    }

    func testItMovesOnlyWhenTheHeardFretsLeaveTheView() {
        let follow = { (current: Int?, heard: ClosedRange<Int>) in
            NeckFollow.target(current: current, heard: heard, width: 319)
        }
        XCTAssertEqual(follow(nil, 3...12), 7, "not centred yet: it goes to the heard frets")
        XCTAssertNil(follow(10, 6...6), "the first fret in view")
        XCTAssertNil(follow(10, 14...14), "the last fret in view")
        XCTAssertEqual(follow(10, 5...5), 5, "one past the first")
        XCTAssertEqual(follow(10, 15...15), 15, "one past the last")
        XCTAssertEqual(follow(10, 13...16), 14, "partly out of view")
        XCTAssertNil(follow(10, 4...16), "wider than the view and already centred on it")
        XCTAssertEqual(follow(10, 4...18), 11, "wider than the view: it centres on the middle")
        XCTAssertNil(NeckFollow.target(current: 10, heard: 30...30, width: 20), "no view to judge by")
    }

    func testItsGeometryIsTheBoards() {
        XCTAssertEqual(NeckFollow.pitch, Double(NeckGeometry.pitch))
        XCTAssertEqual(NeckFollow.cell, Double(NeckGeometry.cellSize))
    }
}
