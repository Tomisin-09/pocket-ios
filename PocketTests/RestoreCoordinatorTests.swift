import SwiftData
import XCTest
@testable import Pocket

/// The door's own copy of the archive, and what happens to it (ADR 0188 S3).
///
/// An empty in-memory container is enough: `inspect` only *fetches*, and the project's test-host trap
/// is about inserting a graph. Nothing here inserts one.
///
/// **The class is deliberately not `@MainActor`; the test methods are.** A `@MainActor` class whose
/// `setUp`/`tearDown` hold a fixture is the shape that has failed CI five times
/// (`ci-swift6-xcode16-strictness`): an override cannot add isolation its superclass method lacks, so
/// the property silently inherits the class annotation and Xcode 16 rejects touching it from
/// `setUpWithError`. The fixture here is a `URL` and needs no actor, so it stays nonisolated and the
/// annotation goes where the main-actor work actually is — `PracticeAudioEngineTests`' idiom, proven
/// green on CI.
final class RestoreCoordinatorTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "RestoreCoordinatorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, Recording.self, TakeNote.self, PracticeRun.self,
            Goal.self, LongTermGoal.self, SavedChord.self, Profile.self, ReferenceLink.self,
            configurations: config)
        return ModelContext(container)
    }

    /// An archive on disk, written by the real exporter and left where a picker would hand it over.
    private func pickedArchive() throws -> URL {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.2 (5)",
                                      includesTakeAudio: false)
        archive.exercises = [ArchiveFixture.exercise(uid: UUID())]
        let exported = try ArchiveWriter.write(archive, takesDirectory: nil,
                                               fileManager: .default, temporaryDirectory: root)
        // Move it out of the export's working directory, then take that directory away — a picked
        // file is not one this app is holding open.
        let picked = root.appending(path: "chosen.zip", directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: exported.zipURL, to: picked)
        try FileManager.default.removeItem(at: exported.workingDirectory)
        return picked
    }

    @MainActor
    func testInspectingAnArchiveReportsWhatItWouldAdd() async throws {
        let context = try makeContext()
        guard case let .success(pending) = await RestoreCoordinator.inspect(try pickedArchive(), in: context) else {
            return XCTFail("a real export should open")
        }
        defer { RestoreCoordinator.discard(pending.workingDirectory) }

        XCTAssertEqual(pending.plan.landingCount, 1)
        XCTAssertEqual(pending.plan.lines.first?.kind, .exercises)
    }

    /// **The assertion that pins the reason the copy exists.** A picked file lives behind a security
    /// scope that closes when `inspect` returns, and `ZipArchiveReader` memory-maps what it opens —
    /// so a restore reading take audio *after* the player confirms would be reading a map into a file
    /// the app is no longer permitted to touch. Deleting the source here stands in for that: if the
    /// door were reading the picked file directly, everything below would fail.
    @MainActor
    func testTheArchiveStaysReadableAfterTheChosenFileIsGone() async throws {
        let context = try makeContext()
        let picked = try pickedArchive()

        guard case let .success(pending) = await RestoreCoordinator.inspect(picked, in: context) else {
            return XCTFail("a real export should open")
        }
        defer { RestoreCoordinator.discard(pending.workingDirectory) }

        try FileManager.default.removeItem(at: picked)
        XCTAssertFalse(FileManager.default.fileExists(atPath: picked.path), "precondition")

        let entry = try XCTUnwrap(pending.read.zip.entry(endingIn: "practice.json"))
        XCTAssertNoThrow(try pending.read.zip.data(for: entry),
                         "the door reads its own copy, not the file the player chose")
    }

    @MainActor
    func testDiscardingRemovesTheCopy() async throws {
        let context = try makeContext()
        guard case let .success(pending) = await RestoreCoordinator.inspect(try pickedArchive(), in: context) else {
            return XCTFail("a real export should open")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.workingDirectory.path))

        RestoreCoordinator.discard(pending.workingDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.workingDirectory.path))
        RestoreCoordinator.discard(pending.workingDirectory)
    }

    /// A refused file must not leave a full-size copy of itself in `tmp/`, which the player cannot see
    /// or reclaim — `ArchiveWriter` takes the same care on its own error path.
    @MainActor
    func testARefusedFileLeavesNothingBehind() async throws {
        let context = try makeContext()
        let notAnArchive = root.appending(path: "notes.txt", directoryHint: .notDirectory)
        try Data("just some text".utf8).write(to: notAnArchive)

        let before = try countOfTemporaryRestoreDirectories()
        guard case let .failure(failure) = await RestoreCoordinator.inspect(notAnArchive, in: context) else {
            return XCTFail("a text file is not an archive")
        }
        XCTAssertEqual(failure, .notAnArchive)
        XCTAssertEqual(try countOfTemporaryRestoreDirectories(), before,
                       "a refused file leaves no working directory behind")
    }

    private func countOfTemporaryRestoreDirectories() throws -> Int {
        let contents = try FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
        return contents.filter { $0.lastPathComponent.hasPrefix("RedMoonRestore-") }.count
    }
}
