import CoreGraphics

/// Where the keyboard's dismiss checkmark sits (`KeyboardDismissAccessory`) — the geometry alone, kept
/// free of UIKit so it can be tested without a keyboard, a window or a device.
enum KeyboardAccessoryPlacement {
    /// The button's side, in points. The size of the system's own floating keyboard button on iOS 26,
    /// and over the 44pt minimum a touch target needs.
    static let side: CGFloat = 48
    /// Distance from the screen's trailing edge, or from the trailing safe area where that is wider
    /// (landscape, where the sensor housing sits on one side).
    static let trailingInset: CGFloat = 16
    /// Gap between the button and the top of the keyboard.
    static let gap: CGFloat = 8
    /// A visible keyboard shorter than this is not a keyboard the player types on — it is the shortcut
    /// bar iOS shows with a hardware keyboard attached, and that keyboard has its own way to dismiss.
    static let minimumKeyboardHeight: CGFloat = 120

    /// The button's frame for a keyboard whose end frame is `keyboard`, on a screen of `bounds` — both
    /// in the same coordinate space — or `nil` when there is no on-screen keyboard to sit above.
    ///
    /// Measured on the part of the keyboard that is **on screen**, so a keyboard animating away (its end
    /// frame below the screen) reads as no keyboard rather than as one to float above.
    static func frame(keyboard: CGRect, in bounds: CGRect, trailingSafeInset: CGFloat = 0) -> CGRect? {
        let visible = keyboard.intersection(bounds)
        guard !visible.isNull, visible.height >= minimumKeyboardHeight else { return nil }
        let inset = max(trailingInset, trailingSafeInset + gap)
        return CGRect(x: bounds.maxX - inset - side, y: visible.minY - gap - side,
                      width: side, height: side)
    }
}
