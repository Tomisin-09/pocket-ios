import XCTest
@testable import Pocket

/// Bulk practice-category edits across a loop selection (ADR 0125). The rules that matter
/// are the partial ones: an untouched field must leave every loop's own value alone, and
/// tags must merge rather than replace.
///
/// Loops here are **uninserted** `@Model` objects — inserting into a context traps in the
/// XCTest host (see the SwiftData notes in `docs/swiftdata-gotchas.md`), and none of this
/// logic needs persistence.
final class LoopBulkEditTests: XCTestCase {

    private func loop(name: String = "Loop",
                      type: LoopType = .unset,
                      focus: Int? = nil,
                      tags: [String] = [],
                      favorite: Bool = false) -> Loop {
        let made = Loop(name: name, start: 0, end: 0.1, speed: 1, repeats: 1)
        made.loopType = type
        made.focus = focus
        made.tags = tags
        made.isFavorite = favorite
        return made
    }

    // MARK: partial application

    func testEmptyEditChangesNothing() {
        let edit = LoopBulkEdit()
        XCTAssertTrue(edit.isEmpty)
        let target = loop(type: .riff, focus: 2, tags: ["solo"])
        edit.apply(to: target)
        XCTAssertEqual(target.loopType, .riff)
        XCTAssertEqual(target.focus, 2)
        XCTAssertEqual(target.tags, ["solo"])
    }

    func testSetTypeAppliesAndLeavesFocusAlone() {
        var edit = LoopBulkEdit()
        edit.loopType = .set(.chords)
        let target = loop(type: .lick, focus: 3)
        edit.apply(to: target)
        XCTAssertEqual(target.loopType, .chords)
        XCTAssertEqual(target.focus, 3, "an unchanged field must not be written")
    }

    /// The three-state field earning its keep: `.set(nil)` clears the focus, which is a
    /// different instruction from "leave it".
    func testFocusCanBeClearedExplicitly() {
        var edit = LoopBulkEdit()
        edit.focus = .set(nil)
        let target = loop(focus: 2)
        edit.apply(to: target)
        XCTAssertNil(target.focus)
        XCTAssertFalse(edit.isEmpty)
    }

    func testUnchangedFocusLeavesAnUntriagedLoopUntriaged() {
        let target = loop(focus: nil)
        LoopBulkEdit().apply(to: target)
        XCTAssertNil(target.focus)
    }

    // MARK: tags merge, never replace

    func testTagsAreAddedToWhatIsAlreadyThere() {
        var edit = LoopBulkEdit()
        edit.tagsToAdd = ["needs-work"]
        let target = loop(tags: ["solo"])
        edit.apply(to: target)
        XCTAssertEqual(target.tags, ["solo", "needs-work"])
    }

    /// Bulk-added tags go through `Labels`, so a differently-cased duplicate folds in
    /// rather than splitting the tag in two.
    func testAddingAnExistingTagInAnotherCaseIsANoOp() {
        var edit = LoopBulkEdit()
        edit.tagsToAdd = ["Solo"]
        let target = loop(tags: ["solo"])
        edit.apply(to: target)
        XCTAssertEqual(target.tags, ["solo"])
    }

    func testRemovalIsCaseInsensitive() {
        var edit = LoopBulkEdit()
        edit.tagsToRemove = ["SOLO"]
        let target = loop(tags: ["solo", "chorus"])
        edit.apply(to: target)
        XCTAssertEqual(target.tags, ["chorus"])
    }

    func testRemovingATagTheLoopDoesNotHaveIsHarmless() {
        var edit = LoopBulkEdit()
        edit.tagsToRemove = ["bridge"]
        let target = loop(tags: ["solo"])
        edit.apply(to: target)
        XCTAssertEqual(target.tags, ["solo"])
    }

    // MARK: reads over the selection

    func testCommonTypeIsNilWhenTheSelectionDiffers() {
        let loops = [loop(type: .riff), loop(type: .lick)]
        XCTAssertNil(LoopSelectionSummary.commonType(of: loops))
    }

    func testCommonTypeIsTheSharedValue() {
        let loops = [loop(type: .riff), loop(type: .riff)]
        XCTAssertEqual(LoopSelectionSummary.commonType(of: loops), .riff)
    }

    /// Outer `nil` = they differ; inner `nil` = they agree on *not triaged*. The two must
    /// not collapse, or the sheet would show "Multiple" for a selection that agrees.
    func testCommonFocusDistinguishesAgreedNilFromDisagreement() {
        let agreed = LoopSelectionSummary.commonFocus(of: [loop(focus: nil), loop(focus: nil)])
        XCTAssertNotNil(agreed)
        XCTAssertNil(agreed ?? 1)

        let differing = LoopSelectionSummary.commonFocus(of: [loop(focus: nil), loop(focus: 2)])
        XCTAssertNil(differing)
    }

    func testSharedTagsAreTheIntersection() {
        let loops = [loop(tags: ["solo", "chorus"]), loop(tags: ["chorus", "fast"])]
        XCTAssertEqual(LoopSelectionSummary.sharedTags(of: loops), ["chorus"])
    }

    func testSharedTagsOfAnEmptySelectionIsEmpty() {
        XCTAssertTrue(LoopSelectionSummary.sharedTags(of: []).isEmpty)
    }

    func testAnyTagsUnionsTheSelection() {
        let loops = [loop(tags: ["solo"]), loop(tags: ["Solo", "fast"])]
        XCTAssertEqual(Set(LoopSelectionSummary.anyTags(of: loops).map { $0.lowercased() }),
                       ["solo", "fast"])
    }

    // MARK: bulk favourite

    func testMixedSelectionFavouritesRatherThanUnstarring() {
        let loops = [loop(favorite: true), loop(favorite: false)]
        XCTAssertTrue(LoopSelectionSummary.favoriteAction(for: loops))
    }

    func testFullyFavouritedSelectionUnfavourites() {
        let loops = [loop(favorite: true), loop(favorite: true)]
        XCTAssertFalse(LoopSelectionSummary.favoriteAction(for: loops))
    }

    func testNoneFavouritedFavourites() {
        XCTAssertTrue(LoopSelectionSummary.favoriteAction(for: [loop(), loop()]))
    }
}
