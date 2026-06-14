import SwiftUI

/// Functional colour system from the product brief. Colour carries meaning —
/// it is never decorative. Keep these definitions as the single source of truth;
/// do not hard-code hex values in views.
///
/// - active  (green)  — playing / active loop
/// - marker  (amber)  — loop markers and selection
/// - fine    (blue)   — Fine-mode precision selection
/// - pin     (purple) — waveform markers
/// - danger  (red)    — delete / destructive
enum PocketColor {
    /// Near-black, not true black (#0f0f0f). Dark-first interface.
    static let background = Color(red: 0x0f / 255, green: 0x0f / 255, blue: 0x0f / 255)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    static let active = Color.green
    static let marker = Color.orange
    static let fine = Color.blue
    static let pin = Color.purple
    static let danger = Color.red

    // Waveform bar states.
    static let barDefault = Color.white.opacity(0.35)
    static let barPlayed = Color.white.opacity(0.18)
}

/// Typography: monospace for all time values and BPM; system sans for the rest.
extension Font {
    static func pocketMono(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }
}
