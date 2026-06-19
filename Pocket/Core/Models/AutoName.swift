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
        let highest = existing.compactMap { name -> Int? in
            guard name.hasPrefix(prefix + " ") else { return nil }
            return Int(name.dropFirst(prefix.count + 1))
        }.max() ?? 0
        return "\(prefix) \(highest + 1)"
    }
}
