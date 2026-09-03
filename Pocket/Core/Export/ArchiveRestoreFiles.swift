import Foundation

/// Writing an archive's files back onto disk — **after** their rows exist (ADR 0188 D7).
///
/// ADR 0182's `OrphanSweep.run` builds its referenced set from every row in the store, so a file
/// written into `Recordings/` or `References/` before its row exists is, for that window, an orphan by
/// the sweep's own definition — and *Reclaim space* is a button the player can press at any moment.
/// The ordering is therefore not a preference: `RestoreCoordinator` inserts and saves the rows, and
/// only then calls this.
///
/// `nonisolated`, and it takes plain `[String: ZipEntry]` rather than the model graph, so inflating
/// and writing a library's worth of take audio happens off the main actor while the rows it belongs to
/// are already safely in the store.
enum ArchiveRestoreFiles {

    /// What a file pass actually did.
    struct Outcome: Sendable, Equatable {
        /// Files written.
        var written: [String] = []
        /// Files already on disk, left alone.
        var skipped: [String] = []
        /// Files whose bytes would not come out of the zip, or would not write.
        var failed: [String] = []

        var isClean: Bool { failed.isEmpty }
    }

    /// Write take audio and reference pictures out of `zip`.
    ///
    /// - Parameters:
    ///   - takes: entries to write into `takesDirectory`, keyed by leaf name.
    ///   - attachments: entries to write into `attachmentsDirectory`, keyed by leaf name.
    ///   - takesDirectory: `RecordingStore.directory()` in the app, a throwaway container in tests.
    ///     `nil` writes none, which is what a caller with no container should do rather than guessing.
    nonisolated static func write(takes: [String: ZipEntry],
                                  attachments: [String: ZipEntry],
                                  from zip: ZipArchiveReader,
                                  takesDirectory: URL?,
                                  attachmentsDirectory: URL?,
                                  fileManager: FileManager = .default) -> Outcome {
        var outcome = Outcome()
        write(takes, into: takesDirectory, from: zip, fileManager: fileManager, outcome: &outcome)
        write(attachments, into: attachmentsDirectory, from: zip, fileManager: fileManager, outcome: &outcome)
        return outcome
    }

    /// One directory's worth.
    ///
    /// **An existing file is never overwritten.** A leaf name is `<uid>.<ext>` in both directories, so
    /// a name already on disk is the same row's own audio — either from an earlier restore of this
    /// archive or because the row was never gone. Overwriting would spend the time to reproduce a file
    /// that is already there, and would do it by truncating the real one first: the failure mode is a
    /// take destroyed by the operation that was restoring it.
    private nonisolated static func write(_ entries: [String: ZipEntry],
                                          into directory: URL?,
                                          from zip: ZipArchiveReader,
                                          fileManager: FileManager,
                                          outcome: inout Outcome) {
        guard let directory, !entries.isEmpty else { return }
        guard (try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            outcome.failed.append(contentsOf: entries.keys.sorted())
            return
        }

        for name in entries.keys.sorted() {
            guard let entry = entries[name] else { continue }
            // The leaf is used as a path component, so it is checked here as well as at the reader.
            // `ZipArchiveReader` already rejects a traversal path, and this is the second lock on the
            // one operation in a restore that writes somewhere the player did not name.
            guard isSafeLeaf(name) else {
                outcome.failed.append(name)
                continue
            }
            let destination = directory.appending(path: name, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: destination.path) {
                outcome.skipped.append(name)
                continue
            }
            do {
                try zip.data(for: entry).write(to: destination, options: .atomic)
                outcome.written.append(name)
            } catch {
                outcome.failed.append(name)
            }
        }
    }

    /// Whether a name is a plain leaf rather than a path.
    ///
    /// `appending(path:)` would happily interpret a `/` in a name as a directory separator, so a name
    /// that survived the reader by being relative and harmless-looking still has to be one component
    /// before it becomes a file.
    private nonisolated static func isSafeLeaf(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".."
            && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
    }
}
