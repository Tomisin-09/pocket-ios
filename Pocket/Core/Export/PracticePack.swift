import Foundation

/// The **`.redmoonpack`** (ADR 0236 D8): practice that carries audio, as one file with a zip inside.
///
///     Tuesday warm-up/
///     ├─ practice.json      the `SharedPractice` payload: a song, or a routine with its songs
///     └─ songs/
///        └─ <audioFileName> one file per song, named as its record names it
///
/// A song with its audio is several files, and they have to arrive as one: the receiver taps one file,
/// and the system hands Red Moon only that one. A `.redmoonpractice` can't hold them, because it's
/// declared as JSON, so a pack is a type of its own.
///
/// **Both halves already exist.** It's zipped by `ArchiveWriter.zip` (ADR 0181 D5) and read by
/// `ZipArchiveReader` (ADR 0188 D8), so no dependency is added (ADR 0120), and the zip method stays part
/// of the format: `PracticePackTests` reads packs this writes, never a fixture.
///
/// A pack comes from someone else, so reading one trusts nothing: the payload's version is checked
/// before any audio is unpacked, a song's file must be a plain name in `songs/`, and an entry larger than
/// any song (or any payload) could be is refused rather than inflated.
enum PracticePack {

    static let fileExtension = "redmoonpack"
    static let payloadName = "practice.json"
    static let songsFolder = "songs"

    /// The largest audio entry a pack may hold: far above any song, far below what would exhaust a phone.
    static let largestSong = 512 * 1024 * 1024

    /// The largest `practice.json` a pack may hold. A routine with its songs' records is kilobytes; the
    /// reader allocates whatever size the zip declares, so a stranger's file mustn't get to name it.
    static let largestPayload = 16 * 1024 * 1024

    /// What reading a pack found: the payload, and each song's audio unpacked, by `audioFileName`.
    struct Contents: Sendable {
        var payload: SharedPractice
        var audio: [String: URL]
    }

    // MARK: - Writing

    /// Write `payload` and the audio its songs name into a pack called `stem`, in a fresh outbox folder,
    /// and return where it is.
    ///
    /// - Parameter audio: each song's `audioFileName`, to where the kept file is. Hard-linked into the
    ///   staging tree, as the archive stages takes, then zipped; the tree is removed once it's zipped.
    nonisolated static func write(_ payload: SharedPractice, audio: [String: URL], named stem: String,
                                  fileManager: FileManager = .default,
                                  temporaryDirectory: URL? = nil) throws -> URL {
        let folder = try ExportStaging.freshFolder(fileManager: fileManager, temporaryDirectory: temporaryDirectory)
        let name = ExportStaging.fileName(stem: stem, fileExtension: "", fallback: "Red Moon practice")
        let root = folder.appending(path: name, directoryHint: .isDirectory)
        let songs = root.appending(path: songsFolder, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: songs, withIntermediateDirectories: true)

        try ArchiveCoding.encode(payload).write(to: root.appending(path: payloadName, directoryHint: .notDirectory))
        for (leaf, source) in audio {
            let destination = songs.appending(path: leaf, directoryHint: .notDirectory)
            do {
                try fileManager.linkItem(at: source, to: destination)
            } catch {
                try fileManager.copyItem(at: source, to: destination)
            }
        }

        let pack = folder.appending(path: "\(name).\(fileExtension)", directoryHint: .notDirectory)
        try ArchiveWriter.zip(directory: root, to: pack, fileManager: fileManager)
        try? fileManager.removeItem(at: root)
        return pack
    }

    // MARK: - Reading

    /// Read a pack: its payload, then each song's audio unpacked into `staging`.
    ///
    /// The version is checked **before** any audio is unpacked (ADR 0188 D2), so a pack from a newer build
    /// costs nothing to turn away. Throws a `ReceiveFailure` the receive door can say in words.
    nonisolated static func read(_ url: URL, into staging: URL,
                                 fileManager: FileManager = .default) throws -> Contents {
        guard let zip = try? ZipArchiveReader(contentsOf: url),
              let entry = zip.entry(endingIn: payloadName), entry.uncompressedSize <= largestPayload,
              let json = try? zip.data(for: entry),
              let payload = try? ArchiveCoding.decode(SharedPractice.self, from: json) else {
            throw ReceiveFailure.corrupt
        }
        if case let .refuse(message) = SchemaVersionGate.evaluate(fileVersion: payload.schemaVersion) {
            throw ReceiveFailure.futureVersion(message: message)
        }

        let entries = zip.entries(inDirectoryNamed: songsFolder)
        var audio: [String: URL] = [:]
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        for record in payload.songs ?? [] {
            guard let leaf = record.audioFileName, isPlainName(leaf), let song = entries[leaf],
                  song.uncompressedSize <= largestSong, let bytes = try? zip.data(for: song) else {
                throw ReceiveFailure.incomplete(.song)
            }
            let target = staging.appending(path: leaf, directoryHint: .notDirectory)
            try bytes.write(to: target)
            audio[leaf] = target
        }
        return Contents(payload: payload, audio: audio)
    }

    /// A name with no path in it: what a song's file in `songs/` must be, so nothing written from a pack
    /// can land outside the folder it's unpacked into.
    nonisolated static func isPlainName(_ leaf: String) -> Bool {
        !leaf.isEmpty && leaf != "." && leaf != ".." && !leaf.contains("/") && !leaf.contains("\\")
    }
}
