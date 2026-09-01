import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// On-disk storage for reference pictures (ADR 0167 phase 2).
///
/// The **downscale is the storage rule**, not an optimisation, so it is tested on real encoded bytes
/// rather than mocked: a test over a stub would prove the plumbing and none of the thing that
/// matters, which is that a 12-megapixel photo cannot reach the container at 12 megapixels.
///
/// Files go into a throwaway container via `TempContainerFileManager`, the same way
/// `SongFileStoreTests` and `StorageUsageTests` work.
final class ReferenceAttachmentStoreTests: XCTestCase {

    private var fileManager: TempContainerFileManager!

    override func setUpWithError() throws {
        fileManager = TempContainerFileManager()
    }

    override func tearDownWithError() throws {
        fileManager.destroy()
        fileManager = nil
    }

    // MARK: - Naming

    func testFileNameIsUidWithJPGExtension() {
        let uid = UUID()
        XCTAssertEqual(ReferenceAttachmentStore.fileName(for: uid, kind: .image),
                       "\(uid.uuidString).jpg")
    }

    /// Unlike `SongFileStore`, which preserves the source extension because a decoder picks its
    /// parser by it, everything here is re-encoded — so the name may state the one format there is.
    func testEveryStoredFileIsJPEGWhateverWentIn() throws {
        let uid = UUID()
        let stored = try ReferenceAttachmentStore.adopt(pngData(width: 100, height: 60),
                                                        contentType: nil, for: uid, fileManager)

        XCTAssertEqual(stored.fileName, "\(uid.uuidString).jpg")
        XCTAssertEqual(stored.kind, .image)
        XCTAssertEqual(try storedType(stored.fileName), UTType.jpeg.identifier)
    }

    // MARK: - The downscale rule

    func testAPictureLargerThanTheCapIsBroughtDownToIt() throws {
        let encoded = try ReferenceAttachmentStore.downscaledJPEG(pngData(width: 4000, height: 2000))
        let size = try XCTUnwrap(pixelSize(encoded))

        XCTAssertEqual(max(size.width, size.height), ReferenceAttachmentStore.maxPixelSize,
                       "the longest edge is capped at exactly the limit")
        XCTAssertEqual(size.height, size.width / 2,
                       "the aspect ratio survives the downscale")
    }

    /// The cap must only ever shrink. A screenshot arriving under it that came back *larger* would
    /// be the store inventing detail and charging the player disk space for it.
    func testAPictureSmallerThanTheCapIsNotUpscaled() throws {
        let encoded = try ReferenceAttachmentStore.downscaledJPEG(pngData(width: 320, height: 240))
        let size = try XCTUnwrap(pixelSize(encoded))

        XCTAssertEqual(size.width, 320)
        XCTAssertEqual(size.height, 240)
    }

    /// Bytes that are nothing we store are refused, and refusing writes nothing.
    ///
    /// **Invalid UTF-8 with no declared type is the only way to be unreadable now**, and that is a
    /// property of the encodings rather than a gap: a single-byte encoding decodes *any* byte
    /// sequence, so text that merely says "this is not a picture" is a perfectly good text file.
    func testBytesThatAreNothingWeStoreAreRefusedRatherThanStored() throws {
        let binary = Data([0xFF, 0xFE, 0x00, 0x01, 0xC3, 0x28, 0xA0, 0xA1])

        XCTAssertThrowsError(try ReferenceAttachmentStore.downscaledJPEG(binary))
        XCTAssertThrowsError(try ReferenceAttachmentStore.adopt(binary, contentType: nil,
                                                                for: UUID(), fileManager))
        XCTAssertTrue(ReferenceAttachmentStore.filesOnDisk(fileManager).isEmpty,
                      "a refused import leaves nothing behind")
    }

