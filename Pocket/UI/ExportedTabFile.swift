import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// A tab on its way out through the share sheet, as plain text or a PDF (ADR 0236 D9).
///
/// Carries where the tab comes from, not the laid-out document: `ShareLink` rebuilds its item on every
/// pass of the view's body, and the layout and the PDF are made in the transfer representation, once a
/// destination is picked. The same split `ExportedAudioFile` makes.
struct ExportedTabFile: Transferable, Sendable, Equatable {

    enum Format: Sendable, Equatable {
        case text, pdf
    }

    var source: TabDocument.Source
    var format: Format

    /// The tab's title with the format's extension: *Riff idea.txt*, *Slow Bend.pdf*.
    var fileName: String {
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExportStaging.fileName(stem: title.isEmpty ? "Tab" : title,
                                      fileExtension: format == .text ? "txt" : "pdf")
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .utf8PlainText) { SentTransferredFile(try await $0.written()) }
            .exportingCondition { $0.format == .text }
        FileRepresentation(exportedContentType: .pdf) { SentTransferredFile(try await $0.written()) }
            .exportingCondition { $0.format == .pdf }
    }

    /// Lay the tab out, write it in its format, and return where it is. The PDF is drawn on the main
    /// actor (`TabPDF`); the text needs nothing but the layout.
    func written() async throws -> URL {
        let document = TabDocument(source)
        let data = switch format {
        case .text: Data(document.text.utf8)
        case .pdf: await TabPDF.data(for: document)
        }
        return try ExportStaging.write(data, as: fileName)
    }
}

/// **Export** on a tab's reading screen (ADR 0236 D9): *Plain text* and *PDF*. One view for both kinds of
/// tab, My tabs and Map the song's Tab view, so the two can't drift apart.
///
/// `ShareLink`s inside a `Menu`, which present: the hold-menu and take-menu exports prove the shape.
/// (A `ShareLink` in a `Form` row is the one that doesn't; see `SharePresenter`.)
struct TabExportMenu: View {
    let source: TabDocument.Source

    var body: some View {
        Menu {
            item(.text, "Plain text", systemImage: "doc.plaintext")
            item(.pdf, "PDF", systemImage: "doc.richtext")
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Export tab")
    }

    private func item(_ format: ExportedTabFile.Format, _ title: String, systemImage: String) -> some View {
        let file = ExportedTabFile(source: source, format: format)
        return ShareLink(item: file, preview: SharePreview(file.fileName)) {
            Label(title, systemImage: systemImage)
        }
    }
}
