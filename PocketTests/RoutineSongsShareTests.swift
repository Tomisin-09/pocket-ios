import XCTest
@testable import Pocket

/// A routine sent with its songs (ADR 0236 D6): which songs go, which blocks keep their ids and which
/// arrive as placeholders, how a received routine's blocks are bound to the songs that came with it and
/// to nothing else, and what each song is called. Over **uninserted** models (the XCTest host's insert
/// trap), as `ReceivedRoutineHydrationTests` reads them.
@MainActor
final class RoutineSongsShareTests: XCTestCase {

    // MARK: - Fixture

    private struct Sitting {
        let routine: Routine
        let bend: Song
        let chorus: Loop
        let road: Song
        let verse: Loop
    }

    /// A loop block on *Slow Bend*, a block playing *Slow Bend*, a rest, and a loop block on *Low Road*.
    private func sitting() -> Sitting {
        let bend = song("Slow Bend", id: "bend-id")
        let chorus = loop("Chorus", on: bend)
        let road = song("Low Road", id: "road-id")
        let verse = loop("Verse", on: road)
        let routine = Routine(name: "Tuesday lesson")
        routine.items = [RoutineItem.item(chorus, order: 0), RoutineItem.item(bend, order: 1),
                         RoutineItem.rest(order: 2), RoutineItem.item(verse, order: 3)]
        return Sitting(routine: routine, bend: bend, chorus: chorus, road: road, verse: verse)
    }

    private func song(_ title: String, id: String) -> Song {
        Song(title: title, artist: "Jack Trader", duration: 120,
             ref: SongRef(id: id, source: .localFile), audioFileName: "\(id).mp3")
    }

    /// Both sides set, and the second only if the first didn't: nothing here is inserted, and whether an
    /// uninserted model keeps its inverse isn't something these tests should rest on.
    private func loop(_ name: String, on song: Song) -> Loop {
        let loop = Loop(name: name, start: 0.2, end: 0.4, speed: 0.75, repeats: 4)
        loop.mastery = 3
        loop.transcription = PieceTranscription(taps: [PieceTranscription.Tap(seconds: 30, label: .pitchClass(0))])
        loop.song = song
        if !song.loops.contains(where: { $0 === loop }) { song.loops.append(loop) }
        return loop
    }

    private func payload(_ sitting: Sitting, songs: [Song]) -> SharedPractice {
        SharedPracticeBuilder.routine(sitting.routine, appVersion: "1.3 (8)", senderName: "Tomisin", songs: songs)
    }

    private func block(_ payload: SharedPractice, _ index: Int) throws -> RoutineItemRecord {
        try XCTUnwrap(payload.routine?.items.first { $0.order == index })
    }

    // MARK: - What goes

    /// Each song once, in the order the sitting first reaches it, whether a block plays it or a loop on it.
    func testTheSongsARoutinePlaysAreEachSongOnceInOrder() {
        XCTAssertEqual(SharedPracticeBuilder.songsPlayed(by: sitting().routine).map(\.title),
                       ["Slow Bend", "Low Road"])
    }

    func testABlockWhoseSongGoesKeepsItsIdAndIsNoPlaceholder() throws {
        let fixture = sitting()
        let sent = payload(fixture, songs: [fixture.bend])
        XCTAssertEqual(try block(sent, 0).loopUID, fixture.chorus.uid)
        XCTAssertEqual(try block(sent, 1).songSourceID, "bend-id")
        XCTAssertEqual(sent.songs?.map(\.title), ["Slow Bend"])
        XCTAssertEqual(sent.senderName, "Tomisin")
        XCTAssertEqual(sent.placeholders.map(\.label), ["Verse — Low Road"],
                       "only the block whose song stayed behind is a placeholder")
    }

    func testABlockWhoseSongStaysIsAPlaceholderWithNoIds() throws {
        let fixture = sitting()
        let sent = payload(fixture, songs: [fixture.bend])
        XCTAssertNil(try block(sent, 3).loopUID)
        XCTAssertNil(try block(sent, 3).songSourceID)
    }

