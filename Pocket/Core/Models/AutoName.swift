import Foundation

/// Auto-naming for annotations created without a naming step (loops are created
/// instantly and named "Loop 3"; the user renames later from the row — ADR 0019).
///
/// Pure and UI-free so the numbering — which silently collides without coverage
/// (re-using a number after a delete) — is unit-tested per AGENTS.md.
enum AutoName {

    /// The next auto name for `prefix`, e.g. `"Loop 3"`: one past the highest
    /// trailing number among `existing` names of the form `"<prefix> <n>"`. Names
    /// the user typed themselves (anything not matching that shape) are ignored, so
    /// the counter tracks the high-water mark and never reissues a number that's
    /// still in use — even after loops in the middle are deleted.
    static func next(prefix: String, existing: [String]) -> String {
        "\(prefix) \(highest(in: existing, leads: [prefix + " "]) + 1)"
    }

    /// The next marker name, e.g. `"M3"` (ADR 0226 D2) — short, because a marker's label floats over
    /// the waveform and competes with it for width.
    ///
    /// **Counts the long form too.** Markers were named `"Marker 3"` until then, and existing labels
    /// are the player's data, so they keep their names. A counter that only saw `"M<n>"` would find no
    /// high-water mark on a song holding `"Marker 1"…"Marker 5"` and start again at `"M1"` — two
    /// markers numbered one, which is the collision this type exists to prevent.
    static func nextMarker(existing: [String]) -> String {
        "M\(highest(in: existing, leads: ["M", "Marker "]) + 1)"
    }

    /// The highest number among `names` that are one of `leads` followed by digits and nothing else.
    private static func highest(in names: [String], leads: [String]) -> Int {
        names.compactMap { name in leads.lazy.compactMap { number(in: name, after: $0) }.first }.max() ?? 0
    }

    /// Digits only — `Int("+5")` and `Int("-5")` parse, and neither is a name this type handed out.
    private static func number(in name: String, after lead: String) -> Int? {
        guard name.hasPrefix(lead) else { return nil }
        let digits = name.dropFirst(lead.count)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }
}
