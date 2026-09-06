import Foundation

/// How much a **seek release** on the song player snaps to what is already drawn (ADR 0194).
///
/// This is one preference over a distinction ADR 0080 drew and this does not flatten: a *tap* means
/// "take me to that structure" and catches markers, loop edges **and** beats; a *scrub* means "put
/// the playhead exactly here" and drops the dense beat grid, keeping only the sparse landmarks. The
/// three values scale that pair down together rather than switching it off wholesale, so the
/// tap/scrub difference survives at every setting that snaps at all.
///
/// `RawRepresentable` with a `String` raw value so it works directly with `@AppStorage`.
enum SeekSnapping: String, CaseIterable, Identifiable {
    /// Today's behaviour, and the default: a tap catches markers, loop edges and beats; a scrub
    /// catches markers and loop edges.
    case structureAndBeat
    /// The beat grid never catches a seek, at either gesture — a tap behaves the way a scrub always
    /// has. For a player who thinks in sections rather than in bars, or whose song carries a grid
    /// dense enough that every tap lands on a pulse.
    case structureOnly
    /// Nothing catches a seek. The playhead lands exactly where the finger lifted, every time.
    case off

    static let `default` = SeekSnapping.structureAndBeat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .structureAndBeat: return "Structure and beat"
        case .structureOnly: return "Structure only"
        case .off: return "Off"
        }
    }

    /// Whether a seek release snaps to anything at all.
    var snapsToAnything: Bool { self != .off }

    /// Whether the **beat grid** is a candidate for this release. Beats need both a setting that
    /// admits them and a gesture that wants them: a scrub drops the grid at every setting (ADR
    /// 0080), which is why this takes the gesture and is not a stored flag.
    func includesBeats(scrubbing: Bool) -> Bool {
        self == .structureAndBeat && !scrubbing
    }
}
