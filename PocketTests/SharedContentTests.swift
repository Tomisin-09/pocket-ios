import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// **What *Save to Red Moon* makes of what it was handed** (ADR 0264 D8, D12). No UI test can drive
/// another app's share sheet (D10.6), so these are the rules, on values.
final class SharedContentTests: XCTestCase {

    // MARK: - What an attachment offers

    func testAWebLinkWinsOverTheSentenceSentWithIt() {
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.url"]), .webLink)
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.plain-text", "public.url"]), .webLink)
    }

    func testAFileLinkIsNotAWebLink() {
        XCTAssertNil(SharedContent.offer(registeredTypes: ["public.file-url"]))
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.file-url", "com.adobe.pdf"]), .pdf)
    }

    func testPicturesPDFsAndTextAreKept() {
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.jpeg"]), .image)
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.heic"]), .image)
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["com.adobe.pdf"]), .pdf)
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.plain-text"]), .plainText)
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["public.utf8-plain-text"]), .plainText)
    }

    /// Markdown conforms to plain text, so it has to be asked first or a `.md` reads as a tab.
    func testMarkdownIsMarkdownNotPlainText() {
        XCTAssertEqual(SharedContent.offer(registeredTypes: ["net.daringfireball.markdown"]), .markdown)
    }

    /// ImageIO can't read SVG, which `public.image` takes in. The app's picker leaves it out too.
    func testAPictureImageIOCantReadIsNotKept() {
        XCTAssertNil(SharedContent.offer(registeredTypes: ["public.svg-image"]))
    }

    func testWhatRedMoonDoesntKeepIsNotOffered() {
        XCTAssertNil(SharedContent.offer(registeredTypes: ["public.zip-archive"]))
        XCTAssertNil(SharedContent.offer(registeredTypes: ["public.mpeg-4"]))
        XCTAssertNil(SharedContent.offer(registeredTypes: []))
    }

    // MARK: - D12: a sentence with a link in it

    func testTheFirstWebLinkInASentenceIsFound() {
        let text = "Watch this: https://youtu.be/abc123 then https://example.com/second"
        XCTAssertEqual(SharedContent.firstWebLink(in: text), "https://youtu.be/abc123")
    }

    func testABareAddressInASentenceReadsAsTheStoreReadsIt() {
        let found = SharedContent.firstWebLink(in: "lesson at youtube.com/watch?v=xyz tonight")
        XCTAssertNotNil(found)
        XCTAssertEqual(found.flatMap(URL.init(string:))?.host, "youtube.com")
        XCTAssertEqual(found.flatMap(ReferenceURL.normalised)?.absoluteString, found, "the store keeps it as is")
    }

    func testOnlyWebLinksCount() {
        XCTAssertNil(SharedContent.firstWebLink(in: "write to me@example.com or mailto:me@example.com"))
        XCTAssertEqual(SharedContent.firstWebLink(in: "mailto:me@example.com then http://example.com/a"),
                       "http://example.com/a")
    }

    func testTextWithNoLinkHasNothingToSave() {
        XCTAssertNil(SharedContent.firstWebLink(in: "Practise the bend slower."))
        XCTAssertEqual(SharedContent.noLink, "There's no link in this to save.")
    }

    // MARK: - Titles

    func testTheSharedTextLessItsLinkSuggestsATitle() {
        XCTAssertEqual(SharedContent.suggestedTitle(fromSharedText: "CAGED, the A shape https://youtu.be/abc",
                                                    link: "https://youtu.be/abc"),
                       "CAGED, the A shape")
        XCTAssertEqual(SharedContent.suggestedTitle(fromSharedText: "Slow Bend lesson\nmore words",
                                                    link: nil),
                       "Slow Bend lesson", "only the first line")
        XCTAssertEqual(SharedContent.suggestedTitle(fromSharedText: "https://youtu.be/abc",
                                                    link: "https://youtu.be/abc"),
                       "", "a link alone suggests nothing")
        XCTAssertEqual(SharedContent.suggestedTitle(fromSharedText: nil, link: nil), "")
    }

    func testADocumentKeepsItsNameAndAPictureLeavesItToThePlayer() {
        XCTAssertEqual(SharedContent.suggestedTitle(fileName: "CAGED part 3.pdf", offer: .pdf), "CAGED part 3")
        XCTAssertEqual(SharedContent.suggestedTitle(fileName: "IMG_4127.HEIC", offer: .image), "")
        XCTAssertEqual(SharedContent.suggestedTitle(fileName: nil, offer: .plainText), "")
    }

    // MARK: - Files

    func testOnlyADocumentHasACeiling() {
        let over = ReferenceAttachmentStore.maxDocumentBytes + 1
        XCTAssertEqual(SharedContent.refusal(for: .pdf, byteCount: over), ReferenceAttachmentCopy.tooLarge)
        XCTAssertEqual(SharedContent.refusal(for: .markdown, byteCount: over), ReferenceAttachmentCopy.tooLarge)
        XCTAssertNil(SharedContent.refusal(for: .pdf, byteCount: ReferenceAttachmentStore.maxDocumentBytes))
        XCTAssertNil(SharedContent.refusal(for: .image, byteCount: over), "a picture is cut down in the app")
    }

    func testAFileKeepsItsOwnExtensionInTheInbox() {
        XCTAssertEqual(SharedContent.inboxFileName(original: "Tab.TXT", offer: .plainText), "shared.txt")
        XCTAssertEqual(SharedContent.inboxFileName(original: "notes.md", offer: .markdown), "shared.md")
        XCTAssertEqual(SharedContent.inboxFileName(original: nil, offer: .pdf), "shared.pdf")
        XCTAssertEqual(SharedContent.inboxFileName(original: "photo", offer: .image), "shared.jpg")
    }
}
