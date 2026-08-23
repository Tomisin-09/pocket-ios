import XCTest
@testable import Pocket

/// What an export actually puts on disk, and what it leaves behind (ADR 0181).
///
/// These run against real files in a throwaway directory rather than a mocked `FileManager`, because
/// the three things most likely to be wrong here — that the hard link is really a link, that the zip
/// is really written, that nothing survives a failure — are all properties of the filesystem and none
/// of them survive being mocked away.
///
/// The staging tree is still inside `workingDirectory` when `write` returns (it is `cleanUp` that
/// takes both), so the archive's layout can be asserted directly instead of unzipping — which the
/// test host has no way to do.
final class ArchiveWriterTests: XCTestCase {

    private var root: URL!
    private var takesDirectory: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "ArchiveWriterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        takesDirectory = root.appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: takesDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    /// A take record plus the audio file it names, so the two are never accidentally out of step.
    @discardableResult
    private func makeTake(bytes: Int = 4096) throws -> RecordingRecord {
        let uid = UUID()
        let fileName = "\(uid.uuidString).m4a"
        try Data(repeating: 0x41, count: bytes)
            .write(to: takesDirectory.appending(path: fileName, directoryHint: .notDirectory))
        return RecordingRecord(uid: uid, createdAt: Date(timeIntervalSince1970: 1000), duration: 12,
                               title: "Take", note: nil, fileName: fileName, ownerLabelAtTake: nil,
                               loopUID: nil, exerciseUID: nil, songSourceID: nil, moments: [])
    }

    private func makeArchive(takes: [RecordingRecord], includesTakeAudio: Bool = true) -> PracticeArchive {
        PracticeArchive(exportedAt: Date(timeIntervalSince1970: 1_755_000_000),
                        appVersion: "1.2 (5)",
                        includesTakeAudio: includesTakeAudio,
                        takes: takes)
    }

    private func write(_ archive: PracticeArchive,
                       fileManager: FileManager = .default) throws -> ExportedArchive {
        try ArchiveWriter.write(archive,
                                takesDirectory: archive.includesTakeAudio ? takesDirectory : nil,
                                fileManager: fileManager,
                                temporaryDirectory: root)
    }

    /// The staged folder inside an export — `red-moon-practice-<day>/`.
    private func stagingRoot(of export: ExportedArchive) throws -> URL {
        let contents = try FileManager.default
            .contentsOfDirectory(at: export.workingDirectory, includingPropertiesForKeys: nil)
        return try XCTUnwrap(contents.first { $0.pathExtension != "zip" },
                             "the export should still hold its staging tree until cleanUp")
    }

