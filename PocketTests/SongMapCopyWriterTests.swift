import XCTest
import SwiftData
@testable import Pocket

/// What the map does to a copy it made (ADR 0310 D4, D5), in a real in-memory store: a shift restamps it and
/// Undo puts it back, and Remove copy removes only a copy still as the map made it, never a loop the player
/// has made theirs, and never the one the waveform is playing.
@MainActor
final class SongMapCopyWriterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var song: Song!
    /// A loop made on the waveform: the verse's first four bars, counted.
    private var verse: Loop!
    /// 120 BPM in 4/4: a bar every 2 s.
    private let grid = SongMapInput.Grid(downbeats: Array(stride(from: 0, to: 64, by: 2)), barSeconds: 2)

    /// Built in the test rather than in `setUp`: the class is `@MainActor` and `XCTestCase.setUp` is not,
    /// which CI's Swift 6 compiler refuses.
    private func prepare() throws {
        container = try ModelContainer(for: Song.self, Loop.self, Routine.self, RoutineItem.self, PracticeRun.self,
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

    /// The verse copied to the chorus, 24–40.
    private func copyToChorus() throws -> Loop {
        let chorus = SongMapCopy.Target(start: 24, end: 40, title: "Chorus", place: nil, name: "Chorus chords",
                                        alongside: [])
        return try XCTUnwrap(SongMapWriter.copy(verse, into: [chorus], grid: grid, in: song, context: context).first)
    }

    private func isTheMaps(_ loop: Loop) -> Bool { SongMapCopy.isTheMaps(SongMapWriter.standing(of: loop)) }

    // MARK: - D4

    func testAShiftMovesTheCopyRestampsItAndUndoPutsItBack() throws {
        try prepare()
        let copy = try copyToChorus()
        let before = try XCTUnwrap(copy.transcription)
        XCTAssertEqual(before.taps.map(\.seconds), [24.25, 28.25, 32.25, 36.25])

        let undo = try XCTUnwrap(SongMapWriter.shift(copy.uid, by: 1, grid: grid, in: song))
        XCTAssertEqual(copy.transcription?.taps.map(\.seconds), [24.75, 28.75, 32.75, 36.75])
        XCTAssertTrue(isTheMaps(copy), "a shift is the map's own, so the copy is still the map's")
        XCTAssertEqual(undo, before)

        SongMapWriter.restore(undo, to: copy.uid, in: song)
        XCTAssertEqual(copy.transcription, before)
        XCTAssertTrue(isTheMaps(copy))
    }

    func testOnlyTheMapsCopyShifts() throws {
        try prepare()
        XCTAssertNil(SongMapWriter.shift(verse.uid, by: 1, grid: grid, in: song), "a loop the player counted")
        XCTAssertEqual(verse.transcription?.taps.map(\.seconds), [8.25, 12.25])
    }

    // MARK: - D5

    func testRemoveCopyRemovesTheMapsCopyAndNothingElse() throws {
        try prepare()
        let copy = try copyToChorus()
        XCTAssertTrue(SongMapWriter.removeCopy(copy.uid, held: nil, from: song, context: context))
        try context.save()
        XCTAssertEqual(song.loops.map(\.uid), [verse.uid])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Loop>()).map(\.uid), [verse.uid])
        XCTAssertFalse(SongMapWriter.removeCopy(verse.uid, held: nil, from: song, context: context),
                       "a loop made on the waveform is never removed from the map")
        XCTAssertEqual(song.loops.count, 1)
    }

    func testACopyNamedSinceIsThePlayersAndStays() throws {
        try prepare()
        let copy = try copyToChorus()
        var piece = try XCTUnwrap(copy.transcription)
        piece.taps[0].label = .chord(root: 9, suffix: "m")
        piece.changedAt = .now.addingTimeInterval(5)
        copy.transcription = piece
        XCTAssertFalse(isTheMaps(copy))
        XCTAssertFalse(SongMapWriter.removeCopy(copy.uid, held: nil, from: song, context: context))
        XCTAssertNil(SongMapWriter.shift(copy.uid, by: 1, grid: grid, in: song))
    }

    func testTheLoopTheWaveformIsPlayingIsNeverRemoved() throws {
        try prepare()
        let copy = try copyToChorus()
        XCTAssertFalse(SongMapWriter.removeCopy(copy.uid, held: copy.uid, from: song, context: context))
        XCTAssertTrue(song.loops.contains { $0.uid == copy.uid })
    }

    func testACopyPractisedOrInARoutineStaysThoughTheLoopDoesntKnow() throws {
        try prepare()
        let practised = try copyToChorus()
        // Saved in a context of its own, as a run is: the loop's relationships don't hear of it.
        let other = ModelContext(container)
        other.insert(PracticeRun(startedAt: .now, durationSeconds: 60, kind: .loop, unitUID: practised.uid))
        try other.save()
        XCTAssertTrue(isTheMaps(practised), "the loop alone can't tell")
        XCTAssertFalse(SongMapWriter.removeCopy(practised.uid, held: nil, from: song, context: context))

        let blocked = try copyToChorus()
        let item = RoutineItem(kind: .focused)
        context.insert(item)
        item.loop = blocked
        try context.save()
        XCTAssertFalse(SongMapWriter.removeCopy(blocked.uid, held: nil, from: song, context: context))
        XCTAssertEqual(song.loops.count, 3)
    }

    func testACopyPractisedOnTheWaveformIsThePlayers() throws {
        try prepare()
        let copy = try copyToChorus()
        copy.lastPracticedSpeed = 0.8
        XCTAssertFalse(isTheMaps(copy), "practised")
    }
}
