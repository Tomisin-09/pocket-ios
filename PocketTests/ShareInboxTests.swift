import XCTest
@testable import Pocket

/// **The inbox and the snapshot on disk** (ADR 0264 D9), in a temporary folder standing in for the App
/// Group, which `TempContainerFileManager` can't reach (D10.5).
final class ShareInboxTests: XCTestCase {

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ShareInboxTests-\(UUID().uuidString)",
                                                                     directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testASavedLinkComesBackAsItWasSaved() throws {
        let folder = try makeFolder()
        let item = ShareInboxItem(id: UUID(), savedAt: Date(timeIntervalSince1970: 1_000), url: "https://example.com/a",
                                  title: "Lesson", note: "the bend at 1:20", destination: "song:x")
        try ShareInbox.deposit(item, in: folder)
        XCTAssertEqual(ShareInbox.pending(in: folder).map(\.item), [item])
    }

    func testASavedFileIsCopiedNotMoved() throws {
        let folder = try makeFolder()
        let source = folder.appending(path: "tab.txt")
        try Data("e|--5--|".utf8).write(to: source)
        let item = ShareInboxItem(id: UUID(), savedAt: .now, fileName: "shared.txt",
                                  typeIdentifier: "public.plain-text")
        try ShareInbox.deposit(item, file: source, in: folder)

        let pending = try XCTUnwrap(ShareInbox.pending(in: folder).first)
        let copied = try XCTUnwrap(pending.fileURL)
        XCTAssertEqual(try Data(contentsOf: copied), Data("e|--5--|".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the sharing app's file stays")
    }

    func testSavesComeBackOldestFirst() throws {
        let folder = try makeFolder()
        let newer = ShareInboxItem(id: UUID(), savedAt: Date(timeIntervalSince1970: 2_000),
                                   url: "https://example.com/b")
        let older = ShareInboxItem(id: UUID(), savedAt: Date(timeIntervalSince1970: 1_000),
                                   url: "https://example.com/a")
        try ShareInbox.deposit(newer, in: folder)
        try ShareInbox.deposit(older, in: folder)
        XCTAssertEqual(ShareInbox.pending(in: folder).map(\.item.id), [older.id, newer.id])
    }

    /// The bytes go in first and `item.json` last, so a folder without one is a save that never
    /// finished. The app clears it rather than filing half a save.
    func testASaveThatNeverFinishedIsCleared() throws {
        let folder = try makeFolder()
        let abandoned = ShareInbox.inbox(in: folder).appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try Data("half a pdf".utf8).write(to: abandoned.appending(path: "shared.pdf"))

        XCTAssertTrue(ShareInbox.pending(in: folder).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
    }

    func testRemovingASaveClearsItsFolder() throws {
        let folder = try makeFolder()
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a"), in: folder)
        let pending = try XCTUnwrap(ShareInbox.pending(in: folder).first)
        ShareInbox.remove(pending)
        XCTAssertTrue(ShareInbox.pending(in: folder).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.folder.path))
    }

    func testAnEmptyFolderHasNothingPending() throws {
        XCTAssertTrue(ShareInbox.pending(in: try makeFolder()).isEmpty)
    }

    // MARK: - The snapshot

    func testTheSnapshotRoundTrips() throws {
        let folder = try makeFolder()
        let snapshot = ShareOwnerSnapshot(standing: .lapsed, appearance: .dark, places: [
            ReferenceDestination(id: "song:a", kind: .song, name: "Slow Bend", parent: "Jack Trader",
                                 lastPracticed: Date(timeIntervalSince1970: 5_000)),
            ReferenceDestination(id: "exercise:b", kind: .exercise, name: "Spider")
        ], fullOfFiles: ["song:a"])
        try snapshot.write(to: folder)
        XCTAssertEqual(ShareOwnerSnapshot.read(from: folder), snapshot)
    }

    func testNoSnapshotReadsAsNone() throws {
        XCTAssertNil(ShareOwnerSnapshot.read(from: try makeFolder()))
    }
}
