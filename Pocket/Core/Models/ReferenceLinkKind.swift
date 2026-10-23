import Foundation

/// What a reference link *is* — a pointer out of the app, stored as a `String` and never as a raw
/// enum attribute (`docs/swiftdata-gotchas.md`: a custom enum stored on a `@Model` migrates cleanly
/// in the simulator and traps on a device that has old data — ADR 0036 paid for that lesson).
///
/// `image` is carried from day one although ADR 0167 sequences images second. The field exists so
/// phase 2 is a **pure addition** rather than a retype after the schema freeze, which
/// `docs/backlog.md` records as now-or-never.
///
/// A file of its own, apart from the `@Model`, because the share extension compiles it (ADR 0264 D10)
/// to name what it can keep, and the extension has no store.
enum ReferenceLinkKind: String, CaseIterable {
    /// A URL the player typed or pasted — a lesson, a tab page, a course, a teacher's write-up.
    case link
    /// A picture of the source: a tab screenshot, a photo of a page, a diagram somebody drew you.
    case image
    /// A PDF — which is what a downloaded tab very often *is*. Stored whole and rendered by PDFKit,
    /// never flattened to a picture of page one: a six-page tab that silently lost five pages would
    /// be a worse feature than refusing PDFs.
    case pdf
    /// A plain-text file — ASCII tab, the format the internet taught guitarists in before anything
    /// else. Stored as bytes and rendered fixed-width without wrapping, because that is the only way
    /// it is readable at all.
    case text
    /// A Markdown file — somebody's written lesson notes. **A separate kind from `.text` on purpose,
    /// and the difference is how it is drawn:** `.txt` is a *grid* (tab only lines up fixed-width and
    /// unwrapped), Markdown is *prose* (it wraps, in a proportional font, with its emphasis
    /// rendered). Storing both as `.text` would have meant picking one treatment and being wrong
    /// about half the files.
    case markdown

    /// The kinds that are **a file on disk** rather than a pointer out of the app.
    static let attachmentKinds: [ReferenceLinkKind] = [.image, .pdf, .text, .markdown]

    /// The extension a stored file of this kind carries. Load-bearing: `filesOnDisk` recognises our
    /// own files by it during a sweep, and it is what makes an exported archive openable by hand.
    var fileExtension: String {
        switch self {
        case .link: return ""
        case .image: return "jpg"
        case .pdf: return "pdf"
        case .text: return "txt"
        case .markdown: return "md"
        }
    }

    /// A heading over several of this kind: the References library's *Site* grouping, where a file has
    /// no site and is grouped by what it is (ADR 0275).
    var pluralTitle: String {
        switch self {
        case .link: return "Links"
        case .image: return "Pictures"
        case .pdf: return "PDFs"
        case .text: return "Text files"
        case .markdown: return "Markdown files"
        }
    }

    /// What the app calls one of these in a sentence.
    /// The noun with a capital, for the places that name a kind on its own rather than mid-sentence
    /// — a row with no title of its own, and the file preview in the editor.
    var capitalizedNoun: String { noun.capitalizedFirst }

    var noun: String {
        switch self {
        case .link: return "link"
        case .image: return "picture"
        case .pdf: return "PDF"
        case .text: return "text file"
        case .markdown: return "Markdown file"
        }
    }
}

private extension String {
    /// "picture" → "Picture". Only ever applied to the fixed nouns above, so there is no locale
    /// subtlety here that `localizedCapitalized` would handle better.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
