import Foundation

/// A finished export, and everything that has to be cleaned up afterwards (ADR 0181).
///
/// `workingDirectory` is the whole of it: the staging tree and the zip both live inside, so
/// `ArchiveWriter.cleanUp` is one `removeItem`. That matters more than it looks — a stranded export
/// is a second full-size copy of the library sitting in `tmp/`, and `tmp/` is not somewhere the
/// player can see or reclaim.
struct ExportedArchive: Sendable, Equatable {

    /// The zip to hand to the share sheet.
    let zipURL: URL

    /// Delete this and the export is gone, zip included.
    let workingDirectory: URL

    /// How many take files were staged.
    let takesWritten: Int

    /// Takes that `practice.json` names but whose audio was not on disk. Not an error — a take can
    /// outlive its file — but the count is worth saying out loud rather than exporting a silent gap.
    let takesMissing: [String]

    /// The zip's size once written. Stated after the fact, because compression is not predictable
    /// from the inputs.
    let byteCount: Int64
}

/// Turns a `PracticeArchive` into a zip on disk (ADR 0181).
///
/// The layout, which is the archive's real contract:
///
/// ```
/// red-moon-practice-2026-08-22/
///   practice.json
///   takes/
///     <recording-uid>.m4a
/// ```
///
/// `practice.json` names each take by `fileName`, and that name is the join to the file in `takes/`.
///
/// **`nonisolated` throughout.** Nothing here touches a model or the main actor: it takes the
/// `Sendable` value `ArchiveBuilder.snapshot` produced and does the slow half — encoding, staging,
/// zipping — wherever the caller runs it, which for a library of any size must not be the main thread.
///
/// **Zipping is Foundation's, not a dependency's.** `NSFileCoordinator`'s `.forUploading` read hands
/// back a zipped copy of a directory. Aptabase is this project's one third-party package and
/// `project.yml` pins it deliberately (ADR 0120); adding a zip library to save a dozen lines would
/// spend that restraint on nothing.
enum ArchiveWriter {

    /// The archive's folder and file stem. User-facing, so it says Red Moon.
    static let folderStem = "red-moon-practice"

    /// Date-only ISO-8601 in the **player's** time zone, for the folder name.
    ///
    /// GMT is the right default for a timestamp inside the file and the wrong one for a name a person
    /// reads: exporting at half past eleven at night should not produce an archive dated tomorrow.
    /// The precise instant is still in `practice.json`'s `exportedAt`, to the millisecond.
    nonisolated static var folderDateStyle: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
    }

    /// Write `archive` out as a zip.
    ///
    /// - Parameters:
    ///   - takesDirectory: where the take audio lives — `RecordingStore.directory()` in the app, a
    ///     throwaway container in tests. Takes are staged only when this is non-`nil` **and** the
    ///     archive says it includes them; the caller keeps those two in step.
    ///   - attachmentsDirectory: where reference pictures live — `ReferenceAttachmentStore.directory()` in the
    ///     app, a throwaway container in tests. `nil` stages none, which is what a caller that has no
    ///     container should do rather than guessing a path.
    ///   - temporaryDirectory: the parent to work in. Defaults to `tmp/`.
    /// - Returns: the zip, and the directory to delete when the share sheet is done with it.
    nonisolated static func write(_ archive: PracticeArchive,
                                  takesDirectory: URL?,
                                  attachmentsDirectory: URL? = nil,
                                  fileManager: FileManager = .default,
                                  temporaryDirectory: URL? = nil) throws -> ExportedArchive {
        let parent = temporaryDirectory ?? fileManager.temporaryDirectory
        let working = parent.appending(path: "RedMoonExport-\(UUID().uuidString)",
                                       directoryHint: .isDirectory)
        do {
            let folderName = "\(folderStem)-\(archive.exportedAt.formatted(folderDateStyle))"
            let root = working.appending(path: folderName, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

            try ArchiveBuilder.encode(archive)
                .write(to: root.appending(path: "practice.json", directoryHint: .notDirectory))

            var written = 0
            var missing: [String] = []
            if archive.includesTakeAudio, let takesDirectory {
                let staged = root.appending(path: "takes", directoryHint: .isDirectory)
                try fileManager.createDirectory(at: staged, withIntermediateDirectories: true)
                for take in archive.takes {
                    let source = takesDirectory.appending(path: take.fileName, directoryHint: .notDirectory)
                    let destination = staged.appending(path: take.fileName, directoryHint: .notDirectory)
                    if stage(from: source, to: destination, fileManager: fileManager) {
                        written += 1
                    } else {
                        missing.append(take.fileName)
                    }
                }
            }

            // Reference pictures, staged unconditionally — see `referenceAttachmentFileNames` for why they
            // are not behind the take-audio switch. A picture that has gone missing is skipped
            // silently rather than counted: `takesMissing` exists because losing a recording is
            // unrecoverable (ADR 0151 keeps a take's row for exactly that reason), while a reference
            // picture whose bytes are gone is a pointer that stopped resolving.
            let images = archive.referenceAttachmentFileNames
            if !images.isEmpty, let attachmentsDirectory {
                let staged = root.appending(path: "references", directoryHint: .isDirectory)
                try fileManager.createDirectory(at: staged, withIntermediateDirectories: true)
                for leaf in images {
                    _ = stage(from: attachmentsDirectory.appending(path: leaf, directoryHint: .notDirectory),
                              to: staged.appending(path: leaf, directoryHint: .notDirectory),
                              fileManager: fileManager)
                }
            }

            let zipURL = working.appending(path: "\(folderName).zip", directoryHint: .notDirectory)
            try zip(directory: root, to: zipURL, fileManager: fileManager)

            let size = (try? zipURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
            return ExportedArchive(zipURL: zipURL, workingDirectory: working,
                                   takesWritten: written, takesMissing: missing, byteCount: size)
        } catch {
            // A half-written export is still a full-size directory. Take it with us on the way out.
            try? fileManager.removeItem(at: working)
            throw error
        }
    }

    /// Delete an export and its staging tree. Idempotent, and deliberately non-throwing: nothing a
    /// caller could usefully do about a failure here, and a cleanup that can throw is a cleanup that
    /// gets skipped on the error path.
    nonisolated static func cleanUp(_ export: ExportedArchive, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: export.workingDirectory)
    }

    /// Put one take into the staging tree.
    ///
    /// **A hard link, not a copy.** A copy would double the recordings on disk before the zip is even
    /// written — on a library that is mostly audio, that is the difference between an export that
    /// works on a full phone and one that doesn't. Both paths are inside the app container and
    /// therefore on one volume, which is the condition `linkItem` needs. The copy stays as a fallback
    /// for the case where it isn't.
    ///
    /// - Returns: whether the file was staged. `false` means the source was not there.
    private nonisolated static func stage(from source: URL, to destination: URL,
                                          fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: source.path) else { return false }
        do {
            try fileManager.linkItem(at: source, to: destination)
            return true
        } catch {
            return (try? fileManager.copyItem(at: source, to: destination)) != nil
        }
    }

    /// Zip a directory using Foundation alone.
    ///
    /// The zip `NSFileCoordinator` hands back is only guaranteed to exist for the length of the
    /// accessor block, so the copy out has to happen inside it. Both errors are carried out rather
    /// than thrown from the block, because the accessor cannot throw.
    private nonisolated static func zip(directory: URL, to destination: URL,
                                        fileManager: FileManager) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading,
                                       error: &coordinationError) { zipped in
            do { try fileManager.copyItem(at: zipped, to: destination) } catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }
}
