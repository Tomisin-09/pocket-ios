import XCTest
@testable import Pocket

/// **The Journal feed's owner-kind facet** (ADR 0190 D5 / D6 / D10) — which kinds an item falls
/// under, and what a selection of them shows.
///
/// A third file beside `JournalReviewTests` and `JournalTimelineTests`, mirroring the source split:
/// the facet grew a selection type of its own when it became multi-select, and the union relation is
/// the part most worth pinning down — it is the one a reasonable reader would guess wrong, since
/// every other list a player uses narrows on a second tick (ADR 0159).
///
/// Pure logic — models are built **uninserted** (no `ModelContext`), which is safe for property reads
/// and avoids the XCTest-host insert trap.
final class JournalOwnerFilterTests: XCTestCase {

    // 2023-11-14 12:00:00 GMT, plus offsets — deterministic, no force-unwraps.
    private let noon = Date(timeIntervalSince1970: 1_699_963_200)
    private let hour: TimeInterval = 3_600

    /// Reads at the call site the way the sheet reads on screen: the kinds that are ticked.
    private func showing(_ kinds: JournalTimeline.OwnerFilter...) -> JournalTimeline.OwnerSelection {
        JournalTimeline.OwnerSelection(Set(kinds))
    }

    private func note(at date: Date) -> JournalEntry {
        JournalEntry.forExercise(text: "n", kind: .note, commandBpmAtEntry: 90, createdAt: date)
    }

    private func take(at date: Date) -> Recording {
        Recording(fileName: "\(UUID()).m4a", duration: 12, createdAt: date)
    }

