import XCTest
@testable import Pocket

/// `JournalTimeline.TagSelection` — the Journal feed's **tag** facet (ADR 0207 D11), the control
/// ADR 0190 D5 deferred.
///
/// Pure logic: models are built **uninserted**, which is safe for property reads and avoids the
/// XCTest-host insert trap.
final class JournalTagFilterTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_699_963_200)

    private func note(_ kind: EntryKind) -> JournalTimeline.Item {
        .note(JournalEntry.forExercise(text: "n", kind: kind, commandBpmAtEntry: 90, createdAt: noon))
    }

    private var take: JournalTimeline.Item {
        .take(Recording(fileName: "\(UUID()).m4a", duration: 12, createdAt: noon))
    }

    // MARK: - What the facet offers

    func testOfferedIsPickerOrderWithoutSession() {
        // `.session` is the one tag the app writes on the player's behalf
        // (`RoutinePlayerView+Finished`), and it would duplicate the owner facet's own Session row.
        XCTAssertFalse(JournalTimeline.TagSelection.offered.contains(.session))
        XCTAssertEqual(JournalTimeline.TagSelection.offered,
                       EntryKind.pickerOrder.filter { $0 != .session })
        // Every other kind is offered — a tag a player can set must be a tag they can find again.
        XCTAssertEqual(Set(JournalTimeline.TagSelection.offered),
                       Set(EntryKind.allCases).subtracting([.session]))
    }

    func testNoteRowSaysItAlsoHoldsTheUntagged() {
        // ADR 0190 D5's objection, answered on the row rather than hidden: `.note` is the default, so
        // this bucket holds both the deliberately-tagged and everyone who never touched the chips.
        XCTAssertEqual(JournalTimeline.TagSelection.label(for: .note), "Note or untagged")
        // Every other row is the chip's own word, so the two controls cannot drift.
        for tag in JournalTimeline.TagSelection.offered where tag != .note {
            XCTAssertEqual(JournalTimeline.TagSelection.label(for: tag), tag.label)
        }
    }

    // MARK: - Matching

    func testEmptySelectionMatchesEverythingIncludingTakes() {
        let selection = JournalTimeline.TagSelection()
        XCTAssertFalse(selection.isFiltering)
        XCTAssertTrue(selection.matches(note(.idea)))
        XCTAssertTrue(selection.matches(note(.session)))
        XCTAssertTrue(selection.matches(take))
    }

    func testTickingOneTagKeepsOnlyThatTag() {
        let selection = JournalTimeline.TagSelection([.idea])
        XCTAssertTrue(selection.matches(note(.idea)))
        XCTAssertFalse(selection.matches(note(.struggle)))
        XCTAssertFalse(selection.matches(note(.note)))
    }

    func testTickingASecondTagWidens() {
        // ADR 0159: OR **within** a facet. An entry carries exactly one tag, so an intersection
        // would empty the screen on the second tick every time.
        let selection = JournalTimeline.TagSelection([.idea, .struggle])
        XCTAssertTrue(selection.matches(note(.idea)))
        XCTAssertTrue(selection.matches(note(.struggle)))
        XCTAssertFalse(selection.matches(note(.goal)))
    }

    func testATakeNeverSurvivesAnActiveTagFilter() {
        // The decision, not an oversight: a take has no `EntryKind` at all, so it falls under no
        // ticked tag — exactly as an orphaned note falls under no owner kind (ADR 0190 D6). It is
        // why the empty state has to name this filter.
        XCTAssertFalse(JournalTimeline.TagSelection([.idea]).matches(take))
        // Even ticking every offered tag does not bring it back, which is the same asymmetry the
        // owner facet has: ticking all is not the same as ticking none.
        let everything = JournalTimeline.TagSelection(Set(JournalTimeline.TagSelection.offered))
        XCTAssertFalse(everything.matches(take))
    }

    func testSessionTaggedNoteIsHiddenByAnyActiveFilter() {
        // `.session` is not offered, so it is in no bucket — the same rule as a take, reached for a
        // different reason. Under no filter it shows, like everything else.
        let everything = JournalTimeline.TagSelection(Set(JournalTimeline.TagSelection.offered))
        XCTAssertFalse(everything.matches(note(.session)))
        XCTAssertTrue(JournalTimeline.TagSelection().matches(note(.session)))
    }

    // MARK: - filter(_:tags:)

    func testFilterPreservesOrderAndDropsTakes() {
        let items = [note(.idea), take, note(.struggle), note(.idea)]
        let kept = JournalTimeline.filter(items, tags: JournalTimeline.TagSelection([.idea]))
        XCTAssertEqual(kept.count, 2)
        XCTAssertEqual(kept.map(\.id), [items[0].id, items[3].id])
    }

    func testFilterUnderEmptySelectionIsIdentity() {
        let items = [note(.idea), take, note(.note)]
        let kept = JournalTimeline.filter(items, tags: JournalTimeline.TagSelection())
        XCTAssertEqual(kept.map(\.id), items.map(\.id))
    }

    // MARK: - Storage

    func testRawValueRoundTrips() {
        let selection = JournalTimeline.TagSelection([.idea, .goal, .improvise])
        XCTAssertEqual(JournalTimeline.TagSelection(rawValue: selection.rawValue), selection)
    }

    func testRawValueIsWrittenInOfferedOrderNotSetOrder() {
        // A `Set` has no order; joining it directly would write a different string for the same
        // selection between runs, churning `UserDefaults` and making this test pass by hash seed.
        let selection = JournalTimeline.TagSelection([.improvise, .goal, .idea])
        XCTAssertEqual(selection.rawValue, "goal,idea,improvise")
    }

    func testEmptySelectionWritesEmptyString() {
        XCTAssertEqual(JournalTimeline.TagSelection().rawValue, "")
        XCTAssertEqual(JournalTimeline.TagSelection(rawValue: ""), JournalTimeline.TagSelection())
    }

    func testUnknownAndUnofferedTokensAreDropped() {
        // `@AppStorage` falls back to its default only when the key is *absent*, so a garbled value
        // has to degrade to the unfiltered feed rather than fail the parse. `session` is dropped for
        // the same reason it is not offered: it would filter to a row the sheet cannot untick.
        XCTAssertEqual(JournalTimeline.TagSelection(rawValue: "idea,gibberish,session"),
                       JournalTimeline.TagSelection([.idea]))
        XCTAssertEqual(JournalTimeline.TagSelection(rawValue: "session"),
                       JournalTimeline.TagSelection())
    }

    func testDefaultIsUnfiltered() {
        XCTAssertEqual(JournalTimeline.TagSelection.default, JournalTimeline.TagSelection())
        XCTAssertFalse(JournalTimeline.TagSelection.default.isFiltering)
    }

    // MARK: - Toggling

    func testToggleAddsThenRemoves() {
        var selection = JournalTimeline.TagSelection()
        selection.toggle(.idea)
        XCTAssertEqual(selection.tags, [.idea])
        selection.toggle(.idea)
        XCTAssertTrue(selection.tags.isEmpty)
    }

    // MARK: - Phrasing

    func testPhraseJoinsWithOrAndUsesTheRowsOwnWords() {
        XCTAssertNil(JournalTimeline.TagSelection().phrase)
        XCTAssertEqual(JournalTimeline.TagSelection([.idea]).phrase, "Idea")
        // Ordered by `offered`, never by the set — and `.note` keeps the row's clumsy, honest label.
        XCTAssertEqual(JournalTimeline.TagSelection([.note, .struggle]).phrase,
                       "Struggle or Note or untagged")
    }

    func testSummaryNamesItsOwnFacetBeyondTwo() {
        // "tags", where the owner facet says "kinds": both can land on the one Show chip, and a bare
        // count would not say which control to open.
        XCTAssertNil(JournalTimeline.TagSelection().summary)
        XCTAssertEqual(JournalTimeline.TagSelection([.idea]).summary, "Idea")
        XCTAssertEqual(JournalTimeline.TagSelection([.idea, .goal, .struggle]).summary, "3 tags")
    }
}
