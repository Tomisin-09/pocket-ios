import Foundation

/// The one **storage** preference (ADR 0182) — whether imported song copies ride along in device
/// backups.
///
/// Split into its own file for the same reason the tuner's four and the diagnostics one were:
/// `AppSettings.swift` sits on SwiftLint's 400-line cap, so the next setting to land anywhere has to
/// land beside it rather than in it. The **key stays in `AppSettings.Key`** — one nested enum, one
/// alphabet of every key the app has ever written.
///
/// Moving it here also unpicks a merged doc comment: this constant had come to sit *inside* the
/// block explaining ADR 0163's four song-player defaults, so that block appeared to document a
/// backup setting and the four constants it was written for had none.
extension AppSettings {

    /// Whether imported song copies ride along in device backups. **Default on, which is today's
    /// behaviour** — ADR 0148 traded bigger backups for song custody deliberately, and ADR 0182 turns
    /// that trade into an informed choice rather than reversing it.
    ///
    /// Named rather than inlined: the literal a `@AppStorage` declares is what SwiftUI actually uses
    /// for an unset key, and it does **not** consult the accessor. A drifted literal here would tell
    /// a player their songs are in their backup while the app acted otherwise.
    static let songsInBackupDefault = true

    /// Whether song copies stay in device backups (ADR 0182). Default on.
    static var songsInBackup: Bool { bool(Key.songsInBackup, default: songsInBackupDefault) }
}
