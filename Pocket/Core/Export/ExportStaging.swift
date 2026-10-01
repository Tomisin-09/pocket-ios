import Foundation

/// Where a file waits while the share sheet hands it on (ADR 0236 D2, D3).
///
/// The receiver sees the shared URL's last component as the file's name. The files the app keeps are
/// named for their uids (`RecordingStore`, `SongFileStore`), which is right for the store and means
/// nothing to anyone else, so each export gets a folder of its own in `tmp/` and the file goes in under
/// the name it should arrive with. The kept file is never renamed or moved.
///
/// **A hard link, not a copy, where the volume allows it** — `ArchiveWriter.stage` makes the same call
/// for the same reason (ADR 0181 D5): a song is megabytes, and a link costs none of them. Both paths are
/// inside the app container, so the link is the case that happens. The copy is the fallback.
///
/// The system says nothing when a share has finished reading a file, so nothing here can delete its
/// own folder on time. Each export sweeps the folders left by earlier ones instead, once they are a day
/// old: long enough for any share that is still running, and a hard link holds no space meanwhile.
enum ExportStaging {

    /// The folder in `tmp/` that every export is staged under.
    static let outboxName = "RedMoonOutbox"

    /// How long a staged export is left before a later one sweeps it.
    static let keepFor: TimeInterval = 24 * 60 * 60

    /// Stage `source` under `fileName`, and return where it now is.
    ///
    /// - Parameters:
    ///   - fileName: the name the receiver sees, extension included. Already made safe by
    ///     `fileName(stem:fileExtension:)`.
    ///   - temporaryDirectory: the parent of the outbox. Defaults to `tmp/`; tests pass a throwaway.
    ///   - now: the clock the sweep reads, so a test can age a folder without waiting a day.
    nonisolated static func stage(_ source: URL, as fileName: String,
                                  fileManager: FileManager = .default,
                                  temporaryDirectory: URL? = nil,
                                  now: Date = .now) throws -> URL {
        let destination = try freshPlace(for: fileName, fileManager: fileManager,
                                         temporaryDirectory: temporaryDirectory, now: now)
        do {
            try fileManager.linkItem(at: source, to: destination)
        } catch {
            try fileManager.copyItem(at: source, to: destination)
        }
        return destination
    }

    /// Write a file made for the export (a tab's text or PDF, ADR 0236 D9) under `fileName`, and return
    /// where it is. Swept with the rest.
    nonisolated static func write(_ data: Data, as fileName: String,
                                  fileManager: FileManager = .default,
                                  temporaryDirectory: URL? = nil,
                                  now: Date = .now) throws -> URL {
        let destination = try freshPlace(for: fileName, fileManager: fileManager,
                                         temporaryDirectory: temporaryDirectory, now: now)
        try data.write(to: destination)
        return destination
    }

    /// A new folder in the outbox, after sweeping the old ones, and the path for `fileName` inside it.
    private nonisolated static func freshPlace(for fileName: String, fileManager: FileManager,
                                               temporaryDirectory: URL?, now: Date) throws -> URL {
        try freshFolder(fileManager: fileManager, temporaryDirectory: temporaryDirectory, now: now)
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    /// A new, empty folder in the outbox, after sweeping the old ones. The practice pack is built in one
    /// (ADR 0236 D8).
    nonisolated static func freshFolder(fileManager: FileManager = .default, temporaryDirectory: URL? = nil,
                                        now: Date = .now) throws -> URL {
        let outbox = (temporaryDirectory ?? fileManager.temporaryDirectory)
            .appending(path: outboxName, directoryHint: .isDirectory)
        sweep(outbox, before: now.addingTimeInterval(-keepFor), fileManager: fileManager)

        let folder = outbox.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// A file name from a stem and an extension, safe to hand to any file system the share sheet
    /// might write it to.
    ///
    /// Unlike `SharedPracticeFile.fileName(for:)`, this keeps the words as the player wrote them,
    /// spaces and `·` included: *Slow Bend · Chorus · 1 Oct 2026.m4a* is the point of D2, and a
    /// hyphenated `Slow-Bend-Chorus` is not a name anyone would give it. So only what a file system
    /// refuses or misreads is replaced: path separators, the colon (a separator to the Finder), and
    /// control characters. A leading dot would hide the file, so leading dots go too.
    ///
    /// Capped at 200 UTF-8 bytes before the extension, inside the 255 most file systems allow, by
    /// dropping whole characters from the end, so a long title can't cost the file its extension.
    nonisolated static func fileName(stem: String, fileExtension: String, fallback: String = "Red Moon") -> String {
        let refused = CharacterSet(charactersIn: "/\\:").union(.controlCharacters).union(.newlines)
        var cleaned = String(String.UnicodeScalarView(stem.unicodeScalars.map { refused.contains($0) ? "-" : $0 }))
            .trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        while cleaned.utf8.count > 200 { cleaned.removeLast() }
        let name = cleaned.trimmingCharacters(in: .whitespaces)
        let base = name.isEmpty ? fallback : name
        return fileExtension.isEmpty ? base : "\(base).\(fileExtension)"
    }

    /// Remove every staged export made before `cutoff`. Best effort: a folder that can't be read or
    /// removed is left for the next sweep, and the export that called this goes ahead regardless.
    nonisolated static func sweep(_ outbox: URL, before cutoff: Date, fileManager: FileManager) {
        guard let folders = try? fileManager.contentsOfDirectory(
            at: outbox, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for folder in folders {
            let made = (try? folder.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let made, made < cutoff {
                try? fileManager.removeItem(at: folder)
            }
        }
    }
}
