import Foundation
import ImageIO
import UniformTypeIdentifiers

/// **What *Save to Red Moon* makes of what it was handed** (ADR 0264 D8, D12). Pure, so the rules are
/// tests rather than share-sheet sessions, which no UI test can drive (D10.6). The extension does the
/// loading; this decides what the loaded thing is and whether Red Moon keeps it.
enum SharedContent {

    /// What an attachment offers, in the order the extension prefers it. A sharing app often offers one
    /// thing several ways (a video app hands over the link and a sentence with the link in it), and the
    /// web link is the one 0167 keeps.
    enum Offer: Int, Comparable, Sendable {
        /// An http or https address.
        case webLink
        /// A picture ImageIO can read.
        case image
        case pdf
        /// A Markdown file, ahead of plain text because it conforms to plain text
        /// (`ReferenceAttachmentStore.markdownType`).
        case markdown
        /// Plain text: a `.txt` file if the sharing app hands over a file, otherwise a sentence that
        /// may have a link in it (D12). The extension can only tell once it has loaded it.
        case plainText

        static func < (lhs: Offer, rhs: Offer) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The type the extension asks the sharing app for.
        var typeIdentifier: String {
            switch self {
            case .webLink: UTType.url.identifier
            case .image: UTType.image.identifier
            case .pdf: UTType.pdf.identifier
            case .markdown: ReferenceAttachmentStore.markdownType?.identifier ?? UTType.plainText.identifier
            case .plainText: UTType.plainText.identifier
            }
        }
    }

    /// The best thing an attachment offers, from the type identifiers it registers, or `nil` when it
    /// offers nothing Red Moon keeps. A file link (`public.file-url`) is not a web link: it's a file,
    /// and its own type says which.
    static func offer(registeredTypes: [String]) -> Offer? {
        let types = registeredTypes.compactMap(UTType.init)
        return types.compactMap(offer(for:)).min()
    }

    private static func offer(for type: UTType) -> Offer? {
        if type.conforms(to: .fileURL) { return nil }
        if type.conforms(to: .url) { return .webLink }
        if type.conforms(to: .pdf) { return .pdf }
        if let markdown = ReferenceAttachmentStore.markdownType, type.conforms(to: markdown) { return .markdown }
        if type.conforms(to: .plainText) { return .plainText }
        if type.conforms(to: .image) { return isDecodableImage(type) ? .image : nil }
        return nil
    }

    /// Whether ImageIO reads this kind of picture. `public.image` takes in SVG, which it can't, and the
    /// app's own picker offers only what it can (`ReferenceAttachmentStore.pickerTypes`).
    static func isDecodableImage(_ type: UTType) -> Bool {
        let readable = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
        return readable.contains { UTType($0).map(type.conforms(to:)) ?? false }
    }

    // MARK: - D12: a sentence with a link in it

    /// The first http or https link in `text`, found on the device by `NSDataDetector`, which makes no
    /// request. A bare `youtube.com/watch?v=…` counts: the detector reads it as http, and the store's rule
    /// (`ReferenceURL`) reads a scheme-less link as https. `mailto:` and the like are passed over.
    static func firstWebLink(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let scheme = url.scheme?.lowercased(),
                  ReferenceURL.allowedSchemes.contains(scheme),
                  let found = Range(match.range, in: text) else { continue }
            // The text as written, so the store normalises what the player saw rather than the
            // detector's reading of it.
            return ReferenceURL.normalised(String(text[found]))?.absoluteString
        }
        return nil
    }

    /// What the extension says when shared text has no link in it (D12, verbatim).
    static let noLink = "There's no link in this to save."

    /// What it says when it was handed nothing it keeps.
    static let nothingToKeep = "Red Moon keeps links, pictures, PDFs and text files."

    // MARK: - Files

    /// Whether a file of `byteCount` may be saved, as the store will judge it (0167 phase 2): a picture
    /// is cut down in the app, so only a document has a ceiling. `nil` when it may, or the reason.
    static func refusal(for offer: Offer, byteCount: Int) -> String? {
        switch offer {
        case .image, .webLink: nil
        case .pdf, .markdown, .plainText:
            byteCount > ReferenceAttachmentStore.maxDocumentBytes ? ReferenceAttachmentCopy.tooLarge : nil
        }
    }

    /// The name a shared file is kept under in its inbox folder: its own extension, or the kind's.
    static func inboxFileName(original: String?, offer: Offer) -> String {
        let fallback: String = switch offer {
        case .image: "jpg"
        case .pdf: "pdf"
        case .markdown: "md"
        case .plainText, .webLink: "txt"
        }
        let ext = original.map { ($0 as NSString).pathExtension }.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        return "shared.\(ext.lowercased())"
    }

    /// What a shared file is called before the player names it: a document's own name without its
    /// extension. A picture's is a camera's (`IMG_4127`), which says nothing, so it's left for the player.
    static func suggestedTitle(fileName: String?, offer: Offer) -> String {
        guard offer != .image, let fileName else { return "" }
        return (fileName as NSString).deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A title from the words the sharing app sent with the item, if it sent any (D12: never fetched).
    /// The link is taken out, since the row shows its site anyway, and only the first line is kept.
    static func suggestedTitle(fromSharedText text: String?, link: String?) -> String {
        guard var words = text else { return "" }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: words, range: NSRange(words.startIndex..., in: words))
            for match in matches.reversed() {
                if let found = Range(match.range, in: words) { words.removeSubrange(found) }
            }
        }
        if let link { words = words.replacingOccurrences(of: link, with: "") }
        let firstLine = words.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–—:|·"))
    }
}
