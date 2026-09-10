import Foundation

/// Path arithmetic for exercise and routine **Folders** (ADR 0210).
///
/// The storage is a flat `[String]` of canonical paths on the item itself (`Exercise.folders`,
/// `Routine.folders`) — Amazon S3's key-prefix convention rather than a directory tree. There are no
/// folder objects to walk: `/` is just a character, and the hierarchy the player sees is *derived*
/// here, the way S3's console renders `CommonPrefixes` as folders. That is what buys multi-membership
/// (one drill in two places), an additive migration-exempt `[String]`, and no reparenting or cascade
/// decisions to make (ADR 0210 D2).
///
/// Pure and UI-free per AGENTS.md — SwiftData and SwiftUI never appear — because this is where the
/// real bugs live and they are all unit-testable: the segment comparison, the case folding, and the
/// prefix rewrite.
///
/// Sits beside `Labels` and delegates to it per segment rather than duplicating whitespace rules:
/// the app has one normaliser (ADR 0034 records that as a build constraint) and folders must not
/// become a second one.
enum FolderPath {

    /// The separator. A single `/`, and **reserved** — a segment can never contain one (D5): the
    /// New-folder field creates one folder at the current level, so typing `Rock/Blues` gets you a
    /// folder called *Rock Blues*, not two levels you did not ask for. Nesting is done by standing
    /// inside a folder and creating there, which is also what keeps the breadcrumb honest.
    static let separator = "/"

    // MARK: - Canonical form

    /// `path` split into its canonical segments — each one whitespace-canonicalised through
    /// `Labels`, empties dropped. `""` (the root) is zero segments.
    static func segments(_ path: String) -> [String] {
        path.components(separatedBy: separator).compactMap { Labels.canonical($0) }
    }

    /// The canonical form of a whole path: every segment normalised, empties dropped, rejoined.
    /// Returns `""` for a path with no content — the root, which is a place but never a stored
    /// membership.
    static func canonical(_ raw: String) -> String {
        segments(raw).joined(separator: separator)
    }

    /// The canonical form of **one** segment typed by the player, or `nil` when it carries no
    /// content. Any `/` is folded to a space rather than obeyed — see `separator`.
    static func canonicalSegment(_ raw: String) -> String? {
        Labels.canonical(raw.replacingOccurrences(of: separator, with: " "))
    }

    /// `prefix` extended by one canonical segment, or `nil` when the segment is empty. This is the
    /// only way a new folder is made, so a created folder is always exactly one level below where
    /// the player is standing.
    static func appending(_ rawSegment: String, to prefix: String) -> String? {
        guard let segment = canonicalSegment(rawSegment) else { return nil }
        let base = canonical(prefix)
        return base.isEmpty ? segment : base + separator + segment
    }

    /// The last segment — what the folder is called, as opposed to where it is. `""` for the root.
    static func leaf(_ path: String) -> String {
        segments(path).last ?? ""
    }

    /// The containing folder's path, or `nil` at the root (which has no parent).
    static func parent(_ path: String) -> String? {
        let parts = segments(path)
        guard !parts.isEmpty else { return nil }
        return parts.dropLast().joined(separator: separator)
    }

    /// Every prefix of `path`, root first, the path itself last: `"A/B"` ⇒ `["A", "A/B"]`. This is
    /// what makes an ancestor exist without a marker of its own — filing something in `A/B` means
    /// `A` is a folder too.
    static func ancestry(_ path: String) -> [String] {
        let parts = segments(path)
        return parts.indices.map { parts.prefix($0 + 1).joined(separator: separator) }
    }

    // MARK: - Membership

    /// Whether `path` is `prefix` **or sits below it**.
    ///
    /// **Not `hasPrefix`.** `"Beginners/Warm-ups".hasPrefix("Beginner")` is `true`, and it is a
    /// different folder — that string comparison would silently merge two folders whose names happen
    /// to share an opening. Segments are compared as segments. Pinned by a test named for the bug.
    ///
    /// An empty `prefix` is the root and contains everything.
    static func isUnder(_ path: String, prefix: String) -> Bool {
        let want = segments(prefix)
        guard !want.isEmpty else { return true }
        let have = segments(path)
        guard have.count >= want.count else { return false }
        return zip(have, want).allSatisfy { $0.caseInsensitiveCompare($1) == .orderedSame }
    }

    /// Whether an item carrying `folders` belongs in the list shown at `prefix` (D6b).
    ///
    /// A level shows every item at **or below** it, which is a deliberate divergence from
    /// `ListObjects(prefix:delimiter:)` — that returns only what sits directly at a prefix, and
    /// copying it faithfully would leave a fully-filed library's root **empty** and hide
    /// `Beginner/Warm-ups`' drills from `Beginner`. The consequence is that folder counts do not sum
    /// to the library total, because a drill filed in two places is counted in both.
    ///
    /// An item in **no** folder is at the root and nowhere else — it is unfiled, not everywhere.
    static func contains(_ folders: [String], within prefix: String) -> Bool {
        guard !segments(prefix).isEmpty else { return true }
        return folders.contains { isUnder($0, prefix: prefix) }
    }

