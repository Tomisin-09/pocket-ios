import XCTest
@testable import Pocket

/// **Reading the journal back** (ADR 0190) — the pin, the persisted defaults, and the jump.
///
/// Split from `JournalTimelineTests`, which covers the merge and the owner labels: those answer
/// *what is on the feed*, and these answer *what the reader can do to find something on it*. The
/// owner facet has a third file of its own (`JournalOwnerFilterTests`), for the same reason its
/// types do. The split is also what keeps all three under the 400-line cap.
///
/// Pure logic — models are built **uninserted** (no `ModelContext`), which is safe for property reads
/// and avoids the XCTest-host insert trap. Every filter here reads model *properties* only, which is
/// the property `JournalTimeline`'s doc comment exists to protect.
final class JournalReviewTests: XCTestCase {

    // 2023-11-14 12:00:00 GMT, plus offsets — deterministic, no force-unwraps.
    private let noon = Date(timeIntervalSince1970: 1_699_963_200)
    private let hour: TimeInterval = 3_600

    private func note(at date: Date, kind: EntryKind = .note) -> JournalEntry {
        JournalEntry.forExercise(text: "n", kind: kind, commandBpmAtEntry: 90, createdAt: date)
    }

    private func take(at date: Date) -> Recording {
        Recording(fileName: "\(UUID()).m4a", duration: 12, createdAt: date)
    }

    // MARK: - pinned filter (ADR 0190)

    func testPinnedOnlyOffKeepsEverything() {
        let items = JournalTimeline.merge(entries: [note(at: noon)], takes: [take(at: noon - hour)])
        XCTAssertEqual(JournalTimeline.filter(items, pinnedOnly: false).count, 2)
    }

    /// The pin reaches **both** row kinds (ADR 0190 D2) — the Journal space's premise is one feed, so
    /// a filter that could only ever keep notes would make the control mean something different
    /// depending on which rows happened to be pinned.
    func testPinnedOnlyKeepsPinnedNotesAndPinnedTakes() {
        let pinnedNote = note(at: noon)
        pinnedNote.isPinned = true
        let plainNote = note(at: noon - hour)
        let pinnedTake = take(at: noon - 2 * hour)
        pinnedTake.isPinned = true
        let plainTake = take(at: noon - 3 * hour)

        let items = JournalTimeline.merge(entries: [pinnedNote, plainNote],
                                          takes: [pinnedTake, plainTake])
        let kept = JournalTimeline.filter(items, pinnedOnly: true)

        XCTAssertEqual(kept.count, 2)
        XCTAssertEqual(kept.map(\.id), [pinnedNote.uid, pinnedTake.uid])
    }

    /// Nothing pins itself (ADR 0190 D1). A `.breakthrough` is the entry an app would be most tempted
    /// to mark on the player's behalf, and marking it would be the app forming a view about which of
    /// their practice mattered — ADR 0070's line, in the form hardest to see coming.
    func testNoKindIsPinnedByDefault() {
        for kind in EntryKind.allCases {
            XCTAssertFalse(note(at: noon, kind: kind).isPinned, "\(kind) pinned itself")
        }
        XCTAssertFalse(take(at: noon).isPinned)
    }

    /// Pinned narrows and never reorders (ADR 0190 D4): the feed is day-grouped, and floating a pin
    /// to the top would render it under a day it did not happen in.
    func testPinnedOnlyPreservesChronologicalOrder() {
        let older = note(at: noon - 5 * hour)
        older.isPinned = true
        let newer = note(at: noon)
        newer.isPinned = true

        let items = JournalTimeline.merge(entries: [older, newer], takes: [])
        XCTAssertEqual(JournalTimeline.filter(items, pinnedOnly: true).map(\.date), [noon, noon - 5 * hour])
    }

    /// Scope and pin are independent axes and compose in either order.
    func testPinnedComposesWithScope() {
        let pinnedNote = note(at: noon)
        pinnedNote.isPinned = true
        let pinnedTake = take(at: noon - hour)
        pinnedTake.isPinned = true

        let items = JournalTimeline.merge(entries: [pinnedNote, note(at: noon - 2 * hour)],
                                          takes: [pinnedTake, take(at: noon - 3 * hour)])
        let notesFirst = JournalTimeline.filter(JournalTimeline.filter(items, scope: .notes),
                                                pinnedOnly: true)
        let pinnedFirst = JournalTimeline.filter(JournalTimeline.filter(items, pinnedOnly: true),
                                                 scope: .notes)
        XCTAssertEqual(notesFirst.map(\.id), [pinnedNote.uid])
        XCTAssertEqual(pinnedFirst.map(\.id), notesFirst.map(\.id))
    }

    // MARK: - persistence raw values (ADR 0190 D8)

