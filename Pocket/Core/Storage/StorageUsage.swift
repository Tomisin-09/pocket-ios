import Foundation

/// What Red Moon is holding on disk, in bytes (ADR 0182).
///
/// The app owns two directories of full-size audio — `Songs/` (ADR 0148) and `Recordings/`
/// (ADR 0069) — plus reference files in `References/` (ADR 0167 phase 2), and until ADR 0182 had
/// no way to say how big any of them was. ADR 0148 §8 put it plainly:
/// owning a player's files means owing them honesty about the space those files take. This is the
/// arithmetic half of that debt; the screen that shows it is ADR 0182's.
///
/// **Pure and `Sendable`.** No SwiftUI, no SwiftData, and the one function that reads the disk takes
/// its `FileManager` by argument, so a test can point it at a throwaway container
/// (`TempContainerFileManager`) and get real numbers back. Measuring is a directory listing plus a
/// resource value per file — cheap, but it is still I/O, so callers run it off the main actor.
///
/// ADR 0181 needs this before ADR 0182's screen exists: an export has to state its size *before* the
/// tap, and the recordings figure is that size.
struct StorageUsage: Equatable, Sendable {

    /// Imported song audio — `Application Support/Songs/`.
    var songBytes: Int64 = 0

    /// Practice takes — `Application Support/Recordings/`.
    var takeBytes: Int64 = 0

    /// Reference files — `Application Support/References/` (ADR 0167 phase 2). Small next to the
    /// audio, and listed anyway for the reason `storeBytes` is: a player comparing this screen
    /// against *iPhone Storage* and finding a gap cannot tell a missing category from a bug.
    var attachmentBytes: Int64 = 0

    /// The SwiftData store and its journal — everything *written* rather than recorded. Years of
    /// journal entries, every loop and its settings, the whole practice log.
    ///
    /// It is reported beside the audio even though it is a rounding error next to it, because the
    /// screen's job is to account for the app's whole footprint. A player comparing this against
    /// *iPhone Storage* and finding a gap has no way to tell a missing category from a bug.
    var storeBytes: Int64 = 0

    /// Everything the app is holding.
    var total: Int64 { songBytes + takeBytes + attachmentBytes + storeBytes }

    static let none = StorageUsage()

    /// The categories, in the order the screen lists them: biggest cause first, and the one a player
    /// can actually act on at the top.
    var breakdown: [(label: String, bytes: Int64)] {
        [("Songs", songBytes), ("Recordings", takeBytes), ("Reference files", attachmentBytes),
         ("Practice data", storeBytes)]
    }

    /// Measure all three directories. The only impure function on the type.
    ///
    /// A file whose size cannot be read counts as zero rather than failing the measurement — a
    /// storage figure that refuses to appear because one file is unreadable is worse than one that is
    /// a few kilobytes light.
    /// - Parameter storeURL: the SwiftData store's location, which only the caller knows — it comes
    ///   off the live `ModelContainer`'s configuration rather than being guessed at
    ///   `Application Support/default.store`, so this type stays free of SwiftData and a store moved
    ///   by a later configuration is still measured. `nil` reports no practice data rather than
    ///   inventing a path.
    static func measure(_ fileManager: FileManager = .default, storeURL: URL? = nil) -> StorageUsage {
        StorageUsage(
            songBytes: SongFileStore.filesOnDisk(fileManager)
                .reduce(into: 0) { $0 += SongFileStore.fileSize(fileName: $1, fileManager) ?? 0 },
            takeBytes: RecordingStore.filesOnDisk(fileManager)
                .reduce(into: 0) { $0 += RecordingStore.fileSize(fileName: $1, fileManager) ?? 0 },
            attachmentBytes: ReferenceAttachmentStore.filesOnDisk(fileManager)
                .reduce(into: 0) { $0 += ReferenceAttachmentStore.fileSize(fileName: $1, fileManager) ?? 0 },
            storeBytes: storeBytes(at: storeURL, fileManager)
        )
    }

    /// The store plus its write-ahead log and shared-memory sibling.
    ///
    /// The `-wal` file is not an implementation detail worth hiding: between checkpoints it can hold
    /// a real fraction of the database, and a figure that ignored it would drift from what the system
    /// reports for no reason a player could ever discover.
    static func storeBytes(at storeURL: URL?, _ fileManager: FileManager = .default) -> Int64 {
        guard let storeURL else { return 0 }
        let directory = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        return [name, name + "-wal", name + "-shm"]
            .map { directory.appending(path: $0, directoryHint: .notDirectory) }
            .reduce(into: 0) { total, url in
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                total += Int64(size ?? 0)
            }
    }

    /// The app's one byte formatter.
    ///
    /// `.file` count style, which is what the platform's own Storage screens use — so a player
    /// comparing Red Moon's number against *Settings ▸ General ▸ iPhone Storage* is comparing two
    /// figures computed the same way. Two screens already call `ByteCountFormatter` directly with
    /// exactly these arguments; ADR 0182 moves them onto this.
    static func formatted(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    /// The same figure with an "about" in front of it, for a size stated *before* the work that
    /// produces it. An export's zip is compressed by an amount nobody can predict from the inputs, so
    /// promising an exact number and then writing a different one is a small dishonesty that is easy
    /// to avoid.
    static func approximate(bytes: Int64) -> String {
        "About \(formatted(bytes: bytes))"
    }
}
