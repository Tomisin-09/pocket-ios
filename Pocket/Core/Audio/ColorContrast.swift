import Foundation

/// sRGB colour components (0…1), kept as a value type (not a 3-tuple) so it stays
/// UI-free and lint-clean. Shared by `HexColor` (extraction) and `ColorContrast`.
struct RGBComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double
}

/// WCAG relative-luminance contrast, pure and UI-free so it can be unit-tested
/// without a colour type. Used to warn when a custom loop colour is too low-contrast
/// against the near-black background (ADR 0031); the warning is advisory — the colour
/// is still allowed.
enum ColorContrast {

    /// WCAG relative luminance of an sRGB colour.
    static func relativeLuminance(_ rgb: RGBComponents) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    /// Contrast ratio between two luminances (1…21).
    static func ratio(_ lumA: Double, _ lumB: Double) -> Double {
        (max(lumA, lumB) + 0.05) / (min(lumA, lumB) + 0.05)
    }

    /// Whether `foreground` is legible on `background`. Defaults to WCAG's 3:1 for
    /// graphical / large elements — a loop colour is an accent, not body text.
    static func isLegible(foreground: RGBComponents, background: RGBComponents,
                          minRatio: Double = 3.0) -> Bool {
        ratio(relativeLuminance(foreground), relativeLuminance(background)) >= minRatio
    }
}
