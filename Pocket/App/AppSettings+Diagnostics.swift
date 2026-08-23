import Foundation

/// The one diagnostics preference (ADR 0183).
///
/// Split into its own file for the same reason the tuner's four were: `AppSettings.swift` sits close
/// to SwiftLint's 400-line cap and this preference answers to a single feature with its own ADR. The
/// **key stays in `AppSettings.Key`** — one nested enum, one alphabet of every key the app has ever
/// written, because scattering keys across extensions is how two end up sharing a string.
extension AppSettings {

    /// Whether the bounded diagnostic line rides along with the next support message (ADR 0183).
    ///
    /// **Default off, and it is the only one of these defaults that is off on principle rather than
    /// on taste.** ADR 0161 D3 made the contact sheet's promise that nothing is attached the player
    /// has not read; a summary that attached itself by default would be true to the letter of that
    /// and false to its point. Nothing here leaves the device until this is turned on *and* a support
    /// message is sent.
    ///
    /// The literal is named because a `@AppStorage` uses the value it declares for an unset key and
    /// does **not** consult the accessor beside it — every site binds to this one constant.
    static let attachDiagnosticsDefault = false

    /// Whether the diagnostic line is attached to support messages. Default off.
    static var attachDiagnostics: Bool {
        bool(Key.attachDiagnostics, default: attachDiagnosticsDefault)
    }
}
