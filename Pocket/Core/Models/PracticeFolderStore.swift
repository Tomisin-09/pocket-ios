import Foundation
import SwiftData

/// The store-side half of **Folders** (ADR 0210) — the verbs that touch more than one model, kept in
/// one place so the three things that know a folder's name (exercises, routines and marker rows)
/// cannot end up disagreeing about it.
///
/// All the arithmetic lives in `FolderPath`, which is pure and tested. What is here is only the
/// fetching and the writing: the union that makes the folder list, and the two verbs — rename and
/// delete — that are a *pass over everything* rather than an edit to one row.
///
/// Fetches are unfiltered and narrowed in memory on purpose. An optional `#Predicate` starves the
/// main thread (the SwiftData optional-predicate freeze), and a string predicate over a path would
/// have to reimplement `isUnder`'s segment comparison in a language that only has `hasPrefix` —
/// which is the bug that comparison exists to avoid.
enum PracticeFolderStore {

    // MARK: - Reading

    /// Every folder path the library knows about: the union of marker paths and the paths derived
    /// from members, **including implied ancestors** (D4).
    ///
    /// The union is what makes markers helpful rather than load-bearing. A library restored from an
    /// archive written before markers, or edited by a build without them, still browses correctly —
    /// its folders are visible because things are filed in them.
    static func namespace(in context: ModelContext) -> [String] {
        var paths: [String] = []
        for folder in fetchMarkers(in: context) {
            paths.append(contentsOf: FolderPath.ancestry(folder.path))
        }
        for exercise in fetchExercises(in: context) {
            paths.append(contentsOf: exercise.folders.flatMap { FolderPath.ancestry($0) })
        }
        for routine in fetchRoutines(in: context) {
            paths.append(contentsOf: routine.folders.flatMap { FolderPath.ancestry($0) })
        }
        return FolderPath.normalized(paths)
    }

    /// The marker rows, as stored.
    static func fetchMarkers(in context: ModelContext) -> [PracticeFolder] {
        (try? context.fetch(FetchDescriptor<PracticeFolder>())) ?? []
    }

    /// How many exercises and routines sit at or below `path` — the numbers the delete confirmation
    /// quotes, so "your drills stay" is a count rather than a promise.
    static func contents(of path: String, in context: ModelContext) -> (exercises: Int, routines: Int) {
        // `filter{}.count`, not `count(where:)` — the latter is Swift 6 stdlib, gated to iOS 18,
        // and this app deploys to 17.
        let drills = fetchExercises(in: context).filter { FolderPath.contains($0.folders, within: path) }
        let sessions = fetchRoutines(in: context).filter { FolderPath.contains($0.folders, within: path) }
        return (drills.count, sessions.count)
    }

