import SwiftData
import XCTest
@testable import Pocket

/// **Attaching a source to a place** (ADR 0264 D5): *Attach to…* and *Start an exercise from this*.
/// What moves and what is copied, the words on the source's screen, and the store's write.
///
/// The verdicts and words are tested on uninserted values. The writes use an in-memory store, because
/// an owner's list only fills its inverse inside a context, and its order is the thing being asserted.
@MainActor
final class ReferenceFilingTests: XCTestCase {

    private let lesson = "https://example.com/a"

    // MARK: - Move or copy, on values

    func testASourceKeptForLaterMoves() {
        let kept = ReferenceLink(urlString: lesson)
        XCTAssertEqual(ReferenceFiling.decide(for: source(kept)), .move(kept.uid))
    }

    /// D2's two deleted drills leave two kept rows: the newest moves, and the other stays kept.
    func testTheNewestOfTwoKeptRowsMoves() {
        let older = ReferenceLink(urlString: lesson, dateAdded: .now - 60)
        let newer = ReferenceLink(urlString: lesson, dateAdded: .now)
        XCTAssertEqual(ReferenceFiling.decide(for: source(older, newer)), .move(newer.uid))
    }

    func testAFiledLinkIsCopied() {
        let filed = ReferenceLink(urlString: lesson, exercise: Exercise(name: "Spider"))
        XCTAssertEqual(ReferenceFiling.decide(for: source(filed)), .copy(filed.uid))
    }

    /// A filed source that also has a row kept for later (D3) files that row, note and all, rather than
    /// copying the link a third time and leaving it behind.
    func testAFiledSourcesKeptRowMovesBeforeAnythingIsCopied() {
        let filed = ReferenceLink(urlString: lesson, dateAdded: .now, exercise: Exercise(name: "Spider"))
        let kept = ReferenceLink(urlString: lesson, dateAdded: .now - 60)
        XCTAssertEqual(ReferenceFiling.decide(for: source(filed, kept)), .move(kept.uid))
    }

    /// A file is copied as a link is: a second row naming the same file.
    func testAFiledFileIsCopied() {
        let picture = ReferenceLink(attachmentFileName: "a.jpg", kind: .image, exercise: Exercise(name: "Spider"))
        XCTAssertEqual(ReferenceFiling.decide(for: source(picture)), .copy(picture.uid))
    }

    // MARK: - The words (D5)

    func testTheAttachButtonSaysWhatItWillDo() {
        let kept = source(ReferenceLink(urlString: lesson))
        let filed = source(ReferenceLink(urlString: lesson, exercise: Exercise(name: "Spider")))
        let filedFile = source(ReferenceLink(attachmentFileName: "a.pdf", kind: .pdf, song: song()))
        XCTAssertEqual(ReferenceFiling.attachTitle(for: kept), "Attach to…")
        XCTAssertEqual(ReferenceFiling.attachTitle(for: filed), "Also attach to…")
        XCTAssertEqual(ReferenceFiling.attachTitle(for: filedFile), "Also attach to…", "a file too")
        XCTAssertEqual(ReferenceFiling.pickerTitle(for: filed), "Also attach to",
                       "the sheet's title drops the ellipsis")
    }

    func testStartingAnExerciseIsTheMainActionOnlyWhileNotFiled() {
        let kept = source(ReferenceLink(urlString: lesson))
        let filed = source(ReferenceLink(urlString: lesson, exercise: Exercise(name: "Spider")))
        XCTAssertEqual(ReferenceFiling.startTitle(for: kept), "Start an exercise from this")
        XCTAssertEqual(ReferenceFiling.startCaption(for: kept), "New exercise opens with this link already attached.")
        XCTAssertEqual(ReferenceFiling.startTitle(for: filed), "Start another exercise from this")
        XCTAssertNil(ReferenceFiling.startCaption(for: filed))
    }

    /// A file's caption names its kind. Once filed, a file starts another drill as a link does.
    func testAFileNamesItselfAndStartsAnotherDrillOnceFiled() {
        let keptPicture = source(ReferenceLink(attachmentFileName: "a.jpg", kind: .image))
        XCTAssertEqual(ReferenceFiling.startCaption(for: keptPicture),
                       "New exercise opens with this picture already attached.")
        let filedPicture = source(ReferenceLink(attachmentFileName: "a.jpg", kind: .image, song: song()))
        XCTAssertEqual(ReferenceFiling.startTitle(for: filedPicture), "Start another exercise from this")
    }

    // MARK: - Edit (D3), on values