    /// The switch off: the file is the one sent before ADR 0236, with the name added (D6).
    func testWithoutItsSongsTheFileIsAsItWas() throws {
        let fixture = sitting()
        let sent = payload(fixture, songs: [])
        XCTAssertNil(sent.songs)
        XCTAssertEqual(sent.placeholders.count, 3)
        XCTAssertNil(try block(sent, 0).loopUID)
        let json = try XCTUnwrap(String(data: try ArchiveCoding.encode(sent), encoding: .utf8))
        XCTAssertFalse(json.contains("\"songs\""), "no songs key, so the shape is the old one")

        let unsigned = SharedPracticeBuilder.routine(fixture.routine, appVersion: "1.3 (8)")
        let plain = try XCTUnwrap(String(data: try ArchiveCoding.encode(unsigned), encoding: .utf8))
        XCTAssertFalse(plain.contains("senderName"), "no name where no screen showed one")
    }

    /// A song in a routine carries no pieces and none of the sender's practice (D4, 0232 D10).
    func testASongInARoutineCarriesNoPiecesOrMastery() throws {
        let fixture = sitting()
        let loop = try XCTUnwrap(payload(fixture, songs: [fixture.bend]).songs?.first?.loops.first)
        XCTAssertNil(loop.transcription)
        XCTAssertNil(loop.mastery)
        XCTAssertEqual(loop.speed, 0.75)
    }

    // MARK: - How it lands

    private func received(_ payload: SharedPractice) throws -> ReceivedRoutine {
        let staging = URL(filePath: "/tmp/RoutineSongsShareTests", directoryHint: .isDirectory)
        let audio = Dictionary(uniqueKeysWithValues: (payload.songs ?? []).compactMap(\.audioFileName).map {
            ($0, staging.appending(path: $0, directoryHint: .notDirectory))
        })
        return try ReceivedRoutineBuilder.received(payload, audio: audio, staging: staging).get()
    }

    /// A song built as the host builds it, with a made-up import standing in for the audio read.
    private func landed(_ received: ReceivedRoutine) -> [LandedSong] {
        received.songs.map { song in
            let prepared = SongImporter.Prepared(title: song.displayTitle, duration: 120, amplitudes: [],
                                                 bookmark: nil, sourceID: UUID().uuidString,
                                                 audioFileName: "new.mp3")
            return ReceivedSongBuilder.landing(song, prepared: prepared, title: song.displayTitle)
        }
    }

    func testTheBlocksAreBoundToTheSongsThatCameWithIt() throws {
        let fixture = sitting()
        let value = try received(payload(fixture, songs: [fixture.bend, fixture.road]))
        XCTAssertEqual(value.senderName, "Tomisin")
        let songs = landed(value)
        let landing = ReceivedRoutineBuilder.materialize(value, songs: songs)

        // Through the landed songs' own maps, not `loop.song`: an uninserted loop's inverse isn't a thing
        // to rest on, and the host inserts the songs before the routine.
        let bend = try XCTUnwrap(songs.first { $0.song.title == "Slow Bend" })
        let road = try XCTUnwrap(songs.first { $0.song.title == "Low Road" })
        XCTAssertIdentical(landing.items[0].loop, bend.loops[fixture.chorus.uid])
        XCTAssertEqual(landing.items[0].loop?.name, "Chorus")
        XCTAssertIdentical(landing.items[1].song, bend.song)
        XCTAssertIdentical(landing.items[3].loop, road.loops[fixture.verse.uid])
        XCTAssertEqual(landing.items[3].loop?.name, "Verse")
        XCTAssertFalse(landing.items.contains(where: \.isOrphaned))
        XCTAssertEqual(landing.songs.count, 2, "the songs land with the routine")
    }

    /// Nothing a received block points at is the sender's: the loop is a new one, with a new uid.
    func testABoundLoopIsANewLoop() throws {
        let fixture = sitting()
        let value = try received(payload(fixture, songs: [fixture.bend]))
        let landing = ReceivedRoutineBuilder.materialize(value, songs: landed(value))
        let loop = try XCTUnwrap(landing.items[0].loop)
        XCTAssertNotEqual(loop.uid, fixture.chorus.uid)
        XCTAssertNil(loop.mastery)
    }

    /// A block's ids reach only the songs that came with it. With none landed, the ids in the file bind
    /// to nothing, and certainly not to a song in the receiver's library.
    func testIdsWithNoArrivedSongBehindThemBindToNothing() throws {
        let fixture = sitting()
        let value = try received(payload(fixture, songs: [fixture.bend]))
        let landing = ReceivedRoutineBuilder.materialize(value, songs: [])
        XCTAssertTrue(landing.items[0].isOrphaned)
        XCTAssertTrue(landing.items[1].isOrphaned)
    }

