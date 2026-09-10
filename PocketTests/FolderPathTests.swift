import XCTest
@testable import Pocket

/// Covers the folder path arithmetic (ADR 0210 D5) — the derived hierarchy behind a flat
/// `[String]` of S3-style key prefixes. Everything the browse surface, the picker, the rename and
/// the share are drawn from is in here, which is why it is tested first.
final class FolderPathTests: XCTestCase {

    // MARK: - Canonical form

    func testCanonicalNormalisesEachSegmentAndDropsEmpties() {
        XCTAssertEqual(FolderPath.canonical("  Beginner / Warm   ups "), "Beginner/Warm ups")
        XCTAssertEqual(FolderPath.canonical("//Grade 2//Scales//"), "Grade 2/Scales")
    }

    func testCanonicalPreservesCase() {
        XCTAssertEqual(FolderPath.canonical("Drop D/Riffs"), "Drop D/Riffs")
    }

    func testRootIsTheEmptyPath() {
        XCTAssertEqual(FolderPath.canonical("   "), "")
        XCTAssertEqual(FolderPath.segments(""), [])
    }

    func testCanonicalSegmentFoldsASlashToASpaceRatherThanObeyingIt() {
        // D5: `/` is reserved. Naming a folder "Rock/Blues" makes one folder, not two levels.
        XCTAssertEqual(FolderPath.canonicalSegment("Rock/Blues"), "Rock Blues")
        XCTAssertNil(FolderPath.canonicalSegment("  /  "))
    }

    func testAppendingCreatesExactlyOneLevelBelowWhereYouStand() {
        XCTAssertEqual(FolderPath.appending("Warm-ups", to: "Beginner"), "Beginner/Warm-ups")
        XCTAssertEqual(FolderPath.appending("Beginner", to: ""), "Beginner")
        XCTAssertEqual(FolderPath.appending("A/B", to: "Grade 2"), "Grade 2/A B")
        XCTAssertNil(FolderPath.appending("   ", to: "Beginner"))
    }

    func testLeafParentAndAncestry() {
        XCTAssertEqual(FolderPath.leaf("Students/2026/Beginner"), "Beginner")
        XCTAssertEqual(FolderPath.parent("Students/2026/Beginner"), "Students/2026")
        XCTAssertEqual(FolderPath.parent("Students"), "")
        XCTAssertNil(FolderPath.parent(""))
        XCTAssertEqual(FolderPath.ancestry("A/B/C"), ["A", "A/B", "A/B/C"])
        XCTAssertEqual(FolderPath.ancestry(""), [])
    }

    // MARK: - isUnder

    func testIsUnderMatchesTheFolderItselfAndEverythingBelowIt() {
        XCTAssertTrue(FolderPath.isUnder("Beginner", prefix: "Beginner"))
        XCTAssertTrue(FolderPath.isUnder("Beginner/Warm-ups", prefix: "Beginner"))
        XCTAssertTrue(FolderPath.isUnder("Beginner/Warm-ups/Day 1", prefix: "Beginner/Warm-ups"))
        XCTAssertFalse(FolderPath.isUnder("Beginner", prefix: "Beginner/Warm-ups"))
    }

    /// The bug this function exists to not have: `hasPrefix` would merge two different folders whose
    /// names happen to share an opening.
    func testIsUnderComparesSegmentsNotCharactersSoBeginnerDoesNotMatchBeginners() {
        XCTAssertTrue("Beginners/Warm-ups".hasPrefix("Beginner"))
        XCTAssertFalse(FolderPath.isUnder("Beginners/Warm-ups", prefix: "Beginner"))
    }

    func testIsUnderIsCaseInsensitiveAndRootContainsEverything() {
        XCTAssertTrue(FolderPath.isUnder("beginner/scales", prefix: "Beginner"))
        XCTAssertTrue(FolderPath.isUnder("Anything/At/All", prefix: ""))
        XCTAssertTrue(FolderPath.isUnder("", prefix: ""))
    }

    // MARK: - What a level shows (D6b)

    func testALevelShowsEveryItemAtOrBelowIt() {
        XCTAssertTrue(FolderPath.contains(["Beginner/Warm-ups"], within: "Beginner"))
        XCTAssertTrue(FolderPath.contains(["Beginner"], within: "Beginner"))
        XCTAssertFalse(FolderPath.contains(["Grade 2"], within: "Beginner"))
    }

    func testTheRootShowsEverythingIncludingUnfiledItems() {
        XCTAssertTrue(FolderPath.contains([], within: ""))
        XCTAssertTrue(FolderPath.contains(["Grade 2/Scales"], within: ""))
    }

    func testAnUnfiledItemIsAtTheRootAndNowhereElse() {
        XCTAssertFalse(FolderPath.contains([], within: "Beginner"))
    }

    // MARK: - children (CommonPrefixes)

    func testChildrenReturnsTheImmediateChildFoldersOnly() {
        let paths = ["Beginner", "Beginner/Warm-ups", "Beginner/Warm-ups/Day 1", "Grade 2/Scales"]
        XCTAssertEqual(FolderPath.children(of: "", in: paths), ["Beginner", "Grade 2"])
        XCTAssertEqual(FolderPath.children(of: "Beginner", in: paths), ["Beginner/Warm-ups"])
        XCTAssertEqual(FolderPath.children(of: "Beginner/Warm-ups", in: paths), ["Beginner/Warm-ups/Day 1"])
        XCTAssertEqual(FolderPath.children(of: "Beginner/Warm-ups/Day 1", in: paths), [])
    }

