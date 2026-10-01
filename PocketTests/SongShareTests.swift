import XCTest
@testable import Pocket

/// A song sent to another Red Moon (ADR 0236 D4, D5): what its record keeps and drops on the way out, what
/// a received one is called, and how it lands with new uids. Over **uninserted** models (the XCTest host's
/// insert trap), as `ArchiveBuilderTests` reads them.
@MainActor
final class SongShareTests: XCTestCase {

    // MARK: - D5, the name

    func testANewTitleLandsAsItIs() {
        XCTAssertEqual(SongCopyName.title(for: "Slow Bend", sender: "Tomisin", existing: ["Low Road"]), "Slow Bend")
    }

    func testATitleTheLibraryHasLandsAsTheSendersCopy() {
        XCTAssertEqual(SongCopyName.title(for: "Low Road", sender: "Tomisin", existing: ["Low Road"]),
                       "Low Road - Tomisin copy")
    }

    /// Trimmed, and ignoring case: "low road " is the song the library already has.
    func testTheMatchIgnoresCaseAndSpace() {
        XCTAssertEqual(SongCopyName.title(for: "Low Road", sender: "Tomisin", existing: [" low road "]),
                       "Low Road - Tomisin copy")
    }

    func testNoArtistNameIsACopy() {
        XCTAssertEqual(SongCopyName.title(for: "Low Road", sender: nil, existing: ["Low Road"]), "Low Road - copy")
        XCTAssertEqual(SongCopyName.title(for: "Low Road", sender: "  ", existing: ["Low Road"]), "Low Road - copy")
    }

    /// Received again: numbered, the way Finder numbers copies.
    func testACopyThatIsTakenIsNumbered() {
        let library = ["Low Road", "Low Road - Tomisin copy", "Low Road - Tomisin copy 2"]
        XCTAssertEqual(SongCopyName.title(for: "Low Road", sender: "Tomisin", existing: library),
                       "Low Road - Tomisin copy 3")
    }

    func testAnUntitledSongIsNamed() {
        XCTAssertEqual(SongCopyName.title(for: " ", sender: nil, existing: []), "Untitled song")
    }

    // MARK: - D4, what leaves

    private func practisedSong() -> Song {
        let song = Song(title: "Slow Bend", artist: "Jack Trader", bpm: 92, collections: ["Gig"],
                        comment: "Capo 2", duration: 81, lastPracticed: .now,
                        ref: SongRef(id: "sender-id", source: .localFile), audioFileName: "sender-id.mp3")
        song.preciseBPM = 92.4
        song.lastPracticedSpeed = 0.8
        let verse = Marker(seconds: 0, label: "Verse")
        verse.startsSection = true
        let chorus = Marker(seconds: 30, label: "Chorus")
        chorus.startsSection = true
        let again = Marker(seconds: 60, label: "Verse 2")
        again.startsSection = true
        again.sameAsUID = verse.uid
        song.markers = [verse, chorus, again]
        let loop = Loop(name: "Chorus", start: 0.37, end: 0.5, speed: 0.7, repeats: 4)
        loop.mastery = 3
        loop.masteryAtSpeed = 0.85
        loop.commandTempo = 88
        loop.isFavorite = true
        loop.automatorEnabled = true
        loop.automatorTargetSpeed = 0.9
        loop.repeatsToSectionEnd = true
        loop.repeatsTo = SongMap.RepeatsTo.through(chorus.uid).stored
        loop.transcription = PieceTranscription(taps: [PieceTranscription.Tap(seconds: 31, label: .pitchClass(0))])
        song.loops = [loop]
        return song
    }