    /// The same bytes, now **claiming** to be plain text, are stored — the legacy ladder is offered
    /// to a file that says it is text, because a `.txt` from a 1990s tab archive is exactly that
    /// case. Neutralise by dropping the `claimsText` gate and the test above stops failing.
    func testBinaryClaimingToBeTextIsTakenAtItsWord() throws {
        let binary = Data([0xFF, 0xFE, 0x00, 0x01, 0xC3, 0x28, 0xA0, 0xA1])

        XCTAssertEqual(try ReferenceAttachmentStore.resolve(binary, contentType: .plainText).kind,
                       .text)
    }

    // MARK: - Replace, delete, measure

    /// Re-picking into the same reference overwrites, the way `SongFileStore.adopt` does for a
    /// relink — otherwise every correction would leave the previous picture stranded on disk.
    func testAdoptingTwiceForOneUIDReplacesRatherThanAccumulates() throws {
        let uid = UUID()
        try ReferenceAttachmentStore.adopt(pngData(width: 100, height: 100), contentType: nil,
                                          for: uid, fileManager)
        try ReferenceAttachmentStore.adopt(pngData(width: 200, height: 200), contentType: nil,
                                          for: uid, fileManager)

        XCTAssertEqual(ReferenceAttachmentStore.filesOnDisk(fileManager).count, 1)
        let leaf = ReferenceAttachmentStore.fileName(for: uid, kind: .image)
        let stored = try XCTUnwrap(ReferenceAttachmentStore.data(fileName: leaf, fileManager))
        XCTAssertEqual(try XCTUnwrap(pixelSize(stored)).width, 200)
    }

    func testDeleteIsIdempotent() throws {
        let uid = UUID()
        let leaf = try ReferenceAttachmentStore.adopt(pngData(width: 50, height: 50), contentType: nil,
                                                  for: uid, fileManager).fileName

        XCTAssertTrue(ReferenceAttachmentStore.exists(fileName: leaf, fileManager))
        try ReferenceAttachmentStore.delete(fileName: leaf, fileManager)
        XCTAssertFalse(ReferenceAttachmentStore.exists(fileName: leaf, fileManager))
        XCTAssertNoThrow(try ReferenceAttachmentStore.delete(fileName: leaf, fileManager),
                         "a missing file is not an error")
    }

    func testFileSizeReadsWhatWasWritten() throws {
        let leaf = try ReferenceAttachmentStore.adopt(pngData(width: 400, height: 400), contentType: nil,
                                                  for: UUID(), fileManager).fileName
        let size = try XCTUnwrap(ReferenceAttachmentStore.fileSize(fileName: leaf, fileManager))

        XCTAssertGreaterThan(size, 0)
        XCTAssertNil(ReferenceAttachmentStore.fileSize(fileName: "nothing.jpg", fileManager))
    }

    func testThumbnailIsSmallerThanTheStoredPicture() throws {
        let leaf = try ReferenceAttachmentStore.adopt(pngData(width: 1600, height: 1600), contentType: nil,
                                                  for: UUID(), fileManager).fileName
        let thumb = try XCTUnwrap(ReferenceAttachmentStore.thumbnailData(fileName: leaf, longestEdge: 132,
                                                                    fileManager))

        XCTAssertEqual(try XCTUnwrap(pixelSize(thumb)).width, 132)
    }

    // MARK: - Documents (PDF, text, Markdown)

    /// A PDF is stored **whole**, not flattened to a picture of page one. That is the decision the
    /// kind exists for: a six-page tab that silently lost five pages would be worse than refusing
    /// PDFs, so this asserts the bytes come back byte-identical.
    func testAPDFIsStoredUnchangedAndKeepsItsExtension() throws {
        let uid = UUID()
        let pdf = pdfFixture()

        let stored = try ReferenceAttachmentStore.adopt(pdf, contentType: .pdf, for: uid, fileManager)

        XCTAssertEqual(stored.kind, .pdf)
        XCTAssertEqual(stored.fileName, "\(uid.uuidString).pdf")
        XCTAssertEqual(ReferenceAttachmentStore.data(fileName: stored.fileName, fileManager), pdf,
                       "a document is never re-encoded")
    }

