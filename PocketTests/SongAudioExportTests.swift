import XCTest
@testable import Pocket

/// A song's audio on its own (ADR 0236 D3): only the copy Red Moon keeps, named for the song.
///
/// Over an **uninserted** `Song` (the XCTest host's insert trap), with a real file written into
/// `SongFileStore` and removed afterwards, since "is the copy on disk" is the question.
final class SongAudioExportTests: XCTestCase {

    private func song(title: String, audioFileName: String?) -> Song {
        Song(title: title, duration: 81, ref: SongRef(id: UUID().uuidString, source: .localFile),
             audioFileName: audioFileName)
    }

    private func writeCopy(named leaf: String) throws -> URL {
        let url = try SongFileStore.url(for: leaf)
        try Data(repeating: 0x41, count: 64).write(to: url)
        return url
    }

    func testASongWithItsOwnCopyExportsItUnderItsTitle() throws {
        let leaf = "\(UUID().uuidString).mp3"
        let kept = try writeCopy(named: leaf)
        defer { try? FileManager.default.removeItem(at: kept) }

        let file = try XCTUnwrap(song(title: "Slow Bend", audioFileName: leaf).exportedAudioFile())
        XCTAssertEqual(file.source, kept)
        XCTAssertEqual(file.fileName, "Slow Bend.mp3")
        XCTAssertTrue(file.contentType.conforms(to: .mp3))
    }

    /// A legacy song, linked to a file elsewhere and not yet copied in, offers nothing until it has
    /// played once and adopted its copy.
    func testASongWithNoCopyOfItsOwnHasNoExport() {
        XCTAssertNil(song(title: "Slow Bend", audioFileName: nil).exportedAudioFile())
    }

    /// A copy the model claims but the disk doesn't have is no copy (ADR 0182).
    func testAClaimedCopyThatIsGoneHasNoExport() {
        XCTAssertNil(song(title: "Slow Bend", audioFileName: "\(UUID().uuidString).mp3").exportedAudioFile())
    }

    func testAnUntitledSongIsCalledSong() throws {
        let leaf = "\(UUID().uuidString).m4a"
        let kept = try writeCopy(named: leaf)
        defer { try? FileManager.default.removeItem(at: kept) }

        XCTAssertEqual(song(title: "  ", audioFileName: leaf).exportedAudioFile()?.fileName, "Song.m4a")
    }
}
