import XCTest
@testable import Pocket

/// The `.redmoonpack` (ADR 0236 D8): written by `ArchiveWriter.zip`, read by `ZipArchiveReader`, against
/// real files. **A pack this writes, never a fixture** (ADR 0188 D8): the zip method is part of the
/// format, and the day it changes is the day these fail.
///
/// `@MainActor` per test, not on the class: CI's toolchain refuses `setUp`/`tearDown` overrides in a
/// main-actor test class.
final class PracticePackTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "PracticePackTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func audio(_ leaf: String, bytes: Int = 50_000) throws -> URL {
        let url = root.appending(path: leaf, directoryHint: .notDirectory)
        // Not one repeated byte: audio barely compresses, and the test should move real-sized bytes.
        try Data((0..<bytes).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }).write(to: url)
        return url
    }

    @MainActor
    private func songPayload(leaf: String = "sender-id.mp3", version: Int = SharedPractice.currentSchemaVersion)
        -> SharedPractice {
        let song = Song(title: "Slow Bend", artist: "Jack Trader", duration: 81,
                        ref: SongRef(id: "sender-id", source: .localFile), audioFileName: leaf)
        song.loops = [Loop(name: "Chorus", start: 0.2, end: 0.4, speed: 0.8, repeats: 4)]
        var payload = SharedSongBuilder.payload(song, senderName: "Tomisin", appVersion: "1.3 (7)")
        payload.schemaVersion = version
        return payload
    }

    private func write(_ payload: SharedPractice, audio: [String: URL]) throws -> URL {
        try PracticePack.write(payload, audio: audio, named: "Slow Bend", temporaryDirectory: root)
    }

    // MARK: - Round trip

    @MainActor
    func testAPackComesBackAsItWent() throws {
        let source = try audio("sender-id.mp3")
        let sent = songPayload()
        let pack = try write(sent, audio: ["sender-id.mp3": source])
        XCTAssertEqual(pack.lastPathComponent, "Slow Bend.redmoonpack")

        let contents = try PracticePack.read(pack, into: root.appending(path: "in", directoryHint: .isDirectory))
        XCTAssertEqual(contents.payload, sent.withExportedAt(contents.payload.exportedAt))
        let unpacked = try XCTUnwrap(contents.audio["sender-id.mp3"])
        XCTAssertEqual(try Data(contentsOf: unpacked), try Data(contentsOf: source))
    }

    /// One file goes out: the staging tree it was built from is gone.
    @MainActor
    func testOnlyThePackIsLeft() throws {
        let pack = try write(songPayload(), audio: ["sender-id.mp3": try audio("sender-id.mp3")])
        let beside = try FileManager.default.contentsOfDirectory(atPath: pack.deletingLastPathComponent().path)
        XCTAssertEqual(beside, ["Slow Bend.redmoonpack"])
    }

    @MainActor
    func testAReceivedPackIsASongReadyToPreview() throws {
        let pack = try write(songPayload(), audio: ["sender-id.mp3": try audio("sender-id.mp3")])
        let staging = root.appending(path: "in", directoryHint: .isDirectory)
        let contents = try PracticePack.read(pack, into: staging)
        guard case let .success(.song(received)) = ReceivedPracticeBuilder.evaluate(contents, staging: staging) else {
            return XCTFail("a song pack didn't read as a song")
        }
        XCTAssertEqual(received.displayTitle, "Slow Bend")
        XCTAssertEqual(received.senderName, "Tomisin")
        XCTAssertEqual(received.record.loops.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: received.audio.path(percentEncoded: false)))
    }

    // MARK: - What a pack must not do

    /// A newer build's pack is turned away before any audio is unpacked.
    @MainActor
    func testAPackFromTheFutureIsRefusedBeforeItsAudio() throws {
        let pack = try write(songPayload(version: SharedPractice.currentSchemaVersion + 1),
                             audio: ["sender-id.mp3": try audio("sender-id.mp3")])
        let staging = root.appending(path: "in", directoryHint: .isDirectory)
        XCTAssertThrowsError(try PracticePack.read(pack, into: staging)) { error in
            guard case ReceiveFailure.futureVersion = error else { return XCTFail("\(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path(percentEncoded: false)))
    }

    @MainActor
    func testASongWhoseAudioIsMissingIsIncomplete() throws {
        let pack = try write(songPayload(), audio: [:])
        XCTAssertThrowsError(try PracticePack.read(pack, into: root.appending(path: "in"))) { error in
            XCTAssertEqual(error as? ReceiveFailure, .incomplete(.song))
        }
    }

    @MainActor
    func testSomethingThatIsntAZipIsCorrupt() throws {
        let fake = root.appending(path: "fake.redmoonpack")
        try Data("not a zip".utf8).write(to: fake)
        XCTAssertThrowsError(try PracticePack.read(fake, into: root.appending(path: "in"))) { error in
            XCTAssertEqual(error as? ReceiveFailure, .corrupt)
        }
    }

    /// Nothing unpacked from a pack can land outside the folder it's unpacked into.
    @MainActor
    func testASongsFileMustBeAPlainName() {
        XCTAssertTrue(PracticePack.isPlainName("sender-id.mp3"))
        XCTAssertFalse(PracticePack.isPlainName("../escape.mp3"))
        XCTAssertFalse(PracticePack.isPlainName("songs/inner.mp3"))
        XCTAssertFalse(PracticePack.isPlainName(".."))
        XCTAssertFalse(PracticePack.isPlainName(""))
    }

    /// A song only travels beside its audio: one in a bare `.redmoonpractice` has nothing to play.
    @MainActor
    func testASongInABareFileIsIncomplete() throws {
        let data = try ArchiveCoding.encode(songPayload())
        XCTAssertEqual(ReceivedPracticeBuilder.evaluate(data: data), .failure(.incomplete(.song)))
    }
}

private extension SharedPractice {
    /// The same payload with another write time: `ArchiveCoding` writes dates to the second.
    func withExportedAt(_ date: Date) -> SharedPractice {
        var copy = self
        copy.exportedAt = date
        return copy
    }
}
