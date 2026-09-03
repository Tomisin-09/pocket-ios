import XCTest
@testable import Pocket

/// Putting an archive's files back on disk (ADR 0188 D7).
///
/// Real files in a throwaway directory rather than a mocked `FileManager`, for `ArchiveWriterTests`'
/// reason: the three things most likely to be wrong here — that the bytes are the right bytes, that an
/// existing file is left alone, that a bad name never becomes a path — are all properties of the
/// filesystem and none of them survive being mocked away.
final class ArchiveRestoreFilesTests: XCTestCase {

    private var root: URL!
    private var source: URL!
    private var destination: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "RestoreFilesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        source = root.appending(path: "Staging", directoryHint: .isDirectory)
        destination = root.appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A zip holding one take, built by the real exporter so the bytes under test travelled the way a
    /// player's would.
    private func archiveHolding(_ files: [String: Data]) throws -> (ZipArchiveReader, [String: ZipEntry]) {
        var takes: [RecordingRecord] = []
        for (name, bytes) in files {
            try bytes.write(to: source.appending(path: name, directoryHint: .notDirectory))
            takes.append(RecordingRecord(uid: UUID(), createdAt: ArchiveFixture.date, duration: 1,
                                         title: nil, note: nil, fileName: name, ownerLabelAtTake: nil,
                                         loopUID: nil, exerciseUID: nil, songSourceID: nil, moments: []))
        }
        let archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.2 (5)",
                                      includesTakeAudio: true, takes: takes)
        let exported = try ArchiveWriter.write(archive, takesDirectory: source,
                                               fileManager: .default, temporaryDirectory: root)
        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        return (reader, reader.entries(inDirectoryNamed: "takes"))
    }

    func testTakeAudioIsWrittenOutByteForByte() throws {
        let bytes = Data(repeating: 0x37, count: 5000)
        let (zip, entries) = try archiveHolding(["take.m4a": bytes])

        let outcome = ArchiveRestoreFiles.write(takes: entries, attachments: [:], from: zip,
                                                takesDirectory: destination, attachmentsDirectory: nil)

        XCTAssertEqual(outcome.written, ["take.m4a"])
        XCTAssertTrue(outcome.isClean)
        let landed = try Data(contentsOf: destination.appending(path: "take.m4a", directoryHint: .notDirectory))
        XCTAssertEqual(landed, bytes)
    }

    /// The failure mode this guards is specific: a leaf is `<uid>.<ext>`, so a name already on disk is
    /// the same row's own audio. Overwriting truncates the real file first, which would make a restore
    /// destroy the take it was restoring.
    func testAFileAlreadyOnDiskIsLeftAlone() throws {
        let (zip, entries) = try archiveHolding(["take.m4a": Data(repeating: 0x37, count: 5000)])
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let existing = Data("the real recording".utf8)
        try existing.write(to: destination.appending(path: "take.m4a", directoryHint: .notDirectory))

        let outcome = ArchiveRestoreFiles.write(takes: entries, attachments: [:], from: zip,
                                                takesDirectory: destination, attachmentsDirectory: nil)

        XCTAssertEqual(outcome.skipped, ["take.m4a"])
        XCTAssertTrue(outcome.written.isEmpty)
        let landed = try Data(contentsOf: destination.appending(path: "take.m4a", directoryHint: .notDirectory))
        XCTAssertEqual(landed, existing, "the file on disk wins")
    }

    /// Which makes a second restore of the same archive a no-op on disk, the same way D6 makes it one
    /// in the store.
    func testWritingTwiceChangesNothingTheSecondTime() throws {
        let (zip, entries) = try archiveHolding(["take.m4a": Data(repeating: 0x37, count: 1000)])

        let first = ArchiveRestoreFiles.write(takes: entries, attachments: [:], from: zip,
                                              takesDirectory: destination, attachmentsDirectory: nil)
        let second = ArchiveRestoreFiles.write(takes: entries, attachments: [:], from: zip,
                                               takesDirectory: destination, attachmentsDirectory: nil)

        XCTAssertEqual(first.written, ["take.m4a"])
        XCTAssertEqual(second.skipped, ["take.m4a"])
        XCTAssertTrue(second.written.isEmpty)
    }

    /// A caller with no container writes nothing rather than guessing a path — `ArchiveWriter` takes
    /// the same position on the way out.
    func testNoDirectoryMeansNoFiles() throws {
        let (zip, entries) = try archiveHolding(["take.m4a": Data(repeating: 1, count: 10)])

        let outcome = ArchiveRestoreFiles.write(takes: entries, attachments: [:], from: zip,
                                                takesDirectory: nil, attachmentsDirectory: nil)
        XCTAssertTrue(outcome.written.isEmpty)
        XCTAssertTrue(outcome.isClean, "writing nothing on purpose is not a failure")
    }

    /// The second lock on the one operation in a restore that writes somewhere the player did not
    /// name. `ZipArchiveReader` rejects a traversal path at the door; this rejects a name that reached
    /// here anyway rather than letting `appending(path:)` read it as a directory separator.
    func testANameThatIsAPathIsRefusedRatherThanWritten() throws {
        let (zip, entries) = try archiveHolding(["take.m4a": Data(repeating: 1, count: 10)])
        let entry = try XCTUnwrap(entries["take.m4a"])

        let outcome = ArchiveRestoreFiles.write(takes: ["../escape.m4a": entry, "..": entry],
                                                attachments: [:], from: zip,
                                                takesDirectory: destination, attachmentsDirectory: nil)

        XCTAssertEqual(outcome.failed.sorted(), ["..", "../escape.m4a"])
        XCTAssertTrue(outcome.written.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "escape.m4a").path))
    }

    /// Pictures and audio go to different directories, and a caller that has one container and not the
    /// other writes only what it can.
    func testAttachmentsGoToTheirOwnDirectory() throws {
        let (zip, entries) = try archiveHolding(["take.m4a": Data(repeating: 9, count: 64)])
        let attachments = root.appending(path: "References", directoryHint: .isDirectory)

        let outcome = ArchiveRestoreFiles.write(takes: [:], attachments: entries, from: zip,
                                                takesDirectory: nil, attachmentsDirectory: attachments)

        XCTAssertEqual(outcome.written, ["take.m4a"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: attachments.appending(path: "take.m4a", directoryHint: .notDirectory).path))
    }
}
