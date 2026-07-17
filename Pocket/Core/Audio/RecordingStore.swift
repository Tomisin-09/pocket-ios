import Foundation

/// On-disk home for practice-take audio (ADR 0069 §5). Takes are **app-authored** files the app
/// owns in its container (`Application Support/Recordings/`), unlike songs (bookmarks to files in
/// place). The `Recording` model stores only the leaf `fileName`; this resolves it to a `URL`,
/// and owns the delete / size / orphan-sweep story that keeps disk use honest.
///
/// `FileManager` is injectable so the pure derivations and the orphan sweep can be unit-tested
/// without a real container.
enum RecordingStore {

    /// Subdirectory of Application Support that holds take files.
    static let directoryName = "Recordings"

    /// The recordings directory, created on first access. Application Support (not Documents) —
    /// these are app-managed artifacts, not user-facing documents.
    static func directory(_ fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        let dir = base.appending(path: directoryName, directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Leaf filename for a take's `uid` — AAC in an `.m4a` container. Pure; the row and its file
    /// share one identity (`Recording.uid`).
    static func fileName(for uid: UUID) -> String { "\(uid.uuidString).m4a" }

    /// Resolve a stored `fileName` to its on-disk `URL`.
    static func url(for fileName: String, _ fileManager: FileManager = .default) throws -> URL {
        try directory(fileManager).appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Delete a take's file if present (idempotent — a missing file is not an error).
    static func delete(fileName: String, _ fileManager: FileManager = .default) throws {
        let fileURL = try url(for: fileName, fileManager)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// File size in bytes for a per-take size hint, or `nil` if it can't be read.
    static func fileSize(fileName: String, _ fileManager: FileManager = .default) -> Int64? {
        guard let fileURL = try? url(for: fileName, fileManager),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return Int64(size)
    }

    /// The take files currently on disk (`.m4a` leaves only).
    static func filesOnDisk(_ fileManager: FileManager = .default) -> [String] {
        guard let dir = try? directory(fileManager),
              let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.filter { $0.hasSuffix(".m4a") }
    }

    /// **Pure** retention sweep: files on disk not referenced by any surviving `Recording` — safe
    /// to delete. Orphans arise when a take's model row is deleted but its file lingers, or an
    /// interrupted write leaves a stray file (ADR 0069 retention story).
    static func orphanedFiles(onDisk: [String], referenced: Set<String>) -> [String] {
        onDisk.filter { !referenced.contains($0) }
    }
}
