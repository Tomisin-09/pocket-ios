import Foundation
import UniformTypeIdentifiers

/// **An audio file another app hands to Red Moon** (ADR 0273): a voice memo, a bounce in Files, a
/// recording a teacher sent. It arrives through the same door a `.redmoonpractice` does (ADR 0188 D3),
/// because the app declares itself a handler for audio, and it lands as a **song**: copied in, read
/// once for its waveform, titled by its file name, exactly as **+** would import it (ADR 0148).
///
/// Pure, so what counts as audio is a test rather than a share-sheet session, which no UI test can
/// drive.
enum SharedAudio {

    /// The type the app declares itself a handler for, at `Alternate` rank (`Info.plist`,
    /// `CFBundleDocumentTypes`): every audio type, so whatever a sharing app calls its recording is
    /// covered. The in-app picker offers the same type (`LibraryView`'s **+**).
    static let declaredType = UTType.audio

    /// Whether a file handed to the app is audio and so becomes a song, rather than a practice file
    /// to read. By the file's own type where the system knows it, else by its extension.
    static func isAudio(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        return type.map(isAudio(type:)) ?? false
    }

    /// Whether `fileExtension` names an audio type, for files the system has no type for yet.
    static func isAudio(fileExtension: String) -> Bool {
        UTType(filenameExtension: fileExtension).map(isAudio(type:)) ?? false
    }

    private static func isAudio(type: UTType) -> Bool {
        type.conforms(to: declaredType)
    }

    /// What the app says when a shared file is audio it can't read: a codec the decoder doesn't know,
    /// a protected purchase, an empty file.
    static let unreadable = "That audio file couldn’t be read."

    /// What it says when the song landed somewhere it can't open: the words a pack's song uses.
    static func landed(title: String) -> String {
        "“\(title)” is in your songs."
    }
}
