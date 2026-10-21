import Foundation

/// What Red Moon says when a file can't be kept (ADR 0167 phase 2), in one place because two screens
/// say it: a References section's pickers, and *Save to Red Moon* (ADR 0264 D8), which compiles this
/// file too (D10).
enum ReferenceAttachmentCopy {
    static let unreadable = "Red Moon couldn't read that one. It takes pictures, PDFs and plain text files."

    static var tooLarge: String {
        let limit = ByteCountFormatter.string(fromByteCount: Int64(ReferenceAttachmentStore.maxDocumentBytes),
                                              countStyle: .file)
        return "That file is bigger than \(limit). Red Moon keeps a copy of everything you attach, "
            + "so it holds the line there."
    }

    static var atLimit: String {
        "This already has \(ReferenceAttachmentStore.maxPerOwner) files. Remove one to add another."
    }
}
