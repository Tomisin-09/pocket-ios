import PDFKit
import SwiftUI

/// The file half of a reference — a row thumbnail and the full view — for all three attachment kinds
/// (ADR 0167 phase 2).
///
/// **Bytes are loaded off the main actor and decoded on it.** `ReferenceAttachmentStore` hands back
/// `Data`, which is `Sendable`; a `UIImage` is not, and under Swift 6 strict concurrency — which CI
/// builds with, and more strictly than local Xcode — carrying one across a task boundary is a warning
/// that becomes an error on the toolchain we ship against.

/// A reference attachment at row size: a thumbnail for a picture, a glyph for a document.
///
/// Loads a **thumbnail**, not the stored file — five 2048px pictures decoded per section would cost
/// more memory than any other screen in the app. A PDF and a text file get their symbol rather than a
/// rendered preview: a page of tab at 44 points is an illegible grey rectangle, and the symbol at
/// least says *what kind of thing this is*, which is the only question a row can answer at that size.
///
/// Shows a placeholder rather than nothing when the file has gone. A reference whose bytes are
/// missing keeps its row on purpose — the title and note the player wrote are still worth reading,
/// and a row that silently disappeared would look like a deletion they did not make.
struct ReferenceAttachmentThumbnail: View {
    let link: ReferenceLink
    var side: CGFloat = 44

    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(PocketColor.surfaceSubtle)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                    }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // The row already reads its title and note as one combined label. A thumbnail that announced
        // itself again would make every attachment row say its kind twice.
        .accessibilityHidden(true)
        .task(id: link.attachmentFileName) { await load() }
    }

    /// Three states share this glyph slot: a document (its own symbol), a picture still loading, and
    /// a picture whose file has gone. Only the last is an error, and only it says so.
    private var symbol: String {
        switch link.kind {
        case .pdf: return "doc.richtext"
        case .text: return "doc.plaintext"
        case .markdown: return "text.alignleft"
        case .image, .link: return loaded ? "photo.badge.exclamationmark" : "photo"
        }
    }

    private func load() async {
        // Only pictures have one. Reading a PDF's bytes here to produce nothing would be I/O per row
        // for a glyph that is already decided.
        guard link.kind == .image else {
            loaded = true
            return
        }
        let leaf = link.attachmentFileName
        guard !leaf.isEmpty else {
            loaded = true
            return
        }
        let pixels = Int(side * 3)
        let data = await Task.detached(priority: .userInitiated) {
            ReferenceAttachmentStore.thumbnailData(fileName: leaf, longestEdge: pixels)
        }.value
        image = data.flatMap(UIImage.init(data:))
        loaded = true
    }
}

/// One stored attachment, full screen, with whatever the player wrote about it underneath.
///
/// **A picture does not zoom.** It is something you glance at beside the thing you are about to
/// practise, and a pinch-zoom viewer is the first step towards a tab reader — the feature
/// `docs/research/feasibility-tab-to-fretboard.md` explicitly does not plan. The stored picture is
/// capped at 2048px precisely because it is read at this size, not inspected. A **PDF** is different
/// and gets PDFKit's own zooming: it arrived as a document, is stored whole, and a multi-page tab you
/// cannot page through is not a tab.
struct ReferenceAttachmentViewer: View {
    let link: ReferenceLink

    @Environment(\.dismiss) private var dismiss
    @State private var payload: Payload?
    @State private var loaded = false

    /// What was actually loaded. The kinds diverge enough in what they hold — pixels, a document, a
    /// string — that one optional per kind would let two be non-nil at once.
    private enum Payload {
        case image(UIImage)
        case pdf(PDFDocument)
        /// Fixed-width and unwrapped — a tab grid.
        case tab(String)
        /// Wrapped prose, with its emphasis rendered.
        case prose(AttributedString)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(link.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task(id: link.attachmentFileName) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch payload {
        case .image(let image):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        // The title *is* the alt text (ADR 0167 phase 2 decision 4). It is not
                        // required, so an unnamed picture reads as the word `displayTitle` falls
                        // back to.
                        .accessibilityLabel(link.displayTitle)
                    note
                }
                .padding(20)
            }

