import Foundation

/// **Where the app and *Save to Red Moon* meet** (ADR 0264 D9): one folder in the App Group container,
/// which both targets can reach. It holds two things, and neither is the store:
///
/// - `owners.json`, the owner snapshot the app writes (`ShareOwnerSnapshot`);
/// - `Inbox/`, one folder per save the extension writes (`ShareInbox`).
///
/// The store stays in the app's own Application Support. Moving it here to power a picker would move
/// every player's history, which 0186 D9 already refused for the widget.
///
/// Everything that reads or writes here takes the folder as a parameter, so a test hands it a temporary
/// one: `TempContainerFileManager` redirects Application Support and can't reach a group container
/// (D10.5).
enum ShareContainer {
    /// The App Group both targets are signed with. The app's and the extension's entitlements name it.
    static let appGroup = "group.click.decooperations.pocket"

    /// The shared folder, created on first use. `nil` when the group can't be reached, which is a
    /// build signed without the entitlement: sharing then has nowhere to meet, and nothing else is
    /// affected.
    static func directory(_ fileManager: FileManager = .default) -> URL? {
        guard let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        let folder = group.appending(path: "References", directoryHint: .isDirectory)
        guard (try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        return folder
    }
}
