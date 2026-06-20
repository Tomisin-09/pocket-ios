import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Light haptic for gesture confirmations — no-op where UIKit is unavailable.
@MainActor func haptic(_ style: HapticStyle) {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: style.uiStyle).impactOccurred()
    #endif
}

enum HapticStyle {
    case light, medium
    #if canImport(UIKit)
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle { self == .light ? .light : .medium }
    #endif
}
