import Foundation

extension Song {

    /// This song's audio on its own, as it leaves for a DAW or another device (ADR 0236 D3), or `nil`
    /// when Red Moon holds no copy of it.
    ///
    /// **Only the copy Red Moon keeps** (ADR 0148), never a legacy bookmark. A song still linked to a
    /// file elsewhere gets its copy the first time it plays (`SongAudioResolver.adoptIfNeeded`), and
    /// exporting through the bookmark would need its security scope held open until the share sheet
    /// reads the file, which nothing here can promise. So such a song offers no export until then.
    ///
    /// Named for the song, in the format it was imported in: *Slow Bend.mp3*.
    func exportedAudioFile(fileManager: FileManager = .default) -> ExportedAudioFile? {
        guard let leaf = audioFileName, SongFileStore.exists(fileName: leaf, fileManager),
              let source = try? SongFileStore.url(for: leaf, fileManager) else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExportedAudioFile(source: source,
                                 fileName: ExportStaging.fileName(stem: name.isEmpty ? "Song" : name,
                                                                  fileExtension: source.pathExtension))
    }
}
