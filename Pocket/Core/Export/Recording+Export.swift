import Foundation

extension Recording {

    /// This take as it leaves through the share sheet (ADR 0236 D2), or `nil` when its audio isn't on
    /// disk — a take whose file has gone has nothing to send, and an *Export take…* that does nothing
    /// is worse than none.
    ///
    /// The caption is the live one when the owner still exists, and the snapshot taken at capture when
    /// it doesn't (ADR 0151), so a take that outlived its loop still says what it was recorded against.
    func exportedFile(fileManager: FileManager = .default) -> ExportedAudioFile? {
        guard let source = try? RecordingStore.url(for: fileName, fileManager),
              fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { return nil }
        let owner = JournalTimeline.ownerLabel(loop: loop, exercise: exercise, song: song) ?? ownerLabelAtTake
        let stem = TakeExportName.stem(title: title, ownerLabel: owner, createdAt: createdAt)
        return ExportedAudioFile(source: source,
                                 fileName: ExportStaging.fileName(stem: stem, fileExtension: source.pathExtension))
    }
}