        case .pdf(let document):
            // The note sits above rather than below: a `PDFView` takes all the height it is given, so
            // a note under it would be off the bottom of a multi-page document.
            VStack(alignment: .leading, spacing: 0) {
                if link.displayNote != nil {
                    note.padding(20)
                    Divider()
                }
                PDFDocumentView(document: document)
            }

        case .tab(let contents):
            TabTextView(contents: contents, note: link.displayNote)

        case .prose(let contents):
            ProseView(contents: contents, note: link.displayNote)

        case nil:
            if loaded { missing } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
    }

    @ViewBuilder
    private var note: some View {
        if let note = link.displayNote {
            Text(note)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The file is gone — a reinstall from a backup that excluded it, or a sweep that ran while the
    /// row was somehow unreferenced. Say so, rather than showing a blank screen.
    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.largeTitle)
            Text("This \(link.kind.noun) isn't on this device any more.")
                .font(.futura(.footnote))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(PocketColor.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        let leaf = link.attachmentFileName
        let kind = link.kind
        guard !leaf.isEmpty else {
            loaded = true
            return
        }
        let bytes = await Task.detached(priority: .userInitiated) {
            ReferenceAttachmentStore.data(fileName: leaf)
        }.value
        if let bytes {
            switch kind {
            case .image, .link: payload = UIImage(data: bytes).map(Payload.image)
            case .pdf: payload = PDFDocument(data: bytes).map(Payload.pdf)
            case .text: payload = ReferenceAttachmentStore.decodedText(bytes).map(Payload.tab)
            case .markdown: payload = ReferenceAttachmentStore.decodedText(bytes).map { Payload.prose(Self.parsed($0)) }
            }
        }
        loaded = true
    }
}

extension ReferenceAttachmentViewer {
    /// Markdown → styled text.
    ///
    /// **`inlineOnlyPreservingWhitespace`, not `.full`.** `.full` collapses the author's line breaks
    /// into flowed paragraphs, which quietly destroys a notes file written as a list of short lines —
    /// and any ASCII tab someone dropped into a fenced block. This keeps every newline they typed and
    /// styles the emphasis, links and inline code on top.
    ///
    /// Unparseable Markdown falls back to the raw text rather than to an error: the file is still
    /// perfectly readable as what it literally says, and refusing to show it would be the app being
    /// precious about syntax on the player's own notes.
    static func parsed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: markdown, options: options))
            ?? AttributedString(markdown)
    }
}

/// A PDF, paged and zoomable, via the framework that already does this properly.
///
/// `autoScales` so a page fits the width on arrival rather than opening at 100% on a phone; continuous
/// vertical paging because a tab is read top to bottom and a page-flip gesture would fight the sheet's
/// own dismiss.
private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

/// A `.txt` attachment, which in practice means **ASCII tab**.
///
/// Two rules, and both are the difference between readable and worthless:
///
/// - **Fixed-width.** ASCII tab is drawn with characters on a grid; in a proportional font the
///   fret numbers stop lining up with the dashes and the notation is meaningless.
/// - **No wrapping.** A tab line is as wide as it is. Soft-wrapping folds bar 3 onto its own line
///   under bar 1 and the six strings stop being six strings — so it scrolls sideways instead,
///   which is what every tab site does for the same reason.
private struct TabTextView: View {
    let contents: String
    let note: String?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                if let note {
                    Text(note)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(contents)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(PocketColor.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                }
            }
            .padding(20)
        }
    }
}

/// A Markdown attachment — somebody's written lesson notes.
///
/// **The opposite treatment to `TabTextView`, deliberately.** Markdown is prose: it wraps, in the
/// app's own proportional face, and its emphasis is rendered rather than shown as asterisks. A `.txt`
/// is a grid and gets the grid treatment. Storing both as one kind would have meant picking one of
/// these and being wrong about half the files.
///
/// The one known cost: ASCII tab pasted inside a `.md` wraps like the prose around it. Saving that as
/// `.txt` is the answer, and the manual says so.
private struct ProseView: View {
    let contents: AttributedString
    let note: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let note {
                    Text(note)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
                Text(contents)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
    }
}
