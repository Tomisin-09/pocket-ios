import Foundation

/// **Which App Icon the player keeps** (ADR 0314): the one their theme wears, or one moon's, whatever
/// the theme. One choice covers both things a player might want: an icon that stays put when the theme
/// changes (Blood Moon's, say, under Harvest Moon colours), and a moon icon with the app left in Blood
/// Moon.
///
/// **Foundation only**, like `MoonTheme`, so what the Home Screen should show is a unit test.
/// `MoonThemeHost` asks it and sets the icon; the App Icon screen draws it.
enum AppIconChoice: Hashable, Sendable {
    /// The icon follows the theme (ADR 0312 D3), which is what it did before this choice existed.
    case matchesTheme
    /// This moon's icon, whatever the theme.
    case moon(MoonTheme)

    /// What no stored choice means (D2): the icon matches the theme, so nothing changes for anyone.
    static let standard = AppIconChoice.matchesTheme

    /// Every choice, in the screen's order: the theme's own first, then the eight moons in theirs.
    static let allCases: [AppIconChoice] = [.matchesTheme] + MoonTheme.allCases.map(AppIconChoice.moon)

    /// The name the App Icon screen and the Appearance row say.
    var name: String {
        switch self {
        case .matchesTheme: "Matches theme"
        case .moon(let theme): theme.name
        }
    }

    /// The choice the app acts on (D3). One moon's icon is part of the plan, as its theme is, so while
    /// the plan is off a moon other than Blood Moon gives way to Blood Moon's. *Matches theme* never
    /// needs the plan: the theme it matches is already the one the plan allows (`MoonTheme.effective`).
    ///
    /// The stored choice isn't touched, so it comes back with the plan, and until StoreKit has
    /// answered it stands, for the reason `MoonTheme.effective` gives.
    static func effective(chosen: AppIconChoice, planIsOn: Bool, planHasResolved: Bool) -> AppIconChoice {
        guard case .moon(let theme) = chosen, theme != .standard else { return chosen }
        return planIsOn || !planHasResolved ? chosen : .moon(.standard)
    }

    /// The moon whose icon this choice puts on the Home Screen, with the app drawn in `drawnTheme`.
    func icon(drawnTheme: MoonTheme) -> MoonTheme {
        switch self {
        case .matchesTheme: drawnTheme
        case .moon(let theme): theme
        }
    }
}

/// Stored as one string under `AppSettings.Key.appIcon`: `matchesTheme`, or a moon's `rawValue`.
extension AppIconChoice: RawRepresentable {
    private static let matchesThemeValue = "matchesTheme"

    /// `nil` for anything unrecognised, so a value written by a later version, or a bad one, falls back
    /// to `standard` through `@AppStorage`'s default rather than to some other moon.
    init?(rawValue: String) {
        if rawValue == Self.matchesThemeValue {
            self = .matchesTheme
        } else if let theme = MoonTheme(rawValue: rawValue) {
            self = .moon(theme)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .matchesTheme: Self.matchesThemeValue
        case .moon(let theme): theme.rawValue
        }
    }
}