    /// The immediate child folder names at `prefix`, sorted case-insensitively.
    ///
    /// This is S3's `CommonPrefixes` and it stays **pure S3** even though the item list widens
    /// (D6b): a level's folder rows are its direct children, and descending is what shows the next
    /// level. `paths` is the union of marker paths and paths derived from members, so an ancestor
    /// nobody created explicitly still appears.
    static func children(of prefix: String, in paths: [String]) -> [String] {
        let depth = segments(prefix).count
        var seen: [String: String] = [:]
        for path in paths where isUnder(path, prefix: prefix) {
            let parts = segments(path)
            guard parts.count > depth else { continue }
            let child = parts.prefix(depth + 1).joined(separator: separator)
            let key = child.lowercased()
            if seen[key] == nil { seen[key] = child }
        }
        return seen.values.sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Folding

    /// `path` rewritten to the display form the namespace already uses, segment by segment.
    ///
    /// **This is more than `Labels.adding` does, and the gap is the whole reason it exists.**
    /// `Labels` folds whole strings, so `beginner/Scales` and `Beginner/Scales` are two different
    /// labels to it — exactly the fragmentation ADR 0033 exists to prevent, reintroduced by the `/`.
    ///
    /// Folding is **positional**: a segment adopts the form used at *that place in the tree*, so
    /// `Grade 1/Picking` never renames `Grade 2/picking`. Two paths that fold together are the same
    /// folder; two that do not are different folders, and a folder is its full path.
    static func folding(_ path: String, into existing: [String]) -> String {
        var settled: [String] = []
        for segment in segments(path) {
            let folded = segment.lowercased()
            let match = existing.lazy
                .map { segments($0) }
                .first { parts in
                    parts.count > settled.count
                        && zip(parts, settled).allSatisfy { $0.caseInsensitiveCompare($1) == .orderedSame }
                        && parts[settled.count].lowercased() == folded
                }
            settled.append(match?[settled.count] ?? segment)
        }
        return settled.joined(separator: separator)
    }

    /// `existing` with `raw` added, folded into the display forms `namespace` already uses, unless it
    /// is empty or already present. The membership analogue of `Labels.adding`, and the only way a
    /// path should ever reach `Exercise.folders` / `Routine.folders`.
    static func adding(_ raw: String, to existing: [String], namespace: [String] = []) -> [String] {
        let path = folding(canonical(raw), into: namespace + existing)
        guard !path.isEmpty else { return existing }
        guard !existing.contains(where: { $0.lowercased() == path.lowercased() }) else { return existing }
        return existing + [path]
    }

    /// `existing` with `path` and everything below it removed — what filing away from a folder, and
    /// deleting one, both do to a member (D10). The item itself is never touched: it stays in
    /// whatever other folders it sits in, and an item left with none is simply unfiled.
    static func removing(_ path: String, from existing: [String]) -> [String] {
        existing.filter { !isUnder($0, prefix: path) }
    }

    /// `list` canonicalised end-to-end and de-duplicated case-insensitively, keeping the first-seen
    /// display form. Use on a stored array of unknown provenance — one restored from an archive
    /// written by another build, say.
    static func normalized(_ list: [String]) -> [String] {
        list.reduce(into: [String]()) { result, raw in
            result = adding(raw, to: result)
        }
    }

    // MARK: - Rename

    /// `paths` with `old` — and everything below it — re-rooted at `new`.
    ///
    /// **A rename is a copy-then-delete across every member**, which is not an implementation
    /// shortcut: S3 cannot rename a prefix either, because there is nothing to rename. One pure
    /// function, applied in one pass to exercises, routines and markers alike, is what keeps the
    /// three from disagreeing about what a folder is called.
    ///
    /// Paths outside `old` are returned untouched, and the result is de-duplicated — renaming
    /// `Grade 1` to `Grade 2` when both exist **merges** them, which is the honest outcome of a
    /// namespace where a folder *is* its path.
    static func renaming(_ old: String, to new: String, in paths: [String]) -> [String] {
        let from = segments(old)
        let to = segments(new)
        guard !from.isEmpty, !to.isEmpty else { return paths }
        let rewritten = paths.map { path -> String in
            guard isUnder(path, prefix: old) else { return path }
            return (to + segments(path).dropFirst(from.count)).joined(separator: separator)
        }
        return normalized(rewritten)
    }

    /// A sibling-safe rename target: `old`'s parent, extended by `rawSegment`. `nil` when the new
    /// name is empty or `old` is the root. Renaming only ever changes the **leaf** — moving a folder
    /// somewhere else is a different verb, and this ADR does not ship one.
    static func renamed(_ old: String, toSegment rawSegment: String) -> String? {
        guard !segments(old).isEmpty, let segment = canonicalSegment(rawSegment) else { return nil }
        return appending(segment, to: parent(old) ?? "")
    }
}
