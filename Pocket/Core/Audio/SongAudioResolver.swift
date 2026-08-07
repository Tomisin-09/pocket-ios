import Foundation
import SwiftData

/// Where a song's audio actually is, and whatever has to stay alive to keep reading it.
struct ResolvedSongAudio {
    let url: URL
    /// Non-`nil` only for a legacy in-place file, which must be held open under its security
    /// scope for the engine's lazy reads. A copy Pocket owns sits inside our own container and
    /// needs no scope at all — the caller stores this regardless and lets it deallocate.
    let access: SecurityScopedAccess?
    /// `true` when this resolved through the legacy bookmark, meaning the song has no copy yet
    /// and `adoptIfNeeded` has work to do.
    let isLegacyBookmark: Bool
}

/// Finds a song's audio (ADR 0148 §2), in one place.
///
/// Three practice surfaces — the waveform screen, the loop run and the song play-along — each
/// carried their own `loadImportedFile`, and they had already drifted: only two of the three
/// re-minted a stale bookmark, so whether a song survived an iCloud eviction depended on which
/// screen you happened to open it from. Resolution order lives here now, once.
enum SongAudioResolver {

    /// Resolve a song's audio: the copy Pocket owns first, the legacy bookmark second.
    ///
    /// Returns `nil` when neither works — the file was moved or deleted before it was ever copied
    /// in, or the app was reinstalled and the bookmark died with the old installation. That is the
    /// case `AudioUnavailableNotice` reports, and the one relink exists to repair.
    /// `fileManager` is injected for the same reason `SongFileStore`'s is: the preference order
    /// below — an owned copy beats a bookmark, even a **dead** bookmark — is the whole point of
    /// ADR 0148, and it should be pinned by a test rather than only observed on a device.
    static func resolve(_ song: Song, _ fileManager: FileManager = .default) -> ResolvedSongAudio? {
        if let leaf = song.audioFileName,
           SongFileStore.exists(fileName: leaf, fileManager),
           let owned = try? SongFileStore.url(for: leaf, fileManager) {
            return ResolvedSongAudio(url: owned, access: nil, isLegacyBookmark: false)
        }

        guard let bookmark = song.bookmark else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              let access = SecurityScopedAccess(url) else { return nil }
        if isStale { refreshStaleBookmark(song: song, url: url) }
        return ResolvedSongAudio(url: url, access: access, isLegacyBookmark: true)
    }

    /// Copy a pre-0148 song's file into the container the first time it resolves, so the *next*
    /// launch takes the owned-copy path (ADR 0148 §3).
    ///
    /// This is the migration, and it is deliberately opportunistic rather than a schema-versioned
    /// pass: it runs only when the file is provably reachable, which is the only moment the copy
    /// can be made at all. A failure is logged and leaves the working bookmark untouched — the song
    /// keeps playing exactly as it did, and the next launch tries again.
    ///
    /// Must be called with `resolved.access` still alive; the source is only readable inside that
    /// security scope.
    @MainActor
    static func adoptIfNeeded(_ song: Song, resolved: ResolvedSongAudio,
                              _ fileManager: FileManager = .default) {
        guard resolved.isLegacyBookmark, song.audioFileName == nil else { return }
        do {
            song.audioFileName = try SongFileStore.adopt(contentsOf: resolved.url,
                                                         sourceID: song.sourceID, fileManager)
            try song.modelContext?.save()
        } catch {
            let reason = error.localizedDescription
            AudioPlumbing.log.error("Song adopt: copy failed for \(song.sourceID, privacy: .public): \(reason)")
        }
    }

    /// A resolved-but-**stale** bookmark still opens today but may stop resolving after the next
    /// file move / iCloud eviction — re-mint it from the live URL while we can. Safe by design:
    /// `SongRef` equality excludes the bookmark, so the song's loops/markers are untouched. A
    /// failed refresh keeps the old (still-working) bookmark and just logs.
    private static func refreshStaleBookmark(song: Song, url: URL) {
        do {
            song.bookmark = try url.bookmarkData()
            try song.modelContext?.save()
        } catch {
            let reason = error.localizedDescription
            AudioPlumbing.log.error("Song resolve: stale bookmark refresh failed: \(reason)")
        }
    }
}
