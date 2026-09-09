import Foundation
import SwiftData

/// A folder that exists (ADR 0210 D4) — S3's **zero-byte marker object**, and nothing more.
///
/// Membership lives on the item, as a flat `[String]` of paths (`Exercise.folders`,
/// `Routine.folders`). This row answers a different question: *does this folder exist while it is
/// empty?* A teacher building `Grade 1…4` before filling them needs the answer to be yes, and a
/// folder emptied by a delete must not vanish out from under the player mid-task.
///
/// **It records existence, never membership.** No relationship to an exercise or a routine, no
/// member list — those would be a second source of truth about where a drill sits, and the first
/// time the two disagreed the bug would be invisible in both.
///
/// The folder list the browse surface draws is the **union** of marker paths and the paths derived
/// from members (`FolderPath.children(of:in:)` handles the derivation). A marker is written whenever
/// a folder is created *or* filed into, so in practice the two converge; the union exists so a
/// library restored from an archive written before markers — or edited by a build without them —
/// still browses correctly rather than losing folders that plainly have things in them.
///
/// Named `PracticeFolder` rather than `Collection` (which shadows the stdlib protocol — ADR 0033
/// flagged this when it named the same trap) and rather than `Folder` (too close to `FileManager`'s
/// vocabulary in a project that also does real file I/O).
///
/// Model discipline per ADR 0011/0036: a business `uid`, and a **declaration default** on every
/// non-optional attribute — the CoreData 134110 rule, where an `init`-only default wipes the store.
/// A brand-new entity is additive on its own account, so registering it costs no migration.
@Model
final class PracticeFolder {

    /// Stable business id — for list diffing and for presenting a sheet by a stable key rather than
    /// by `persistentModelID`, which self-dismisses (ADR 0090).
    var uid: UUID

    /// The canonical path this marker asserts, `"Beginner/Warm-ups"`. Written only through
    /// `FolderPath`, so the segment-wise canonicalisation and case folding cannot be bypassed here
    /// and reintroduce the fragmentation ADR 0033 exists to prevent.
    ///
    /// A marker exists for a folder's own path; its ancestors are derived, not marked, so deleting
    /// `Beginner` cannot orphan `Beginner/Warm-ups` into invisibility — the child's own path still
    /// derives both.
    var path: String = ""

    /// When the folder was made. The natural secondary sort, and the only provenance a marker has.
    var dateAdded: Date = Date.now

    init(uid: UUID = UUID(), path: String, dateAdded: Date = .now) {
        self.uid = uid
        self.path = path
        self.dateAdded = dateAdded
    }
}
