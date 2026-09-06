import Foundation

/// The song player's **seek snapping** preference (ADR 0194).
///
/// Its own file for the reason `AppSettings+Tuner.swift` is: `AppSettings.swift` sits on SwiftLint's
/// 400-line cap. The four ADR 0163 display defaults stay where they are rather than moving here with
/// it — they are read by five waveform views apiece, and moving them would be churn in exchange for
/// nothing. The **key stays in `AppSettings.Key`**, one alphabet of every key the app has written.
extension AppSettings {

    /// The default: **structure and beat**, which is exactly what the player did before this setting
    /// existed, so an upgrading install sees no change.
    ///
    /// Named rather than written as a literal, because the value an `@AppStorage` declares is what
    /// SwiftUI uses for an unset key and it does **not** consult the accessor below. Here the two
    /// sites are a Settings screen and a gesture release, which would disagree silently.
    static let seekSnappingDefault = SeekSnapping.default

    /// How much a seek release snaps (ADR 0194). Default `.structureAndBeat`.
    static var seekSnapping: SeekSnapping {
        resolvedSeekSnapping(storedValue: UserDefaults.standard.string(forKey: Key.seekSnapping))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to
    /// `.structureAndBeat` rather than crashing on a bad raw value (mirrors `resolvedTempoWarning`).
    /// Degrading *towards* snapping is the right direction — the failure mode of a playhead that
    /// won't line up with a marker is worse than one that lines up when you meant it not to, and it
    /// is the behaviour every install already had.
    static func resolvedSeekSnapping(storedValue: String?) -> SeekSnapping {
        guard let storedValue else { return seekSnappingDefault }
        return SeekSnapping(rawValue: storedValue) ?? seekSnappingDefault
    }
}
