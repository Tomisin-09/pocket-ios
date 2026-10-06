import SwiftUI

/// While a loop or a phrase plays, which tap is being heard. **The one view on its screen that reads a
/// clock** (ADR 0153): it redraws on its own, 30 times a second, and reports only when the tap changes, so
/// nothing above it redraws per frame. Name the notes' strip uses it, and so does *Watch it on the neck*
/// (ADR 0254), which it was lifted out for.
struct HeardTapTracker: View {
    let read: @MainActor () -> Int?
    let report: (Int?) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let heard = read()
            Color.clear
                .onChange(of: heard, initial: true) { _, now in report(now) }
        }
        .accessibilityHidden(true)
    }
}
