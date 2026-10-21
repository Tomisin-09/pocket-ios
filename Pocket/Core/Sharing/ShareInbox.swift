import Foundation

/// **One save from *Save to Red Moon*, waiting for the app** (ADR 0264 D9): a link or a file, what the
/// player called it and took from it, and where it goes.
struct ShareInboxItem: Codable, Equatable, Sendable {
    /// Becomes the reference's `uid`, so an item drained twice (the app stopped between the save and
    /// clearing the inbox) is seen as already there, never filed twice.
    let id: UUID
    /// When the player tapped *Save*. The reference is dated by this, not by when the app drained it.
    let savedAt: Date
    /// The link, as `ReferenceURL` normalised it. `nil` for a file.
    var url: String?
    /// The file's name inside the item's folder. `nil` for a link.
    var fileName: String?
    /// What the sharing app said the file was, as a hint to `ReferenceAttachmentStore.resolve`, which
    /// lets the bytes decide.
    var typeIdentifier: String?
    var title: String = ""
    var note: String = ""
    /// The place, as a `ReferenceDestination.id`, or `nil` for *Keep for later*.
    var destination: String?

    var isFile: Bool { fileName != nil }
}

/// **The inbox** (D9): one folder per save, in the shared folder (`ShareContainer`). The extension
/// deposits, the app drains (`ShareInboxDrain`).
///
/// A save is its bytes first and `item.json` last, so a folder without `item.json` is a save that never
/// finished: the extension was stopped mid-copy. The app clears those when it drains, which it does only
/// in the foreground, when no extension can be writing. On an iPhone, the share sheet belongs to another
/// app in front of Red Moon.
enum ShareInbox {
    static let folderName = "Inbox"
    static let itemFileName = "item.json"

    /// A deposited save and the folder holding it.
    struct Pending: Equatable, Sendable {
        let item: ShareInboxItem
        let folder: URL

        /// The shared file's bytes on disk, for a file.
        var fileURL: URL? {
            item.fileName.map { folder.appending(path: $0, directoryHint: .notDirectory) }
        }
    }

    static func inbox(in directory: URL) -> URL {
        directory.appending(path: folderName, directoryHint: .isDirectory)
    }

    // MARK: - The extension's half

    /// Write one save. `file` is copied in first, never moved: it belongs to the sharing app. Then the
    /// item, last, which is what makes the save count.
    static func deposit(_ item: ShareInboxItem, file: URL? = nil, in directory: URL,
                        _ fileManager: FileManager = .default) throws {
        let folder = inbox(in: directory).appending(path: item.id.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        if let file, let name = item.fileName {
            try fileManager.copyItem(at: file, to: folder.appending(path: name, directoryHint: .notDirectory))
        }
        let data = try JSONEncoder().encode(item)
        try data.write(to: folder.appending(path: itemFileName, directoryHint: .notDirectory), options: .atomic)
    }

    // MARK: - The app's half

    /// Every finished save, oldest first, so the library lists them in the order they were made. A
    /// folder that never finished, or whose item can't be read, is removed: there is nothing in it the
    /// app could file.
    static func pending(in directory: URL, _ fileManager: FileManager = .default) -> [Pending] {
        let root = inbox(in: directory)
        guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var found: [Pending] = []
        for folder in folders {
            let itemURL = folder.appending(path: itemFileName, directoryHint: .notDirectory)
            guard let data = try? Data(contentsOf: itemURL),
                  let item = try? JSONDecoder().decode(ShareInboxItem.self, from: data) else {
                try? fileManager.removeItem(at: folder)
                continue
            }
            found.append(Pending(item: item, folder: folder))
        }
        return found.sorted { lhs, rhs in
            lhs.item.savedAt == rhs.item.savedAt ? lhs.item.id.uuidString < rhs.item.id.uuidString
                                                 : lhs.item.savedAt < rhs.item.savedAt
        }
    }

    /// Clear a save once the app holds it.
    static func remove(_ pending: Pending, _ fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: pending.folder)
    }
}
