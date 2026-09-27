import Foundation

/// Count the notes' one preference (ADR 0225): whether the tap rows show the song's beats.
///
/// Its own file because `AppSettings.swift` sits on SwiftLint's 400-line cap. The **key stays in
/// `AppSettings.Key`**, one alphabet of every key the app has written.
extension AppSettings {

    /// **Off.** Notes lead and beats are optional: the count and where the dots land carry the screen,
    /// and the grid they'd be drawn against can be wrong (one tempo per song, ADR 0154).
    ///
    /// Named rather than written as a literal at each `@AppStorage`, because the value an `@AppStorage`
    /// declares is what SwiftUI uses for an unset key and it does **not** consult the accessor below.
    static let countShowsBeatsDefault = false

    /// Whether Count the notes draws beat lines and a per-beat split. Remembered across loops and launches.
    static var countShowsBeats: Bool { bool(Key.countShowsBeats, default: countShowsBeatsDefault) }
}