    /// The magic number decides, not the extension: PDFKit hands back an empty document for something
    /// that merely claims to be one, and a row saying *PDF* about that is a dead end.
    func testPDFIsRecognisedByItsHeaderNotItsClaimedType() throws {
        XCTAssertTrue(ReferenceAttachmentStore.isPDF(pdfFixture()))
        XCTAssertFalse(ReferenceAttachmentStore.isPDF(Data("not a pdf at all".utf8)))

        // Claimed as a PDF, but the bytes are text — so it is stored as text.
        let lying = Data("e|--0--2--3--|\n".utf8)
        let stored = try ReferenceAttachmentStore.resolve(lying, contentType: .pdf)
        XCTAssertEqual(stored.kind, .text)
    }

    func testPlainTextIsStoredAsTextAndKeepsItsExtension() throws {
        let uid = UUID()
        let tab = Data("e|--0--2--3--|\nB|--1--1--1--|\n".utf8)

        let stored = try ReferenceAttachmentStore.adopt(tab, contentType: .plainText, for: uid,
                                                        fileManager)

        XCTAssertEqual(stored.kind, .text)
        XCTAssertEqual(stored.fileName, "\(uid.uuidString).txt")
        XCTAssertEqual(ReferenceAttachmentStore.text(fileName: stored.fileName, fileManager),
                       "e|--0--2--3--|\nB|--1--1--1--|\n")
    }

    /// **The ordering test.** `net.daringfireball.markdown` conforms to `public.plain-text`, so a
    /// resolver that asked the plain-text question first would answer `true` for every `.md` and draw
    /// prose as if it were a tab grid. Neutralise by swapping the two branches and this fails.
    func testMarkdownIsRecognisedBeforePlainTextClaimsIt() throws {
        let markdown = try XCTUnwrap(ReferenceAttachmentStore.markdownType)
        XCTAssertTrue(markdown.conforms(to: .plainText),
                      "the conformance that makes the branch order load-bearing")

        let stored = try ReferenceAttachmentStore.resolve(Data("# CAGED\n\nUse **shape 2**.".utf8),
                                                          contentType: markdown)
        XCTAssertEqual(stored.kind, .markdown)
        XCTAssertEqual(ReferenceAttachmentStore.fileName(for: UUID(), kind: .markdown).hasSuffix(".md"),
                       true)
    }

    /// A picker that says nothing still gets an answer, because the bytes are the fact.
    func testTextWithNoDeclaredTypeIsStillStored() throws {
        let stored = try ReferenceAttachmentStore.resolve(Data("just some notes".utf8), contentType: nil)
        XCTAssertEqual(stored.kind, .text)
    }

    /// A `.txt` from a tab archive is routinely in a legacy single-byte encoding. Refusing to show one
    /// because it is not UTF-8 would fail exactly the file this feature exists to keep.
    func testLegacyEncodedTextStillDecodes() throws {
        let latin1 = try XCTUnwrap("Café — bar 12".data(using: .windowsCP1252))
        XCTAssertNil(String(data: latin1, encoding: .utf8), "precondition: not valid UTF-8")

        XCTAssertEqual(ReferenceAttachmentStore.decodedText(latin1), "Café — bar 12")
        XCTAssertEqual(try ReferenceAttachmentStore.resolve(latin1, contentType: .plainText).kind, .text)
    }

    /// Documents are not re-encoded, so nothing else bounds them. Images cannot reach this — the
    /// pixel cap gets there first.
    func testAnOversizeDocumentIsRefusedWithItsOwnError() {
        let huge = Data(repeating: 0x25, count: ReferenceAttachmentStore.maxDocumentBytes + 1)

        XCTAssertThrowsError(try ReferenceAttachmentStore.resolve(huge, contentType: .pdf)) { error in
            XCTAssertEqual(error as? ReferenceAttachmentStore.ImportError, .tooLarge)
        }
    }