    private func loopNote(at date: Date) -> JournalEntry {
        let entry = JournalEntry.forLoop(text: "n", kind: .note, masteryAtEntry: 2,
                                         commandTempoAtEntry: 0.9, createdAt: date)
        entry.loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 1.0, repeats: 1)
        return entry
    }

    private func exerciseNote(at date: Date) -> JournalEntry {
        let entry = note(at: date)
        entry.exercise = Exercise(name: "Chords", currentTempo: 80, commandTempo: 96)
        return entry
    }

    private func sessionNote(at date: Date) -> JournalEntry {
        JournalEntry.forSession(text: "n", kind: .session, routineUID: UUID(),
                                routineName: "Morning warm-up", units: [], createdAt: date)
    }

    private func metronomeNote(at date: Date) -> JournalEntry {
        let context = MetronomeJournalContext(bpm: 92, timeSignature: .standard,
                                              subdivision: .none, withdrawal: .off)
        return JournalEntry.forMetronome(text: "n", kind: .note, context: context, createdAt: date)
    }

    // MARK: - what each kind holds (ADR 0190 D5 / D6)

    /// An empty selection is a pass-through, not a filter that happens to keep everything — an orphan
    /// and a song-owned take have no case of their own and must still be reachable (D6).
    func testAnEmptySelectionKeepsEverythingIncludingTheUnfilterableKinds() {
        let orphan = note(at: noon)          // no relationships at all
        orphan.ownerLabelAtEntry = "Spider · exercise"
        let songTake = take(at: noon - hour)
        songTake.song = Song.sample()

        let items = JournalTimeline.merge(entries: [orphan, sessionNote(at: noon - 2 * hour)],
                                          takes: [songTake])
        XCTAssertEqual(JournalTimeline.filter(items, owner: showing()).map(\.id), items.map(\.id))
    }

    /// Each offered kind keeps exactly its own notes.
    func testEachKindSeparatesItsOwnNotes() {
        let cases: [(JournalTimeline.OwnerFilter, JournalEntry)] = [
            (.exercise, exerciseNote(at: noon)),
            (.loop, loopNote(at: noon - hour)),
            (.session, sessionNote(at: noon - 2 * hour)),
            (.metronome, metronomeNote(at: noon - 3 * hour)),
            (.standalone, JournalEntry.forStandalone(text: "n", kind: .note,
                                                     createdAt: noon - 4 * hour))
        ]
        let items = JournalTimeline.merge(entries: cases.map(\.1), takes: [])

        for (kind, entry) in cases {
            XCTAssertEqual(JournalTimeline.filter(items, owner: showing(kind)).map(\.id),
                           [entry.uid], "\(kind) kept the wrong entries")
        }
    }

    /// **The filter reaches takes on the same axis as notes** (ADR 0190 D2's reasoning applied to
    /// D5): the Journal space's premise is one feed, so *Loop* has to bring the loop's takes with its
    /// notes — a control that silently dropped every take would mean something different depending on
    /// which rows a day happened to hold.
    func testAKindKeepsTakesOfTheSameKind() {
        let loopTake = take(at: noon)
        loopTake.loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 1.0, repeats: 1)
        let exerciseTake = take(at: noon - hour)
        exerciseTake.exercise = Exercise(name: "Chords", currentTempo: 80, commandTempo: 96)

        let items = JournalTimeline.merge(entries: [loopNote(at: noon - 2 * hour)],
                                          takes: [loopTake, exerciseTake])

        let loops = JournalTimeline.filter(items, owner: showing(.loop))
        XCTAssertEqual(loops.count, 2, "a loop's take belongs under Loop beside its note")
        XCTAssertTrue(loops.contains { $0.id == loopTake.uid })
        XCTAssertEqual(JournalTimeline.filter(items, owner: showing(.exercise)).map(\.id),
                       [exerciseTake.uid])
    }

    /// **An orphan is in none of the five and that is a finding, not a simplification** (ADR 0190
    /// D6). A note that outlives its unit keeps its caption but not which *kind* of unit it had been —
    /// `loop` and `exercise` both nullify — so the app genuinely no longer knows, and offering it
    /// under either would be inventing the answer.
    func testAnOrphanedNoteIsInNoOfferedKind() {
        let orphan = note(at: noon)
        orphan.ownerLabelAtEntry = "Slow Bend · Verse riff"
        let items = JournalTimeline.merge(entries: [orphan], takes: [])

        for kind in JournalTimeline.OwnerFilter.allCases {
            XCTAssertTrue(JournalTimeline.filter(items, owner: showing(kind)).isEmpty,
                          "an orphan surfaced under \(kind)")
        }
        XCTAssertEqual(JournalTimeline.filter(items, owner: showing()).count, 1)
    }

    /// The take-shaped version of the same loss, plus the song case: a **song**-owned take is not one
    /// of D6's five kinds either. If songs ever gain a recorder, this is the test that has to change
    /// deliberately rather than a fall-through that quietly hides them.
    func testAnOwnerlessOrSongTakeIsInNoOfferedKind() {
        let songTake = take(at: noon)
        songTake.song = Song.sample()
        let items = JournalTimeline.merge(entries: [], takes: [songTake, take(at: noon - hour)])

        for kind in JournalTimeline.OwnerFilter.allCases {
            XCTAssertTrue(JournalTimeline.filter(items, owner: showing(kind)).isEmpty,
                          "a song-owned or ownerless take surfaced under \(kind)")
        }
        XCTAssertEqual(JournalTimeline.filter(items, owner: showing()).count, 2)
    }

    // MARK: - the union (ADR 0190 D10, ADR 0159)

    /// **The decision this facet turns on: a second tick widens.** An item has exactly one owner
    /// kind, so an intersection of two kinds would return nothing every single time — which is how
    /// ADR 0159's collection filter behaved, and how it was found to be broken. This is the test that
    /// fails if anyone reaches for `allSatisfy` again.
    func testTickingASecondKindWidensRatherThanNarrows() {
        let loop = loopNote(at: noon)
        let session = sessionNote(at: noon - hour)
        let exercise = exerciseNote(at: noon - 2 * hour)
        let items = JournalTimeline.merge(entries: [loop, session, exercise], takes: [])

        let both = JournalTimeline.filter(items, owner: showing(.loop, .session))
        XCTAssertEqual(both.map(\.id), [loop.uid, session.uid])
        XCTAssertGreaterThan(both.count,
                             JournalTimeline.filter(items, owner: showing(.loop)).count)
    }

    /// Widening stops at everything the app can still name. **Ticking all five is not the same as
    /// ticking none** — an orphan matches none of the five — and that asymmetry is deliberate (D6),
    /// so it is asserted rather than left to be discovered.
    func testEveryKindTickedStillExcludesTheUnnameableOnes() {
        let orphan = note(at: noon)
        orphan.ownerLabelAtEntry = "Slow Bend · Verse riff"
        let items = JournalTimeline.merge(entries: [orphan, sessionNote(at: noon - hour)], takes: [])

        let all = JournalTimeline.OwnerSelection(Set(JournalTimeline.OwnerFilter.allCases))
        XCTAssertEqual(JournalTimeline.filter(items, owner: all).count, 1)
        XCTAssertEqual(JournalTimeline.filter(items, owner: showing()).count, 2)
    }

    /// Owner is a fourth independent axis and composes with the other three in any order.
    func testOwnerComposesWithScopeAndPinned() {
        let pinnedLoopNote = loopNote(at: noon)
        pinnedLoopNote.isPinned = true
        let plainLoopNote = loopNote(at: noon - hour)
        let pinnedLoopTake = take(at: noon - 2 * hour)
        pinnedLoopTake.isPinned = true
        pinnedLoopTake.loop = Loop(name: "Verse", start: 0.1, end: 0.2, speed: 1.0, repeats: 1)

        let items = JournalTimeline.merge(entries: [pinnedLoopNote, plainLoopNote,
                                                    exerciseNote(at: noon - 3 * hour)],
                                          takes: [pinnedLoopTake])

        let ownerFirst = JournalTimeline.filter(
            JournalTimeline.filter(JournalTimeline.filter(items, owner: showing(.loop)),
                                   scope: .notes),
            pinnedOnly: true)
        let pinnedFirst = JournalTimeline.filter(
            JournalTimeline.filter(JournalTimeline.filter(items, pinnedOnly: true),
                                   owner: showing(.loop)),
            scope: .notes)

        XCTAssertEqual(ownerFirst.map(\.id), [pinnedLoopNote.uid])
        XCTAssertEqual(pinnedFirst.map(\.id), ownerFirst.map(\.id))
    }

    // MARK: - crossing @AppStorage (ADR 0190 D8 / D10)

    /// The stored string is written in `allCases` order, **never the set's own**. A `Set` has no
    /// order, so a naive join writes a different string for the same selection between runs — which
    /// churns `UserDefaults` and makes this very round-trip pass or fail by hash seed.
    func testTheStoredStringIsOrderedByDeclarationNotBySet() {
        let one = JournalTimeline.OwnerSelection([.standalone, .loop, .exercise])
        let other = JournalTimeline.OwnerSelection([.exercise, .standalone, .loop])
        XCTAssertEqual(one.rawValue, "exercise,loop,standalone")
        XCTAssertEqual(one.rawValue, other.rawValue)
    }

    func testASelectionSurvivesARoundTripThroughItsRawValue() {
        for kinds in [Set<JournalTimeline.OwnerFilter>(),
                      [.session],
                      [.loop, .metronome],
                      Set(JournalTimeline.OwnerFilter.allCases)] {
            let selection = JournalTimeline.OwnerSelection(kinds)
            XCTAssertEqual(JournalTimeline.OwnerSelection(rawValue: selection.rawValue), selection)
        }
    }

    /// **The migration from the single-select build, and it is free.** That key held one bare kind,
    /// which parses to a one-kind selection — the same feed the player left on. The old `"all"`
    /// sentinel is not a case any more and drops to empty, which is exactly what it meant.
    func testTheOldSingleValueKeysStillParse() {
        XCTAssertEqual(JournalTimeline.OwnerSelection(rawValue: "session").kinds, [.session])
        XCTAssertFalse(JournalTimeline.OwnerSelection(rawValue: "all").isFiltering)
    }

    /// Unknown tokens are dropped rather than failing the parse. `@AppStorage` falls back to the
    /// default only for an *absent* key, not an unparseable one, so degrading to the unfiltered feed
    /// is the only safe landing.
    func testAGarbledStoredValueDegradesToTheUnfilteredFeed() {
        XCTAssertEqual(JournalTimeline.OwnerSelection(rawValue: "loop,nonsense,,session").kinds,
                       [.loop, .session])
        XCTAssertFalse(JournalTimeline.OwnerSelection(rawValue: "🎸").isFiltering)
    }

    // MARK: - what the screen says about it

    /// The phrase names **every** ticked kind and joins them with "or". ADR 0159 §3's finding was
    /// that a filter stating the count and hiding the relation leaves the one question worth asking
    /// unanswered — so the empty state and the VoiceOver label both spell it out.
    func testThePhraseNamesEveryKindAndTheRelation() {
        XCTAssertNil(JournalTimeline.OwnerSelection().phrase)
        XCTAssertEqual(showing(.loop).phrase, "Loop")
        XCTAssertEqual(showing(.loop, .session).phrase, "Loop or Session")
        XCTAssertEqual(showing(.standalone, .exercise).phrase, "Exercise or Just me")
    }

    /// The menu row is one line, so past two kinds it counts instead. The phrase is still what the
    /// empty state and VoiceOver use — this shortening is the row's alone.
    func testTheMenuRowSummaryCountsPastTwoKinds() {
        XCTAssertNil(JournalTimeline.OwnerSelection().summary)
        XCTAssertEqual(showing(.loop, .session).summary, "Loop or Session")
        XCTAssertEqual(showing(.loop, .session, .metronome).summary, "3 kinds")
    }

    func testTogglingAKindAddsThenRemovesIt() {
        var selection = JournalTimeline.OwnerSelection()
        selection.toggle(.metronome)
        XCTAssertEqual(selection.kinds, [.metronome])
        selection.toggle(.metronome)
        XCTAssertFalse(selection.isFiltering)
    }
}
