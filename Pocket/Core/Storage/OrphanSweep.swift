import Foundation

/// Deleting the files nothing points at any more (ADR 0182).
///
/// The two stores have had pure `orphanedFiles` sweeps since ADR 0069 and ADR 0148, both unit-tested
/// — and **neither had a production caller.** `docs/architecture.md` described the retention story as
/// though it ran. It did not. This is the part that makes the description true: it composes the two
/// pure sweeps, measures what they would free, deletes it, and says what it did.
///
/// **Nothing here decides what is referenced.** The caller builds both sets from the live store, and
/// that is deliberate — an orphan is defined by the absence of a row, so a sweep that fetched its own
/// idea of "referenced" would be one bad predicate away from deleting a player's audio.
enum OrphanSweep {

    /// What a sweep found and freed.
    struct Outcome: Equatable, Sendable {
        var songFiles: [String] = []
        var takeFiles: [String] = []
        var bytesFreed: Int64 = 0

        var fileCount: Int { songFiles.count + takeFiles.count }
        var isEmpty: Bool { fileCount == 0 }
    }

    /// Sweep both directories.
    ///
    /// - Parameters:
    ///   - referencedSongFiles: every surviving `Song.audioFileName`.
    ///   - referencedTakeFiles: every surviving `Recording.fileName` — **every** one, from the whole
    ///     store, never from one owner's relationship. Takes arrive from more paths than they used to
    ///     (ADR 0179 and ADR 0180 let a routine block record), and a take whose loop was deleted keeps
    ///     its row on purpose (ADR 0151), so a set built from any single owner would classify real
    ///     recordings as rubbish and delete them.
    ///
    /// Sizes are read **before** the delete, because afterwards there is nothing left to measure. A
    /// file that fails to delete is left out of the total rather than counted optimistically.
    static func run(referencedSongFiles: Set<String>,
                    referencedTakeFiles: Set<String>,
                    _ fileManager: FileManager = .default) -> Outcome {
        var outcome = Outcome()

        for leaf in SongFileStore.orphanedFiles(onDisk: SongFileStore.filesOnDisk(fileManager),
                                                referenced: referencedSongFiles) {
            let size = SongFileStore.fileSize(fileName: leaf, fileManager) ?? 0
            guard (try? SongFileStore.delete(fileName: leaf, fileManager)) != nil else { continue }
            outcome.songFiles.append(leaf)
            outcome.bytesFreed += size
        }

        for leaf in RecordingStore.orphanedFiles(onDisk: RecordingStore.filesOnDisk(fileManager),
                                                 referenced: referencedTakeFiles) {
            let size = RecordingStore.fileSize(fileName: leaf, fileManager) ?? 0
            guard (try? RecordingStore.delete(fileName: leaf, fileManager)) != nil else { continue }
            outcome.takeFiles.append(leaf)
            outcome.bytesFreed += size
        }

        return outcome
    }

    /// What to tell the player afterwards. Pure, so the wording is testable.
    ///
    /// "Nothing to reclaim" is the **good** answer and reads as one — a sweep that found nothing means
    /// the app has not been leaking, and phrasing it as a failure would teach players to keep pressing
    /// a button that has nothing to do.
    static func summary(_ outcome: Outcome) -> String {
        guard !outcome.isEmpty else { return "Nothing to reclaim — no stray files." }
        let files = outcome.fileCount == 1 ? "1 stray file" : "\(outcome.fileCount) stray files"
        return "Removed \(files), freeing \(StorageUsage.formatted(bytes: outcome.bytesFreed))."
    }
}
