import XCTest
@testable import Pocket

/// The tags → folders backfill (ADR 0210 D7). Exercised as plain uninserted `@Model` objects — the
/// per-drill rule is deliberately separable from the store for exactly this reason.
final class ExerciseFolderBackfillTests: XCTestCase {

    private func drill(tags: [String], folders: [String] = []) -> Exercise {
        let exercise = Exercise()
        exercise.tags = tags
        exercise.folders = folders
        return exercise
    }

    func testEachTagBecomesATopLevelFolder() {
        let exercise = drill(tags: ["picking", "warmup"])
        let namespace = ExerciseFolderBackfill.apply(to: exercise, namespace: [])
        XCTAssertEqual(exercise.folders, ["picking", "warmup"])
        XCTAssertEqual(namespace, ["picking", "warmup"])
    }

    /// It copies. Removing the column is a destructive change under ADR 0189 and this buys none of
    /// its cost, so the tag has to still be there afterwards.
    func testTagsAreCopiedNotMoved() {
        let exercise = drill(tags: ["technique"])
        _ = ExerciseFolderBackfill.apply(to: exercise, namespace: [])
        XCTAssertEqual(exercise.tags, ["technique"])
    }

    /// The property that makes it safe to run against a real library rather than a held release.
    func testASecondRunAddsNothing() {
        let exercise = drill(tags: ["scales"])
        let first = ExerciseFolderBackfill.apply(to: exercise, namespace: [])
        let second = ExerciseFolderBackfill.apply(to: exercise, namespace: first)
        XCTAssertEqual(exercise.folders, ["scales"])
        XCTAssertEqual(second, ["scales"])
    }

    /// A player who has since filed the drill elsewhere, or taken it out of the folder a tag made,
    /// must not have that decision quietly undone.
    func testItLeavesFilingThePlayerHasAlreadyDoneAlone() {
        let exercise = drill(tags: ["picking"], folders: ["Grade 2/Warm-ups"])
        _ = ExerciseFolderBackfill.apply(to: exercise, namespace: ["Grade 2/Warm-ups"])
        XCTAssertEqual(exercise.folders, ["Grade 2/Warm-ups", "picking"])
    }

    func testATagFoldsOntoTheFolderTheNamespaceAlreadyUses() {
        let exercise = drill(tags: ["picking"])
        _ = ExerciseFolderBackfill.apply(to: exercise, namespace: ["Picking"])
        XCTAssertEqual(exercise.folders, ["Picking"], "The existing display form wins")
    }

    /// A tag with a slash in it is a name, not a statement about hierarchy — `/` is reserved (D5).
    func testASlashInATagIsFoldedToASpaceRatherThanMakingTwoLevels() {
        let exercise = drill(tags: ["warm/up"])
        _ = ExerciseFolderBackfill.apply(to: exercise, namespace: [])
        XCTAssertEqual(exercise.folders, ["warm up"])
    }

    func testAnEmptyTagIsSkipped() {
        let exercise = drill(tags: ["   ", "rhythm"])
        _ = ExerciseFolderBackfill.apply(to: exercise, namespace: [])
        XCTAssertEqual(exercise.folders, ["rhythm"])
    }
}
