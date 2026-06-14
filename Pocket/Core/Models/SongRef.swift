import Foundation

/// A stable, source-agnostic identity for a song that Pocket data (loops, markers,
/// song info) attaches to.
///
/// The product brief keyed every model off `MusicItemID`, but Pocket's primary
/// audio source is DRM-free local / iCloud files (Apple Music streaming audio
/// cannot be tapped for waveform/speed — see docs/decisions/0001). Local files
/// have no `MusicItemID`, so identity is modelled here instead.
///
/// Equality and hashing are by `(id, source)` only. For local files the
/// security-scoped `bookmark` may be refreshed over time (iCloud eviction,
/// re-grants); two refs to the same imported file must stay equal even when the
/// bookmark bytes differ, otherwise loops/markers would orphan on relaunch.
struct SongRef: Codable, Identifiable {

    enum Source: String, Codable {
        /// Apple Music catalog item. `id` is the `MusicItemID` raw value.
        /// Browse/metadata only in V1 — not a waveform/playback source.
        case appleMusic
        /// Local or iCloud Drive file imported via the Files picker.
        /// `id` is a UUID assigned at import time and persisted.
        case localFile
    }

    /// Stable identifier. Never derived from a resolvable resource (paths,
    /// bookmarks) so it survives the resource moving or being re-granted.
    let id: String

    let source: Source

    /// Security-scoped bookmark for resolving a `.localFile` back to a URL.
    /// `nil` for `.appleMusic`. Not part of identity — see type doc.
    var bookmark: Data?

    init(id: String, source: Source, bookmark: Data? = nil) {
        self.id = id
        self.source = source
        self.bookmark = bookmark
    }

    /// Apple Music catalog reference (browse/metadata).
    static func appleMusic(id: String) -> SongRef {
        SongRef(id: id, source: .appleMusic)
    }

    /// Local/iCloud file reference. Assigns a fresh stable id by default.
    static func localFile(bookmark: Data, id: String = UUID().uuidString) -> SongRef {
        SongRef(id: id, source: .localFile, bookmark: bookmark)
    }
}

extension SongRef: Hashable {
    // Identity is (id, source); bookmark is deliberately excluded.
    static func == (lhs: SongRef, rhs: SongRef) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(source)
    }
}