    /// A file in two places is one file with one name, and a note per place.
    func testEditingAFileRenamesEveryRowAndNotesOnlyItsOwn() {
        let here = ReferenceLink(title: "Chart", note: "Bar 3", attachmentFileName: "a.pdf", kind: .pdf,
                                 exercise: Exercise(name: "Spider"))
        let there = ReferenceLink(title: "Chart", note: "Intro only", attachmentFileName: "a.pdf", kind: .pdf,
                                  routine: Routine(name: "Week 3"))
        XCTAssertTrue(ReferenceLinkStore.edit(here, of: source(here, there),
                                              title: "Solo chart", url: "", note: "Bars 3 to 8"))
        XCTAssertEqual([here.title, there.title], ["Solo chart", "Solo chart"])
        XCTAssertEqual([here.note, there.note], ["Bars 3 to 8", "Intro only"])
    }

    /// A link's new address goes to every row, so the source stays one; one the gate refuses writes nothing.
    func testEditingALinkWritesItsAddressToEveryRow() {
        let here = ReferenceLink(title: "Lesson", note: "From 3:40", urlString: lesson,
                                 exercise: Exercise(name: "Spider"))
        let there = ReferenceLink(title: "Lesson", urlString: lesson, routine: Routine(name: "Week 3"))
        let before = source(here, there)
        XCTAssertFalse(ReferenceLinkStore.edit(here, of: before, title: "X", url: "javascript:alert(1)", note: ""))
        XCTAssertEqual([here.title, there.title], ["Lesson", "Lesson"])
        XCTAssertTrue(ReferenceLinkStore.edit(here, of: before, title: "Lesson, part 2",
                                              url: "https://example.com/b", note: "From 3:40"))
        XCTAssertEqual(Set([here.urlString, there.urlString]), ["https://example.com/b"])
        XCTAssertEqual(there.title, "Lesson, part 2")
        XCTAssertEqual(there.note, "")
    }

    // MARK: - The write, in a store

