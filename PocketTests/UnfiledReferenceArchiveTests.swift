import SwiftData
import XCTest
@testable import Pocket

/// References kept for later in a backup (ADR 0264 D7). Every other reference nests under its owner, so
/// one with no owner was in no export at all until `unfiledReferences` carried it.
///
/// Mostly built on **uninserted** models and asserted on the uninserted graph `materialize` returns, the
/// same split `ArchiveRestoreHydrationTests` uses: inserting a song's graph in this host traps. The last
/// three use an in-memory store, holding drills and references only.
@MainActor
final class UnfiledReferenceArchiveTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(_ source: ArchiveSource) -> PracticeArchive {
        ArchiveBuilder.snapshot(from: source, appVersion: "1.4 (8)", includesTakeAudio: false, exportedAt: date)
    }

    private func record(_ title: String, uid: UUID = UUID(), file: String? = nil,
                        added: Date? = nil) -> ReferenceLinkRecord {
        ReferenceLinkRecord(uid: uid, title: title, note: "", urlString: "https://example.com/\(title)",
                            order: 0, dateAdded: added ?? date, kindRaw: file == nil ? "link" : "pdf",
                            attachmentFileName: file)
    }

    private func archive(unfiled: [ReferenceLinkRecord]?) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: date, appVersion: "1.4 (8)", includesTakeAudio: false)
        archive.unfiledReferences = unfiled
        return archive
    }

    // MARK: - Export

    /// Only the references no owner holds are written on their own. A filed one already travels under
    /// its owner, and writing it twice would restore it twice.
    func testOnlyUnfiledReferencesAreWrittenOnTheirOwn() {
        let drill = Exercise(name: "Spider")
        let filed = ReferenceLink(title: "Filed", urlString: "https://example.com/a", exercise: drill)
        let kept = ReferenceLink(title: "Kept for later", note: "From 3:40", urlString: "https://example.com/b")
        var source = ArchiveSource()
        source.exercises = [drill]
        source.references = [filed, kept]

        let archive = snapshot(source)
        XCTAssertEqual(archive.unfiledReferences?.map(\.title), ["Kept for later"])
        XCTAssertEqual(archive.unfiledReferences?.first?.note, "From 3:40")
        XCTAssertEqual(archive.exercises.first?.references.map(\.title), ["Filed"])
    }

    /// Newest first, as the library lists them, so two exports of one library are byte-identical.
    func testUnfiledReferencesAreNewestFirst() {
        let older = ReferenceLink(title: "Older", urlString: "https://example.com/o", dateAdded: date)
        let newer = ReferenceLink(title: "Newer", urlString: "https://example.com/n",
                                  dateAdded: date.addingTimeInterval(60))
        var source = ArchiveSource()
        source.references = [older, newer]
        XCTAssertEqual(snapshot(source).unfiledReferences?.map(\.title), ["Newer", "Older"])
    }

    /// A file on an unfiled reference is staged into the zip like any other reference's file. An export
    /// that named a file it didn't carry would be a record the player can't put back together.
    func testAnUnfiledReferencesFileIsStaged() {
        let archive = archive(unfiled: [record("Tab", file: "tab.pdf")])
        XCTAssertEqual(archive.referenceAttachmentFileNames, ["tab.pdf"])
    }

    func testTheFieldSurvivesARoundTrip() throws {
        let original = archive(unfiled: [record("Lesson")])
        let decoded = try ArchiveBuilder.decode(ArchiveBuilder.encode(original))
        XCTAssertEqual(decoded.unfiledReferences, original.unfiledReferences)
    }

    /// An archive written before ADR 0264 has no key at all, and still decodes.
    func testAnArchiveWithoutTheFieldStillDecodes() throws {
        let data = try ArchiveBuilder.encode(archive(unfiled: nil))
        XCTAssertFalse(String(bytes: data, encoding: .utf8)?.contains("unfiledReferences") ?? true)
        XCTAssertNil(try ArchiveBuilder.decode(data).unfiledReferences)
    }

    // MARK: - Restore

    func testAnUnfiledReferenceLandsWithNoOwnerAndItsOwnUID() {
        let uid = UUID()
        let landing = ArchiveRestoreWriter.materialize(archive(unfiled: [record("Lesson", uid: uid)]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.unfiledReferences.map(\.uid), [uid])
        XCTAssertEqual(landing.unfiledReferences.first?.isFiled, false)
    }

    /// D6: nothing is overwritten. A reference the library already has, filed since the export or not,
    /// is left where it is, so restoring the same archive twice adds nothing the second time.
    func testAReferenceTheLibraryAlreadyHasIsSkipped() {
        let uid = UUID()
        var existing = RestoreExistingKeys()
        existing.referenceUIDs = [uid]
        let landing = ArchiveRestoreWriter.materialize(archive(unfiled: [record("Lesson", uid: uid)]),
                                                       existing: existing)
        XCTAssertTrue(landing.unfiledReferences.isEmpty)
    }

    func testAUIDRepeatedInTheFileLandsOnce() {
        let uid = UUID()
        let landing = ArchiveRestoreWriter.materialize(
            archive(unfiled: [record("Lesson", uid: uid), record("Lesson again", uid: uid)]),
            existing: RestoreExistingKeys())
        XCTAssertEqual(landing.unfiledReferences.map(\.title), ["Lesson"])
    }

    /// Its file comes out of the zip with it, and nothing counts it as a library item in the preview.
    func testAnUnfiledReferencesFileIsWrittenAndNotCounted() {
        let landing = ArchiveRestoreWriter.materialize(archive(unfiled: [record("Tab", file: "tab.pdf")]),
                                                       existing: RestoreExistingKeys())
        XCTAssertEqual(landing.referencedAttachmentNames, ["tab.pdf"])
        XCTAssertEqual(landing.rowCount, 0)
    }

    // MARK: - Against a store
    //
    // The three lines that read or write the store: the export's fetch, the restore's existing keys,
    // and the restore's insert. No `Song` graph goes in, which is what traps in this host.

    /// The whole path a player takes: delete the drill, back up, and the lesson it was built from is
    /// in the file on its own, while a drill that still holds its reference keeps it nested.
    func testADeletedDrillsReferenceIsInTheNextExport() throws {
        let context = try makeStore()
        let kept = Exercise(name: "Spider")
        let gone = Exercise(name: "Chromatic")
        context.insert(kept)
        context.insert(gone)
        ReferenceLinkStore.add(title: "Filed", url: "https://example.com/a", to: kept, in: context)
        ReferenceLinkStore.add(title: "Left behind", url: "https://example.com/b", to: gone, in: context)
        context.insert(ReferenceLink(title: "Kept for later", urlString: "https://example.com/c"))
        try context.save()
        context.delete(gone)
        try context.save()

        let archive = snapshot(try ArchiveSource.everything(in: context))
        XCTAssertEqual(Set(archive.unfiledReferences?.map(\.title) ?? []), ["Left behind", "Kept for later"])
        XCTAssertEqual(archive.exercises.map(\.name), ["Spider"])
        XCTAssertEqual(archive.exercises.first?.references.map(\.title), ["Filed"])
    }

    func testTheRestoreKnowsEveryReferenceTheLibraryHas() throws {
        let context = try makeStore()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        let filed = try XCTUnwrap(ReferenceLinkStore.add(title: "Filed", url: "https://example.com/a",
                                                         to: drill, in: context))
        let unfiled = ReferenceLink(title: "Kept for later", urlString: "https://example.com/b")
        context.insert(unfiled)
        try context.save()

        XCTAssertEqual(ArchiveRestoreWriter.existingKeys(in: context).referenceUIDs, [filed.uid, unfiled.uid])
    }

    func testARestoredUnfiledReferenceIsWrittenToTheStore() throws {
        let context = try makeStore()
        let uid = UUID()
        let landing = ArchiveRestoreWriter.materialize(archive(unfiled: [record("Lesson", uid: uid)]),
                                                       existing: RestoreExistingKeys())
        landing.insert(into: context)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<ReferenceLink>())
        XCTAssertEqual(stored.map(\.uid), [uid])
        XCTAssertEqual(stored.first?.isFiled, false)
    }

    /// Every type `ArchiveSource.everything(in:)` fetches, as `PocketApp` declares them.
    private func makeStore() throws -> ModelContext {
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self, Routine.self,
            RoutineItem.self, Goal.self, LongTermGoal.self, Recording.self, TakeNote.self, SavedChord.self,
            Profile.self, PracticeRun.self, ReferenceLink.self, LoopSpanChange.self, Snag.self,
            PracticeFolder.self, CustomSkill.self, SavedProgression.self, WrittenTab.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}
