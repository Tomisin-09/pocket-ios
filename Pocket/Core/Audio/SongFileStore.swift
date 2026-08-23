import Foundation

/// On-disk home for imported song audio (ADR 0148). Songs used to be security-scoped bookmarks to
/// files *in place*; a bookmark encodes access granted to one installation, so deleting and
/// reinstalling the app — including the way iOS "restores" one from a backup — leaves a perfectly
/// intact library that plays nothing. Pocket now keeps its own copy, which rides along in the app
/// container and therefore in every device backup.
///
/// Deliberately shaped like `RecordingStore` (ADR 0069 §5), the app's other owned-files store:
/// `Application Support` rather than `Documents` (app-managed artefacts, not user documents), the
/// model stores only the leaf `fileName`, and `FileManager` is injected so the pure derivations and
/// the orphan sweep can be unit-tested without a real container.
enum SongFileStore {

    /// Subdirectory of Application Support that holds imported song files.
    static let directoryName = "Songs"

    /// The songs directory, created on first access.
    static func directory(_ fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        let dir = base.appending(path: directoryName, directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Leaf filename for a song's `sourceID`. Pure. The **source extension is preserved** — the
    /// decoder picks a parser by extension, so flattening everything to one suffix would break
    /// formats that `WaveformExtractor` reads happily today. An extension-less source keeps the
    /// bare id rather than inventing a format it isn't.
    static func fileName(for sourceID: String, sourceExtension: String) -> String {
        sourceExtension.isEmpty ? sourceID : "\(sourceID).\(sourceExtension)"
    }

    /// Resolve a stored `fileName` to its on-disk `URL`.
    static func url(for fileName: String, _ fileManager: FileManager = .default) throws -> URL {
        try directory(fileManager).appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Whether a stored `fileName` still has a file behind it — the test that decides whether the
    /// owned copy or the legacy bookmark is used.
    static func exists(fileName: String, _ fileManager: FileManager = .default) -> Bool {
        guard let fileURL = try? url(for: fileName, fileManager) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Copy a picked file into the container and return its leaf name.
    ///
    /// The caller is responsible for holding the source's security scope open — at import that is
    /// `SongImporter.prepare`, which already has the file open to extract the waveform. Any existing
    /// file for this `sourceID` is replaced, so a re-import or a relink overwrites rather than
    /// accumulating.
    @discardableResult
    static func adopt(contentsOf source: URL, sourceID: String,
                      _ fileManager: FileManager = .default) throws -> String {
        let leaf = fileName(for: sourceID, sourceExtension: source.pathExtension)
        let destination = try url(for: leaf, fileManager)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
        return leaf
    }

    /// Delete a song's copy if present (idempotent — a missing file is not an error).
    static func delete(fileName: String, _ fileManager: FileManager = .default) throws {
        let fileURL = try url(for: fileName, fileManager)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// File size in bytes for a per-song size hint, or `nil` if it can't be read.
    static func fileSize(fileName: String, _ fileManager: FileManager = .default) -> Int64? {
        guard let fileURL = try? url(for: fileName, fileManager),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return Int64(size)
    }

    /// The song files currently on disk.
    static func filesOnDisk(_ fileManager: FileManager = .default) -> [String] {
        guard let dir = try? directory(fileManager),
              let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names
    }

    /// Whether the songs directory is currently held out of iCloud/iTunes backup (ADR 0182).
    ///
    /// Read back from the filesystem rather than from the preference that set it: the two can
    /// disagree — a restore, a reinstall, or a write that silently failed — and the disk is the one
    /// that decides whether a backup carries the audio.
    static func isExcludedFromBackup(_ fileManager: FileManager = .default) -> Bool {
        guard let dir = try? directory(fileManager),
              let values = try? dir.resourceValues(forKeys: [.isExcludedFromBackupKey]) else {
            return false
        }
        return values.isExcludedFromBackup ?? false
    }

    /// Hold the songs directory in or out of device backup (ADR 0182 amending ADR 0148).
    ///
    /// **Songs only, never takes.** A song's audio came from a file the player still has somewhere
    /// and can point Red Moon at again; a take has no source to regenerate from, which is why
    /// `Song.recordings` nullifies rather than cascades (ADR 0151). Excluding recordings would be
    /// offering to lose the one thing that cannot be replaced.
    ///
    /// The resource value is set on the **directory**, so it covers every song copy including ones
    /// imported later — setting it per file would leave every subsequent import in the backup and
    /// make the setting quietly untrue.
    static func setExcludedFromBackup(_ excluded: Bool, _ fileManager: FileManager = .default) throws {
        var dir = try directory(fileManager)
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try dir.setResourceValues(values)
    }

    /// **Pure** retention sweep: files on disk not referenced by any surviving `Song` — safe to
    /// delete. Orphans arise when a song row is deleted but its copy lingers, or an interrupted
    /// copy leaves a stray file (ADR 0148 §8).
    static func orphanedFiles(onDisk: [String], referenced: Set<String>) -> [String] {
        onDisk.filter { !referenced.contains($0) }
    }
}