    private func inode(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.systemFileNumber] as? Int)
    }

    // MARK: - The layout

    /// `practice.json` is the archive. If it does not decode back into the value that was written,
    /// nothing else here matters.
    func testTheArchiveHoldsAPracticeJSONThatDecodesBack() throws {
        let archive = makeArchive(takes: [try makeTake()])
        let export = try write(archive)

        let json = try stagingRoot(of: export)
            .appending(path: "practice.json", directoryHint: .notDirectory)
        XCTAssertEqual(try ArchiveBuilder.decode(Data(contentsOf: json)), archive)
    }

    /// The zip is the thing handed to the share sheet, so its absence is the one failure a player
    /// would meet directly.
    func testTheExportProducesANamedNonEmptyZip() throws {
        let export = try write(makeArchive(takes: [try makeTake()]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: export.zipURL.path))
        XCTAssertEqual(export.zipURL.pathExtension, "zip")
        XCTAssertTrue(export.zipURL.lastPathComponent.hasPrefix("red-moon-practice-"),
                      "got \(export.zipURL.lastPathComponent)")
        XCTAssertGreaterThan(export.byteCount, 0)
    }

    /// The join between `practice.json` and `takes/` is the file name. Every take the JSON names must
    /// have audio beside it, or the archive is a record of recordings that aren't there.
    func testEveryTakeNamedInTheArchiveHasItsAudioStaged() throws {
        let takes = [try makeTake(), try makeTake(), try makeTake()]
        let export = try write(makeArchive(takes: takes))

        let staged = try stagingRoot(of: export).appending(path: "takes", directoryHint: .isDirectory)
        for take in takes {
            let file = staged.appending(path: take.fileName, directoryHint: .notDirectory)
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), take.fileName)
        }
        XCTAssertEqual(export.takesWritten, 3)
        XCTAssertEqual(export.takesMissing, [])
    }

    // MARK: - The hard link

    /// A copy would double the recordings on disk before the zip is even written. Same volume, so the
    /// link is free — and the inode is the only way to tell the two apart after the fact.
    func testStagingLinksTheAudioRatherThanCopyingIt() throws {
        let take = try makeTake()
        let export = try write(makeArchive(takes: [take]))

        let source = takesDirectory.appending(path: take.fileName, directoryHint: .notDirectory)
        let staged = try stagingRoot(of: export)
            .appending(path: "takes", directoryHint: .isDirectory)
            .appending(path: take.fileName, directoryHint: .notDirectory)
        XCTAssertEqual(try inode(staged), try inode(source),
                       "a staged take should be a hard link to the original, not a second copy")
    }

    // MARK: - The choice, and the gaps

    /// *Include recordings* off must produce no `takes/` at all — not an empty one. An empty
    /// directory reads as "your recordings are gone", which is the opposite of what happened.
    func testExcludingRecordingsWritesNoTakesDirectory() throws {
        let take = try makeTake()
        let export = try write(makeArchive(takes: [take], includesTakeAudio: false))

        let staged = try stagingRoot(of: export).appending(path: "takes", directoryHint: .isDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(export.takesWritten, 0)
        XCTAssertEqual(export.takesMissing, [])

        // The take is still fully described in the JSON — only its audio is absent.
        let json = try stagingRoot(of: export)
            .appending(path: "practice.json", directoryHint: .notDirectory)
        XCTAssertEqual(try ArchiveBuilder.decode(Data(contentsOf: json)).takes.first?.fileName,
                       take.fileName)
    }

    /// A take whose file has gone missing must not fail the whole export. It is named in the result so
    /// the screen can say so.
    func testAMissingTakeFileIsReportedRatherThanFatal() throws {
        let present = try makeTake()
        let absent = try makeTake()
        try FileManager.default.removeItem(
            at: takesDirectory.appending(path: absent.fileName, directoryHint: .notDirectory))

        let export = try write(makeArchive(takes: [present, absent]))

        XCTAssertEqual(export.takesWritten, 1)
        XCTAssertEqual(export.takesMissing, [absent.fileName])
    }

    // MARK: - Cleanup, on both paths

    /// A stranded export is a second full-size copy of the library in a directory the player cannot
    /// see or reclaim.
    func testCleanUpRemovesTheZipAndTheStagingTree() throws {
        let export = try write(makeArchive(takes: [try makeTake()]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.workingDirectory.path))

        ArchiveWriter.cleanUp(export)

        XCTAssertFalse(FileManager.default.fileExists(atPath: export.workingDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: export.zipURL.path))
    }

    /// The failure path is the one that leaks, because the caller never gets a handle to clean up
    /// with. `practice.json` is already written by the time this throws, so the assertion is that a
    /// *partial* export is taken with it.
    func testAFailedExportLeavesNothingBehind() throws {
        let failing = FailAtTakesDirectory()

        XCTAssertThrowsError(try write(makeArchive(takes: [try makeTake()]), fileManager: failing))

        let leftovers = try FileManager.default
            .contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != "Recordings" }
        XCTAssertEqual(leftovers, [], "a failed export left \(leftovers.count) directory behind")
    }
}

/// Fails the export *after* the staging root and `practice.json` exist, which is the only interesting
/// moment: a failure before then has nothing to clean up.
private final class FailAtTakesDirectory: FileManager {
    override func createDirectory(at url: URL, withIntermediateDirectories: Bool,
                                  attributes: [FileAttributeKey: Any]? = nil) throws {
        guard url.lastPathComponent != "takes" else { throw CocoaError(.fileWriteUnknown) }
        try super.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories,
                                  attributes: attributes)
    }
}
