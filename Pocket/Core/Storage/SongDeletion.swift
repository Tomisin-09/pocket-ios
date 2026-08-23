import Foundation

/// Everything deleting a song has to take with it (ADR 0182).
///
/// A one-line seam, and it exists because the missing line was invisible for four months.
/// `LibraryView+GroupedList` held the app's **only** song-delete path and it was a bare
/// `context.delete(song)`, so every song a player ever removed left its full-size audio copy in the
/// container forever — silently, permanently, and directly against ADR 0148 §8's promise that owning
/// a player's files means owing them honesty about the space those files take.
///
/// Pulled out of the view so the rule can be **tested and neutralised** rather than only reviewed.
/// A missing side effect is exactly the kind of defect that survives a green build.
enum SongDeletion {

    /// Delete a song's audio, then its row.
    ///
    /// - Parameter deleteRow: the caller's `context.delete(song)`. Injected rather than performed
    ///   here so this stays free of SwiftData and testable over an uninserted model — inserting into
    ///   a container traps in the XCTest host.
    ///
    /// The file goes **first**, while `audioFileName` is certain to still be readable. Safe without a
    /// reference check: `SongImporter` mints a fresh `sourceID` per import and the leaf is named for
    /// it, so a file belongs to exactly one song even when the same source file is imported twice.
    /// A failed delete is swallowed on purpose — a song the player asked to remove must go whether or
    /// not its audio could be reached, and anything left behind is what the orphan sweep is for.
    @MainActor
    static func perform(_ song: Song, _ fileManager: FileManager = .default,
                        deleteRow: () -> Void) {
        if let leaf = song.audioFileName {
            try? SongFileStore.delete(fileName: leaf, fileManager)
        }
        deleteRow()
    }
}
