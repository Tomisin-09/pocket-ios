import Foundation

/// A `FileManager` whose "Application Support" is a throwaway directory, so the app's owned-file
/// stores (`SongFileStore`, ADR 0148) can be exercised for real — copies, replacement, deletion —
/// without touching the test host's container.
///
/// Shared by `SongFileStoreTests` and `SongAudioResolverTests`: both need a container they can
/// write into and then destroy, and duplicating the override invites the two suites to drift.
final class TempContainerFileManager: FileManager {
    let root: URL

    override init() {
        root = FileManager.default.temporaryDirectory
            .appending(path: "PocketFileStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        super.init()
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func url(for directory: FileManager.SearchPathDirectory,
                      in domain: FileManager.SearchPathDomainMask,
                      appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        directory == .applicationSupportDirectory
            ? root
            : try super.url(for: directory, in: domain, appropriateFor: url, create: shouldCreate)
    }

    /// Write a throwaway source file to copy in, standing in for a picked document.
    func makeSourceFile(named name: String, contents: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .notDirectory)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func destroy() { try? FileManager.default.removeItem(at: root) }
}
