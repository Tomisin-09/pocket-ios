import SwiftUI

/// **Export take…** (ADR 0236 D2): the hold-menu item both lists of takes share, the Journal's feed
/// and a loop's Takes sheet. One view, so the two can't drift apart in wording or glyph.
///
/// It sits above Delete in both. Draws nothing when the take's audio isn't on disk
/// (`Recording.exportedFile`).
///
/// "Export", not "Share" (ADR 0236 D1): the take goes into a DAW, to a teacher, or into Files, and the
/// words say so.
struct ExportTakeMenuItem: View {
    let take: Recording

    var body: some View {
        if let file = take.exportedFile() {
            ShareLink(item: file, preview: SharePreview(file.fileName)) {
                Label("Export take…", systemImage: "square.and.arrow.up")
            }
        }
    }
}
