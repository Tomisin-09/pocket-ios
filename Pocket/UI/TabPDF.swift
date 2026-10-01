import UIKit

/// A tab drawn onto pages (ADR 0236 D9): the lines `TabDocument` lays out, in a fixed-width font, so the
/// PDF reads exactly as the text file does.
///
/// **A4, or US Letter where the locale measures in inches.** A row's lines are kept together on a page,
/// with its section's heading, so a page never ends between a tab's strings. The ink is the app's
/// light-mode palette, since a PDF is printed and read on white: chords in the chords lane's indigo,
/// names in the notes lane's teal (ADR 0232 D3), everything else near-black.
///
/// UIKit, so it lives here rather than beside `TabDocument`, which stays pure. On the main actor: the
/// drawing APIs are thread-safe in practice, but the SDKs don't all say so, and CI's older one is the
/// stricter reader. A tab is a page or two, so drawing it on the main actor costs nothing anyone sees.
@MainActor
enum TabPDF {

    /// The document as a PDF.
    static func data(for document: TabDocument, locale: Locale = .current) -> Data {
        let page = pageSize(for: locale)
        let style = Style(document: document, pageWidth: page.width)
        let pages = paginate(document.blocks, style: style, pageHeight: page.height)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        return renderer.pdfData { context in
            for (number, blocks) in pages.enumerated() {
                context.beginPage()
                var top = style.margin
                if number == 0 { top = drawTitle(document, style: style, top: top) }
                for block in blocks {
                    top = draw(block, style: style, top: top)
                }
                if number == pages.count - 1 {
                    draw(document.footer, font: style.small, color: style.quiet,
                         at: CGPoint(x: style.margin, y: top + 6))
                }
                let folio = "\(number + 1) / \(pages.count)"
                draw(folio, font: style.small, color: style.quiet,
                     at: CGPoint(x: page.width - style.margin - width(of: folio, font: style.small),
                                 y: page.height - style.margin + 12))
            }
        }
    }

    /// Points, by the locale's measurement system.
    nonisolated static func pageSize(for locale: Locale) -> CGSize {
        locale.measurementSystem == .us ? CGSize(width: 612, height: 792) : CGSize(width: 595.28, height: 841.89)
    }

    // MARK: - Layout

    /// The type and spacing, worked out once per document. The tab's font is as large as 10 pt allows
    /// while the widest line still fits between the margins.
    private struct Style {
        let margin: CGFloat = 48
        let title = UIFont(name: "Futura-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        let subtitle = UIFont(name: "Futura-Medium", size: 11) ?? .systemFont(ofSize: 11)
        let heading = UIFont(name: "Futura-Bold", size: 12) ?? .boldSystemFont(ofSize: 12)
        let small = UIFont(name: "Futura-Medium", size: 8.5) ?? .systemFont(ofSize: 8.5)
        let mono: UIFont
        let monoBold: UIFont
        let lineHeight: CGFloat
        let ink = UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1)
        let quiet = UIColor(red: 0x6B / 255, green: 0x65 / 255, blue: 0x60 / 255, alpha: 1)
        /// `toolkit`, light (design-brief §3): the chords lane.
        let chords = UIColor(red: 0x4B / 255, green: 0x3F / 255, blue: 0x94 / 255, alpha: 1)
        /// `practice`, light: the notes lane.
        let names = UIColor(red: 0x2B / 255, green: 0x69 / 255, blue: 0x82 / 255, alpha: 1)

        init(document: TabDocument, pageWidth: CGFloat) {
            let widest = CGFloat(document.blocks.flatMap(\.lines).map(\.text.count).max() ?? 1)
            let probe = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            let advance = ("0" as NSString).size(withAttributes: [.font: probe]).width / 10
            let size = min(10, (pageWidth - 2 * margin) / max(widest * advance, 1))
            mono = .monospacedSystemFont(ofSize: size, weight: .regular)
            monoBold = .monospacedSystemFont(ofSize: size, weight: .semibold)
            lineHeight = size * 1.3
        }

        func height(of block: TabDocument.Block) -> CGFloat {
            (block.heading == nil ? 0 : 20) + CGFloat(block.lines.count) * lineHeight + 12
        }
    }

    /// Blocks shared out onto pages, none split. The first page gives up room for the title, the last for
    /// the footer; a block taller than a page has one to itself.
    private static func paginate(_ blocks: [TabDocument.Block], style: Style,
                                 pageHeight: CGFloat) -> [[TabDocument.Block]] {
        let bottom = pageHeight - style.margin - 20
        var pages: [[TabDocument.Block]] = [[]]
        var top = style.margin + 60
        for block in blocks {
            let height = style.height(of: block)
            if top + height > bottom, !(pages.last?.isEmpty ?? true) {
                pages.append([])
                top = style.margin
            }
            pages[pages.count - 1].append(block)
            top += height
        }
        return pages
    }

    // MARK: - Drawing

    private static func drawTitle(_ document: TabDocument, style: Style, top: CGFloat) -> CGFloat {
        var line = top
        draw(document.title, font: style.title, color: style.ink, at: CGPoint(x: style.margin, y: line))
        line += 28
        if let subtitle = document.subtitle {
            draw(subtitle, font: style.subtitle, color: style.quiet, at: CGPoint(x: style.margin, y: line))
            line += 18
        }
        return line + 14
    }

    private static func draw(_ block: TabDocument.Block, style: Style, top: CGFloat) -> CGFloat {
        var cursor = top
        if let heading = block.heading {
            draw(heading, font: style.heading, color: style.ink, at: CGPoint(x: style.margin, y: cursor))
            cursor += 20
        }
        for line in block.lines {
            let (font, color): (UIFont, UIColor) = switch line.kind {
            case .ruler: (style.mono, style.quiet)
            case .chords: (style.monoBold, style.chords)
            case .names: (style.monoBold, style.names)
            case .strings: (style.mono, style.ink)
            }
            draw(line.text, font: font, color: color, at: CGPoint(x: style.margin, y: cursor))
            cursor += style.lineHeight
        }
        return cursor + 12
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, at point: CGPoint) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func width(of text: String, font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