    /// The three persisted enums cross `@AppStorage` as their raw strings, so a raw value is a
    /// **stored** value: renaming one silently resets every player's screen to its default on the
    /// next launch. Pinned here so that rename has to be a deliberate act.
    func testPersistedFilterRawValuesAreStable() {
        XCTAssertEqual(JournalTimeline.Scope.allCases.map(\.rawValue), ["all", "notes", "takes"])
        XCTAssertEqual(JournalTimeline.SortOrder.allCases.map(\.rawValue), ["newest", "oldest"])
        XCTAssertEqual(JournalTimeline.OwnerFilter.allCases.map(\.rawValue),
                       ["exercise", "loop", "session", "metronome", "standalone"])
    }

    /// Each default is single-sourced — the `@AppStorage` initialisers read these, rather than
    /// repeating a literal SwiftUI would actually use for an unset key.
    func testDefaultsAreTheUnfilteredFeed() {
        XCTAssertEqual(JournalTimeline.Scope.default, .all)
        XCTAssertEqual(JournalTimeline.SortOrder.default, .newest)
        XCTAssertFalse(JournalTimeline.OwnerSelection.default.isFiltering)
    }

    // MARK: - jump to a date (ADR 0190 D9)

    private func day(_ offsetDays: Int) -> Date {
        Calendar.current.startOfDay(for: noon.addingTimeInterval(Double(offsetDays) * 86_400))
    }

    func testJumpLandsExactlyOnADayThatHasEntries() {
        let days = [day(0), day(-3), day(-10)]
        XCTAssertEqual(JournalTimeline.jumpTarget(for: day(-3), in: days), day(-3))
    }

    /// **At or before**, because most days have no entry: picking the 14th when you last played on
    /// the 11th has to land somewhere, and landing *after* would scroll past the work being reached
    /// for.
    func testJumpFallsBackToTheNearestEarlierDay() {
        let days = [day(0), day(-3), day(-10)]
        XCTAssertEqual(JournalTimeline.jumpTarget(for: day(-5), in: days), day(-10))
        XCTAssertEqual(JournalTimeline.jumpTarget(for: day(-1), in: days), day(-3))
    }

    /// The one exception: a day earlier than the whole journal has nothing at or before it, so the
    /// jump falls **forwards** to the earliest section. Doing nothing there would be
    /// indistinguishable from a broken control.
    func testJumpBeforeTheJournalBeginsLandsOnItsEarliestDay() {
        let days = [day(0), day(-3), day(-10)]
        XCTAssertEqual(JournalTimeline.jumpTarget(for: day(-99), in: days), day(-10))
    }

    /// A `DatePicker` hands back an instant partway through a day; section keys are start-of-day.
    func testJumpNormalisesTheChosenInstantToItsDay() {
        let days = [day(0), day(-3)]
        let midAfternoon = day(-3).addingTimeInterval(15 * 3_600)
        XCTAssertEqual(JournalTimeline.jumpTarget(for: midAfternoon, in: days), day(-3))
    }

    /// Order-independent by construction — it reads the *set* of days, so `newest` and `oldest` jump
    /// to the same section rather than to opposite ends of the feed.
    func testJumpIsIndependentOfFeedOrder() {
        let newestFirst = [day(0), day(-3), day(-10)]
        XCTAssertEqual(JournalTimeline.jumpTarget(for: day(-5), in: newestFirst),
                       JournalTimeline.jumpTarget(for: day(-5), in: newestFirst.reversed()))
    }

    func testJumpOnAnEmptyFeedHasNoTarget() {
        XCTAssertNil(JournalTimeline.jumpTarget(for: noon, in: []))
    }

    // MARK: - the reset that keeps a driven run honest (ADR 0190 D8)

    /// A simulator keeps its `UserDefaults` between runs, and these are the first filters in the app
    /// that survive leaving a screen. Without the launch reset, a shoot that switches the feed to
    /// *Takes* leaves it there for the next test — and `testJournalTakes` sorts before
    /// `testJournalTimeline`, so the timeline figure comes back a clean photograph of the wrong list.
    ///
    /// Writes and restores the four keys around itself, so running this test is not itself a way to
    /// change how the app opens.
    func testResettingJournalFiltersClearsAllFourKeys() {
        let keys = [AppSettings.Key.journalScope, AppSettings.Key.journalSortOrder,
                    AppSettings.Key.journalPinnedOnly, AppSettings.Key.journalOwnerFilter]
        let defaults = UserDefaults.standard
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        defaults.set(JournalTimeline.Scope.takes.rawValue, forKey: AppSettings.Key.journalScope)
        defaults.set(JournalTimeline.SortOrder.oldest.rawValue, forKey: AppSettings.Key.journalSortOrder)
        defaults.set(true, forKey: AppSettings.Key.journalPinnedOnly)
        defaults.set(JournalTimeline.OwnerFilter.session.rawValue,
                     forKey: AppSettings.Key.journalOwnerFilter)

        AppSettings.resetJournalFilters()

        for key in keys {
            XCTAssertNil(defaults.object(forKey: key),
                         "\(key) survived the reset, so a driven run inherits it")
        }
    }
}
