import SwiftUI

/// Appearance override for the app's colour scheme (ADR 0062 follow-up). `.system`
/// (the default) follows the device setting, as ADR 0062 originally shipped; `.light`/
/// `.dark` pin the app regardless of the device, both to aid testing across appearances
/// on one device and as a standing user preference. `RawRepresentable` with a `String`
/// raw value so it works directly with `@AppStorage`.
///
/// In a file of its own because the share extension compiles it (ADR 0264 D10): the owner snapshot
/// carries the player's choice, so *Save to Red Moon* draws in the appearance the app does.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Maps the persisted preference to the `.preferredColorScheme(_:)` argument — `nil`
/// for `.system` so SwiftUI falls through to the device setting instead of pinning one.
extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
