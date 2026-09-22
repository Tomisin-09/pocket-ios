import Foundation
import SwiftData

/// Imports DRM-free local/iCloud audio files into the library (ADR 0011 Slice 2,
/// ADR 0001). The work is split so a batch import (multi-select) never freezes the
/// UI: `prepare` does the expensive, background-safe decode (security-scoped
/// bookmark + `WaveformExtractor`), and `persist` does the fast, `@MainActor`
/// SwiftData insert. `importSong` composes both for the single-file path.
enum SongImporter {

    enum ImportError: Error {
        case accessDenied
        /// The bundled starter track is not in the app bundle (ADR 0219) — only reachable by
        /// dropping the resource from the target, and reported rather than trapped so a broken
        /// build degrades to "no starter track" instead of a crash on first launch.
        case starterTrackMissing
    }

    /// Everything a `Song` needs, extracted off the main actor so the insert on the
    /// main actor is cheap. `Sendable` so it can cross the `Task.detached` boundary.
    struct Prepared: Sendable {
        let title: String
        let duration: TimeInterval
        let amplitudes: [Double]
        /// Security-scoped bookmark for a picked file. **`nil` for the bundled starter track**
        /// (ADR 0219): a bookmark into the app bundle resolves to a path that moves on every app
        /// update, and the track does not need one — it always has an owned copy, which
        /// `SongAudioResolver.resolve` prefers over a bookmark anyway.
        let bookmark: Data?
        /// Identity assigned here rather than in `persist`, because the copy on disk is named
        /// after it and the two have to agree.
        let sourceID: String
        /// Leaf name of Pocket's own copy (ADR 0148 §1), or `nil` if the copy failed — the song
        /// still imports and still plays, it just falls back to the bookmark like a pre-0148 one.
        let audioFileName: String?
    }

    /// A display title from the file name, extension dropped. Falls back to a
    /// generic label when the name is empty.
    static func title(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty || name == "/" ? "Untitled song" : name
    }

    /// Resolve a picked file URL into the data a `Song` needs — copy the file into Pocket's own
    /// container (ADR 0148), take a security-scoped bookmark as provenance and legacy fallback,
    /// and extract the waveform. This is the expensive step (full-file decode) and touches no
    /// model context, so it is safe to run off the main actor. The picked URL is accessed under
    /// its security scope only for the duration of this call — which is why the copy belongs
    /// here, at the one moment the file is guaranteed readable.
    static func prepare(from url: URL) throws -> Prepared {
        guard url.startAccessingSecurityScopedResource() else { throw ImportError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        // iOS document-picker URLs produce a security-scoped bookmark with default
        // options (the macOS-only `.withSecurityScope` option must NOT be passed here).
        let bookmark = try url.bookmarkData()
        let sourceID = UUID().uuidString
        // A failed copy must not fail the import: a song that plays via its bookmark is worth
        // more than no song, and `SongAudioResolver.adoptIfNeeded` will retry on a later open.
        let audioFileName = try? SongFileStore.adopt(contentsOf: url, sourceID: sourceID)
        let (duration, amplitudes) = try WaveformExtractor.extract(from: url)
        return Prepared(title: title(for: url), duration: duration,
                        amplitudes: amplitudes, bookmark: bookmark,
                        sourceID: sourceID, audioFileName: audioFileName)
    }

    /// Insert a prepared import as a `Song`. Cheap and `@MainActor` — the decode
    /// already happened in `prepare`.
    @MainActor
    @discardableResult
    static func persist(_ prepared: Prepared, into context: ModelContext) -> Song {
        let song = Song(title: prepared.title, duration: prepared.duration,
                        amplitudes: prepared.amplitudes, dateAdded: .now,
                        ref: SongRef(id: prepared.sourceID, source: .localFile,
                                     bookmark: prepared.bookmark),
                        audioFileName: prepared.audioFileName)
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

    // MARK: - The starter track (ADR 0219)

    /// Resolve the bundled starter track into the data a `Song` needs.
    ///
    /// **A sibling of `prepare` rather than a caller of it**, for exactly one reason: `prepare`
    /// opens a security scope, and a file inside our own bundle has none —
    /// `startAccessingSecurityScopedResource()` returns `false` for it, so routing the starter
    /// track through `prepare` would throw `.accessDenied` every time. Everything after that guard
    /// is shared: the same `SongFileStore.adopt`, the same `WaveformExtractor`, the same owned copy
    /// the resolver prefers. **There is no second audio path here**, which is precisely what ADR
    /// 0148 §7 objected to when it dropped the bundled song — the objection does not survive the
    /// file being adopted like any other import.
    ///
    /// The copy is *not* optional the way it is in `prepare`. A picked file that fails to copy
    /// still plays from its bookmark, so the import is worth keeping; the starter track has no
    /// bookmark to fall back on, so a failed copy means a song that cannot play and the throw is
    /// the honest answer.
    ///
    /// Expensive (a full-file decode) and touches no model context, so call it off the main actor.
    static func prepareStarterTrack() throws -> Prepared {
        guard let url = StarterTrack.bundledURL else { throw ImportError.starterTrackMissing }
        let audioFileName = try SongFileStore.adopt(contentsOf: url,
                                                    sourceID: StarterTrack.sourceID)
        let (duration, amplitudes) = try WaveformExtractor.extract(from: url)
        return Prepared(title: StarterTrack.title, duration: duration,
                        amplitudes: amplitudes, bookmark: nil,
                        sourceID: StarterTrack.sourceID, audioFileName: audioFileName)
    }

    /// Insert the starter track, carrying the metadata `persist` doesn't take.
    ///
    /// The extra fields are set after the insert rather than by widening `persist`'s signature:
    /// every other import learns its artist and key from the player, and a `persist` that took
    /// eight optional arguments to serve one caller would make the common path worse to read.
    ///
    /// **The caller is responsible for not calling this twice** — `HomeFeed.shouldOfferStarterTrack`
    /// is that check. Nothing here dedupes, because deduping needs a fetch and this deliberately
    /// stays a plain insert.
    @MainActor
    @discardableResult
    static func importStarterTrack(_ prepared: Prepared, into context: ModelContext) -> Song {
        let song = persist(prepared, into: context)
        song.artist = StarterTrack.artist
        song.genre = StarterTrack.genre
        song.key = StarterTrack.key
        song.bpm = StarterTrack.bpm
        return song
    }
}
