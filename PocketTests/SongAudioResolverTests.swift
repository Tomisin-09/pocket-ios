import XCTest
@testable import Pocket

/// How a song's audio is found (ADR 0148 §2/§3).
///
/// The behaviour under test is the reason the ADR exists: **an owned copy beats a bookmark, even a
/// dead one.** A library restored from a device backup has every bookmark dead and every copy
/// intact, and it must play. That was the failure found on device on 2026-08-07, and it is pinned
/// here so it can't come back quietly.
///
/// `Song` objects are built but never inserted into a context — inserting into a `ModelContainer`
/// traps in the XCTest host, and none of this logic needs persistence.
final class SongAudioResolverTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    /// Bookmark bytes that cannot resolve to anything — the state every song is left in by an app
    /// reinstall, since a bookmark encodes access granted to the installation that made it.
    private let deadBookmark = Data([0x00, 0x01, 0x02, 0x03])

    override func setUp() {
        super.setUp()
        fileManager = TempContainerFileManager()
    }

    override func tearDown() {
        fileManager.destroy()
        fileManager = nil
        super.tearDown()
    }

    private func makeSong(sourceID: String = "song-1",
                          bookmark: Data?,
                          audioFileName: String?) -> Song {
        Song(title: "Covered in Rain", duration: 313,
             ref: SongRef(id: sourceID, source: .localFile, bookmark: bookmark),
             audioFileName: audioFileName)
    }

    // MARK: - The owned copy

    func testResolvesTheOwnedCopyWithoutASecurityScope() throws {
        let source = try fileManager.makeSourceFile(named: "picked.m4a", contents: "audio")
        let leaf = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)
        let song = makeSong(bookmark: nil, audioFileName: leaf)

        let resolved = try XCTUnwrap(SongAudioResolver.resolve(song, fileManager))
        XCTAssertEqual(resolved.url.lastPathComponent, "song-1.m4a")
        XCTAssertNil(resolved.access, "a file inside our own container needs no security scope")
        XCTAssertFalse(resolved.isLegacyBookmark)
    }

    func testOwnedCopyWinsOverADeadBookmark() throws {
        // The restore-from-backup case, and the whole point of ADR 0148: the bookmark died with the
        // old installation, the copy came back with the container, and the song plays.
        let source = try fileManager.makeSourceFile(named: "picked.m4a", contents: "audio")
        let leaf = try SongFileStore.adopt(contentsOf: source, sourceID: "song-1", fileManager)
        let song = makeSong(bookmark: deadBookmark, audioFileName: leaf)

        let resolved = try XCTUnwrap(SongAudioResolver.resolve(song, fileManager))
        XCTAssertFalse(resolved.isLegacyBookmark, "the copy is preferred, not the fallback")
    }

    // MARK: - Nothing to resolve

    func testResolvesToNilWhenTheCopyIsGoneAndTheBookmarkIsDead() {
        // Both doors shut — the state that draws `AudioUnavailableNotice` and that relink repairs.
        let song = makeSong(bookmark: deadBookmark, audioFileName: "song-1.m4a")
        XCTAssertNil(SongAudioResolver.resolve(song, fileManager))
    }

    func testResolvesToNilForAPre0148SongWhoseBookmarkNoLongerWorks() {
        let song = makeSong(bookmark: deadBookmark, audioFileName: nil)
        XCTAssertNil(SongAudioResolver.resolve(song, fileManager))
    }

    func testResolvesToNilForTheDemoSampleWhichHasNoFileAtAll() {
        let song = makeSong(bookmark: nil, audioFileName: nil)
        XCTAssertNil(SongAudioResolver.resolve(song, fileManager))
    }

    // MARK: - What counts as an imported song

    func testASongWithOnlyACopyStillCountsAsImported() {
        // A relinked song can lose its bookmark entirely; it is still a real song, not the demo.
        let song = makeSong(bookmark: nil, audioFileName: "song-1.m4a")
        XCTAssertTrue(song.hasImportedAudio)
    }

    func testASongWithOnlyABookmarkStillCountsAsImported() {
        XCTAssertTrue(makeSong(bookmark: deadBookmark, audioFileName: nil).hasImportedAudio)
    }

    func testTheDemoSampleIsNotAnImportedSong() {
        XCTAssertFalse(makeSong(bookmark: nil, audioFileName: nil).hasImportedAudio)
    }

    // MARK: - Adoption (the migration)

    @MainActor
    func testALegacySongAdoptsItsFileOnFirstResolve() throws {
        let source = try fileManager.makeSourceFile(named: "picked.m4a", contents: "audio")
        let song = makeSong(bookmark: deadBookmark, audioFileName: nil)
        let resolved = ResolvedSongAudio(url: source, access: nil, isLegacyBookmark: true)

        SongAudioResolver.adoptIfNeeded(song, resolved: resolved, fileManager)

        XCTAssertEqual(song.audioFileName, "song-1.m4a")
        XCTAssertTrue(SongFileStore.exists(fileName: "song-1.m4a", fileManager))
    }

    @MainActor
    func testAdoptionIsSkippedForASongThatAlreadyOwnsItsCopy() throws {
        let source = try fileManager.makeSourceFile(named: "picked.m4a", contents: "audio")
        let song = makeSong(bookmark: nil, audioFileName: "song-1.m4a")
        let resolved = ResolvedSongAudio(url: source, access: nil, isLegacyBookmark: false)

        SongAudioResolver.adoptIfNeeded(song, resolved: resolved, fileManager)

        XCTAssertTrue(SongFileStore.filesOnDisk(fileManager).isEmpty,
                      "resolving an owned copy must not re-copy anything")
    }

    @MainActor
    func testAdoptionPreservesTheSongIdentityThatLoopsHangOff() throws {
        // ADR 0148 §4: whatever happens to the audio, `sourceID` — the identity loops, markers and
        // takes are attached to — must not move.
        let source = try fileManager.makeSourceFile(named: "picked.m4a", contents: "audio")
        let song = makeSong(sourceID: "stable-id", bookmark: deadBookmark, audioFileName: nil)
        let resolved = ResolvedSongAudio(url: source, access: nil, isLegacyBookmark: true)

        SongAudioResolver.adoptIfNeeded(song, resolved: resolved, fileManager)

        XCTAssertEqual(song.sourceID, "stable-id")
        XCTAssertEqual(song.ref.id, "stable-id")
    }
}
