import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// An audio file on its way out through the share sheet: a take (ADR 0236 D2), or a song's audio on
/// its own (D3).
///
/// Holds where the file lives and what it should be called, nothing more. `ShareLink` rebuilds its
/// item on every pass of the view's body, and staging a file there would be disk work paid for a sheet
/// that may never open, so the file is staged in the transfer representation instead, which the
/// system calls once, when the player has picked where it goes. The same split `SharedPracticeFile`
/// makes for its JSON.
struct ExportedAudioFile: Transferable, Sendable, Equatable {

    /// The file as the app keeps it.
    var source: URL

    /// What the receiver sees, extension included.
    var fileName: String

    /// The file's type, read from its extension. Plain audio when the extension says nothing.
    var contentType: UTType {
        UTType(filenameExtension: (fileName as NSString).pathExtension) ?? .audio
    }

    /// The types given a representation of their own. A receiver that only takes MP3, or only
    /// MPEG-4 audio, matches on these, which a bare `public.audio` would not tell it.
    static let namedTypes: [UTType] = [.mpeg4Audio, .mp3, .wav, .aiff]

    static var transferRepresentation: some TransferRepresentation {
        file(as: .mpeg4Audio)
        file(as: .mp3)
        file(as: .wav)
        file(as: .aiff)
        // Anything else a song could have been imported as (FLAC, CAF, AAC…) still leaves, as audio.
        FileRepresentation(exportedContentType: .audio) { SentTransferredFile(try $0.staged()) }
            .exportingCondition { file in !namedTypes.contains { file.contentType.conforms(to: $0) } }
    }

    private static func file(as type: UTType) -> some TransferRepresentation<ExportedAudioFile> {
        FileRepresentation(exportedContentType: type) { SentTransferredFile(try $0.staged()) }
            .exportingCondition { $0.contentType.conforms(to: type) }
    }

    /// Put the file where the share sheet can read it under its name. See `ExportStaging`.
    func staged() throws -> URL {
        try ExportStaging.stage(source, as: fileName)
    }
}
