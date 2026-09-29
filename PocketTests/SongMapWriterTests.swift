import XCTest
import SwiftData
@testable import Pocket

/// What the song map writes (ADR 0232 D9, D14–D17), in a real in-memory store: above all, that its Undo
/// takes back only the loops it made, so a loop made on the waveform can't be lost from the map.
@MainActor
final class SongMapWriterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var song: Song!
    /// A loop made on the waveform: the verse's first four bars, counted.
    private var verse: Loop!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(for: Song.self, Loop.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        song = Song(title: "Slow Bend", duration: 64, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        context.insert(song)
        verse = Loop(name: "Verse changes", start: 8.0 / 64, end: 16.0 / 64, speed: 0.8, repeats: 4)
        verse.loopType = .chords
        verse.transcription = PieceTranscription(taps: [.init(seconds: 8.25, label: .chord(root: 0, suffix: "")),
                                                        .init(seconds: 12.25, label: .chord(root: 7, suffix: ""))])
        context.insert(verse)
        verse.song = song
    }

    override func tearDown() async throws {
        verse = nil
        song = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    private func target(_ start: TimeInterval, _ end: TimeInterval, _ name: String) -> SongMapCopy.Target {
        SongMapCopy.Target(start: start, end: end, title: name, place: nil, name: name, alongside: [])
    }

    func testUndoTakesBackWhatTheMapMadeAndNothingElse() throws {
        let gap = SongMap.Gap(layer: .chords, start: 40, end: 52, name: "Bridge chords")
        let made = try XCTUnwrap(SongMapWriter.make(gap, in: song, context: context))
        let copies = SongMapWriter.copy(verse, into: [target(24, 40, "Chorus chords"), target(52, 64, "Outro chords")],
                                        grid: nil, in: song, context: context)
        XCTAssertEqual(copies.count, 2)
        XCTAssertEqual(song.loops.count, 4)

        SongMapWriter.takeBack(Set([made.uid] + copies.map(\.uid)), from: song, context: context)
        try context.save()
        XCTAssertEqual(song.loops.map(\.uid), [verse.uid], "the waveform's loop is still there")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Loop>()).map(\.uid), [verse.uid], "and nothing else is")
        XCTAssertNotNil(verse.transcription, "with its piece")
    }

    func testUndoAfterOneMadePieceLeavesTheWaveformsLoop() throws {
        let gap = SongMap.Gap(layer: .notes, start: 40, end: 52, name: "Bridge notes")
        let made = try XCTUnwrap(SongMapWriter.make(gap, in: song, context: context))
        SongMapWriter.takeBack([made.uid], from: song, context: context)
        XCTAssertEqual(song.loops.map(\.uid), [verse.uid])
    }

    func testAMadePieceFillsItsGapAndIsTypedByItsLane() throws {
        let chords = try XCTUnwrap(SongMapWriter.make(SongMap.Gap(layer: .chords, start: 40, end: 52,
                                                                   name: "Bridge chords"), in: song, context: context))
        XCTAssertEqual(chords.start * 64, 40, accuracy: 1e-9)
        XCTAssertEqual(chords.end * 64, 52, accuracy: 1e-9)
        XCTAssertEqual(chords.loopType, .chords)
        XCTAssertNil(chords.transcription, "empty until it's counted")
        let notes = try XCTUnwrap(SongMapWriter.make(SongMap.Gap(layer: .notes, start: 40, end: 52,
                                                                  name: "Bridge notes"), in: song, context: context))
        XCTAssertNotEqual(notes.loopType, .chords)
    }

    func testACopyIsTypedAsItsSourceAndHoldsThePieceWrittenAcrossIt() throws {
        let copy = try XCTUnwrap(SongMapWriter.copy(verse, into: [target(24, 40, "Chorus chords")], grid: nil,
                                                    in: song, context: context).first)
        XCTAssertEqual(copy.name, "Chorus chords")
        XCTAssertEqual(copy.loopType, .chords)
        XCTAssertEqual(copy.speed, 1, "a new loop plays at full speed, not its source's")
        XCTAssertEqual(copy.transcription?.taps.map(\.seconds), [24.25, 28.25, 32.25, 36.25])
        XCTAssertTrue(copy.song === song)
        XCTAssertEqual(verse.transcription?.taps.map(\.seconds), [8.25, 12.25], "the source is untouched")
    }

    func testRepeatsSetTheSwitchAndHowFarAndClearBoth() {
        let chorus = UUID()
        SongMapWriter.setRepeats(verse.uid, .through(chorus), in: song)
        XCTAssertTrue(verse.repeatsToSectionEnd)
        XCTAssertEqual(verse.repeatsTo, chorus.uuidString)
        SongMapWriter.setRepeats(verse.uid, .sectionEnd, in: song)
        XCTAssertNil(verse.repeatsTo, "its own section is stored as nothing")
        SongMapWriter.setRepeats(verse.uid, nil, in: song)
        XCTAssertFalse(verse.repeatsToSectionEnd)
        XCTAssertNil(verse.repeatsTo)
    }
}
