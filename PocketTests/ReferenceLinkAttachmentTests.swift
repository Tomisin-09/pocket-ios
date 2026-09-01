import ImageIO
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// The image half of `ReferenceLink` (ADR 0167 phase 2) — the model fields, the store's picture
/// paths, and the per-owner cap.
///
/// Split from `ReferenceLinkTests` rather than added to it: that file was already at the 400-line
/// cap, and these tests need a throwaway file container as well as a model context, which the URL
/// half does not.
///
/// Fixtures are **real encoded PNGs**. `ReferenceAttachmentStore` decodes everything it is handed, so
/// bytes it could not read would make every test here pass without exercising the thing under test.
final class ReferenceLinkAttachmentTests: XCTestCase {

    func testDisplayTitleOfAnUnnamedAttachmentNamesItsKind() {
        // There is no host to fall back to, and this word is also what VoiceOver reads — the title
        // *is* the alt text, and it is deliberately not required.
        XCTAssertEqual(ReferenceLink(attachmentFileName: "a.jpg", kind: .image).displayTitle, "Picture")
        XCTAssertEqual(ReferenceLink(attachmentFileName: "a.pdf", kind: .pdf).displayTitle, "PDF")
        XCTAssertEqual(ReferenceLink(attachmentFileName: "a.txt", kind: .text).displayTitle, "Text file")
        XCTAssertEqual(ReferenceLink(attachmentFileName: "a.md", kind: .markdown).displayTitle,
                       "Markdown file")
        XCTAssertEqual(ReferenceLink(title: "Bar 12 chart", attachmentFileName: "a.jpg",
                                     kind: .image).displayTitle, "Bar 12 chart")
    }

    /// An attachment must never be openable *outside* the app. If `destination` resolved for one, a
    /// row tap would hand a container file URL to `openURL`.
    func testAnAttachmentHasNoOutboundDestinationEvenIfAURLIsSomehowStored() {
        let link = ReferenceLink(urlString: "https://youtube.com/watch?v=x",
                                 attachmentFileName: "a.jpg", kind: .image)
        XCTAssertNil(link.destination)
        XCTAssertTrue(link.isAttachment)
    }

    /// **`isAttachment` keys on the filename, not the kind, and this is why.** A row written by a
    /// newer build in a kind this one has never heard of falls back to `.link` — and if that decided
    /// the question, the row would be handed to `openURL` with an empty address.
    func testARowWithAnUnknownKindButAFileIsStillTreatedAsAnAttachment() {
        let link = ReferenceLink(attachmentFileName: "a.future")
        link.kindRaw = "hologram"

        XCTAssertEqual(link.kind, .link, "unknown kinds still read as .link")
        XCTAssertTrue(link.isAttachment, "but the file is the fact")
        XCTAssertNil(link.destination)
    }

    func testALinkIsNotAnAttachment() {
        XCTAssertFalse(ReferenceLink(urlString: "https://example.com").isAttachment)
    }

    /// The same rule as `note`: a declaration default, never `nil`. This is the assertion that
    /// catches somebody retyping the field as `String?`, which passes in the simulator and traps on
    /// a device holding old data (`docs/swiftdata-gotchas.md`).
    func testANewLinkHasAnEmptyImageFileNameRatherThanNil() {
        XCTAssertEqual(ReferenceLink().attachmentFileName, "")
    }

    func testAddImageStoresTheLeafAndMarksTheKind() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        let link = try ReferenceLinkStore.addAttachment(try pngFixture(), title: "  Chart  ",
                                                   note: "  Bar 12.  ",
                                                   to: exercise, in: context, files)
        try context.save()

