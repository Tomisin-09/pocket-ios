import XCTest
@testable import Pocket

/// The arithmetic behind *how much space is this using?* (ADR 0181's half of ADR 0182).
///
/// Real files in a throwaway container via `TempContainerFileManager`, because the point of the type
/// is that it reports what is actually on disk — a test over invented numbers would prove the
/// addition and none of the reading.
final class StorageUsageTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    override func setUpWithError() throws {
        fileManager = TempContainerFileManager()
    }

    override func tearDownWithError() throws {
        fileManager.destroy()
        fileManager = nil
    }

    private func writeSong(_ name: String, bytes: Int) throws {
        try Data(repeating: 0x53, count: bytes)
            .write(to: try SongFileStore.url(for: name, fileManager))
    }

    private func writeTake(_ name: String, bytes: Int) throws {
        try Data(repeating: 0x54, count: bytes)
            .write(to: try RecordingStore.url(for: name, fileManager))
    }

    // MARK: - Measuring

    func testAnEmptyContainerUsesNothing() throws {
        XCTAssertEqual(StorageUsage.measure(fileManager), .none)
    }

    /// The two directories are reported apart, because the screen has to say which of them is the big
    /// one before a player can do anything about it.
    func testSongsAndTakesAreCountedSeparatelyAndSummed() throws {
        try writeSong("a.wav", bytes: 1000)
        try writeSong("b.wav", bytes: 2000)
        try writeTake("\(UUID().uuidString).m4a", bytes: 500)

        let usage = StorageUsage.measure(fileManager)

        XCTAssertEqual(usage.songBytes, 3000)
        XCTAssertEqual(usage.takeBytes, 500)
        // No store URL passed, so practice data contributes nothing here.
        XCTAssertEqual(usage.storeBytes, 0)
        XCTAssertEqual(usage.total, 3500)
    }

    /// `RecordingStore.filesOnDisk` filters to `.m4a`, and the measurement inherits that: a stray
    /// `.trimtmp` left by an interrupted trim is not part of what the player's takes cost.
    func testOnlyM4AFilesCountAsTakes() throws {
        try writeTake("\(UUID().uuidString).m4a", bytes: 800)
        try Data(repeating: 0, count: 9999)
            .write(to: try RecordingStore.directory(fileManager)
                .appending(path: "notes.txt", directoryHint: .notDirectory))

        XCTAssertEqual(StorageUsage.measure(fileManager).takeBytes, 800)
    }

    // MARK: - The store

    /// The SwiftData store is measured with its journal siblings. Between checkpoints the `-wal` can
    /// hold a real fraction of the database, and ignoring it would put the app's own figure quietly
    /// below the system's for a reason no player could discover.
    func testThePracticeStoreCountsItsWriteAheadLogAndSharedMemory() throws {
        let store = fileManager.root.appending(path: "default.store", directoryHint: .notDirectory)
        try Data(repeating: 0x44, count: 4000).write(to: store)
        try Data(repeating: 0x44, count: 1500)
            .write(to: fileManager.root.appending(path: "default.store-wal", directoryHint: .notDirectory))
        try Data(repeating: 0x44, count: 500)
            .write(to: fileManager.root.appending(path: "default.store-shm", directoryHint: .notDirectory))

        XCTAssertEqual(StorageUsage.storeBytes(at: store, fileManager), 6000)
    }

    /// No store URL means no practice data reported — never a guessed path. The container's own
    /// configuration is the only thing that knows where the store is.
    func testAnAbsentStoreURLReportsNothingRatherThanGuessing() {
        XCTAssertEqual(StorageUsage.storeBytes(at: nil, fileManager), 0)
    }

    /// A store file that is not there yet — first launch, before the first save — is zero, not a
    /// failed measurement.
    func testAStoreThatDoesNotExistYetIsZero() {
        let missing = fileManager.root.appending(path: "nothing.store", directoryHint: .notDirectory)
        XCTAssertEqual(StorageUsage.storeBytes(at: missing, fileManager), 0)
    }

    // MARK: - The breakdown

    /// The screen lists the categories in this order, and the total is their sum. If the two ever
    /// disagree, the screen is accounting for less than the app is using.
    func testTheBreakdownNamesEveryCategoryAndSumsToTheTotal() {
        let usage = StorageUsage(songBytes: 100, takeBytes: 20, storeBytes: 3)

        XCTAssertEqual(usage.breakdown.map(\.label), ["Songs", "Recordings", "Practice data"])
        XCTAssertEqual(usage.breakdown.reduce(0) { $0 + $1.bytes }, usage.total)
        XCTAssertEqual(usage.total, 123)
    }

    // MARK: - Formatting

    /// A negative figure is arithmetic nobody should see. Clamped rather than trusted, because the one
    /// place a subtraction could go negative — a "you would free up X" figure — is exactly where a
    /// minus sign would be most alarming and least informative.
    func testANegativeCountFormatsAsZero() {
        XCTAssertEqual(StorageUsage.formatted(bytes: -4096), StorageUsage.formatted(bytes: 0))
    }

    /// The approximation is the same number with the hedge in front, so the two can never disagree
    /// about the figure itself.
    func testAnApproximateSizeSaysSoAndCarriesTheSameNumber() {
        let exact = StorageUsage.formatted(bytes: 5_000_000)
        let approximate = StorageUsage.approximate(bytes: 5_000_000)

        XCTAssertTrue(approximate.hasPrefix("About "), approximate)
        XCTAssertTrue(approximate.hasSuffix(exact), "\(approximate) should end in \(exact)")
    }
}