    private static func fetchExercises(in context: ModelContext) -> [Exercise] {
        (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    }

    private static func fetchRoutines(in context: ModelContext) -> [Routine] {
        (try? context.fetch(FetchDescriptor<Routine>())) ?? []
    }

    // MARK: - Creating

    /// Make sure a marker exists for `path`, and return it. Matched case-insensitively against the
    /// markers already stored, so filing into a folder that exists does not mint a second row that
    /// renders as the same folder.
    @discardableResult
    static func ensureMarker(for path: String, in context: ModelContext) -> PracticeFolder? {
        let canonical = FolderPath.canonical(path)
        guard !canonical.isEmpty else { return nil }
        let existing = fetchMarkers(in: context).first { $0.path.lowercased() == canonical.lowercased() }
        if let existing { return existing }
        let folder = PracticeFolder(path: canonical)
        context.insert(folder)
        return folder
    }

    /// The **New folder…** verb: one segment, at the level the player is standing on (D5). Returns
    /// the created folder's full path, or `nil` when the name was empty.
    ///
    /// The name is folded into the namespace first, so typing `beginner` where `Beginner` already
    /// exists lands *in* that folder rather than creating a near-twin beside it — ADR 0033's
    /// convergence rule, applied per segment.
    @discardableResult
    static func createFolder(named rawName: String,
                             at prefix: String,
                             in context: ModelContext) -> String? {
        guard let path = FolderPath.appending(rawName, to: prefix) else { return nil }
        let folded = FolderPath.folding(path, into: namespace(in: context))
        ensureMarker(for: folded, in: context)
        return folded
    }

    // MARK: - Filing

    /// File `exercise` into `path`, minting the marker if the folder is new.
    static func file(_ exercise: Exercise, into path: String, in context: ModelContext) {
        let folded = FolderPath.folding(FolderPath.canonical(path), into: namespace(in: context))
        guard !folded.isEmpty else { return }
        exercise.folders = FolderPath.adding(folded, to: exercise.folders)
        ensureMarker(for: folded, in: context)
    }

    /// File `routine` into `path`, minting the marker if the folder is new.
    static func file(_ routine: Routine, into path: String, in context: ModelContext) {
        let folded = FolderPath.folding(FolderPath.canonical(path), into: namespace(in: context))
        guard !folded.isEmpty else { return }
        routine.folders = FolderPath.adding(folded, to: routine.folders)
        ensureMarker(for: folded, in: context)
    }

    // MARK: - Renaming

    /// Rename `path`'s **leaf**, rewriting every member and marker at or below it in one pass (D5).
    /// Returns the new path, or `nil` when the name was empty.
    ///
    /// A rename is a copy-then-delete across every holder because S3 cannot rename a prefix either —
    /// there is nothing to rename, only keys that happen to share an opening. Doing it in one pass
    /// here is what stops the three holders from drifting.
    @discardableResult
    static func rename(_ path: String, toSegment rawName: String, in context: ModelContext) -> String? {
        guard let target = FolderPath.renamed(path, toSegment: rawName) else { return nil }
        guard target.lowercased() != FolderPath.canonical(path).lowercased() else { return target }

        for exercise in fetchExercises(in: context) where FolderPath.contains(exercise.folders, within: path) {
            exercise.folders = FolderPath.renaming(path, to: target, in: exercise.folders)
        }
        for routine in fetchRoutines(in: context) where FolderPath.contains(routine.folders, within: path) {
            routine.folders = FolderPath.renaming(path, to: target, in: routine.folders)
        }
        var seen = Set(fetchMarkers(in: context).map { $0.path.lowercased() })
        for marker in fetchMarkers(in: context) where FolderPath.isUnder(marker.path, prefix: path) {
            let moved = FolderPath.renaming(path, to: target, in: [marker.path]).first ?? marker.path
            // Renaming onto a folder that exists **merges** — a folder is its path, so two markers
            // for one path would be one folder drawn twice. Drop the loser rather than keep both.
            if seen.contains(moved.lowercased()), moved.lowercased() != marker.path.lowercased() {
                context.delete(marker)
            } else {
                seen.remove(marker.path.lowercased())
                seen.insert(moved.lowercased())
                marker.path = moved
            }
        }
        return target
    }

    // MARK: - Deleting

    /// Delete `path` and everything below it — **the folder, never its contents** (D10).
    ///
    /// The markers go and the prefix is stripped from every member. A drill filed only here becomes
    /// unfiled and shows at the root; a drill also filed elsewhere is untouched there. Nothing is
    /// deleted from the library, which is why the confirmation says so in words: "Delete folder" in
    /// most apps on this device means something considerably more frightening.
    static func deleteFolder(_ path: String, in context: ModelContext) {
        guard !FolderPath.canonical(path).isEmpty else { return }
        for exercise in fetchExercises(in: context) where FolderPath.contains(exercise.folders, within: path) {
            exercise.folders = FolderPath.removing(path, from: exercise.folders)
        }
        for routine in fetchRoutines(in: context) where FolderPath.contains(routine.folders, within: path) {
            routine.folders = FolderPath.removing(path, from: routine.folders)
        }
        for marker in fetchMarkers(in: context) where FolderPath.isUnder(marker.path, prefix: path) {
            context.delete(marker)
        }
    }
}
