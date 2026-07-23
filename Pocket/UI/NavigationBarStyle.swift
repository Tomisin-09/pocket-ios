import UIKit

/// One global navigation-bar **title** style: render every `.navigationTitle` in **Futura-Bold**
/// (ADR 0110), applied once at launch via the `UINavigationBar.appearance()` proxy. SwiftUI has no
/// native hook to swap the title face, so a UIKit appearance proxy is the single lever — it catches
/// every screen, and every future one, for free. **Only the title text font changes**: the bar's
/// background is left at the system default material (the app sets no `.toolbarBackground` anywhere,
/// so there is nothing for the proxy to clash with).
///
/// The two screens that hand-roll a `.principal` toolbar item in Futura — Home's wordmark and
/// `MetronomeView`'s header — supply their own centre view, so they're unaffected.
///
/// **Reversibility:** this whole file plus its one call site
/// (`AppDelegate.application(_:didFinishLaunchingWithOptions:)`) is the entire footprint — delete both
/// to revert. Large titles are gated on a single line (`largeTitleTextAttributes`) so they can be
/// dropped alone if they read wrong at 34pt.
enum NavigationBarStyle {
    /// Install the Futura title appearance on the shared `UINavigationBar` proxy. Call once, early, at
    /// launch — before any navigation bar is created.
    @MainActor
    static func apply() {
        let ink = UIColor(named: "Ink") ?? .label
        // Futura-Bold at the title / large-title anchor sizes, `UIFontMetrics`-scaled so Dynamic Type
        // still grows them. Sizes mirror `Font.uiSizes` (.headline 17, .largeTitle 34) in DesignTokens.
        let titleAttributes: [NSAttributedString.Key: Any] =
            [.font: scaledFutura(size: 17, textStyle: .headline), .foregroundColor: ink]
        let largeTitleAttributes: [NSAttributedString.Key: Any] =
            [.font: scaledFutura(size: 34, textStyle: .largeTitle), .foregroundColor: ink]

        // The material bar shown when content scrolls under it — keep the system default background,
        // change only the title font.
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.titleTextAttributes = titleAttributes
        standard.largeTitleTextAttributes = largeTitleAttributes

        // The flat, transparent bar at rest (scroll edge) — same title font, no material.
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.titleTextAttributes = titleAttributes
        scrollEdge.largeTitleTextAttributes = largeTitleAttributes

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        bar.scrollEdgeAppearance = scrollEdge
        bar.compactScrollEdgeAppearance = scrollEdge
    }

    /// Futura-Bold at `size`, scaled for `textStyle` via `UIFontMetrics` so Dynamic Type still grows
    /// it. Falls back to the system bold font if Futura is unavailable (matching `Font.futura`).
    @MainActor
    private static func scaledFutura(size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: "Futura-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}