    func testTheSendersPracticeStaysWithThem() {
        let record = SharedSongBuilder.record(practisedSong())
        XCTAssertEqual(record.comment, "")
        XCTAssertEqual(record.collections, [])
        XCTAssertNil(record.lastPracticed)
        XCTAssertNil(record.lastPracticedSpeed)
        let loop = try? XCTUnwrap(record.loops.first)
        XCTAssertNil(loop?.mastery)
        XCTAssertNil(loop?.masteryAtSpeed)
        XCTAssertNil(loop?.commandTempo)
        XCTAssertNil(loop?.transcription, "a loop's piece is the song's tab, and stays")
        XCTAssertEqual(loop?.isFavorite, false)
    }

    func testTheSongsOwnSettingsGo() {
        let record = SharedSongBuilder.record(practisedSong())
        XCTAssertEqual(record.title, "Slow Bend")
        XCTAssertEqual(record.artist, "Jack Trader")
        XCTAssertEqual(record.preciseBPM, 92.4)
        XCTAssertEqual(record.audioFileName, "sender-id.mp3")
        XCTAssertEqual(record.markers.count, 3)
        XCTAssertEqual(record.loops.first?.speed, 0.7)
        XCTAssertEqual(record.loops.first?.automatorTargetSpeed, 0.9)
    }

    func testTheSendersNameIsTrimmedAndNoneIsNil() {
        XCTAssertEqual(SharedSongBuilder.senderName("  Tomisin "), "Tomisin")
        XCTAssertNil(SharedSongBuilder.senderName("   "))
        XCTAssertNil(SharedSongBuilder.senderName(nil))
        let payload = SharedSongBuilder.payload(practisedSong(), senderName: "Tomisin", appVersion: "1.3 (7)")
        XCTAssertEqual(payload.kind, .song)
        XCTAssertEqual(payload.senderName, "Tomisin")
        XCTAssertEqual(payload.songs?.count, 1)
    }

    // MARK: - D4, how it lands

    private func landed(from record: SongRecord) -> Song {
        let song = Song(title: "Slow Bend", duration: 81, ref: SongRef(id: "receiver-id", source: .localFile))
        ReceivedSongBuilder.apply(record, to: song)
        return song
    }

    func testEveryUidIsMintedFresh() {
        let record = SharedSongBuilder.record(practisedSong())
        let song = landed(from: record)
        XCTAssertTrue(Set(song.markers.map(\.uid)).isDisjoint(with: record.markers.map(\.uid)))
        XCTAssertTrue(Set(song.loops.map(\.uid)).isDisjoint(with: record.loops.map(\.uid)))
    }

    /// "Same as" and "repeats through" follow their sections to the new uids.
    func testLinksBetweenSectionsFollowToTheNewUids() throws {
        let song = landed(from: SharedSongBuilder.record(practisedSong()))
        let verse = try XCTUnwrap(song.markers.first { $0.label == "Verse" })
        let chorus = try XCTUnwrap(song.markers.first { $0.label == "Chorus" })
        let again = try XCTUnwrap(song.markers.first { $0.label == "Verse 2" })
        XCTAssertEqual(again.sameAsUID, verse.uid)
        XCTAssertEqual(song.loops.first?.repeatsTo, SongMap.RepeatsTo.through(chorus.uid).stored)
        XCTAssertTrue(chorus.startsSection)
    }

    /// A receive trusts nothing: mastery in the file is not read, whoever wrote it.
    func testAStrangersMasteryIsNeverRead() {
        var record = SharedSongBuilder.record(practisedSong())
        record.loops[0].mastery = 5
        record.loops[0].commandTempo = 120
        let loop = landed(from: record).loops.first
        XCTAssertNil(loop?.mastery)
        XCTAssertNil(loop?.commandTempo)
        XCTAssertEqual(loop?.speed, 0.7)
        XCTAssertEqual(loop?.automatorEnabled, true)
    }

    func testTheGridAndMetadataLand() {
        let song = landed(from: SharedSongBuilder.record(practisedSong()))
        XCTAssertEqual(song.artist, "Jack Trader")
        XCTAssertEqual(song.preciseBPM, 92.4)
        XCTAssertEqual(song.collections, [])
        XCTAssertEqual(song.comment, "")
    }
}