    func testAttachingAKeptLinkMovesItWithItsNoteToTheEndOfTheList() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        let first = try XCTUnwrap(ReferenceLinkStore.add(title: "First", url: "https://example.com/1",
                                                         to: drill, in: context))
        let kept = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: lesson, note: "From 3:40",
                                                        to: KeepForLater(), in: context))
        try context.save()

        let attached = ReferenceLinkStore.attach(try fetchedSource(kept, in: context), to: drill, in: context)
        try context.save()

        XCTAssertEqual(attached?.uid, kept.uid, "the same row, not a copy")
        XCTAssertIdentical(kept.exercise, drill)
        XCTAssertEqual(kept.note, "From 3:40")
        XCTAssertEqual(drill.referencesInOrder.map(\.uid), [first.uid, kept.uid])
        XCTAssertEqual(drill.referencesInOrder.map(\.order), [0, 1])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).count, 2)
    }

    func testAttachingAFiledLinkCopiesItsNameAndLinkButNotItsNote() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Week 3")
        context.insert(drill)
        context.insert(routine)
        let onDrill = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: lesson, note: "Strings 1 to 3",
                                                           to: drill, in: context))
        try context.save()

        let copy = try XCTUnwrap(ReferenceLinkStore.attach(try fetchedSource(onDrill, in: context),
                                                           to: routine, in: context))
        try context.save()

        XCTAssertNotEqual(copy.uid, onDrill.uid)
        XCTAssertIdentical(copy.routine, routine)
        XCTAssertEqual(copy.title, "Lesson")
        XCTAssertEqual(copy.urlString, lesson)
        XCTAssertEqual(copy.note, "", "each place keeps its own note")
        XCTAssertIdentical(onDrill.exercise, drill, "the first place keeps its row")
        XCTAssertEqual(onDrill.note, "Strings 1 to 3")
        let all = try context.fetch(FetchDescriptor<ReferenceLink>())
        XCTAssertEqual(ReferenceLibrary.sources(all).count, 1, "one source, used in two places")
    }

    /// A filed file is copied as a second row naming the **same file**, at the end of the new place's
    /// list, with its name and kind and no note. The first place keeps its row, and the two are one
    /// source, so the source's screen shows both places. The bytes are a file test's
    /// (`ReferenceLinkAttachmentTests`); this one never writes any.
    func testAttachingAFiledFileAddsARowNamingTheSameFile() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let target = song()
        context.insert(drill)
        context.insert(target)
        let picture = ReferenceLink(title: "Chart", note: "Bar 3", attachmentFileName: "a.jpg", order: 0,
                                    kind: .image, exercise: drill)
        context.insert(picture)
        let before = try XCTUnwrap(ReferenceLinkStore.add(title: "Before", url: "https://example.com/2",
                                                          to: target, in: context))
        try context.save()

        let copy = try XCTUnwrap(ReferenceLinkStore.attach(try fetchedSource(picture, in: context),
                                                           to: target, in: context))
        try context.save()

        XCTAssertNotEqual(copy.uid, picture.uid)
        XCTAssertIdentical(copy.song, target)
        XCTAssertEqual(copy.attachmentFileName, "a.jpg")
        XCTAssertEqual(copy.kind, .image)
        XCTAssertEqual(copy.title, "Chart")
        XCTAssertEqual(copy.note, "", "each place keeps its own note")
        XCTAssertEqual(target.referencesInOrder.map(\.uid), [before.uid, copy.uid])
        XCTAssertEqual(copy.order, 1)
        XCTAssertIdentical(picture.exercise, drill, "the first place keeps its row")
        XCTAssertEqual(picture.note, "Bar 3")
        let shared = try fetchedSource(picture, in: context)
        XCTAssertEqual(Set(shared.rows.map(\.uid)), [picture.uid, copy.uid], "one source")
        XCTAssertEqual(Set(shared.places.map(\.name)), ["Slow Bend", "Spider"], "used in two places")
    }

    func testAttachingASourceThatHasGoneWritesNothing() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        XCTAssertNil(ReferenceLinkStore.attach(sourceContaining: UUID(), to: drill, in: context))
        XCTAssertTrue(drill.references.isEmpty)
    }

    // MARK: - Start an exercise from this (D5), through the one insert path

    func testANewDrillStartedFromAKeptLinkTakesIt() throws {
        let context = try makeContext()
        let kept = try XCTUnwrap(ReferenceLinkStore.add(title: "CAGED, the A shape", url: lesson,
                                                        note: "Root on the 5th string", to: KeepForLater(),
                                                        in: context))
        try context.save()
        var plan = makePlan(name: "CAGED shape 2")
        plan.startedFromReference = kept.uid

        let drill = try XCTUnwrap(plan.finalise(in: context))
        try context.save()

        XCTAssertEqual(drill.references.map(\.uid), [kept.uid])
        XCTAssertEqual(kept.order, 0, "the first on an empty list: its order was read before it was hung there")
        XCTAssertEqual(kept.note, "Root on the 5th string")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).count, 1, "moved, not copied")
    }

    func testANewDrillStartedFromAFiledLinkGetsACopy() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)
        let onRoutine = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: lesson, to: routine, in: context))
        try context.save()
        var plan = makePlan(name: "Triad climb")
        plan.startedFromReference = onRoutine.uid

        let drill = try XCTUnwrap(plan.finalise(in: context))
        try context.save()

        XCTAssertEqual(drill.references.map(\.urlString), [lesson])
        XCTAssertIdentical(onRoutine.routine, routine, "the routine keeps its own")
    }

    /// *Start another exercise from this*, on a file: the drill gets a row naming the same file.
    func testANewDrillStartedFromAFiledFileGetsARowNamingTheSameFile() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)
        let onRoutine = ReferenceLink(attachmentFileName: "a.pdf", kind: .pdf, routine: routine)
        context.insert(onRoutine)
        try context.save()
        var plan = makePlan(name: "Triad climb")
        plan.startedFromReference = onRoutine.uid

        let drill = try XCTUnwrap(plan.finalise(in: context))
        try context.save()

        XCTAssertEqual(drill.references.map(\.attachmentFileName), ["a.pdf"])
        XCTAssertIdentical(onRoutine.routine, routine, "the routine keeps its own")
    }

    func testAPlanStartedFromNothingAttachesNothing() throws {
        let context = try makeContext()
        ReferenceLinkStore.add(title: "Lesson", url: lesson, to: KeepForLater(), in: context)
        try context.save()

        let drill = try XCTUnwrap(makePlan(name: "Spider").finalise(in: context))

        XCTAssertTrue(drill.references.isEmpty)
    }

    // MARK: - Helpers

    private func source(_ rows: ReferenceLink...) -> ReferenceSource {
        ReferenceLibrary.sources(rows)[0]
    }

    private func fetchedSource(_ row: ReferenceLink, in context: ModelContext) throws -> ReferenceSource {
        try XCTUnwrap(ReferenceLibrary.source(containing: row.uid,
                                              in: context.fetch(FetchDescriptor<ReferenceLink>())))
    }

    private func song() -> Song {
        Song(title: "Slow Bend", duration: 180, ref: SongRef(id: "Slow Bend", source: .localFile, bookmark: nil))
    }

    private func makePlan(name: String) -> NewExercisePlan {
        NewExercisePlan(name: name, command: 90, signature: .standard, template: .basic, instrument: .guitar,
                        strum: nil, fretboard: nil, chords: nil, strumChords: nil, songs: [])
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, ReferenceLink.self, configurations: config)
        return ModelContext(container)
    }
}
