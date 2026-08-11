import XCTest
import SwiftData
@testable import Pocket

/// `JournalWriter` — the shared owner-aware write path (ADR 0058). Proven against a real
/// in-memory store: adding attaches to the right owner and snapshots the right units, empty
/// text is ignored, and update/delete behave. The snapshot-honesty guarantee (a BPM never
/// lands in the loop's song-fraction field) is what these lock down.
final class JournalWriterTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    func testAddToLoopSnapshotsMasteryAndFraction() throws {
        let context = try makeContext()
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        loop.mastery = 3
        loop.commandTempo = 0.9
        context.insert(loop)

        XCTAssertTrue(JournalWriter.add(to: .loop(loop), text: "  clean  ", kind: .breakthrough,
                                        into: context))
        let entry = try XCTUnwrap(loop.journal.first)
        XCTAssertEqual(entry.text, "clean", "text is trimmed")
        XCTAssertEqual(entry.masteryAtEntry, 3)
        XCTAssertEqual(entry.commandTempoAtEntry, 0.9)
        XCTAssertNil(entry.commandBpmAtEntry, "a loop entry never carries a BPM")
        XCTAssertNil(entry.exercise)
    }

    func testAddToExerciseSnapshotsBpmOnly() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider", currentTempo: 90, commandTempo: 120)
        context.insert(exercise)

        XCTAssertTrue(JournalWriter.add(to: .exercise(exercise), text: "held it", kind: .note,
                                        into: context))
        let entry = try XCTUnwrap(exercise.journal.first)
        XCTAssertEqual(entry.commandBpmAtEntry, 120)
        XCTAssertNil(entry.masteryAtEntry, "exercises have no mastery")
        XCTAssertNil(entry.commandTempoAtEntry, "a BPM never lands in the song-fraction field")
        XCTAssertNil(entry.loop)
    }

    func testAddToUnpromotedExerciseRecordsNilBpm() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "New drill")   // commandTempo nil (un-promoted)
        context.insert(exercise)

        XCTAssertTrue(JournalWriter.add(to: .exercise(exercise), text: "first go", kind: .note,
                                        into: context))
        XCTAssertNil(exercise.journal.first?.commandBpmAtEntry)
    }

    func testAddIgnoresWhitespaceOnlyText() throws {
        let context = try makeContext()
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        context.insert(loop)

        XCTAssertFalse(JournalWriter.add(to: .loop(loop), text: "   \n ", kind: .note,
                                         into: context))
        XCTAssertTrue(loop.journal.isEmpty)
    }

    func testUpdateTrimsAndKeepsSnapshot() throws {
        let context = try makeContext()
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        loop.commandTempo = 0.8
        context.insert(loop)
        _ = JournalWriter.add(to: .loop(loop), text: "before", kind: .note, into: context)
        let entry = try XCTUnwrap(loop.journal.first)

        JournalWriter.update(entry, text: "  after  ", kind: .goal)
        XCTAssertEqual(entry.text, "after")
        XCTAssertEqual(entry.kind, .goal)
        XCTAssertEqual(entry.commandTempoAtEntry, 0.8, "snapshot is immutable on edit")
    }

    func testUpdateIgnoresEmptyText() throws {
        let context = try makeContext()
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        context.insert(loop)
        _ = JournalWriter.add(to: .loop(loop), text: "keep me", kind: .note, into: context)
        let entry = try XCTUnwrap(loop.journal.first)

        JournalWriter.update(entry, text: "   ", kind: .struggle)
        XCTAssertEqual(entry.text, "keep me", "empty edit leaves the entry unchanged")
        XCTAssertEqual(entry.kind, .note)
    }

    /// The compact capture sheet names the unit a note is about (ADR 0142) — it can be opened from
    /// inside a routine, where "which of these am I writing about" is a real question. An unnamed unit
    /// must still read as a phrase, since the name is dropped into a sentence.
    func testOwnerDisplayNameFallsBackToThePhraseNotAnEmptyString() {
        let named = Exercise(name: "Alternating picking", currentTempo: 80, commandTempo: 96)
        XCTAssertEqual(JournalOwner.exercise(named).displayName, "Alternating picking")
        let unnamed = Exercise(name: "", currentTempo: 80, commandTempo: 96)
        XCTAssertEqual(JournalOwner.exercise(unnamed).displayName, "this exercise")
        let loop = Loop(name: "", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        XCTAssertEqual(JournalOwner.loop(loop).displayName, "this loop")
    }

    func testDeleteRemovesEntry() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Spider", currentTempo: 90, commandTempo: 120)
        context.insert(exercise)
        _ = JournalWriter.add(to: .exercise(exercise), text: "gone soon", kind: .note, into: context)
        let entry = try XCTUnwrap(exercise.journal.first)

        JournalWriter.delete(entry, from: context)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    // MARK: - Session entries (ADR 0143)

    private func sessionContext(routineName: String = "Morning warm-up",
                                units: [SessionUnitRef] = []) -> SessionJournalContext {
        SessionJournalContext(routineUID: UUID(), routineName: routineName, units: units)
    }

    func testAddToSessionSnapshotsTheRoutineAndItsUnits() throws {
        let context = try makeContext()
        let units = [SessionUnitRef(uid: UUID(), title: "Spider", kind: .exercise),
                     SessionUnitRef(uid: UUID(), title: "Verse riff", kind: .loop)]
        let session = sessionContext(units: units)

        XCTAssertTrue(JournalWriter.add(to: .session(session), text: "  a good hour  ",
                                        kind: .session, into: context))

        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(entry.text, "a good hour", "text is trimmed, as for any owner")
        XCTAssertEqual(entry.routineUID, session.routineUID)
        XCTAssertEqual(entry.routineNameAtEntry, "Morning warm-up")
        XCTAssertEqual(entry.practisedUnits, units)
        XCTAssertEqual(entry.ownerKind, .session)
    }

    /// The honesty guarantee this suite exists for, extended to the third owner: a session spans
    /// several units at several tempos, so **no** tempo or mastery may be invented for it.
    func testASessionEntryCarriesNoTempoOrMastery() throws {
        let context = try makeContext()

        _ = JournalWriter.add(to: .session(sessionContext()), text: "tired today", kind: .session,
                              into: context)

        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertNil(entry.masteryAtEntry)
        XCTAssertNil(entry.commandTempoAtEntry)
        XCTAssertNil(entry.commandBpmAtEntry)
        XCTAssertNil(entry.commandNotesPerBeatAtEntry)
        XCTAssertNil(entry.loop, "no relationship — that is what makes it deletion-safe")
        XCTAssertNil(entry.exercise)
    }

    func testAnEmptySessionNoteIsIgnored() throws {
        let context = try makeContext()

        XCTAssertFalse(JournalWriter.add(to: .session(sessionContext()), text: "   \n ",
                                         kind: .session, into: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    // MARK: - The fourth owner (ADR 0155)

    /// Writing through the fourth owner stores the flag, and stores nothing else. The `isStandalone`
    /// assertion is the one that matters: without it the row would be indistinguishable on disk from
    /// an orphan, and there is no backfill for a distinction that was never recorded.
    func testAddToStandaloneStoresTheFlagAndNoSnapshot() throws {
        let context = try makeContext()

        XCTAssertTrue(JournalWriter.add(to: .standalone, text: "  strings are dead  ",
                                        kind: .note, into: context))

        let entry = try XCTUnwrap(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        XCTAssertEqual(entry.text, "strings are dead", "text is trimmed, as for any owner")
        XCTAssertEqual(entry.ownerKind, .standalone)
        XCTAssertEqual(entry.isStandalone, true)
        XCTAssertNil(entry.masteryAtEntry)
        XCTAssertNil(entry.commandTempoAtEntry)
        XCTAssertNil(entry.commandBpmAtEntry)
        XCTAssertNil(entry.routineUID, "a standalone note is not a session note with a missing id")
        XCTAssertNil(entry.ownerLabelAtEntry, "no caption — it was never about a unit")
        XCTAssertNil(entry.loop)
        XCTAssertNil(entry.exercise)
    }

    func testAnEmptyStandaloneNoteIsIgnored() throws {
        let context = try makeContext()

        XCTAssertFalse(JournalWriter.add(to: .standalone, text: "   \n ", kind: .note,
                                         into: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
    }

    /// The composer's footer copy. Each owner owns a whole sentence (ADR 0155 §5) because the two
    /// fragments it replaced have no honest form here — assembling them yields "Saves to your
    /// Journal's Journal", which is the concrete bug this shape prevents.
    func testStandaloneDestinationLinePromisesNoOwnerAndNoSnapshot() {
        let line = JournalOwner.standalone.destinationLine
        XCTAssertEqual(line, "Saves straight to your Journal — not attached to any loop or exercise.")
        XCTAssertFalse(line.contains("snapshot"), "there is nothing to snapshot")
        XCTAssertFalse(line.contains("Journal's Journal"), "the fragment-assembly bug")
    }

    /// A standalone owner holds no journal to read back — like `.session`, it exists only at the
    /// write seam, so the per-owner browse sheet has nothing to show and never hosts one.
    func testStandaloneOwnerHoldsNoJournal() {
        XCTAssertTrue(JournalOwner.standalone.entries.isEmpty)
        XCTAssertTrue(JournalOwner.standalone.entriesByRecent.isEmpty)
        XCTAssertTrue(JournalOwner.standalone.isEmpty)
    }
}
