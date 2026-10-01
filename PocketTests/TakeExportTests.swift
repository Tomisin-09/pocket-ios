import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// A take leaving through the share sheet (ADR 0236 D2): what it's called, and what staging it does on
/// disk.
///
/// Staging runs against real files in a throwaway directory, for `ArchiveWriterTests`' reason: whether
/// the link is really a link and whether the sweep really removes a folder are properties of the file
/// system, and neither survives a mock.
final class TakeExportTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "TakeExportTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private let british = Locale(identifier: "en_GB")
    private let utc = TimeZone.gmt
    /// 1 October 2026, 18:00 UTC.
    private let firstOfOctober = Date(timeIntervalSince1970: 1_790_877_600)

    // MARK: - The name

    func testATakesTitleNamesItBeforeItsOwner() {
        XCTAssertEqual(TakeExportName.stem(title: "Clean run", ownerLabel: "Slow Bend · Chorus",
                                           createdAt: firstOfOctober, locale: british, timeZone: utc),
                       "Clean run · 1 Oct 2026")
    }

    func testAnUntitledTakeIsNamedForWhatItWasRecordedAgainst() {
        XCTAssertEqual(TakeExportName.stem(title: nil, ownerLabel: "Slow Bend · Chorus",
                                           createdAt: firstOfOctober, locale: british, timeZone: utc),
                       "Slow Bend · Chorus · 1 Oct 2026")
    }

    /// A blank title is no title. Otherwise the file would be called " · 1 Oct 2026".
    func testABlankTitleFallsThroughToTheOwner() {
        XCTAssertEqual(TakeExportName.stem(title: "   ", ownerLabel: "Spider Walk · exercise",
                                           createdAt: firstOfOctober, locale: british, timeZone: utc),
                       "Spider Walk · exercise · 1 Oct 2026")
    }

    /// A standalone take (ADR 0224) has neither.
    func testATakeWithNeitherIsATake() {
        XCTAssertEqual(TakeExportName.stem(title: nil, ownerLabel: nil,
                                           createdAt: firstOfOctober, locale: british, timeZone: utc),
                       "Take · 1 Oct 2026")
    }

    func testTheDateIsWrittenTheWayThePlayersLocaleWritesOne() {
        let american = TakeExportName.stem(title: nil, ownerLabel: nil, createdAt: firstOfOctober,
                                           locale: Locale(identifier: "en_US"), timeZone: utc)
        XCTAssertEqual(american, "Take · Oct 1, 2026")
    }

    // MARK: - A safe file name

    func testTheWordsAreKeptAsWritten() {
        XCTAssertEqual(ExportStaging.fileName(stem: "Slow Bend · Chorus · 1 Oct 2026", fileExtension: "m4a"),
                       "Slow Bend · Chorus · 1 Oct 2026.m4a")
    }

    func testSeparatorsAndControlCharactersAreReplaced() {
        XCTAssertEqual(ExportStaging.fileName(stem: "AC/DC: Live\\Tonight\n", fileExtension: "mp3"),
                       "AC-DC- Live-Tonight-.mp3")
    }

    /// A name starting with a dot is a hidden file in Files and on a Mac.
    func testALeadingDotIsDropped() {
        XCTAssertEqual(ExportStaging.fileName(stem: "..Intro", fileExtension: "m4a"), "Intro.m4a")
    }

    func testNothingLeftIsNamedForTheApp() {
        XCTAssertEqual(ExportStaging.fileName(stem: " / ", fileExtension: "m4a"), "-.m4a")
        XCTAssertEqual(ExportStaging.fileName(stem: "  ", fileExtension: "m4a"), "Red Moon.m4a")
    }

    /// The cap drops whole characters, so a multi-byte title is never cut mid-character, and the
    /// extension always survives.
    func testALongNameIsCappedAndKeepsItsExtension() {
        let name = ExportStaging.fileName(stem: String(repeating: "é", count: 300), fileExtension: "m4a")
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertLessThanOrEqual(name.utf8.count, 204)
        XCTAssertEqual(name.dropLast(4).utf8.count, 200)
    }

    func testNoExtensionMeansNoTrailingDot() {
        XCTAssertEqual(ExportStaging.fileName(stem: "Slow Bend", fileExtension: ""), "Slow Bend")
    }

    // MARK: - Staging

    private func makeSource(named name: String = "\(UUID().uuidString).m4a") throws -> URL {
        let url = root.appending(path: name, directoryHint: .notDirectory)
        try Data(repeating: 0x41, count: 2048).write(to: url)
        return url
    }

    func testAStagedFileArrivesUnderItsNameAndTheKeptFileStays() throws {
        let source = try makeSource()
        let staged = try ExportStaging.stage(source, as: "Take · 1 Oct 2026.m4a", temporaryDirectory: root)

        XCTAssertEqual(staged.lastPathComponent, "Take · 1 Oct 2026.m4a")
        XCTAssertEqual(try Data(contentsOf: staged), try Data(contentsOf: source))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
    }

    /// A link costs no space. Two names on one file is what a hard link is.
    func testStagingLinksRatherThanCopies() throws {
        let source = try makeSource()
        _ = try ExportStaging.stage(source, as: "Take.m4a", temporaryDirectory: root)
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path(percentEncoded: false))
        let links = attributes[.referenceCount]
        XCTAssertEqual(links as? Int, 2)
    }

    /// Exporting the same take twice must not collide on its name.
    func testEachExportGetsAFolderOfItsOwn() throws {
        let source = try makeSource()
        let first = try ExportStaging.stage(source, as: "Take.m4a", temporaryDirectory: root)
        let second = try ExportStaging.stage(source, as: "Take.m4a", temporaryDirectory: root)
        XCTAssertNotEqual(first.deletingLastPathComponent(), second.deletingLastPathComponent())
    }

    func testAnExportSweepsFoldersADayOldAndLeavesNewerOnes() throws {
        let source = try makeSource()
        let old = try ExportStaging.stage(source, as: "Old.m4a", temporaryDirectory: root)
        let recent = try ExportStaging.stage(source, as: "Recent.m4a", temporaryDirectory: root)
        try FileManager.default.setAttributes([.creationDate: Date().addingTimeInterval(-ExportStaging.keepFor - 60)],
                                              ofItemAtPath: old.deletingLastPathComponent().path(percentEncoded: false))

        _ = try ExportStaging.stage(source, as: "New.m4a", temporaryDirectory: root)

        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)),
                      "the sweep removed a link, never the kept file")
    }

    // MARK: - The file's type

    func testTheTypeComesFromTheExtension() {
        let take = ExportedAudioFile(source: root, fileName: "Take.m4a")
        XCTAssertTrue(take.contentType.conforms(to: .mpeg4Audio))
        let song = ExportedAudioFile(source: root, fileName: "Slow Bend.mp3")
        XCTAssertTrue(song.contentType.conforms(to: .mp3))
    }

    // MARK: - A take's own file

    /// A take whose audio has gone has nothing to send, so it offers nothing.
    func testATakeWithNoAudioOnDiskHasNoExport() {
        let take = Recording(fileName: "\(UUID().uuidString).m4a", duration: 12)
        XCTAssertNil(take.exportedFile())
    }

    func testATakeOnDiskExportsUnderItsName() throws {
        let take = Recording(fileName: "\(UUID().uuidString).m4a", duration: 12, createdAt: firstOfOctober)
        take.title = "Clean run"
        let kept = try RecordingStore.url(for: take.fileName)
        try Data(repeating: 0x41, count: 64).write(to: kept)
        defer { try? FileManager.default.removeItem(at: kept) }

        let file = try XCTUnwrap(take.exportedFile())
        XCTAssertEqual(file.source, kept)
        XCTAssertTrue(file.fileName.hasPrefix("Clean run · "))
        XCTAssertTrue(file.fileName.hasSuffix(".m4a"))
    }
}