    func testABlockNamingALoopTheFileDoesntCarryIsAnOrphan() throws {
        let fixture = sitting()
        var sent = payload(fixture, songs: [fixture.bend])
        let index = try XCTUnwrap(sent.routine?.items.firstIndex { $0.order == 0 })
        sent.routine?.items[index].loopUID = UUID()
        let value = try received(sent)
        XCTAssertTrue(ReceivedRoutineBuilder.materialize(value, songs: landed(value)).items[0].isOrphaned)
    }

    /// The labelled placeholder still lands named beside a bound block (0188 D4).
    func testAPlaceholderBesideBoundBlocksKeepsItsName() throws {
        let fixture = sitting()
        let value = try received(payload(fixture, songs: [fixture.bend]))
        let item = ReceivedRoutineBuilder.materialize(value, songs: landed(value)).items[3]
        XCTAssertTrue(item.isOrphaned)
        XCTAssertEqual(item.orphanLabel, "Verse — Low Road")
    }

    // MARK: - What a receive refuses

    /// A sender only writes songs into a pack. A bare file that names them has none of their audio.
    func testABareFileThatNamesSongsIsIncomplete() throws {
        let fixture = sitting()
        let data = try ArchiveCoding.encode(payload(fixture, songs: [fixture.bend]))
        XCTAssertEqual(ReceivedPracticeBuilder.evaluate(data: data), .failure(.incomplete(.song)))
    }

    func testASongWhoseAudioIsntInThePackIsIncomplete() {
        let fixture = sitting()
        let result = ReceivedRoutineBuilder.received(payload(fixture, songs: [fixture.bend]), audio: [:],
                                                     staging: URL(filePath: "/tmp"))
        XCTAssertEqual(result.map(\.displayName), .failure(.incomplete(.song)))
    }

    // MARK: - Names (D5)

    /// Two songs sent under one title still land as two names, the second a copy.
    func testTwoSongsWithOneTitleLandUnderTwoNames() {
        XCTAssertEqual(SongCopyName.titles(for: ["Intro", "Intro"], sender: "Tomisin", existing: []),
                       ["Intro", "Intro - Tomisin copy"])
    }

    func testEachSongIsNamedAgainstTheLibrary() {
        XCTAssertEqual(SongCopyName.titles(for: ["Low Road", "Slow Bend"], sender: nil, existing: ["Low Road"]),
                       ["Low Road - copy", "Slow Bend"])
    }

    // MARK: - The pack

    /// A routine with two songs, written by the pack writer and read back by the reader, arrives with both
    /// songs' audio. A pack this writes, never a fixture (0188 D8).
    func testARoutinePackComesBackWithItsSongs() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "RoutineSongsShareTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var audio: [String: URL] = [:]
        for leaf in ["bend-id.mp3", "road-id.mp3"] {
            let url = root.appending(path: leaf, directoryHint: .notDirectory)
            try Data((0..<20_000).map { UInt8(truncatingIfNeeded: $0 &* 13 &+ leaf.count) }).write(to: url)
            audio[leaf] = url
        }
        let fixture = sitting()
        let pack = try PracticePack.write(payload(fixture, songs: [fixture.bend, fixture.road]), audio: audio,
                                          named: "Tuesday lesson", temporaryDirectory: root)
        XCTAssertEqual(pack.lastPathComponent, "Tuesday lesson.redmoonpack")

        let staging = root.appending(path: "in", directoryHint: .isDirectory)
        let contents = try PracticePack.read(pack, into: staging)
        guard case let .success(.routine(value)) = ReceivedPracticeBuilder.evaluate(contents, staging: staging) else {
            return XCTFail("a routine pack didn't read as a routine")
        }
        XCTAssertEqual(value.songs.map(\.displayTitle), ["Slow Bend", "Low Road"])
        for song in value.songs {
            let leaf = try XCTUnwrap(song.record.audioFileName)
            XCTAssertEqual(try Data(contentsOf: song.audio), try Data(contentsOf: try XCTUnwrap(audio[leaf])))
        }
    }
}