    /// The picker must offer only what the app can actually store. Offering SVG — which conforms to
    /// `public.image` but which ImageIO cannot decode — is how a file gets advertised and then
    /// refused.
    func testThePickerDoesNotOfferSVG() throws {
        let offered = Set(ReferenceAttachmentStore.pickerTypes.map(\.identifier))

        XCTAssertFalse(offered.contains(UTType.svg.identifier),
                       "SVG conforms to public.image but ImageIO cannot read it")
        XCTAssertTrue(offered.contains(UTType.jpeg.identifier))
        XCTAssertTrue(offered.contains(UTType.png.identifier))
        XCTAssertTrue(offered.contains(UTType.pdf.identifier))
        XCTAssertTrue(offered.contains(UTType.plainText.identifier))
    }

    /// Every extension the sweep recognises must be one a kind actually writes, or a file we stored
    /// becomes invisible to `filesOnDisk` and can never be reclaimed.
    func testEveryAttachmentKindHasADistinctExtension() {
        let extensions = ReferenceLinkKind.attachmentKinds.map(\.fileExtension)

        XCTAssertEqual(Set(extensions).count, extensions.count, "\(extensions)")
        XCTAssertFalse(extensions.contains(""), "an empty extension would make the leaf a bare uid")
        XCTAssertEqual(ReferenceLinkKind.link.fileExtension, "", "a link is not a file")
    }

    // MARK: - The sweep

    /// The sweep is the **primary** collector here rather than a backstop: a cascade from a deleted
    /// owner removes the rows without running any of our code, so these files have nothing else
    /// coming for them.
    func testOrphanedFilesAreThoseNoLinkStillPointsAt() {
        let onDisk = ["a.jpg", "b.jpg", "c.jpg"]
        XCTAssertEqual(ReferenceAttachmentStore.orphanedFiles(onDisk: onDisk,
                                                             referenced: ["a.jpg", "c.jpg"]),
                       ["b.jpg"])
        XCTAssertEqual(ReferenceAttachmentStore.orphanedFiles(onDisk: onDisk, referenced: []), onDisk)
    }

    func testAReferencedFileMissingFromDiskIsNotAnOrphan() {
        XCTAssertTrue(ReferenceAttachmentStore.orphanedFiles(onDisk: [], referenced: ["ghost.jpg"]).isEmpty)
    }

    /// `filesOnDisk` filters to our own extensions, so a stray file in the directory is never
    /// proposed for deletion by a sweep that has no idea what it is.
    func testFilesOnDiskIgnoresLeavesWeDidNotWrite() throws {
        try ReferenceAttachmentStore.adopt(pngData(width: 40, height: 40), contentType: nil,
                                           for: UUID(), fileManager)
        let stray = try ReferenceAttachmentStore.directory(fileManager)
            .appending(path: "somebody-elses.rtf", directoryHint: .notDirectory)
        try Data("hello".utf8).write(to: stray)

        XCTAssertEqual(ReferenceAttachmentStore.filesOnDisk(fileManager).count, 1)
    }

    // MARK: - Fixtures

    /// The smallest thing that is really a PDF: the header the format is identified by, plus enough
    /// body that nothing downstream chokes on emptiness.
    private func pdfFixture() -> Data {
        Data("%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n".utf8)
    }

    /// A real PNG of the requested size, so the downscale is measured against encoded bytes rather
    /// than against a `CGImage` handed straight back.
    private func pngData(width: Int, height: Int) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let output = NSMutableData()
        let writer = try XCTUnwrap(CGImageDestinationCreateWithData(output,
                                                                    UTType.png.identifier as CFString,
                                                                    1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        return output as Data
    }

    private func pixelSize(_ data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }

    private func storedType(_ leaf: String) throws -> String? {
        let data = try XCTUnwrap(ReferenceAttachmentStore.data(fileName: leaf, fileManager))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceGetType(source) as String?
    }
}
