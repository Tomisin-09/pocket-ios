import Foundation
import SwiftData

/// The one-time **tags → folders backfill** (ADR 0210 D7), run once at launch beside the preset
/// backfills.
///
/// `Exercise.tags` existed, was canonicalised, was shown on the ⓘ sheet, and **nothing browsed or
/// filtered by it** — the state ADR 0033 named as *"a grouping you can't filter by is just a note"*.
/// Folders are the browse surface it never had, so every tag becomes a top-level folder and the
/// drills that carried it arrive already filed.
///
/// **It copies; it never moves.** Folding tags in does not mean deleting the column: removing one is
/// a destructive change under ADR 0189, costing a `VersionedSchema`, a `SchemaMigrationPlan`, a
/// migration test against a store the previous build wrote, and a device upgrade run — and 0189 D1
/// names the additive alternative as the thing a destructive change has to beat. It does not beat
/// it. `tags` is retired **in place**: inert, documented as vestigial, still written into a share so
/// a build without folders shows a received drill something meaningful (D8).
///
/// The payoff is the empty state. The seeded presets ship with tags (`picking`, `technique`,
/// `scales`, `warmup`…), so a library opens **already organised** rather than showing a new axis
/// with nothing in it — the way a fresh grouping feature usually fails.
///
/// One caution the precedent raises: `ExerciseNoteRateBackfill`'s header says its assumption was
/// affordable *"because the release is being held and there are no users yet"*. **That is no longer
/// true.** This one runs against real libraries, which is exactly why it copies rather than moves,
/// and why idempotence is a tested property rather than a hope.
enum ExerciseFolderBackfill {

    /// `UserDefaults` key guarding the one-time run.
    static let backfillKey = "exerciseFolderBackfill.v1"

    /// File every tagged drill into the matching top-level folders and mint their markers. Fetch
    /// **all** exercises and work in memory — never an optional `#Predicate`, which starves the main
    /// thread. Guarded so it runs at most once; safe to call on every launch.
    static func runIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: backfillKey) else { return }
        var namespace = PracticeFolderStore.namespace(in: context)
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            namespace = apply(to: exercise, namespace: namespace)
        }
        for path in namespace {
            PracticeFolderStore.ensureMarker(for: path, in: context)
        }
        try? context.save()
        defaults.set(true, forKey: backfillKey)
    }

    /// The per-exercise rule, split out so it is unit-testable without a store. Returns the namespace
    /// with this drill's folders folded in, so the next drill's `beginner` lands in the first one's
    /// `Beginner` instead of beside it.
    ///
    /// **Idempotent**, and that is the property that matters here: `FolderPath.adding` refuses a
    /// folder the drill is already in, so a second run adds nothing — and a player who has since
    /// filed the drill somewhere else, or removed it from the folder a tag made, does not have that
    /// decision quietly undone.
    static func apply(to exercise: Exercise, namespace: [String]) -> [String] {
        var namespace = namespace
        for tag in exercise.tags {
            // A tag is one folder at the top level, never a path: a tag reading "warm/up" is a name
            // with a slash in it, not a statement about hierarchy, and `/` is reserved (D5).
            guard let name = FolderPath.canonicalSegment(tag) else { continue }
            let folded = FolderPath.folding(name, into: namespace)
            exercise.folders = FolderPath.adding(folded, to: exercise.folders)
            namespace = FolderPath.adding(folded, to: namespace)
        }
        return namespace
    }
}
