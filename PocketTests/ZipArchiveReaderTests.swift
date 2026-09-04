import XCTest
@testable import Pocket

/// The reader, tested against archives the **real exporter** wrote (ADR 0188 D8).
///
/// This is the test D8 asks for by name. The reader's whole scope is "archives this app produced", so
/// a checked-in zip fixture would prove the reader can read a file someone once made, and prove
/// nothing about the file the app writes today. `ArchiveWriter.write` is called for real here, and the
/// day `NSFileCoordinator`'s `.forUploading` changes what it emits — or the day someone replaces it —
/// this is what fails.
///
/// `ArchiveWriterTests` says in its own header that the test host "has no way to unzip". That is what
/// this slice changes, and the round-trip below is the first assertion in the suite that reads an
/// export back rather than inspecting the staging tree it was made from.
final class ZipArchiveReaderTests: XCTestCase {

    private var root: URL!
    private var takesDirectory: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "ZipReaderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        takesDirectory = root.appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: takesDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    private func makeTake(bytes: Int, byte: UInt8 = 0x41) throws -> RecordingRecord {
        let uid = UUID()
        let fileName = "\(uid.uuidString).m4a"
        try Data(repeating: byte, count: bytes)
            .write(to: takesDirectory.appending(path: fileName, directoryHint: .notDirectory))
        return RecordingRecord(uid: uid, createdAt: Date(timeIntervalSince1970: 1000), duration: 12,
                               title: "Take", note: nil, fileName: fileName, ownerLabelAtTake: nil,
                               loopUID: nil, exerciseUID: nil, songSourceID: nil, moments: [])
    }

    private func export(_ archive: PracticeArchive) throws -> ExportedArchive {
        try ArchiveWriter.write(archive,
                                takesDirectory: archive.includesTakeAudio ? takesDirectory : nil,
                                fileManager: .default,
                                temporaryDirectory: root)
    }

    /// Deliberately built out of `RecordingRecord`s rather than a richer library: they carry dates,
    /// optionals and a nested array, which is everything the JSON round trip needs to prove, and they
    /// are the same rows whose audio the take assertions below follow through the zip.
    private func makeArchive(takes: [RecordingRecord] = [], includesTakeAudio: Bool = true) -> PracticeArchive {
        PracticeArchive(exportedAt: Date(timeIntervalSince1970: 1_755_000_000.25),
                        appVersion: "1.2 (5)",
                        includesTakeAudio: includesTakeAudio,
                        takes: takes)
    }

    // MARK: - The round trip D8 asks for

    func testReadsPracticeJSONBackOutOfARealExport() throws {
        let archive = makeArchive(takes: [try makeTake(bytes: 256)])
        let exported = try export(archive)
        defer { ArchiveWriter.cleanUp(exported) }

        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        let entry = try XCTUnwrap(reader.entry(endingIn: "practice.json"),
                                  "the export's payload should be findable by suffix under the dated folder")
        let decoded = try ArchiveCoding.decode(PracticeArchive.self, from: reader.data(for: entry))

        XCTAssertEqual(decoded, archive, "a round trip through zip and back must change nothing")
    }

    /// The entry is found under the dated folder rather than at the zip's root, which is the detail
    /// that makes every lookup a suffix match instead of a hard-coded path.
    func testEntriesAreNestedUnderTheDatedExportFolder() throws {
        let exported = try export(makeArchive())
        defer { ArchiveWriter.cleanUp(exported) }

        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        let path = try XCTUnwrap(reader.entry(endingIn: "practice.json")).path
        XCTAssertTrue(path.hasPrefix("\(ArchiveWriter.folderStem)-"), "got \(path)")
        XCTAssertTrue(path.contains("/"), "practice.json should be inside the folder, not beside it")
    }

    /// Take audio has to survive byte-for-byte: it is the one thing in an archive that cannot be
    /// recreated (ADR 0151), and a silently corrupt `.m4a` is discovered months later.
    func testTakeAudioSurvivesByteForByte() throws {
        let quiet = try makeTake(bytes: 64_000, byte: 0x00)
        let noisy = try makeTake(bytes: 3_333, byte: 0x5A)
        let exported = try export(makeArchive(takes: [quiet, noisy]))
        defer { ArchiveWriter.cleanUp(exported) }

        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        let staged = reader.entries(inDirectoryNamed: "takes")
        XCTAssertEqual(staged.count, 2)

        for (take, byte) in [(quiet, UInt8(0x00)), (noisy, UInt8(0x5A))] {
            let entry = try XCTUnwrap(staged[take.fileName], "missing \(take.fileName)")
            let bytes = try reader.data(for: entry)
            XCTAssertEqual(bytes, Data(repeating: byte,
                                       count: take.fileName == quiet.fileName ? 64_000 : 3_333))
        }
    }

    /// 64KB of one repeated byte compresses hard, so this is the path that actually exercises inflate
    /// rather than a stored entry. Asserting the compression happened keeps the test honest: if the
    /// writer ever stopped deflating, the round trip above would still pass and prove less.
    func testTheDeflatePathIsTheOneUnderTest() throws {
        let take = try makeTake(bytes: 64_000, byte: 0x00)
        let exported = try export(makeArchive(takes: [take]))
        defer { ArchiveWriter.cleanUp(exported) }

        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        let entry = try XCTUnwrap(reader.entries(inDirectoryNamed: "takes")[take.fileName])
        XCTAssertEqual(entry.uncompressedSize, 64_000)
        XCTAssertNoThrow(try reader.data(for: entry))
    }

    func testDirectoryEntriesAreNotListedAsFiles() throws {
        let exported = try export(makeArchive(takes: [try makeTake(bytes: 128)]))
        defer { ArchiveWriter.cleanUp(exported) }

        let reader = try ZipArchiveReader(contentsOf: exported.zipURL)
        XCTAssertFalse(reader.entries.contains { $0.path.hasSuffix("/") },
                       "a directory record carries no bytes and has no place in a restore")
    }

    // MARK: - Refusals

    func testSomethingThatIsNotAZipIsRefusedAsSuch() {
        let data = Data("this is not a zip, it is a sentence".utf8)
        XCTAssertThrowsError(try ZipArchiveReader(data: data)) { error in
            XCTAssertEqual(error as? ZipReadFailure, .notAZip)
        }
    }

    func testAnEmptyFileIsRefusedRatherThanCrashing() {
        XCTAssertThrowsError(try ZipArchiveReader(data: Data())) { error in
            XCTAssertEqual(error as? ZipReadFailure, .notAZip)
        }
    }

    /// Truncation is the realistic corruption — a half-copied archive, an interrupted AirDrop. The
    /// central directory lives at the *end*, so lopping the tail off is what a real one looks like.
    func testATruncatedArchiveIsRefusedRatherThanCrashing() throws {
        let exported = try export(makeArchive(takes: [try makeTake(bytes: 4096)]))
        defer { ArchiveWriter.cleanUp(exported) }

        let whole = try Data(contentsOf: exported.zipURL)
        let truncated = whole.prefix(whole.count / 2)
        XCTAssertThrowsError(try ZipArchiveReader(data: Data(truncated)))
    }

    /// Every byte of the central directory, one at a time, must fail rather than trap. This is the
    /// assertion that justifies the bounds check on every field read: the door opens a file the app
    /// did not write in this run, and an out-of-range subscript is a crash the door cannot report.
    func testCorruptionAnywhereFailsWithoutTrapping() throws {
        let exported = try export(makeArchive(takes: [try makeTake(bytes: 512)]))
        defer { ArchiveWriter.cleanUp(exported) }
        let whole = try Data(contentsOf: exported.zipURL)

        for cut in stride(from: 0, to: whole.count, by: 37) {
            var damaged = whole
            damaged[cut] = damaged[cut] &+ 1
            if let reader = try? ZipArchiveReader(data: damaged) {
                for entry in reader.entries { _ = try? reader.data(for: entry) }
            }
        }
    }

    /// A CRC mismatch has to be caught, or a corrupt take lands silently and plays as noise.
    ///
    /// Deliberately a **stored** entry: with no compression in the way, inflate cannot be the thing
    /// that notices, so this isolates the CRC check itself. The payload byte is at a computed offset
    /// rather than a guessed one — a fixture entry's bytes begin at `30 + name.count`, and an earlier
    /// version of this test flipped a byte a third of the way into the file, which landed in a header
    /// and passed for the wrong reason.
    func testAStoredPayloadThatDoesNotMatchItsCRCIsRefused() throws {
        let name = "practice.json"
        var zip = try ZipFixture.zip(entries: [name: Data(repeating: 0x11, count: 2048)])
        let payloadStart = 30 + name.count

        let intact = try ZipArchiveReader(data: zip)
        XCTAssertNoThrow(try intact.data(for: XCTUnwrap(intact.entry(endingIn: name))),
                         "precondition: the entry reads cleanly before damage")

        zip[payloadStart + 100] = zip[payloadStart + 100] &+ 1
        let damaged = try ZipArchiveReader(data: zip)
        XCTAssertThrowsError(try damaged.data(for: XCTUnwrap(damaged.entry(endingIn: name)))) { error in
            XCTAssertEqual(error as? ZipReadFailure, .corrupt)
        }
    }

    /// The same damage to a real deflated take, located through its own local header. Inflate is the
    /// likely objector here and the CRC is the backstop; the assertion is that one of them fires, not
    /// which, because a restore only cares that bad bytes never reach a `.m4a`.
    func testADamagedDeflatePayloadIsRefused() throws {
        let take = try makeTake(bytes: 64_000, byte: 0x00)
        let exported = try export(makeArchive(takes: [take]))
        defer { ArchiveWriter.cleanUp(exported) }

        var whole = try Data(contentsOf: exported.zipURL)
        let reader = try ZipArchiveReader(data: whole)
        let entry = try XCTUnwrap(reader.entries(inDirectoryNamed: "takes")[take.fileName])
        XCTAssertEqual(try reader.data(for: entry).count, 64_000, "precondition: reads cleanly")

        let header = entry.localHeaderOffset
        let nameLength = Int(try ZipArchiveReader.integer(whole, at: header + 26, UInt16.self))
        let extraLength = Int(try ZipArchiveReader.integer(whole, at: header + 28, UInt16.self))
        let payloadStart = header + 30 + nameLength + extraLength
        whole[payloadStart + 4] = whole[payloadStart + 4] &+ 0x7F

        let damaged = try ZipArchiveReader(data: whole)
        let sameEntry = try XCTUnwrap(damaged.entries(inDirectoryNamed: "takes")[take.fileName])
        XCTAssertThrowsError(try damaged.data(for: sameEntry))
    }

    // MARK: - Path safety

    /// A zip path is an instruction to create a file, so traversal has to be refused at the reader
    /// rather than by every caller that writes one out.
    func testTraversalPathsAreRejected() throws {
        for name in ["../escape.m4a", "/etc/passwd", "takes/../../escape.m4a"] {
            let zip = try ZipFixture.zip(entries: [name: Data("x".utf8)])
            XCTAssertThrowsError(try ZipArchiveReader(data: zip), "accepted \(name)") { error in
                XCTAssertEqual(error as? ZipReadFailure, .corrupt)
            }
        }
    }

    func testAnEncryptedEntryIsNamedRatherThanAttempted() throws {
        let zip = try ZipFixture.zip(entries: ["practice.json": Data("{}".utf8)], generalPurposeFlags: 0x0001)
        XCTAssertThrowsError(try ZipArchiveReader(data: zip)) { error in
            guard case .unsupported = error as? ZipReadFailure else {
                return XCTFail("expected .unsupported, got \(error)")
            }
        }
    }

    func testAStoredEntryReadsBack() throws {
        let payload = Data("practice".utf8)
        let zip = try ZipFixture.zip(entries: ["practice.json": payload])
        let reader = try ZipArchiveReader(data: zip)
        let entry = try XCTUnwrap(reader.entry(endingIn: "practice.json"))
        XCTAssertEqual(try reader.data(for: entry), payload)
    }
}
