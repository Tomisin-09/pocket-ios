import Foundation
import SwiftData

/// Imports DRM-free local/iCloud audio files into the library (ADR 0011 Slice 2,
/// ADR 0001). The work is split so a batch import (multi-select) never freezes the
/// UI: `prepare` does the expensive, background-safe decode (security-scoped
/// bookmark + `WaveformExtractor`), and `persist` does the fast, `@MainActor`
/// SwiftData insert. `importSong` composes both for the single-file path.
enum SongImporter {

    enum ImportError: Error { case accessDenied }

    /// Everything a `Song` needs, extracted off the main actor so the insert on the
    /// main actor is cheap. `Sendable` so it can cross the `Task.detached` boundary.
    struct Prepared: Sendable {
        let title: String
        let duration: TimeInterval
        let amplitudes: [Double]
        let bookmark: Data
    }

    /// A display title from the file name, extension dropped. Falls back to a
    /// generic label when the name is empty.
    static func title(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty || name == "/" ? "Untitled song" : name
    }

    /// Resolve a picked file URL into the data a `Song` needs — take a
    /// security-scoped bookmark (durable access across launches, resolved later in
    /// `WaveformPracticeModel`) and extract the waveform. This is the expensive step
    /// (full-file decode) and touches no model context, so it is safe to run off the
    /// main actor. The picked URL is accessed under its security scope only for the
    /// duration of this call.
    static func prepare(from url: URL) throws -> Prepared {
        guard url.startAccessingSecurityScopedResource() else { throw ImportError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        // iOS document-picker URLs produce a security-scoped bookmark with default
        // options (the macOS-only `.withSecurityScope` option must NOT be passed here).
        let bookmark = try url.bookmarkData()
        let (duration, amplitudes) = try WaveformExtractor.extract(from: url)
        return Prepared(title: title(for: url), duration: duration,
                        amplitudes: amplitudes, bookmark: bookmark)
    }

    /// Insert a prepared import as a `Song`. Cheap and `@MainActor` — the decode
    /// already happened in `prepare`.
    @MainActor
    @discardableResult
    static func persist(_ prepared: Prepared, into context: ModelContext) -> Song {
        let song = Song(title: prepared.title, duration: prepared.duration,
                        amplitudes: prepared.amplitudes, dateAdded: .now,
                        ref: .localFile(bookmark: prepared.bookmark))
        context.insert(song)
        return song
    }

    /// Single-file convenience: prepare then persist. The title defaults to the file
    /// name — the rest is filled in later.
    @MainActor
    @discardableResult
    static func importSong(from url: URL, into context: ModelContext) throws -> Song {
        persist(try prepare(from: url), into: context)
    }
}
