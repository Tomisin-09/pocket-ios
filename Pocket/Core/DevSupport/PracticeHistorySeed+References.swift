#if DEBUG
import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Where you learned it (ADR 0167), seeded for `references/section` — moved here from
/// `PracticeHistorySeed.swift` when the picture went in, since that file is near the line cap.
extension PracticeHistorySeed {

    /// Two reference links on Alternate Picking — one of them carrying a note — and one picture.
    ///
    /// Seeded rather than driven. Typing two URLs through the keyboard would add a minute to a run
    /// that is already six, and a URL field is exactly where a UI test's typing goes wrong —
    /// autocorrect, a missed keyboard dismissal, a `.` that lands as `,`. The editor sheet itself is
    /// still driven (`references/editor`), so the flow a player takes is photographed, not simulated.
    ///
    /// **Deliberately generic hosts.** A figure in a published manual is an implicit endorsement and
    /// an implicit permission claim, so these name no real teacher's channel and no real tab site.
    /// They read as what a player would save without being anybody's actual page. The picture is
    /// drawn here for the same reason: nobody's handout, only ruled lines and fret numbers.
    ///
    /// Pinned to **Alternate Picking** by name, not to `exercises.first`. A `FetchDescriptor` with no
    /// sort returns store order, so "first" is whatever the preset seed happened to insert first —
    /// stable today and silently re-pointable by an unrelated change to `PracticePresets`. A figure
    /// whose subject can move is a figure that goes wrong without anything failing.
    @MainActor
    static func seedReferences(exercises: [Exercise], into context: ModelContext) {
        guard let exercise = exercises.first(where: { $0.name == "Alternate Picking" })
                ?? exercises.first else { return }
        // **One noted, one not** — on purpose. The note is optional, so a figure showing only
        // noted rows would promise a third line that most rows do not have, and a figure showing
        // none could not illustrate the field at all. Two rows is exactly enough to show both.
        let sources = [("The lesson this came from",
                        "https://example.com/lessons/alternate-picking",
                        "The down-up bit starts about four minutes in — the rest is theory."),
                       ("Tab for the whole run",
                        "https://tabs.example.org/alternate-picking",
                        "")]
        for (title, url, note) in sources {
            ReferenceLinkStore.add(title: title, url: url, note: note, to: exercise, in: context)
        }
        // After the links, so it lists third, under them, as the figure's alt text says.
        _ = try? ReferenceLinkStore.addAttachment(writtenOutTab(), contentType: .png,
                                                  title: "The pattern, written out", to: exercise,
                                                  in: context)
    }

    /// A page of hand-ruled tab: six lines and a run of fret numbers, ink on paper. Drawn rather than
    /// bundled, so the seed carries no image file and no one's material.
    static func writtenOutTab() -> Data {
        let size = CGSize(width: 900, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let ink = UIColor(white: 0.15, alpha: 1)
            ink.setStroke()
            let top: CGFloat = 170, gap: CGFloat = 46
            for string in 0..<6 {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 60, y: top + CGFloat(string) * gap))
                path.addLine(to: CGPoint(x: 840, y: top + CGFloat(string) * gap))
                path.lineWidth = 2
                path.stroke()
            }
            let font = UIFont.systemFont(ofSize: 34, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink,
                                                             .backgroundColor: UIColor(white: 0.96, alpha: 1)]
            // Alternate picking up the A minor pentatonic, low to high: (string from the top, fret).
            let notes = [(5, 5), (5, 8), (4, 5), (4, 7), (3, 5), (3, 7), (2, 5), (2, 7), (1, 5), (1, 8)]
            for (index, note) in notes.enumerated() {
                let point = CGPoint(x: 100 + CGFloat(index) * 72, y: top + CGFloat(note.0) * gap - 22)
                NSString(string: "\(note.1)").draw(at: point, withAttributes: attributes)
            }
            NSString(string: "down  up  down  up …").draw(
                at: CGPoint(x: 100, y: 80),
                withAttributes: [.font: UIFont.italicSystemFont(ofSize: 32), .foregroundColor: ink])
        }
        return image.pngData() ?? Data()
    }
}
#endif
