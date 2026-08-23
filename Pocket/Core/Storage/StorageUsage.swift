import Foundation

/// What Red Moon is holding on disk, in bytes (ADR 0182).
///
/// The app owns two directories of full-size audio — `Songs/` (ADR 0148) and `Recordings/`
/// (ADR 0069) — and until now had no way to say how big either was. ADR 0148 §8 put it plainly:
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

    /// Everything the app owns that a player would recognise as theirs.
    ///
    /// The SwiftData store itself is deliberately not in here yet: it is a fraction of the audio and
    /// ADR 0182 is where it gets measured and explained. A total that quietly folded it in would be a
    /// number nobody could reconcile against anything.
    var total: Int64 { songBytes + takeBytes }

    static let none = StorageUsage()

    /// Measure both directories. The only impure function on the type.
    ///
    /// A file whose size cannot be read counts as zero rather than failing the measurement — a
    /// storage figure that refuses to appear because one file is unreadable is worse than one that is
    /// a few kilobytes light.
    static func measure(_ fileManager: FileManager = .default) -> StorageUsage {
        StorageUsage(
            songBytes: SongFileStore.filesOnDisk(fileManager)
                .reduce(into: 0) { $0 += SongFileStore.fileSize(fileName: $1, fileManager) ?? 0 },
            takeBytes: RecordingStore.filesOnDisk(fileManager)
                .reduce(into: 0) { $0 += RecordingStore.fileSize(fileName: $1, fileManager) ?? 0 }
        )
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