    /// An ancestor nobody created explicitly still appears — which is what makes markers optional
    /// rather than load-bearing for a folder that has members.
    func testChildrenDerivesAncestorsThatWereNeverCreatedExplicitly() {
        XCTAssertEqual(FolderPath.children(of: "", in: ["Students/2026/Beginner"]), ["Students"])
        XCTAssertEqual(FolderPath.children(of: "Students", in: ["Students/2026/Beginner"]), ["Students/2026"])
    }

    func testChildrenDeDuplicatesCaseInsensitivelyKeepingTheFirstSeenForm() {
        let children = FolderPath.children(of: "", in: ["Beginner/A", "beginner/B", "BEGINNER"])
        XCTAssertEqual(children, ["Beginner"])
    }

    func testChildrenSortsCaseInsensitively() {
        XCTAssertEqual(FolderPath.children(of: "", in: ["zeta", "Alpha", "beta"]), ["Alpha", "beta", "zeta"])
    }

    // MARK: - Folding

    /// `Labels` folds whole strings, so the `/` would reintroduce exactly the fragmentation ADR 0033
    /// exists to prevent. Folding compares segment by segment.
    func testFoldingAdoptsTheExistingDisplayFormSegmentBySegment() {
        let existing = ["Beginner/Scales"]
        XCTAssertEqual(FolderPath.folding("beginner/Warm-ups", into: existing), "Beginner/Warm-ups")
        // What `Labels` alone would have stored: it folds *whole* strings, so a path that differs
        // anywhere is a brand-new label and the stray `beginner` survives into the namespace.
        XCTAssertEqual(Labels.adding("beginner/Warm-ups", to: existing),
                       ["Beginner/Scales", "beginner/Warm-ups"])
    }

    func testFoldingIsPositionalSoTheSameNameElsewhereIsUntouched() {
        let existing = ["Grade 1/Picking"]
        XCTAssertEqual(FolderPath.folding("grade 1/picking", into: existing), "Grade 1/Picking")
        // A different place in the tree is a different folder, and keeps the form it was typed with.
        XCTAssertEqual(FolderPath.folding("Grade 2/picking", into: existing), "Grade 2/picking")
    }

    func testFoldingLeavesAnUnknownPathAlone() {
        XCTAssertEqual(FolderPath.folding("New/Thing", into: ["Beginner"]), "New/Thing")
    }

    // MARK: - adding / removing

    func testAddingFoldsIntoTheNamespaceAndRefusesDuplicates() {
        let namespace = ["Beginner/Warm-ups"]
        var folders = FolderPath.adding("beginner/warm-ups", to: [], namespace: namespace)
        XCTAssertEqual(folders, ["Beginner/Warm-ups"])
        folders = FolderPath.adding("BEGINNER/WARM-UPS", to: folders, namespace: namespace)
        XCTAssertEqual(folders, ["Beginner/Warm-ups"], "A second add of the same folder is a no-op")
    }

    func testAddingRejectsAnEmptyPath() {
        XCTAssertEqual(FolderPath.adding("  /  ", to: ["Beginner"]), ["Beginner"])
    }

    func testAddingKeepsMultiMembership() {
        var folders = FolderPath.adding("Grade 2", to: [])
        folders = FolderPath.adding("Technique/Alternate picking", to: folders)
        XCTAssertEqual(folders, ["Grade 2", "Technique/Alternate picking"])
    }

    func testRemovingStripsTheFolderAndItsSubtreeAndNothingElse() {
        let folders = ["Beginner", "Beginner/Warm-ups", "Beginners", "Grade 2"]
        XCTAssertEqual(FolderPath.removing("Beginner", from: folders), ["Beginners", "Grade 2"])
    }

    func testNormalizedDeDuplicatesAStoredArrayOfUnknownProvenance() {
        XCTAssertEqual(FolderPath.normalized([" Beginner / Scales ", "beginner/scales", ""]),
                       ["Beginner/Scales"])
    }

    // MARK: - Rename

    func testRenamingRewritesTheFolderAndEverythingBelowIt() {
        let paths = ["Beginner", "Beginner/Warm-ups", "Grade 2"]
        XCTAssertEqual(FolderPath.renaming("Beginner", to: "Grade 1", in: paths),
                       ["Grade 1", "Grade 1/Warm-ups", "Grade 2"])
    }

    func testRenamingLeavesASiblingWithASharedOpeningAlone() {
        let paths = ["Beginner", "Beginners/Warm-ups"]
        XCTAssertEqual(FolderPath.renaming("Beginner", to: "Grade 1", in: paths),
                       ["Grade 1", "Beginners/Warm-ups"])
    }

    /// A folder *is* its path, so renaming onto an existing one merges rather than making two
    /// folders with the same name.
    func testRenamingOntoAnExistingFolderMerges() {
        XCTAssertEqual(FolderPath.renaming("Grade 1", to: "Grade 2", in: ["Grade 1", "Grade 2"]),
                       ["Grade 2"])
    }

    func testRenamingIgnoresAnEmptyTarget() {
        XCTAssertEqual(FolderPath.renaming("Beginner", to: "  ", in: ["Beginner"]), ["Beginner"])
    }

    func testRenamedChangesOnlyTheLeaf() {
        XCTAssertEqual(FolderPath.renamed("Students/2026/Beginner", toSegment: "Grade 1"),
                       "Students/2026/Grade 1")
        XCTAssertNil(FolderPath.renamed("Beginner", toSegment: "  "))
        XCTAssertNil(FolderPath.renamed("", toSegment: "Grade 1"))
    }
}
