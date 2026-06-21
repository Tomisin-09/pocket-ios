import SwiftUI
import UIKit

/// Conversions between SwiftUI `Color` and a `#RRGGBB` hex string, plus RGB component
/// extraction — the bridge for persisting a custom loop colour (ADR 0031) and feeding
/// the pure `ColorContrast` check. Kept here (UIKit-backed) so the model and the pure
/// math stay colour-type-free.
enum HexColor {

    /// `#RRGGBB` (or `RRGGBB`) → `Color`, or `nil` if it doesn't parse.
    static func color(from hex: String) -> Color? {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt64(string, radix: 16) else { return nil }
        return Color(.sRGB,
                     red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    /// `Color` → `#RRGGBB` (uppercase).
    static func hex(from color: Color) -> String {
        let rgb = components(of: color)
        return String(format: "#%02X%02X%02X",
                      Int((rgb.red * 255).rounded()),
                      Int((rgb.green * 255).rounded()),
                      Int((rgb.blue * 255).rounded()))
    }

    /// sRGB components of a `Color`, via `UIColor`.
    static func components(of color: Color) -> RGBComponents {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBComponents(red: Double(red), green: Double(green), blue: Double(blue))
    }
}