        XCTAssertEqual(link.kind, .image)
        XCTAssertEqual(link.attachmentFileName,
                       ReferenceAttachmentStore.fileName(for: link.uid, kind: .image),
                       "the row and its file share one identity")
        XCTAssertTrue(ReferenceAttachmentStore.exists(fileName: link.attachmentFileName, files))
        XCTAssertEqual(link.title, "Chart")
        XCTAssertEqual(link.note, "Bar 12.")
        XCTAssertEqual(link.urlString, "", "a picture has no address")
    }

    /// The same ordering trap `add` documents: `makeReference()` populates the inverse immediately,
    /// so measuring after minting would count the new link against itself.
    func testAddImageAppendsAfterExistingReferences() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        ReferenceLinkStore.add(title: "Lesson", url: "https://example.com", to: exercise, in: context)
        let picture = try ReferenceLinkStore.addAttachment(try pngFixture(), to: exercise, in: context, files)

        XCTAssertEqual(picture.order, 1)
        XCTAssertEqual(exercise.referencesInOrder.map(\.order), [0, 1])
    }

    /// Bytes that are nothing we store leave the store exactly as it was — the file write is the
    /// throwing half and it runs *before* the row exists, so there is no row to clean up.
    ///
    /// The fixture is deliberately **invalid UTF-8 with no declared type**, because that is now the
    /// only way to be unreadable: a single-byte encoding decodes any bytes at all, so the legacy
    /// ladder is offered only to a file that *claims* to be text.
    func testAddAttachmentInsertsNothingWhenTheBytesAreNothingWeStore() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        let binary = Data([0xFF, 0xFE, 0x00, 0x01, 0xC3, 0x28, 0xA0, 0xA1])
        XCTAssertThrowsError(try ReferenceLinkStore.addAttachment(binary, to: exercise,
                                                                  in: context, files))
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
        XCTAssertTrue(ReferenceAttachmentStore.filesOnDisk(files).isEmpty)
    }

    /// Deleting a picture through the store takes its bytes with it. The cascade path cannot —
    /// that is what the orphan sweep is for — but this path can, and space coming back when you
    /// delete something is the difference the player actually notices.
    func testDeletingAnImageReferenceRemovesItsFile() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        let link = try ReferenceLinkStore.addAttachment(try pngFixture(), to: exercise, in: context, files)
        let leaf = link.attachmentFileName
        try context.save()

        ReferenceLinkStore.delete([link], from: exercise, in: context, files)
        try context.save()

        XCTAssertFalse(ReferenceAttachmentStore.exists(fileName: leaf, files))
        XCTAssertTrue(try context.fetch(FetchDescriptor<ReferenceLink>()).isEmpty)
    }

    /// Correcting a picture writes the words and nothing else. `updateImage` takes no URL at all, so
    /// there is no path by which a rename could re-point it.
    func testUpdateImageChangesOnlyTheWords() throws {
        let link = ReferenceLink(title: "Old", note: "Old note", attachmentFileName: "x.jpg", kind: .image)
        ReferenceLinkStore.updateAttachment(link, title: "  New  ", note: "  New note  ")

        XCTAssertEqual(link.title, "New")
        XCTAssertEqual(link.note, "New note")
        XCTAssertEqual(link.attachmentFileName, "x.jpg")
        XCTAssertEqual(link.kind, .image)
    }

    // MARK: - The per-owner cap

    func testTheCapCountsPicturesOnlyAndLinksAreUncapped() throws {
        let files = TempContainerFileManager()
        defer { files.destroy() }
        let context = try makeContext()
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)

        for index in 0..<20 {
            ReferenceLinkStore.add(title: "L\(index)", url: "https://example.com/\(index)",
                                   to: exercise, in: context)
        }
        XCTAssertEqual(exercise.attachmentReferenceCount, 0)
        XCTAssertTrue(exercise.canAddAttachment, "links never use up the picture allowance")

        for _ in 0..<ReferenceAttachmentStore.maxPerOwner {
            try ReferenceLinkStore.addAttachment(try pngFixture(), to: exercise, in: context, files)
        }
        XCTAssertEqual(exercise.attachmentReferenceCount, ReferenceAttachmentStore.maxPerOwner)
        XCTAssertFalse(exercise.canAddAttachment)
    }

    // MARK: - Helpers

    /// A tiny real PNG. Real bytes, because `ReferenceAttachmentStore` decodes what it is handed and a
    /// fixture it cannot read would make every image test pass for the wrong reason.
    private func pngFixture() throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: 24, height: 24, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let writer = try XCTUnwrap(CGImageDestinationCreateWithData(output,
                                                                    UTType.png.identifier as CFString,
                                                                    1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        return output as Data
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, ReferenceLink.self, configurations: config)
        return ModelContext(container)
    }
}

// MARK: - The draft that describes a file as it is added

extension ReferenceLinkAttachmentTests {

    /// **A file is named as it is added, the way a link always has been.** `.naming` is the second
    /// half of adding one, so the sheet has to open on the row that was just written — not on a
    /// blank draft, and not on the fixed id `.adding` uses.
    func testNamingADraftIdentifiesTheRowItWasOpenedOn() {
        let link = ReferenceLink(attachmentFileName: "a.jpg", kind: .image)
        XCTAssertEqual(ReferenceLinkDraft.naming(link).id, link.uid)
        XCTAssertNotEqual(ReferenceLinkDraft.naming(link).id, ReferenceLinkDraft.adding.id)
    }

    /// The sheet reads the row it points at, so a file that arrived with words already on it — which
    /// nothing does today, but a future import path could — opens showing them rather than blank.
    func testNamingReadsTheRowsWordsRatherThanStartingEmpty() {
        let link = ReferenceLink(title: "Bar 12 chart", note: "Only the second system matters",
                                 attachmentFileName: "a.jpg", kind: .image)
        let draft = ReferenceLinkDraft.naming(link)
        XCTAssertEqual(draft.title, "Bar 12 chart")
        XCTAssertEqual(draft.note, "Only the second system matters")
        XCTAssertTrue(draft.urlString.isEmpty)
    }

    /// What the editor branches on to hide the Link field and show the file instead. It reads the
    /// **row**, not the case, for the same reason `isAttachment` keys on the filename: a draft that
    /// said "attachment" while pointing at a link would offer an unfillable address field.
    func testTheDraftHandsBackTheRowSoTheSheetCanTellAFileFromALink() {
        let file = ReferenceLink(attachmentFileName: "a.pdf", kind: .pdf)
        let web = ReferenceLink(urlString: "https://example.com/x")
        XCTAssertEqual(ReferenceLinkDraft.naming(file).link?.isAttachment, true)
        XCTAssertEqual(ReferenceLinkDraft.editing(file).link?.isAttachment, true)
        XCTAssertEqual(ReferenceLinkDraft.editing(web).link?.isAttachment, false)
        XCTAssertNil(ReferenceLinkDraft.adding.link)
    }

    /// The word the file preview shows beside the thumbnail, and the one an unnamed row falls back
    /// to — one accessor now, so the two cannot drift into disagreeing about what a `.md` is called.
    func testTheCapitalisedNounIsWhatAnUnnamedRowFallsBackTo() {
        XCTAssertEqual(ReferenceLinkKind.image.capitalizedNoun, "Picture")
        XCTAssertEqual(ReferenceLinkKind.markdown.capitalizedNoun, "Markdown file")
        XCTAssertEqual(ReferenceLink(attachmentFileName: "a.md", kind: .markdown).displayTitle,
                       ReferenceLinkKind.markdown.capitalizedNoun)
    }
}
