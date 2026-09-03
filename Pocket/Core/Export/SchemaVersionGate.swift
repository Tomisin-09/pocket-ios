import Foundation

/// The first thing either inbound door reads (ADR 0188 D2, S2).
///
/// `schemaVersion` has been written into every file this app produces since ADR 0181 and read by
/// nothing. This is its first reader, and it branches three ways: **equal** proceeds, **lower**
/// migrates, **higher** refuses.
///
/// `.migrate` does nothing today — there is one schema version and nothing to migrate *from* — and
/// the case exists anyway, because the first time there is something to migrate, the door already has
/// somewhere to put it. A gate that collapsed "older" into "proceed" would have to be found and
/// re-split at exactly the moment the format changes, which is the worst moment to be discovering
/// where the branch belongs.
///
/// Pure and Foundation-only: both doors share it, and a version rule that is only exercised through a
/// file picker is a version rule nobody can test.
enum SchemaVersionGate {

    /// What to do with a file that announces a given schema version.
    enum Verdict: Equatable {
        /// The file was written by a build that agrees with this one about the format.
        case proceed
        /// Written by an older build. Carries the version it came from, so a future migration knows
        /// which one it is migrating.
        case migrate(from: Int)
        /// Written by a newer build, and refused with a sentence the player can act on.
        case refuse(message: String)
    }

    /// What a refusal says.
    ///
    /// D2 words it *"this archive was made by a newer version of Red Moon; update the app and try
    /// again"*, written from the restore door's side. It says **file** here because the same sentence
    /// has to serve a shared routine, which is not an archive and is not the player's own — calling a
    /// teacher's handover "your archive" would be wrong in the one place the copy is meant to be
    /// clear. Red Moon, never the target name, because a player reads this (`.swiftlint.yml`).
    static let refusalMessage =
        "This file was made by a newer version of Red Moon. Update the app and try again."

    /// Decide what a file announcing `fileVersion` is allowed to do.
    ///
    /// A version this app cannot possibly have written — zero or negative, from a hand-edited or
    /// truncated file — reads as **refused** rather than as an ancient archive to migrate: there is
    /// no such older format, so the honest answer is that this build does not understand the file.
    static func evaluate(fileVersion: Int,
                         currentVersion: Int = SharedPractice.currentSchemaVersion) -> Verdict {
        guard fileVersion > 0 else { return .refuse(message: refusalMessage) }
        if fileVersion > currentVersion { return .refuse(message: refusalMessage) }
        if fileVersion < currentVersion { return .migrate(from: fileVersion) }
        return .proceed
    }
}
