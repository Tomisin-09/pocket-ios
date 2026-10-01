import Foundation

/// A song as it leaves for another Red Moon (ADR 0236 D4): what's needed to practise it, and none of the
/// sender's practice.
///
/// Starts from `ArchiveBuilder.songRecord`, the record a backup writes, so a receiver reads the shape it
/// already reads from an archive, then takes out what is the sender's own:
///
/// - **their practice**: mastery, the speeds they reached, the command tempo they measured, when they last
///   practised, their snags and the history of a loop's span. A stranger's achievement must not arrive
///   wearing the receiver's name (ADR 0188 D5, ADR 0070).
/// - **their work on the song**: every loop's piece and its kept versions, which is the song's tab
///   (0232 D10), and the song's notes.
/// - **where they keep it**: collections, favourites, reference links, skills.
///
/// What stays is the song's own: its audio, its metadata, its tempo and beat grid, every loop's settings,
/// and every marker with its sections.
///
/// On the main actor because it reads models, as `ArchiveBuilder` does.
@MainActor
enum SharedSongBuilder {

    /// One song's record, stripped. Its `audioFileName` names the file in the pack's `songs/` folder.
    static func record(_ song: Song) -> SongRecord {
        var record = ArchiveBuilder.songRecord(song)
        record.comment = ""
        record.collections = []
        record.dateAdded = nil
        record.lastPracticed = nil
        record.lastPracticedSpeed = nil
        record.references = []
        record.snags = []
        record.loops = record.loops.map(shareable)
        return record
    }

    /// A loop's settings, without the sender's practice or pieces.
    static func shareable(_ loop: LoopRecord) -> LoopRecord {
        var loop = loop
        loop.isFavorite = false
        loop.lastPracticedSpeed = nil
        loop.mastery = nil
        loop.masteryAtSpeed = nil
        loop.focus = nil
        loop.commandTempo = nil
        loop.skillIDs = nil
        loop.transcription = nil
        loop.keptTranscriptions = nil
        loop.references = []
        loop.spanChanges = []
        return loop
    }

    /// The payload of a song sent on its own: kind `song`, the one record, and the sender's name.
    static func payload(_ song: Song, senderName: String?, appVersion: String,
                        exportedAt: Date = .now) -> SharedPractice {
        SharedPractice(kindRaw: SharedPracticeKind.song.rawValue, exportedAt: exportedAt, appVersion: appVersion,
                       songs: [record(song)], senderName: senderName)
    }

    /// The artist name as it travels: trimmed, and `nil` when there's nothing left (ADR 0236 D7).
    static func senderName(_ artistName: String?) -> String? {
        let name = artistName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
}
