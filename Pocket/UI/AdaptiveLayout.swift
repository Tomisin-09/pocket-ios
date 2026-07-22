import SwiftUI

/// Width-adaptive layout helpers (ADR 0105 — iPad adaptivity groundwork).
///
/// The app is iPhone-only for v1 (`TARGETED_DEVICE_FAMILY: "1"`), so these caps are
/// **dormant** on shipping builds — a `frame(maxWidth:)` cap is a no-op at compact
/// width, where the screen is already narrower than the measure. They take effect only
/// at *regular* width: iPad (after the eventual universal flip) and iPhone Pro Max in
/// landscape. Because the cap self-disables on narrow screens, `readableWidth()` is safe
/// to apply unconditionally — no `horizontalSizeClass` branch required.
enum PocketLayout {
    /// The comfortable reading measure for a single column of full-width cards/prose.
    /// Wide enough that iPad portrait keeps only modest side margins, narrow enough that
    /// a landscape iPad centres the column instead of stretching it edge-to-edge.
    static let readableContentWidth: CGFloat = 700

    /// The width content should occupy given the space available: capped at the readable
    /// measure, never upscaled past what's offered. Pure (no SwiftUI) so the cap rule is
    /// unit-testable — mirrors what `frame(maxWidth:)` resolves to, made explicit.
    static func contentWidth(available: CGFloat, cap: CGFloat = readableContentWidth) -> CGFloat {
        min(available, cap)
    }
}

extension View {
    /// Caps this view to a readable measure and centres it in the available width, so at
    /// regular width the content sits as a centred column rather than stretching to the
    /// full screen. A no-op at compact width (content is already ≤ the cap). See
    /// `PocketLayout` and ADR 0105.
    func readableWidth(_ cap: CGFloat = PocketLayout.readableContentWidth) -> some View {
        frame(maxWidth: cap)
            .frame(maxWidth: .infinity)
    }
}
