import XCTest
@testable import Pocket

/// `DiagnosticsStore` against a throwaway container, the same way `SongFileStore`'s tests work: a
/// `FileManager` subclass that points Application Support at a temp directory, so every path —
/// including the ones that fail — runs without touching the real one.
final class DiagnosticsStoreTests: XCTestCase {

    /// A `FileManager` whose Application Support is a directory this test owns.
    private final class TempContainer: FileManager {
        let root: URL

        init(root: URL) {
            self.root = root
            super.init()
        }

        override func url(for directory: FileManager.SearchPathDirectory,
                          in domain: FileManager.SearchPathDomainMask,
                          appropriateFor url: URL?, create: Bool) throws -> URL {
            guard directory == .applicationSupportDirectory else {
                return try super.url(for: directory, in: domain, appropriateFor: url, create: create)
            }
            return root
        }
    }

    private var root: URL!
    private var files: TempContainer!

    override func setUpWithError() throws {
        root = URL.temporaryDirectory.appending(path: "diagnostics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        files = TempContainer(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func event(_ kind: DiagnosticEvent.Kind = .crash, daysAgo: Double,
                       detail: String? = nil) -> DiagnosticEvent {
        DiagnosticEvent(kind: kind, date: Date.now.addingTimeInterval(-daysAgo * 86_400),
                        detail: detail, appBuild: "4", systemVersion: "18.5")
    }

    func testRoundTripsEveryFieldIncludingTheDate() throws {
        let original = event(daysAgo: 1, detail: "EXC_BAD_ACCESS")
        DiagnosticsStore.save([original], files)
        // Whole-value equality, so a field added to `DiagnosticEvent` without a coding key fails
        // here rather than going missing from a support message months later — including the date,
        // which is why the store encodes it as a `Double` rather than an ISO 8601 string. Even with
        // fractional seconds that format quantises to the millisecond, and this assertion then fails
        // with a message in which both sides print identically.
        XCTAssertEqual(DiagnosticsStore.load(files), [original])
    }

    func testAMissingFileIsAnEmptyListRatherThanAThrow() {
        XCTAssertTrue(DiagnosticsStore.load(files).isEmpty)
    }

    func testACorruptFileIsAnEmptyListRatherThanACrashInTheCrashReporter() throws {
        let fileURL = try DiagnosticsStore.url(files)
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertTrue(DiagnosticsStore.load(files).isEmpty)
    }

    func testTheFileCannotGrowPastWhatIsKept() throws {
        let events = (1...12).map { event(daysAgo: Double($0)) }
        let written = DiagnosticsStore.save(events, files)
        XCTAssertEqual(written.count, DiagnosticSummary.retained)
        XCTAssertEqual(DiagnosticsStore.load(files).count, DiagnosticSummary.retained,
                       "The cap has to apply on the way to disk, not only on the way to the screen "
                        + "— otherwise the file grows forever and only looks bounded")
    }

    func testStaleEventsAreDroppedOnRead() throws {
        // Written past the reader's window: the file is the older build's idea of retention, and
        // this build's has to win without anything migrating.
        let fileURL = try DiagnosticsStore.url(files)
        // 1 Jan 2001 as a `Date`'s own reference offset — the encoding the store now uses.
        try Data(#"[{"id":"\#(UUID().uuidString)","kind":"crash","date":0}]"#
            .utf8).write(to: fileURL)
        XCTAssertTrue(DiagnosticsStore.load(files).isEmpty)
    }

    func testClearRemovesTheFile() throws {
        DiagnosticsStore.save([event(daysAgo: 1)], files)
        DiagnosticsStore.clear(files)
        XCTAssertFalse(files.fileExists(atPath: try DiagnosticsStore.url(files).path))
    }

    /// Not a preference, unlike songs (ADR 0182). A crash report restored onto a new phone would
    /// attach the old phone's crashes to the new one's support message.
    func testTheDirectoryIsHeldOutOfBackup() throws {
        let dir = try DiagnosticsStore.directory(files)
        let values = try dir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
