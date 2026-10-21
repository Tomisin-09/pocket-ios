import SwiftData
import XCTest
@testable import Pocket

/// **The app files what *Save to Red Moon* saved** (ADR 0264 D9): through `ReferenceLinkStore`, onto
/// the place picked or into *Not filed*, dated when the player saved it, and never twice.
@MainActor
final class ShareInboxDrainTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, ReferenceLink.self, configurations: config)
        return ModelContext(container)
    }

    /// A temporary folder standing in for the App Group, and one standing in for Application Support.
    private func makeFolders() throws -> (group: URL, files: TempContainerFileManager) {
        let group = FileManager.default.temporaryDirectory.appending(path: "ShareDrain-\(UUID().uuidString)",
                                                                    directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        let files = TempContainerFileManager()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: group)
            files.destroy()
        }
        return (group, files)
    }

    private func song(_ title: String = "Slow Bend") -> Song {
        Song(title: title, duration: 180, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    private func references(_ context: ModelContext) throws -> [ReferenceLink] {
        try context.fetch(FetchDescriptor<ReferenceLink>())
    }

    // MARK: - Links

    func testALinkKeptForLaterLandsInNotFiled() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let saved = Date(timeIntervalSince1970: 1_000_000)
        let item = ShareInboxItem(id: UUID(), savedAt: saved, url: "https://example.com/lesson",
                                  title: "Lesson", note: "the bend at 1:20")
        try ShareInbox.deposit(item, in: group)

        XCTAssertEqual(ShareInboxDrain.drain(from: group, standing: .neverBought, in: context, files), 1)

        let link = try XCTUnwrap(try references(context).first)
        XCTAssertFalse(link.isFiled)
        XCTAssertEqual(link.uid, item.id, "the save's id is the reference's, so a second drain can tell")
        XCTAssertEqual(link.title, "Lesson")
        XCTAssertEqual(link.note, "the bend at 1:20")
        XCTAssertEqual(link.urlString, "https://example.com/lesson")
        XCTAssertEqual(link.dateAdded, saved, "dated when it was saved, not when the app opened")
        XCTAssertTrue(ShareInbox.pending(in: group).isEmpty, "the inbox is cleared")
    }

    func testALinkSavedToASongIsFiledOnIt() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let slowBend = song()
        context.insert(slowBend)
        let key = ReferenceDestination(song: slowBend).id
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a",
                                              destination: key), in: group)

        ShareInboxDrain.drain(from: group, standing: .neverBought, in: context, files)

        XCTAssertEqual(slowBend.references.count, 1)
        XCTAssertEqual(try references(context).filter(\.isFiled).count, 1)
    }

    func testAPlaceDeletedSinceTheSnapshotKeepsTheSaveForLater() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a",
                                              destination: ReferenceDestination.key(.exercise, UUID().uuidString)),
                               in: group)

        XCTAssertEqual(ShareInboxDrain.drain(from: group, standing: .onPlan, in: context, files), 1)
        XCTAssertEqual(try references(context).map(\.isFiled), [false], "kept, not dropped")
    }

    /// D6: a drill isn't the never-bought player's to file on, whatever the save says.
    func testANeverBoughtPlayersSaveToADrillIsKeptForLater() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a",
                                              destination: ReferenceDestination(exercise: drill).id), in: group)

        ShareInboxDrain.drain(from: group, standing: .neverBought, in: context, files)

        XCTAssertTrue(drill.references.isEmpty)
        XCTAssertEqual(try references(context).map(\.isFiled), [false])
    }

    func testALapsedPlayersSaveToADrillIsFiledOnIt() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let drill = Exercise(name: "Spider")
        context.insert(drill)
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a",
                                              destination: ReferenceDestination(exercise: drill).id), in: group)

        ShareInboxDrain.drain(from: group, standing: .lapsed, in: context, files)

        XCTAssertEqual(drill.references.count, 1)
    }

    /// A save already in the store (the app stopped between saving and clearing the inbox) is cleared
    /// without filing it a second time.
    func testASaveAlreadyFiledIsNotFiledTwice() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let item = ShareInboxItem(id: UUID(), savedAt: .now, url: "https://example.com/a")
        context.insert(ReferenceLink(uid: item.id, urlString: "https://example.com/a"))
        try context.save()
        try ShareInbox.deposit(item, in: group)

        XCTAssertEqual(ShareInboxDrain.drain(from: group, standing: .onPlan, in: context, files), 0)
        XCTAssertEqual(try references(context).count, 1)
        XCTAssertTrue(ShareInbox.pending(in: group).isEmpty)
    }

    // MARK: - Files

    func testAFileIsStoredThroughTheStoresOwnRules() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let slowBend = song()
        context.insert(slowBend)
        let source = group.appending(path: "tab.txt")
        try Data("e|--5--7--|".utf8).write(to: source)
        let item = ShareInboxItem(id: UUID(), savedAt: .now, fileName: "shared.txt",
                                  typeIdentifier: "public.plain-text",
                                  title: "Intro tab", destination: ReferenceDestination(song: slowBend).id)
        try ShareInbox.deposit(item, file: source, in: group)

        XCTAssertEqual(ShareInboxDrain.drain(from: group, standing: .neverBought, in: context, files), 1)

        let link = try XCTUnwrap(slowBend.references.first)
        XCTAssertEqual(link.kind, .text)
        XCTAssertEqual(link.attachmentFileName, ReferenceAttachmentStore.fileName(for: item.id, kind: .text))
        XCTAssertEqual(ReferenceAttachmentStore.text(fileName: link.attachmentFileName, files), "e|--5--7--|")
    }

    /// Five files a place (0167 phase 2): a sixth is kept for later, bytes and all.
    func testAFileForAFullPlaceIsKeptForLater() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let slowBend = song()
        context.insert(slowBend)
        for index in 0..<ReferenceAttachmentStore.maxPerOwner {
            context.insert(ReferenceLink(attachmentFileName: "\(index).txt", kind: .text, song: slowBend))
        }
        let source = group.appending(path: "tab.txt")
        try Data("e|--5--|".utf8).write(to: source)
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, fileName: "shared.txt",
                                              typeIdentifier: "public.plain-text",
                                              destination: ReferenceDestination(song: slowBend).id),
                               file: source, in: group)

        ShareInboxDrain.drain(from: group, standing: .onPlan, in: context, files)

        XCTAssertEqual(slowBend.references.count, ReferenceAttachmentStore.maxPerOwner)
        let kept = try XCTUnwrap(try references(context).first { !$0.isFiled })
        XCTAssertTrue(kept.isAttachment)
    }

    /// A save the store can't take at all is cleared rather than refused on every launch.
    func testAFileTheStoreCantReadIsCleared() throws {
        let context = try makeContext()
        let (group, files) = try makeFolders()
        let source = group.appending(path: "blob.bin")
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: source)
        try ShareInbox.deposit(ShareInboxItem(id: UUID(), savedAt: .now, fileName: "shared.pdf",
                                              typeIdentifier: "com.adobe.pdf"), file: source, in: group)

        XCTAssertEqual(ShareInboxDrain.drain(from: group, standing: .onPlan, in: context, files), 0)
        XCTAssertTrue(try references(context).isEmpty)
        XCTAssertTrue(ShareInbox.pending(in: group).isEmpty)
    }

    // MARK: - The snapshot

    /// What the extension is given (D9): every place, temporary sessions left out (ADR 0243), and which
    /// places can't take another file.
    func testTheSnapshotListsEveryPlaceTheExtensionMayOffer() throws {
        let context = try makeContext()
        let slowBend = song()
        let loop = Loop(name: "Bridge bend", start: 0.1, end: 0.2, speed: 1, repeats: 4)
        loop.song = slowBend
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Week 3")
        let temporary = Routine(name: "Today")
        temporary.isTemporary = true
        for model in [slowBend, loop, drill, routine, temporary] as [any PersistentModel] { context.insert(model) }
        for index in 0..<ReferenceAttachmentStore.maxPerOwner {
            context.insert(ReferenceLink(attachmentFileName: "\(index).txt", kind: .text, exercise: drill))
        }

        let snapshot = ShareOwnerSnapshot(context: context, standing: .lapsed, appearance: .dark)

        XCTAssertEqual(Set(snapshot.places.map(\.name)), ["Slow Bend", "Bridge bend", "Spider", "Week 3"])
        XCTAssertEqual(snapshot.places.first { $0.kind == .loop }?.parent, "Slow Bend")
        XCTAssertEqual(snapshot.fullOfFiles, [ReferenceDestination(exercise: drill).id])
        XCTAssertEqual(snapshot.standing, .lapsed)
        XCTAssertEqual(snapshot.appearance, .dark)
    }
}
