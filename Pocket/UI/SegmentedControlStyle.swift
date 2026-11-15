import UIKit

/// Every segmented control's labels in **Futura-Medium** (ADR 0061: Futura for all UI text), applied
/// once at launch via the `UISegmentedControl.appearance()` proxy, the way `NavigationBarStyle` does
/// titles (ADR 0110). SwiftUI ignores `.font` on a `Picker` with `.segmented` style, so the proxy is the
/// one lever, and it reaches all of them, now and later. Before this every segmented control in the app
/// drew in the system font.
///
/// **Medium in both states.** The system sets the selected segment semibold; Futura ships only Medium
/// and Bold, and Bold is wide enough to change a label's width as the selection moves, which on the
/// app's tightest controls (five segments) truncates. The selected pill already says which is chosen.
///
/// **Scaled, with a ceiling.** `UIFontMetrics` grows the 13 pt anchor with Dynamic Type, up to 17 pt.
/// The system control does not scale at all; past the ceiling a segment's label would truncate rather
/// than wrap.
///
/// **Reversibility:** this file plus its one call site (`AppDelegate`) is the whole footprint.
enum SegmentedControlStyle {
    /// The system's own segmented label size.
    static let pointSize: CGFloat = 13
    static let maximumPointSize: CGFloat = 17

    /// Install the Futura label font on the shared `UISegmentedControl` proxy. Call once, early, at
    /// launch, before any control is built.
    @MainActor
    static func apply() {
        let base = UIFont(name: "Futura-Medium", size: pointSize) ?? .systemFont(ofSize: pointSize, weight: .medium)
        let font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: base, maximumPointSize: maximumPointSize)
        let control = UISegmentedControl.appearance()
        control.setTitleTextAttributes([.font: font], for: .normal)
        control.setTitleTextAttributes([.font: font], for: .selected)
    }
}
