import Foundation
import Observation
import UniformTypeIdentifiers

/// **One *Save to Red Moon* session** (ADR 0264 D8): what was shared, what the player calls it and took
/// from it, and where it goes. *Keep for later* is the pick until the player chooses a place.
@MainActor
@Observable
final class ShareSaveModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// Nothing to keep. The screen says why and offers only *Cancel* (D12).
        case refused(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var payload: SharedPayload?
    var title = ""
    var note = ""
    /// The place, as a `ReferenceDestination.id`, or `nil` for *Keep for later*.
    var destination: String?
    /// Why *Save* didn't, if it didn't.
    var saveFailure: String?

    /// The library as the app last wrote it, or `nil` if the app hasn't opened since it was installed.
    let snapshot: ShareOwnerSnapshot?

    init(snapshot: ShareOwnerSnapshot?) {
        self.snapshot = snapshot
    }

    /// Where the player stands, as the snapshot says. Without one, as a player who hasn't bought the
    /// plan, so nothing is offered that the drain would refuse; and without one there are no places
    /// to offer anyway.
    var standing: PlanStanding { snapshot?.standing ?? .neverBought }

    /// The places, with D6's rules applied and, for a file, the full places greyed.
    var rows: [ReferenceDestinationPicker.Row] {
        guard let snapshot else { return [] }
        return ReferenceDestinationPicker.rows(snapshot.places, for: standing,
                                               full: isFile ? snapshot.fullOfFiles : [])
    }

    var isFile: Bool {
        if case .file = payload { return true }
        return false
    }

    // MARK: - Loading

    func load(_ items: [NSExtensionItem]) async {
        let loaded = await SharedItemLoader.load(items)
        let sharedText = items.first.flatMap { $0.attributedTitle?.string ?? $0.attributedContentText?.string }
        switch loaded {
        case .link(let url):
            title = SharedContent.suggestedTitle(fromSharedText: sharedText, link: url)
        case .file(_, let offer, let originalName, let byteCount):
            if let refusal = SharedContent.refusal(for: offer, byteCount: byteCount) {
                phase = .refused(refusal)
                return
            }
            title = SharedContent.suggestedTitle(fileName: originalName, offer: offer)
        case .refused(let reason):
            phase = .refused(reason)
            return
        }
        payload = loaded
        phase = .ready
    }

    // MARK: - Saving

    /// Hand the save to the app (D9): into the inbox, which the app drains when it next opens. `false`
    /// when it couldn't be written, with `saveFailure` saying so.
    func save(into directory: URL?) -> Bool {
        guard let directory, let payload else {
            saveFailure = Self.couldNotSave
            return false
        }
        var item = ShareInboxItem(id: UUID(), savedAt: .now, title: title, note: note, destination: destination)
        var file: URL?
        switch payload {
        case .link(let url):
            item.url = url
        case .file(let url, let offer, _, _):
            item.fileName = url.lastPathComponent
            item.typeIdentifier = UTTypeIdentifier.for(offer, fileName: url.lastPathComponent)
            file = url
        case .refused:
            return false
        }
        do {
            try ShareInbox.deposit(item, file: file, in: directory)
        } catch {
            saveFailure = Self.couldNotSave
            return false
        }
        if let file { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        return true
    }

    static let couldNotSave = "Red Moon couldn't keep this. Open Red Moon, then try sharing it again."

    #if DEBUG
    /// A loaded share without a sharing app, for a preview.
    func preview(_ payload: SharedPayload, title: String) {
        self.payload = payload
        self.title = title
        phase = .ready
    }
    #endif
}

/// The type a saved file goes to the store with: its extension's, which says *Markdown* where the
/// offer may only have said text.
private enum UTTypeIdentifier {
    static func `for`(_ offer: SharedContent.Offer, fileName: String) -> String {
        UTType(filenameExtension: (fileName as NSString).pathExtension)?.identifier ?? offer.typeIdentifier
    }
}
