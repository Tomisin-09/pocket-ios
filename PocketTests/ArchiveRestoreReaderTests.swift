import XCTest
@testable import Pocket

/// Whether an archive can be opened at all (ADR 0188 D2, S3), and what happens to the files inside it.
///
/// Every happy-path case here goes through the **real exporter**: `ArchiveWriter.write` produces the
/// zip and the reader opens it, so the two halves of the loop ADR 0181 left open are tested against
/// each other rather than against a fixture either one might have drifted from.
final class ArchiveRestoreReaderTests: XCTestCase {

    private var root: URL!
    private var takesDirectory: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "RestoreReaderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        takesDirectory = root.appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: takesDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    private func exportedArchive(_ build: (inout PracticeArchive) -> Void = { _ in }) throws -> ExportedArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.2 (5)",
                                      includesTakeAudio: true)
        archive.exercises = [ArchiveFixture.exercise(uid: UUID())]
        build(&archive)
        return try ArchiveWriter.write(archive, takesDirectory: takesDirectory,
                                       fileManager: .default, temporaryDirectory: root)
    }

    private func read(_ exported: ExportedArchive) -> Result<ReadArchive, RestoreFailure> {
        ArchiveRestoreReader.read(contentsOf: exported.zipURL)
    }

    private func failure(of result: Result<ReadArchive, RestoreFailure>) throws -> RestoreFailure {
        switch result {
        case .success: throw XCTSkip("expected a failure")
        case let .failure(failure): return failure
        }
    }

    // MARK: - The loop ADR 0181 left open

    func testARealExportOpensAndCarriesItsPayload() throws {
        let exported = try exportedArchive()
        defer { ArchiveWriter.cleanUp(exported) }

        guard case let .success(read) = read(exported) else { return XCTFail("should open") }
        XCTAssertEqual(read.archive.exercises.count, 1)
        XCTAssertEqual(read.archive.appVersion, "1.2 (5)")
        XCTAssertEqual(read.archive.exportedAt, ArchiveFixture.date)
    }

    func testTakeAudioIsFoundAndKeyedByFileName() throws {
        let uid = UUID()
        let fileName = "\(uid.uuidString).m4a"
        try Data(repeating: 0x42, count: 3000)
            .write(to: takesDirectory.appending(path: fileName, directoryHint: .notDirectory))

        let exported = try exportedArchive { $0.takes = [ArchiveFixture.take(uid: uid, fileName: fileName)] }
        defer { ArchiveWriter.cleanUp(exported) }

        guard case let .success(read) = read(exported) else { return XCTFail("should open") }
        XCTAssertEqual(Set(read.takeAudio.keys), [fileName])
        XCTAssertEqual(try read.zip.data(for: XCTUnwrap(read.takeAudio[fileName])).count, 3000)
    }

    // MARK: - Refusals

    /// D2's first reader, from the archive side. A file from the future is refused in
    /// `SchemaVersionGate`'s words, so both doors say the same sentence.
    func testAnArchiveFromANewerBuildIsRefusedInTheSharedWords() throws {
        let exported = try exportedArchive { $0.schemaVersion = PracticeArchive.currentSchemaVersion + 1 }
        defer { ArchiveWriter.cleanUp(exported) }

        XCTAssertEqual(try failure(of: read(exported)),
                       .futureVersion(message: SchemaVersionGate.refusalMessage))
    }

    /// A file from the future may well decode — the fields it shares with this build are the fields
    /// this build wrote. Decoding it anyway would silently drop whatever is new in it, which is why
    /// the version is probed before the payload is trusted.
    func testTheVersionIsCheckedBeforeThePayloadIsDecoded() throws {
        let exported = try exportedArchive {
            $0.schemaVersion = 99
            $0.exercises = [ArchiveFixture.exercise(uid: UUID())]
        }
        defer { ArchiveWriter.cleanUp(exported) }

        guard case let .failure(failure) = read(exported) else { return XCTFail("should refuse") }
        XCTAssertEqual(failure, .futureVersion(message: SchemaVersionGate.refusalMessage))
    }

    /// A version this app cannot have written — zero, from a hand-edited or truncated header — reads
    /// as refused rather than as an ancient archive to migrate. There is no such older format, so the
    /// honest answer is that this build does not understand the file (`SchemaVersionGate.evaluate`).
    func testAVersionZeroHeaderIsRefusedRatherThanTreatedAsAncient() throws {
        let exported = try exportedArchive { $0.schemaVersion = 0 }
        defer { ArchiveWriter.cleanUp(exported) }

        XCTAssertEqual(try failure(of: read(exported)),
                       .futureVersion(message: SchemaVersionGate.refusalMessage))
    }

    func testSomethingThatIsNotAZipReadsAsNotAnArchive() throws {
        let url = root.appending(path: "notes.txt", directoryHint: .notDirectory)
        try Data("just some text".utf8).write(to: url)

        XCTAssertEqual(try failure(of: ArchiveRestoreReader.read(contentsOf: url)), .notAnArchive)
    }

    /// A zip that opens and holds no `practice.json` is the same mistake from the player's side as
    /// choosing a file that is not a zip: they picked the wrong thing.
    func testAZipWithNoPayloadReadsAsNotAnArchive() throws {
        let zip = try ZipFixture.zip(entries: ["photos/holiday.jpg": Data("not json".utf8)])
        let reader = try ZipArchiveReader(data: zip)

        XCTAssertEqual(try failure(of: ArchiveRestoreReader.read(zip: reader)), .notAnArchive)
    }

    func testAPayloadThatIsNotTheRightShapeReadsAsCorrupt() throws {
        let zip = try ZipFixture.zip(entries: ["practice.json": Data(#"{"nope": true}"#.utf8)])
        let reader = try ZipArchiveReader(data: zip)

        XCTAssertEqual(try failure(of: ArchiveRestoreReader.read(zip: reader)), .corrupt)
    }

    func testAMissingFileReadsAsNotAnArchiveRatherThanCrashing() throws {
        let missing = root.appending(path: "nothing-here.zip", directoryHint: .notDirectory)
        XCTAssertEqual(try failure(of: ArchiveRestoreReader.read(contentsOf: missing)), .notAnArchive)
    }

    /// Every failure the player can reach has to have words, or the door reports a decode error at
    /// someone who chose a file.
    func testEveryFailureHasASentence() {
        let failures: [RestoreFailure] = [.notAnArchive, .corrupt,
                                          .unsupportedArchive(reason: "ZIP64"),
                                          .futureVersion(message: SchemaVersionGate.refusalMessage)]
        for failure in failures {
            XCTAssertFalse(failure.message.isEmpty, "\(failure) has no message")
            XCTAssertFalse(failure.message.contains("Pocket"), "user copy says Red Moon, never Pocket")
        }
    }
}
