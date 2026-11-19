import SwiftData
import XCTest
@testable import Pocket

/// **The song's shift** (ADR 0305 slice 2): a song raised or lowered to meet your tuning, and a piece that
/// always describes the recording (D5). Stored against the recording, shown and edited as you hear it; the
/// two moves are one function with opposite signs, so the tests pin both ends and the round trip.
@MainActor
final class SongShiftTests: XCTestCase {

    private let standard = Instrument.guitar.standardTuning.engineOpenMidi        // [64, 59, 55, 50, 45, 40]
    private let halfStepDown = Instrument.guitar.tuning(named: "Half step down").engineOpenMidi
    private let dropD = Instrument.guitar.tuning(named: "Drop D").engineOpenMidi

    private func song(key: MusicalKey = .gMinor, shift: Int = 0) -> Song {
        let song = Song(title: "Slow Bend", duration: 100, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        song.musicalKey = key
        song.pitchShift = shift
        return song
    }

    private func loop(on song: Song) -> Loop {
        let loop = Loop(name: "Lick", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        loop.song = song
        return loop
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Song.self, Loop.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    // MARK: - The song (D4)

    func testASongPlaysAsRecordedUntilItIsMoved() {
        let fresh = song()
        XCTAssertEqual(fresh.pitchShift, 0, "the declaration default every older song migrates to")
        XCTAssertEqual(fresh.heardKey, .gMinor)
        XCTAssertEqual(song(shift: 1).heardKey, .gSharpMinor, "the key stays the recording's; the heard key moves")
        XCTAssertEqual(song(shift: 9).heardShift, 6, "held within six whatever was stored")
        XCTAssertEqual(song(key: .unknown, shift: 2).heardKey, .unknown)
    }

    /// The mockup's copy (`XGN3XZoBnL1WVhRdr8Suq9`, *Edit song* and *Song player*).
    func testEditSongAndTheChipSayWhereTheShiftLands() {
        XCTAssertEqual(KeyShift.songLine(key: .fSharpMinor, shift: 0), "As recorded")
        XCTAssertEqual(KeyShift.songLine(key: .fSharpMinor, shift: 1), "Up 1 semitone · F♯ minor → G minor")
        XCTAssertEqual(KeyShift.songLine(key: .dSharpMajor, shift: 1), "Up 1 semitone · E♭ major → E major",
                       "spelled key-first on both sides")
        XCTAssertEqual(KeyShift.songLine(key: .unknown, shift: -2), "Down 2 semitones")
        XCTAssertEqual(KeyShift.chipLabel(1), "+1 semitone")
        XCTAssertEqual(KeyShift.chipLabel(-2), "−2 semitones")
        XCTAssertEqual(KeyShift.spokenSongShift(-2), "Lowered 2 semitones")
    }

    // MARK: - Saved against the recording (D5)

    /// Named in Standard on a song raised by 1: the frets the player placed, on *Half step down*.
    func testStandardAtPlusOneSavesAsHalfStepDownWithTheFretsKept() {
        let heard = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 2, fret: 5)),
                                              .init(seconds: 2, label: .fretted(string: 1, fret: 7))],
                                       openMidi: standard, tuningLabel: "Guitar · Standard")
        let saved = heard.moved(by: -1)
        XCTAssertEqual(saved.openMidi, halfStepDown)
        XCTAssertEqual(saved.tuningLabel, "Guitar · Half step down")
        XCTAssertEqual(saved.labels, heard.labels, "the frets don't move")
        XCTAssertEqual(saved.moved(by: 1), heard, "and moved back up, it's what was named")
    }

    func testNamesByEarAndChordRootsMoveDownByTheShift() {
        let heard = PieceTranscription(taps: [.init(seconds: 1, label: .pitchClass(0)),
                                              .init(seconds: 2, label: .chord(root: 7, suffix: "m")),
                                              .init(seconds: 3, label: .muted),
                                              .init(seconds: 4)])
        let saved = heard.moved(by: -1)
        XCTAssertEqual(saved.labels, [.pitchClass(11), .chord(root: 6, suffix: "m"), .muted, nil])
        XCTAssertNil(saved.openMidi, "nothing on the neck, so no strings to record")
        XCTAssertEqual(heard.moved(by: 0), heard)
    }

    /// The two players D5 promises save the same piece: one retuned to Half step down, one raised the song.
    func testAPlayerWhoRetunedAndOneWhoRaisedTheSongSaveEqualPieces() throws {
        let taps: [PieceTranscription.Tap] = [.init(seconds: 1, label: .fretted(string: 2, fret: 5))]
        let retuned = PieceTranscription(taps: taps, openMidi: halfStepDown, tuningLabel: "Guitar · Half step down")
        let raised = PieceTranscription(taps: taps, openMidi: standard, tuningLabel: "Guitar · Standard").moved(by: -1)
        XCTAssertEqual(raised, retuned)
    }

    /// A tuning with no name in the list is the player's tuning moved, and says so, and comes back.
    func testATuningWithNoNameIsDescribedAsTheTuningMoved() {
        let heard = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 5, fret: 0))],
                                       openMidi: dropD, tuningLabel: "Guitar · Drop D")
        let saved = heard.moved(by: -1)
        XCTAssertEqual(saved.tuningLabel, "Guitar · Drop D, 1 semitone down")
        XCTAssertEqual(saved.moved(by: 1), heard)
        XCTAssertEqual(PieceTuning.label(openMidi: standard.map { $0 + 2 }, near: "Guitar · Standard"),
                       "Guitar · Standard, 2 semitones up")
        XCTAssertEqual(PieceTuning.label(openMidi: standard.map { $0 - 2 }, near: "Guitar · Standard"),
                       "Guitar · Full step down", "a curated name wins when the strings are one")
        XCTAssertEqual(PieceTuning.label(openMidi: [43, 38, 33, 28].map { $0 - 1 }, near: "Bass · Standard"),
                       "Bass · Half step down")
        XCTAssertEqual(PieceTuning.label(openMidi: dropD.map { $0 + 1 }, near: "Guitar · Drop D · song raised 1"),
                       "Guitar · Drop D, 1 semitone up", "the heard line's note isn't read as a tuning")
    }

    // MARK: - The model, named at the song's shift

    /// Naming opens as you hear it and saves against the recording: the round trip Name the notes makes.
    func testNamingOnARaisedSongShowsWhatYouHearAndSavesTheRecording() throws {
        let raised = song(shift: 1)
        let lick = loop(on: raised)
        lick.transcription = PieceTranscription(taps: [.init(seconds: 10.5, label: .pitchClass(9)),
                                                       .init(seconds: 11)])
        let model = CountTheNotesModel(loop: lick)
        model.nameSaved()
        let request = try XCTUnwrap(model.naming)
        XCTAssertEqual(request.taps.first?.label, .pitchClass(10), "A on the record is heard as B♭")
        var named = request.taps
        named[1].label = .fretted(string: 2, fret: 5)
        model.finishNaming(request, result: NamingResult(taps: named, openMidi: standard,
                                                         tuningLabel: "Guitar · Standard"),
                           context: try makeContext())
        let saved = try XCTUnwrap(lick.transcription)
        XCTAssertEqual(saved.labels, [.pitchClass(9), .fretted(string: 2, fret: 5)])
        XCTAssertEqual(saved.openMidi, halfStepDown)
        XCTAssertEqual(saved.tuningLabel, "Guitar · Half step down")
        XCTAssertEqual(CountTheNotesModel.spelling(for: lick).name(pitchClass: 8), "G♯",
                       "spelled for G♯ minor, the key you hear")
    }

    func testOpeningAndClosingWithoutAChangeWritesNothing() throws {
        let lick = loop(on: song(shift: 1))
        let stored = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 2, fret: 5))],
                                        openMidi: halfStepDown, tuningLabel: "Guitar · Half step down")
        lick.transcription = stored
        let model = CountTheNotesModel(loop: lick)
        model.nameSaved()
        let request = try XCTUnwrap(model.naming)
        XCTAssertEqual(request.openMidi, standard, "heard on the player's strings")
        XCTAssertEqual(request.tuningLabel, "Guitar · Standard · song raised 1", "and the line says why")
        model.finishNaming(request, result: NamingResult(taps: request.taps, openMidi: request.openMidi ?? [],
                                                         tuningLabel: request.tuningLabel ?? ""),
                           context: try makeContext())
        XCTAssertEqual(lick.transcription, stored, "unchanged, so not re-dated either")
    }

    // MARK: - Frets placed before the shift changed (Q5)

    func testFretsPlacedBeforeTheSongWasRaisedAreOfferedAMoveUp() throws {
        let heard = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 2, fret: 5)),
                                              .init(seconds: 2, label: .pitchClass(4))],
                                       openMidi: standard, tuningLabel: "Guitar · Standard").moved(by: 1)
        let offer = try XCTUnwrap(PieceRefret.offer(for: heard, playerStrings: standard, songShift: 1))
        XCTAssertEqual(offer.semitones, 1)
        XCTAssertEqual(offer.stuck, [])
        XCTAssertEqual(offer.applied(to: heard.labels), [.fretted(string: 2, fret: 6), .pitchClass(5)])
        XCTAssertEqual(offer.button, "Move them up 1")
        XCTAssertEqual(offer.line(playerTuning: "Standard"),
                       "These frets were placed before the song's pitch changed. In Standard they sound "
                       + "1 semitone under what you hear.")
    }

    /// An open string lowered has no fret to go to, so it asks rather than guessing another string.
    func testAnOpenStringLoweredCantMoveAndIsLeftToName() throws {
        let leadIn = FrettedNote(string: 1, fret: 3, leadIn: LeadIn(from: .fret(1), join: .legato))
        let heard = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 5, fret: 0)),
                                              .init(seconds: 2, label: .fretted([leadIn], into: nil)),
                                              .init(seconds: 3, label: .fretted(string: 0, fret: 22))],
                                       openMidi: standard.map { $0 - 1 }, tuningLabel: "Guitar · Half step down")
        let offer = try XCTUnwrap(PieceRefret.offer(for: heard, playerStrings: standard, songShift: -1))
        XCTAssertEqual(offer.semitones, -1)
        XCTAssertEqual(offer.stuck, [0], "the open low E")
        let moved = offer.applied(to: heard.labels)
        XCTAssertNil(moved[0], "left for the player to name")
        let movedLeadIn = FrettedNote(string: 1, fret: 2, leadIn: LeadIn(from: .fret(0), join: .legato))
        XCTAssertEqual(moved[1], .fretted([movedLeadIn], into: nil), "a lead-in moves with its note")
        XCTAssertEqual(moved[2], .fretted(string: 0, fret: 21))
        XCTAssertEqual(offer.stuckMessage, "Note 1 can't move: on its string it would be lower than the open "
                       + "string. The rest move, and note 1 is left for you to name again.")
    }

    func testNothingIsOfferedWhenTheFretsMatchOrTheSongIsntShifted() {
        let onPlayersStrings = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 2, fret: 5))],
                                                  openMidi: standard, tuningLabel: "Guitar · Standard")
        XCTAssertNil(PieceRefret.offer(for: onPlayersStrings, playerStrings: standard, songShift: 1),
                     "named at the song's shift: heard on exactly the player's strings")
        let retunedSince = PieceTranscription(taps: onPlayersStrings.taps, openMidi: halfStepDown,
                                              tuningLabel: "Guitar · Half step down")
        XCTAssertNil(PieceRefret.offer(for: retunedSince, playerStrings: standard, songShift: 0),
                     "a new tuning keeps the frets (ADR 0227): only a song's shift offers a move")
        XCTAssertNil(PieceRefret.offer(for: onPlayersStrings, playerStrings: dropD, songShift: 1),
                     "a different tuning isn't one move")
        let byEar = PieceTranscription(taps: [.init(seconds: 1, label: .pitchClass(4))])
        XCTAssertNil(PieceRefret.offer(for: byEar, playerStrings: standard, songShift: 1))
    }

    func testTheModelOffersTheMoveWhenItOpensTheSheet() throws {
        UserDefaults.standard.removeObject(forKey: AppSettings.Key.tunerTuning)
        let lick = loop(on: song(shift: 1))
        lick.transcription = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(string: 2, fret: 5))],
                                                openMidi: standard, tuningLabel: "Guitar · Standard")
        let model = CountTheNotesModel(loop: lick)
        model.nameSaved()
        XCTAssertEqual(model.naming?.refret?.semitones, 1)
    }

    // MARK: - The archive (D4, ADR 0188)

    private func archive(_ songs: [SongRecord]) -> PracticeArchive {
        PracticeArchive(exportedAt: Date(timeIntervalSinceReferenceDate: 800_000_000), appVersion: "1.5",
                        includesTakeAudio: false, songs: songs)
    }

    func testTheShiftTravelsInTheArchiveAndIsAbsentAtZero() throws {
        let raised = song(shift: 1)
        XCTAssertEqual(ArchiveBuilder.songRecord(raised).pitchShift, 1)
        XCTAssertNil(ArchiveBuilder.songRecord(song()).pitchShift, "a song as recorded exports as it did")
        let landing = ArchiveRestoreWriter.materialize(archive([ArchiveBuilder.songRecord(raised)]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.songs.first?.pitchShift, 1)
        let received = Song(title: "Copy", duration: 100, ref: SongRef(id: "copy", source: .localFile, bookmark: nil))
        ReceivedSongBuilder.apply(ArchiveBuilder.songRecord(raised), to: received)
        XCTAssertEqual(received.pitchShift, 1, "a shared song arrives raised, and its chip says so")
    }

    /// Encoded for real and stripped, as `BeatMapArchiveTests` does: one missing key mustn't fail the file.
    func testAnArchiveFromBeforeTheShiftReadsZero() throws {
        let data = try ArchiveBuilder.encode(archive([ArchiveBuilder.songRecord(song(shift: 2))]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let songs = try XCTUnwrap(object["songs"] as? [[String: Any]])
        XCTAssertEqual(songs.first?["pitchShift"] as? Int, 2)
        object["songs"] = songs.map { song in
            var song = song
            song.removeValue(forKey: "pitchShift")
            return song
        }
        let read = try ArchiveBuilder.decode(JSONSerialization.data(withJSONObject: object))
        let record = try XCTUnwrap(read.songs.first)
        XCTAssertNil(record.pitchShift)
        let landing = ArchiveRestoreWriter.materialize(archive([record]), existing: RestoreExistingKeys())
        XCTAssertEqual(landing.songs.first?.pitchShift, 0)
    }

    // MARK: - Active listening on a moved song (D1, D3)

    func testActiveListeningCountsFromTheSongAsItPlays() {
        let atZero = HeardKey(recording: .gMinor, shift: 0, song: 1)
        XCTAssertEqual(atZero.line, "G♯ minor · song raised 1")
        XCTAssertEqual(HeardKey(recording: .unknown, shift: 0, song: -2).line, "Song lowered 2")
        let moved = HeardKey(recording: .gMinor, shift: 3, song: 1)
        XCTAssertEqual(moved.heard, .bMinor)
        XCTAssertEqual(moved.line, "B minor · 3 up")
        XCTAssertEqual(moved.namingLine, "Naming in B minor · your names in G♯ minor stay as they are",
                       "the saved names are shown at the song's shift, so that's the key they're in")
        XCTAssertEqual(HeardKey(recording: .gMinor, shift: -7, song: 1).line,
                       "C♯ minor · 7 down · same key as 5 up")
    }
}
