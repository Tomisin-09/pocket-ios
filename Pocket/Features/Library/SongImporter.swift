import Foundation
import SwiftData

/// Imports a DRM-free local/iCloud audio file into the library (ADR 0011 Slice 2,
/// ADR 0001). Takes a **security-scoped bookmark** for durable access across
/// launches, extracts the waveform up front (`WaveformExtractor`), and persists a
/// `Song`. The title defaults to the file name — the rest is filled in later.
enum SongImporter {

    enum ImportError: Error { case accessDenied }

    /// A display title from the file name, extension dropped. Falls back to a
    /// generic label when the name is empty.
    static func title(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty || name == "/" ? "Untitled song" : name
    }

    /// Resolve a picked file URL into a persisted `Song`: take a bookmark, extract
    /// its waveform, and insert it into `context`. The picked URL is accessed under
    /// its security scope only for the duration of this call; the bookmark is what
    /// grants access later (resolved in `WaveformPracticeModel`).
    @MainActor
    @discardableResult
    static func importSong(from url: URL, into context: ModelContext) throws -> Song {
        guard url.startAccessingSecurityScopedResource() else { throw ImportError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        // iOS document-picker URLs produce a security-scoped bookmark with default
        // options (the macOS-only `.withSecurityScope` option must NOT be passed here).
        let bookmark = try url.bookmarkData()
        let (duration, amplitudes) = try WaveformExtractor.extract(from: url)
        let song = Song(title: title(for: url), duration: duration,
                        amplitudes: amplitudes, ref: .localFile(bookmark: bookmark))
        context.insert(song)
        return song
    }
}
