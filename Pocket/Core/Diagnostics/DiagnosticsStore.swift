import Foundation

/// Where the last few `DiagnosticEvent`s live between launches (ADR 0183).
///
/// A small JSON file in Application Support, beside `Songs/` and `Recordings/` — the app's two other
/// owned-file directories (ADR 0069 §5, ADR 0148). Shaped like `SongFileStore`: a `directory` created
/// on first access, `FileManager` injected so every path can be exercised against a throwaway
/// container rather than the real one.
///
/// **Held out of backup, unconditionally.** ADR 0182 made the songs exclusion a *choice* because a
/// song copy is something the player would miss on a restored phone. Nobody misses a crash report: it
/// describes a build that is about to be replaced, and restoring it onto a new device would attach
/// the old phone's crashes to the new one's support message. So this one is not a setting, and does
/// not appear on the Storage screen's toggle.
enum DiagnosticsStore {

    /// Subdirectory of Application Support that holds the diagnostics file.
    static let directoryName = "Diagnostics"

    /// The one file in it.
    static let fileName = "events.json"

    /// The diagnostics directory, created and excluded from backup on first access.
    ///
    /// The exclusion is applied on **every** call rather than once at creation: a directory restored
    /// from an older backup arrives without the resource value, and a write that silently failed
    /// leaves no trace to notice later. It is a cheap idempotent write.
    static func directory(_ fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        var dir = base.appending(path: directoryName, directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }

    /// The events file's URL.
    static func url(_ fileManager: FileManager = .default) throws -> URL {
        try directory(fileManager).appending(path: fileName, directoryHint: .notDirectory)
    }

    /// The stored events, already put through `DiagnosticSummary.keeping` — so a file written by a
    /// build with different retention rules still presents under this build's, and nothing migrates.
    ///
    /// **Every failure returns an empty array.** A missing file is the normal case on first launch,
    /// and a corrupt one is not worth a second thought: these are disposable notes about crashes,
    /// and throwing from the diagnostics reader would be a crash in the crash reporter.
    static func load(now: Date = .now, _ fileManager: FileManager = .default) -> [DiagnosticEvent] {
        guard let fileURL = try? url(fileManager),
              let data = fileManager.contents(atPath: fileURL.path),
              let events = try? JSONDecoder().decode([DiagnosticEvent].self, from: data) else {
            return []
        }
        return DiagnosticSummary.keeping(events, now: now)
    }

    /// Write the events, capped on the way out so the file cannot grow past what is kept.
    ///
    /// Returns what was written, so the caller holds exactly what is on disk rather than its own
    /// longer idea of the same list.
    @discardableResult
    static func save(_ events: [DiagnosticEvent], now: Date = .now,
                     _ fileManager: FileManager = .default) -> [DiagnosticEvent] {
        let kept = DiagnosticSummary.keeping(events, now: now)
        guard let fileURL = try? url(fileManager), let data = try? JSONEncoder().encode(kept) else {
            return kept
        }
        try? data.write(to: fileURL, options: .atomic)
        return kept
    }

    /// Delete the file. The *Clear* button on the diagnostics screen, and the only way a player can
    /// take back a report that has not been sent.
    static func clear(_ fileManager: FileManager = .default) {
        guard let fileURL = try? url(fileManager) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    // Dates use `JSONCoder`'s **default** strategy — a `Double` — and deliberately not the ISO 8601
    // strings ADR 0181's archive uses.
    //
    // This is an internal cache nobody reads but the app; the archive is an interchange format a
    // person opens on a Mac, and legibility is worth a rounding there. Here it is worth nothing and
    // costs the one property this file needs: an **exact** round trip. `Date.ISO8601FormatStyle`
    // with fractional seconds still quantises to the millisecond, which is enough to fail a
    // whole-value equality check — and the failure reads as "x is not equal to x", because both
    // sides print to the second. A `Double` in and the same `Double` out has no such gap.
}
