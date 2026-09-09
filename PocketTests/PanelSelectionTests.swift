import XCTest
@testable import Pocket

/// Multi-select state for the loops / markers panels (ADR 0125). Pure rules: what a hold
/// seeds, what Select-all does when everything is already selected, and what happens to a
/// live selection when the rows underneath it are deleted.
final class PanelSelectionTests: XCTestCase {

    private let alpha = UUID()
    private let beta = UUID()
    private let gamma = UUID()

    // MARK: entering

    /// The mode opens with nothing selected — the way in is a hold on the header, and a
    /// header hold names no particular row.
    func testBeginSelectsNothing() {
        var selection = PanelSelection()
        selection.begin()
        XCTAssertTrue(selection.isActive)
        XCTAssertTrue(selection.isEmpty)
    }

    func testTogglesAreIgnoredWhileInactive() {
        var selection = PanelSelection()
        selection.toggle(alpha)
        XCTAssertTrue(selection.isEmpty)
        XCTAssertFalse(selection.isActive)
    }

    // MARK: selecting

    func testToggleAddsThenRemoves() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggle(alpha)
        selection.toggle(beta)
        XCTAssertEqual(selection.count, 2)
        selection.toggle(alpha)
        XCTAssertEqual(selection.ids, [beta])
    }

    func testToggleAllSelectsEverything() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggle(alpha)
        selection.toggleAll(of: [alpha, beta, gamma])
        XCTAssertEqual(selection.ids, [alpha, beta, gamma])
        XCTAssertTrue(selection.allSelected(of: [alpha, beta, gamma]))
    }

    /// Select-all is a toggle: a second tap with everything selected clears it, so the
    /// header never needs a separate "none" control.
    func testToggleAllClearsWhenEverythingIsSelected() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggleAll(of: [alpha, beta])
        selection.toggleAll(of: [alpha, beta])
        XCTAssertTrue(selection.isEmpty)
        XCTAssertTrue(selection.isActive, "clearing the selection must not leave the mode")
    }

    func testAllSelectedIsFalseForAnEmptyList() {
        var selection = PanelSelection()
        selection.begin()
        XCTAssertFalse(selection.allSelected(of: []))
    }

    // MARK: rows disappearing underneath

    /// A bulk delete removes exactly the rows that were selected; the stale ids must go
    /// or the header keeps counting rows that aren't there.
    func testReconcileDropsDeletedRows() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggleAll(of: [alpha, beta, gamma])
        selection.reconcile(with: [beta])
        XCTAssertEqual(selection.ids, [beta])
        XCTAssertTrue(selection.isActive)
    }

    func testReconcileEndsTheModeWhenNothingIsLeft() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggle(alpha)
        selection.reconcile(with: [])
        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.isEmpty)
    }

    func testEndClearsEverything() {
        var selection = PanelSelection()
        selection.begin()
        selection.toggle(alpha)
        selection.end()
        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.isEmpty)
    }

    // MARK: header title

    func testTitleReadsAsAPromptWhenNothingIsSelected() {
        XCTAssertEqual(PanelSelection.title(count: 0, noun: "loop", plural: "loops"), "Select loops")
    }

    func testTitleSingularAndPlural() {
        XCTAssertEqual(PanelSelection.title(count: 1, noun: "loop", plural: "loops"), "1 loop selected")
        XCTAssertEqual(PanelSelection.title(count: 4, noun: "marker", plural: "markers"),
                       "4 markers selected")
    }

    // MARK: - ADR 0206 D2, seeding a selection

    /// The snags panel's "in this loop" shortcut hands the selection a set rather than performing a
    /// delete — the whole point being that the rows it means end up visibly ticked.
    func testSelectingASubsetAddsToWhatIsAlreadyChosen() {
        let first = UUID()
        let second = UUID()
        var selection = PanelSelection()
        selection.begin()
        selection.toggle(first)

        selection.select([second])

        XCTAssertEqual(selection.count, 2)
        XCTAssertTrue(selection.contains(first), "Seeding a second span must not drop the first")
    }

    /// Every mutation on this type is inert outside the mode, so a stray call cannot conjure a
    /// selection over a panel that is not selecting.
    func testSelectingASubsetDoesNothingWhileBrowsing() {
        var selection = PanelSelection()
        selection.select([UUID(), UUID()])
        XCTAssertTrue(selection.isEmpty)
    }
}
