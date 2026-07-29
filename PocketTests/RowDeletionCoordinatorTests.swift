import SwiftUI
import XCTest
@testable import Pocket

/// Deferred, undoable row deletion (Slice 3) — the bookkeeping behind `.pocketRowActions`'s Undo
/// toast: which rows a list should hide, and when the real delete actually runs.
///
/// Driven with plain `UUID`s rather than real models: the coordinator keys on `AnyHashable`
/// precisely so this is testable without inserting a `@Model` in the XCTest host (which traps —
/// `docs/swiftdata-gotchas.md`).
@MainActor
final class RowDeletionCoordinatorTests: XCTestCase {

    func testRequestHidesTheRowWithoutDeletingIt() {
        let coordinator = RowDeletionCoordinator()
        let id = UUID()
        var deleted = false

        coordinator.request(PocketRowDelete(id: id, name: "Spider") { deleted = true })

        XCTAssertTrue(coordinator.isPending(id), "the row should leave the list immediately")
        XCTAssertFalse(deleted, "the delete waits for the undo window to close")
        XCTAssertEqual(coordinator.toast?.message, "Deleted Spider")
    }

    func testUndoRestoresTheRowAndNeverDeletes() {
        let coordinator = RowDeletionCoordinator()
        let id = UUID()
        var deleted = false
        coordinator.request(PocketRowDelete(id: id, name: "Spider") { deleted = true })

        coordinator.undo()

        XCTAssertFalse(coordinator.isPending(id))
        XCTAssertFalse(deleted, "undo is free precisely because nothing was destroyed")
        XCTAssertNil(coordinator.toast)
    }

    func testCommitPerformsTheDeleteAndClearsTheToast() {
        let coordinator = RowDeletionCoordinator()
        let id = UUID()
        var deleted = false
        coordinator.request(PocketRowDelete(id: id, name: "Spider") { deleted = true })

        coordinator.commitPending()

        XCTAssertTrue(deleted)
        XCTAssertFalse(coordinator.isPending(id))
        XCTAssertNil(coordinator.toast)
    }

    func testCommitIsIdempotent() {
        let coordinator = RowDeletionCoordinator()
        var deletes = 0
        coordinator.request(PocketRowDelete(id: UUID(), name: "Spider") { deletes += 1 })

        coordinator.commitPending()
        coordinator.commitPending()

        XCTAssertEqual(deletes, 1)
    }

    /// Only the latest delete is undoable — a second request commits the first, matching the
    /// waveform's toast (ADR 0019).
    func testSecondDeleteCommitsTheFirst() {
        let coordinator = RowDeletionCoordinator()
        let (first, second) = (UUID(), UUID())
        var firstDeleted = false
        var secondDeleted = false

        coordinator.request(PocketRowDelete(id: first, name: "Spider") { firstDeleted = true })
        coordinator.request(PocketRowDelete(id: second, name: "Legato") { secondDeleted = true })

        XCTAssertTrue(firstDeleted, "the earlier delete is committed, not forgotten")
        XCTAssertFalse(coordinator.isPending(first), "and its row does not come back")
        XCTAssertFalse(secondDeleted)
        XCTAssertTrue(coordinator.isPending(second))
        XCTAssertEqual(coordinator.toast?.message, "Deleted Legato")
    }

    /// Undo after a second delete only rescues the second — the first is already gone.
    func testUndoAfterASecondDeleteRescuesOnlyTheLatest() {
        let coordinator = RowDeletionCoordinator()
        let (first, second) = (UUID(), UUID())
        var firstDeleted = false
        var secondDeleted = false
        coordinator.request(PocketRowDelete(id: first, name: "Spider") { firstDeleted = true })
        coordinator.request(PocketRowDelete(id: second, name: "Legato") { secondDeleted = true })

        coordinator.undo()

        XCTAssertTrue(firstDeleted)
        XCTAssertFalse(secondDeleted)
        XCTAssertFalse(coordinator.isPending(second))
    }

    func testUnrelatedRowsAreNeverPending() {
        let coordinator = RowDeletionCoordinator()
        coordinator.request(PocketRowDelete(id: UUID(), name: "Spider") {})
        XCTAssertFalse(coordinator.isPending(UUID()))
    }

    /// The window closes on its own, so a delete the user walks away from still happens.
    func testTheWindowExpiresAndCommits() async throws {
        let coordinator = RowDeletionCoordinator()
        let id = UUID()
        var deleted = false
        coordinator.request(PocketRowDelete(id: id, name: "Spider") { deleted = true })

        try await Task.sleep(for: RowDeletionCoordinator.window + .milliseconds(500))

        XCTAssertTrue(deleted)
        XCTAssertFalse(coordinator.isPending(id))
        XCTAssertNil(coordinator.toast)
    }

    /// The environment's default seam (no `.pocketRowUndoHost()` above — a preview, a test) deletes
    /// straight away rather than silently swallowing the action.
    func testDefaultSeamDeletesImmediately() {
        let seam = EnvironmentValues().rowDeletion
        var deleted = false

        seam.request(PocketRowDelete(id: UUID(), name: "Spider") { deleted = true })

        XCTAssertTrue(deleted)
        XCTAssertFalse(seam.isPending(UUID()))
    }
}
