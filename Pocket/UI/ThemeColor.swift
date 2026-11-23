import SwiftUI
import UIKit

/// **How a theme reaches every colour** (ADR 0311 D8). `PocketColor`'s themed tokens are dynamic
/// colours: each asks the theme for its colour set at the moment it is drawn, the way a catalog colour
/// asks for light or dark. So none of their ~600 call sites changes, and nothing has to remember to
/// read the theme.
///
/// The theme travels as an environment value that is also a UIKit trait (`UITraitBridgedEnvironmentKey`,
/// iOS 17). Setting `\.moonTheme` once at the `PocketApp` root writes the trait, and a change of trait
/// redraws every dynamic colour beneath it, including views whose bodies never read the theme, and
/// UIKit's own (bars, alerts, segmented controls). A sheet inherits the environment like any child.
///
/// Anywhere the root hasn't set it (a preview, the share extension before its snapshot arrives) it
/// reads Blood Moon, the default (D1).
struct MoonThemeTrait: UITraitDefinition {
    static let defaultValue = MoonTheme.standard
    /// A change of theme redraws colours, exactly as a change of appearance does.
    static let affectsColorAppearance = true
    static let name = "MoonTheme"
}

private struct MoonThemeKey: UITraitBridgedEnvironmentKey {
    static let defaultValue = MoonTheme.standard

    static func read(from traitCollection: UITraitCollection) -> MoonTheme {
        traitCollection[MoonThemeTrait.self]
    }

    static func write(to mutableTraits: inout UIMutableTraits, value: MoonTheme) {
        mutableTraits[MoonThemeTrait.self] = value
    }
}

extension EnvironmentValues {
    /// The theme everything beneath draws in. Set once, at the root (`PocketApp`), and by the Theme
    /// screen's previews, which draw themes that aren't the current one.
    var moonTheme: MoonTheme {
        get { self[MoonThemeKey.self] }
        set { self[MoonThemeKey.self] = newValue }
    }
}

extension Color {
    /// The colour `role` takes in whatever theme it is drawn in. See `MoonThemeTrait`.
    init(themed role: ThemeRole) {
        self.init(uiColor: UIColor { traits in
            let name = traits[MoonThemeTrait.self].colorSet(role)
            // A colour set this mapping names but the catalog lacks would draw nothing; magenta makes
            // it impossible to miss, and `MoonThemeTests` fails on it first.
            return UIColor(named: name)?.resolvedColor(with: traits) ?? .magenta
        })
    }
}
