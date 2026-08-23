import Foundation

/// The tuner's four preferences (ADR 0115, widened to bass by ADR 0116).
///
/// Split out of `AppSettings` when that file reached SwiftLint's 400-line cap, and split here rather
/// than anywhere else because the tuner is the one settings group that answers to a whole feature
/// with its own ADR — instrument, mode, reference pitch and chime are read by `TunerView` and nothing
/// else. Everything left behind in the main file is read from several places at once.
///
/// **The keys stay in `AppSettings.Key`.** It is a nested enum and a single alphabet of every key the
/// app has ever written; scattering it across extensions is how two keys end up with the same string.
extension AppSettings {

    /// Reference-pitch (concert A) calibration range offered by the tuner, in Hz. A440 is the
    /// default; A432–A446 covers the ensembles a player might tune to. Free — unlike Fender, we
    /// don't gate calibration behind a paid tier (our Pro line is author-vs-run, ADR 0112).
    static var tunerReferenceRange: ClosedRange<Int> { 432...446 }

    /// The tuner's default reference pitch, standard concert A.
    static var tunerReferenceDefault: Int { 440 }

    /// The tuner's instrument axis. Default `.guitar`.
    static var tunerInstrument: Instrument {
        resolvedInstrument(storedValue: UserDefaults.standard.string(forKey: Key.tunerInstrument))
    }

    /// Pure default-resolution: a missing or unrecognised value falls back to `.guitar`.
    static func resolvedInstrument(storedValue: String?) -> Instrument {
        guard let storedValue else { return .default }
        return Instrument(rawValue: storedValue) ?? .default
    }

    /// The tuner's mode — guided vs chromatic. Default `.guided`.
    static var tunerMode: TunerMode {
        resolvedTunerMode(storedValue: UserDefaults.standard.string(forKey: Key.tunerMode))
    }

    /// Pure default-resolution: a missing or unrecognised value falls back to `.guided`.
    static func resolvedTunerMode(storedValue: String?) -> TunerMode {
        guard let storedValue else { return .default }
        return TunerMode(rawValue: storedValue) ?? .default
    }

    /// The tuner's reference pitch in Hz, clamped to `tunerReferenceRange`. Default 440.
    static var tunerReferenceA: Int {
        let resolved = resolvedInt(storedValue: UserDefaults.standard.object(forKey: Key.tunerReferenceA),
                                   default: tunerReferenceDefault)
        return min(tunerReferenceRange.upperBound, max(tunerReferenceRange.lowerBound, resolved))
    }

    /// Whether the tuner sounds a short chime when a string settles in tune. Default on.
    /// Rewarding an *objective* pitch target — not performance feedback (ADR 0070 intact).
    static var tunerChimeEnabled: Bool { bool(Key.tunerChimeEnabled, default: true) }
}
