import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// **Remove, delete and keep** (ADR 0264 D11, D5, D1): what happens to a reference when it comes off an
/// owner, when its source is deleted from References, and when it's added with no owner.
///
/// The verdicts are tested on uninserted values. The store paths use an in-memory store, because
/// they fetch, and because "this row is still in the store" is the thing being asserted.
final class ReferenceRemovalTests: XCTestCase {

    // MARK: - The rule (D11), on values

    func testALinkUsedNowhereElseIsUnfiled() {
        let link = ReferenceLink(urlString: "https://example.com/a", exercise: Exercise(name: "Spider"))
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: []), .unfile)
    }

    /// The source stays in the library through its other place, so only this use goes.
    func testALinkFiledSomewhereElseIsDeleted() {
        let link = ReferenceLink(urlString: "https://example.com/a", exercise: Exercise(name: "Spider"))
        let elsewhere = ReferenceLink(urlString: "https://example.com/a", routine: Routine(name: "Week 3"))
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: [elsewhere]), .delete)
    }

    /// A row kept for later is not a place: removing the last filed use keeps this one's note too.
    func testARowKeptForLaterIsNotSomewhereElse() {
        let link = ReferenceLink(urlString: "https://example.com/a", exercise: Exercise(name: "Spider"))
        let kept = ReferenceLink(urlString: "https://example.com/a")
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: [kept]), .unfile)
    }

    func testADifferentLinkIsNotSomewhereElse() {
        let link = ReferenceLink(urlString: "https://example.com/a", exercise: Exercise(name: "Spider"))
        let other = ReferenceLink(urlString: "https://example.com/b", routine: Routine(name: "Week 3"))
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: [other]), .unfile)
    }

    /// The row itself, if it is handed in among the others, doesn't count as its own other place.
    func testARowIsNotSomewhereElseToItself() {
        let link = ReferenceLink(urlString: "https://example.com/a", exercise: Exercise(name: "Spider"))
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: [link]), .unfile)
    }

    /// A file attached in two places is one file named by two rows (D3). Removing one use deletes that
    /// row only; the bytes stay for the other (`ReferenceLinkAttachmentTests`).
    func testAFileFiledSomewhereElseIsDeleted() {
        let picture = ReferenceLink(attachmentFileName: "a.jpg", kind: .image, exercise: Exercise(name: "Spider"))
        let elsewhere = ReferenceLink(attachmentFileName: "a.jpg", kind: .image, routine: Routine(name: "Week 3"))
        XCTAssertEqual(ReferenceRemoval.decide(for: picture, among: [elsewhere]), .delete)
    }

    /// A different file, or a link filed elsewhere that happens to carry the file row's address (a newer
    /// build's row), is not the same source: a file is matched on its file alone.
    func testAFileUsedNowhereElseIsUnfiled() {
        let url = "https://example.com/a"
        let picture = ReferenceLink(urlString: url, attachmentFileName: "a.jpg", kind: .image,
                                    exercise: Exercise(name: "Spider"))
        let linkElsewhere = ReferenceLink(urlString: url, routine: Routine(name: "Week 3"))
        let otherFile = ReferenceLink(attachmentFileName: "b.jpg", kind: .image, routine: Routine(name: "Week 3"))
        XCTAssertEqual(ReferenceRemoval.decide(for: picture, among: [linkElsewhere, otherFile]), .unfile)
    }

    /// The other way round: a file elsewhere is not the same source as a link, whatever it carries.
    func testAFileElsewhereIsNotTheSameSource() {
        let url = "https://example.com/a"
        let link = ReferenceLink(urlString: url, exercise: Exercise(name: "Spider"))
        let fileElsewhere = ReferenceLink(urlString: url, attachmentFileName: "a.jpg", kind: .image,
                                          routine: Routine(name: "Week 3"))
        XCTAssertEqual(ReferenceRemoval.decide(for: link, among: [fileElsewhere]), .unfile)
    }

    // MARK: - Remove, in a store

    func testRemovingTheOnlyUseKeepsItForLaterWithItsNote() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        let link = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: "https://example.com/a",
                                                        note: "From 3:40", to: drill, in: context))
        try context.save()

        ReferenceLinkStore.remove([link], from: drill, in: context)
        try context.save()

        let left = try context.fetch(FetchDescriptor<ReferenceLink>())
        XCTAssertEqual(left.map(\.uid), [link.uid])
        XCTAssertEqual(left.first?.note, "From 3:40")
        XCTAssertEqual(left.first?.isFiled, false)
        XCTAssertTrue(drill.references.isEmpty)
    }

    func testRemovingOneOfTwoUsesDeletesThatRowAndLeavesTheOther() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Week 3")
        context.insert(drill)
        context.insert(routine)
        let onDrill = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: "https://example.com/a",
                                                           to: drill, in: context))
        let onRoutine = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: "example.com/a",
                                                             to: routine, in: context))
        try context.save()

        ReferenceLinkStore.remove([onDrill], from: drill, in: context)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).map(\.uid), [onRoutine.uid],
                       "a scheme-less paste is stored as https, so the two are one source")
        XCTAssertIdentical(onRoutine.routine, routine)
    }

    /// Two rows of one link on one owner, removed together: the first sees the second, so it goes; the
    /// second then sees nothing filed, so it is kept. One survives, kept for later.
    func testRemovingTwoUsesOfOneLinkTogetherKeepsOne() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        let lesson = "https://example.com/a"
        let first = try XCTUnwrap(ReferenceLinkStore.add(title: "A", url: lesson, to: drill, in: context))
        let second = try XCTUnwrap(ReferenceLinkStore.add(title: "B", url: lesson, to: drill, in: context))
        try context.save()

        ReferenceLinkStore.remove([first, second], from: drill, in: context)
        try context.save()

        let left = try context.fetch(FetchDescriptor<ReferenceLink>())
        XCTAssertEqual(left.map(\.uid), [second.uid])
        XCTAssertEqual(left.first?.isFiled, false)
    }

    /// The routine editor holds every change until Save. A link added and removed in one edit was never
    /// kept, so it goes rather than landing in *Not filed*.
    func testARowNeverSavedGoesOutright() throws {
        let context = try makeContext()
        let routine = Routine(name: "Week 3")
        context.insert(routine)
        try context.save()
        let link = try XCTUnwrap(ReferenceLinkStore.add(title: "Typo", url: "https://example.com/a",
                                                        to: routine, in: context))

        ReferenceLinkStore.remove([link], from: routine, in: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    // MARK: - Delete from References (D5)

    /// Every row of the source goes, filed or kept, and each owner's list closes its gap.
    func testDeletingASourceTakesEveryRowAndRenumbersTheOwners() throws {
        let context = try makeContext()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        let first = try XCTUnwrap(ReferenceLinkStore.add(title: "First", url: "https://example.com/1",
                                                         to: drill, in: context))
        let doomed = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: "https://example.com/a",
                                                          to: drill, in: context))
        let last = try XCTUnwrap(ReferenceLinkStore.add(title: "Last", url: "https://example.com/3",
                                                        to: drill, in: context))
        let kept = ReferenceLink(title: "Lesson", urlString: "https://example.com/a")
        context.insert(kept)
        try context.save()

        let all = try context.fetch(FetchDescriptor<ReferenceLink>())
        let source = try XCTUnwrap(ReferenceLibrary.source(containing: doomed.uid, in: all))
        XCTAssertEqual(source.rows.count, 2)
        ReferenceLinkStore.delete(source, in: context)
        try context.save()

        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<ReferenceLink>()).map(\.uid)), [first.uid, last.uid])
        XCTAssertEqual(drill.referencesInOrder.map(\.order), [0, 1])
    }

    // MARK: - The toast's count (D2)

    /// Deleting a song takes its loops, and both their references stay, so the toast counts both.
    func testASongsDeleteCountsItsLoopsReferences() throws {
        let context = try makeContext()
        let song = Song(title: "Slow Bend", duration: 180,
                        ref: SongRef(id: "Slow Bend", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.2, speed: 1.0, repeats: 4)
        loop.song = song
        context.insert(song)
        context.insert(loop)
        ReferenceLinkStore.add(title: "Transcription", url: "https://example.com/song", to: song, in: context)
        ReferenceLinkStore.add(title: "That lick", url: "https://example.com/loop", to: loop, in: context)
        ReferenceLinkStore.add(title: "Slowed", url: "https://example.com/slow", to: loop, in: context)
        try context.save()
        XCTAssertEqual(song.referencesLeftByDelete, 3)
    }

    // MARK: - Keep for later (D1)

    func testAddingToKeepForLaterLeavesNoOwner() throws {
        let context = try makeContext()
        let link = try XCTUnwrap(ReferenceLinkStore.add(title: "Lesson", url: "youtube.com/watch?v=x",
                                                        to: KeepForLater(), in: context))
        try context.save()
        XCTAssertFalse(link.isFiled)
        XCTAssertEqual(link.urlString, "https://youtube.com/watch?v=x", "the store's one gate still applies")
        XCTAssertNil(ReferenceLinkStore.add(title: "Nope", url: "javascript:alert(1)", to: KeepForLater(),
                                            in: context))
    }

    /// The five-file cap is per exercise, song, loop or routine, and References is none of those.
    func testKeepForLaterHasNoFileCap() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let keep = KeepForLater()
        for index in 0...ReferenceAttachmentStore.maxPerOwner {
            XCTAssertTrue(keep.canAddAttachment)
            let link = try ReferenceLinkStore.addAttachment(Data("e|--\(index)--|".utf8), contentType: .plainText,
                                                            to: keep, in: context, files)
            XCTAssertFalse(link.isFiled)
        }
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReferenceLink>()).count,
                       ReferenceAttachmentStore.maxPerOwner + 1)
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, ReferenceLink.self, configurations: config)
        return ModelContext(container)
    }
}
