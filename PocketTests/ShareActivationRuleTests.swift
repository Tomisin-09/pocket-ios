import XCTest
@testable import Pocket

/// **Red Moon appears in the share sheet only for what it keeps** (ADR 0264 D8): the extension's
/// `NSExtensionActivationRule`, read out of the built extension inside the app, evaluated against the
/// shapes the common sharing apps hand over.
///
/// The shapes are written from what each kind of app sends (a link, a sentence, one photo, a file from
/// Files); a device check with the real apps is still owed (D10.6), and this keeps the rule from
/// drifting from that check once it's done.
final class ShareActivationRuleTests: XCTestCase {

    private func rule() throws -> NSPredicate {
        let plugIns = try XCTUnwrap(Bundle.main.builtInPlugInsURL, "the app carries its extension")
        let info = try XCTUnwrap(NSDictionary(contentsOf: plugIns.appending(path: "PocketShare.appex/Info.plist")),
                                 "PocketShare.appex is embedded in the app")
        let fields = try XCTUnwrap(info["NSExtension"] as? NSDictionary)
        let attributes = try XCTUnwrap(fields["NSExtensionAttributes"] as? NSDictionary)
        let format = try XCTUnwrap(attributes["NSExtensionActivationRule"] as? String,
                                   "the rule is a predicate, so it can name exactly what's kept")
        return NSPredicate(format: format)
    }

    /// One shared item per array, each attachment as the type identifiers it registers.
    private func shows(_ items: [[[String]]]) throws -> Bool {
        let extensionItems = items.map { attachments in
            ["attachments": attachments.map { ["registeredTypeIdentifiers": $0] }]
        }
        return try rule().evaluate(with: ["extensionItems": extensionItems])
    }

    func testALinkFromABrowserShowsRedMoon() throws {
        XCTAssertTrue(try shows([[["public.url"]]]))
    }

    func testALinkSentWithItsTitleShowsRedMoon() throws {
        XCTAssertTrue(try shows([[["public.url"], ["public.plain-text"]]]))
    }

    /// D12: a sentence with a link in it. Whether it holds one is only known once it's read.
    func testSharedTextShowsRedMoon() throws {
        XCTAssertTrue(try shows([[["public.plain-text"]]]))
        XCTAssertTrue(try shows([[["public.utf8-plain-text"]]]))
    }

    func testOnePhotoShowsRedMoon() throws {
        XCTAssertTrue(try shows([[["public.heic", "public.jpeg"]]]))
    }

    func testAPDFOrAMarkdownFileFromFilesShowsRedMoon() throws {
        XCTAssertTrue(try shows([[["com.adobe.pdf", "public.file-url"]]]))
        XCTAssertTrue(try shows([[["net.daringfireball.markdown", "public.file-url"]]]))
    }

    /// One reference at a time (D8): two photos would be two.
    func testTwoPhotosDontShowRedMoon() throws {
        XCTAssertFalse(try shows([[["public.jpeg"], ["public.jpeg"]]]))
        XCTAssertFalse(try shows([[["public.jpeg"], ["com.adobe.pdf"]]]))
        XCTAssertFalse(try shows([[["public.url"]], [["public.url"]]]), "two shared items")
    }

    func testWhatRedMoonDoesntKeepDoesntShowIt() throws {
        XCTAssertFalse(try shows([[["public.zip-archive", "public.file-url"]]]), "a file link is not a web link")
        XCTAssertFalse(try shows([[["public.mpeg-4"]]]))
        XCTAssertFalse(try shows([[["public.vcard"]]]))
        XCTAssertFalse(try shows([[[]]]))
    }

    /// Audio is the app's, through *Open in* (ADR 0273), so the extension stays off for it: a voice memo
    /// offering both would put two Red Moon icons side by side in the share sheet.
    func testAudioDoesntShowTheExtension() throws {
        XCTAssertFalse(try shows([[["com.apple.m4a-audio", "public.file-url"]]]), "a voice memo")
        XCTAssertFalse(try shows([[["public.mp3"]]]))
        XCTAssertFalse(try shows([[["com.microsoft.waveform-audio", "public.file-url"]]]))
    }
}
