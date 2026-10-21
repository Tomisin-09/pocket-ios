import UIKit
import UniformTypeIdentifiers

/// What the sharing app handed over, once loaded (ADR 0264 D8, D12).
enum SharedPayload: Equatable, Sendable {
    /// A web link, as `ReferenceURL` normalised it.
    case link(String)
    /// A file, copied into the extension's own temporary folder: the sharing app's copy can vanish as
    /// soon as the load returns.
    case file(URL, SharedContent.Offer, originalName: String?, byteCount: Int)
    /// Nothing Red Moon keeps, and what to say about it.
    case refused(String)
}

/// **Loading what was shared.** The only part of *Save to Red Moon* that talks to the sharing app;
/// what it loads is decided by `SharedContent`, which is pure and tested.
enum SharedItemLoader {

    /// The best thing in `items` Red Moon keeps: the attachment offering the most preferred kind
    /// (`SharedContent.Offer`), tried in that order until one loads.
    @MainActor
    static func load(_ items: [NSExtensionItem]) async -> SharedPayload {
        let offers = items.flatMap { item in
            (item.attachments ?? []).compactMap { provider in
                SharedContent.offer(registeredTypes: provider.registeredTypeIdentifiers).map { (provider, $0) }
            }
        }
        .sorted { $0.1 < $1.1 }
        var fallback = SharedPayload.refused(SharedContent.nothingToKeep)
        for (provider, offer) in offers {
            let payload = await load(provider, as: offer)
            if case .refused = payload {
                // Keep the most specific reason: shared text with no link says so (D12).
                if case .refused(SharedContent.nothingToKeep) = fallback { fallback = payload }
                continue
            }
            return payload
        }
        return fallback
    }

    /// One attachment, as one kind. The completion handler runs on a queue of the provider's choosing,
    /// so it is written `@Sendable`: a closure inferred as main-actor isolated traps when called from
    /// anywhere else (the AVAudio tap learned this on a device first).
    @MainActor
    private static func load(_ provider: NSItemProvider, as offer: SharedContent.Offer) async -> SharedPayload {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: offer.typeIdentifier, options: nil) { @Sendable item, _ in
                continuation.resume(returning: payload(from: item, as: offer))
            }
        }
    }

    /// What one loaded item is. A sharing app can hand the same kind over as a file, as bytes, as a
    /// string or as a picture object, and each is taken as it comes.
    private nonisolated static func payload(from item: (any NSSecureCoding)?,
                                            as offer: SharedContent.Offer) -> SharedPayload {
        switch item {
        case let url as URL where url.isFileURL:
            return file(at: url, as: offer)
        case let url as URL:
            return ReferenceURL.normalised(url.absoluteString).map { .link($0.absoluteString) }
                ?? .refused(SharedContent.nothingToKeep)
        case let text as String:
            return words(text, as: offer)
        case let data as Data:
            if offer == .plainText, let text = String(data: data, encoding: .utf8) { return words(text, as: offer) }
            return file(data, as: offer)
        case let image as UIImage:
            guard let data = image.jpegData(compressionQuality: ReferenceAttachmentStore.jpegQuality) else {
                return .refused(ReferenceAttachmentCopy.unreadable)
            }
            return file(data, as: .image, originalName: "shared.jpg")
        default:
            return .refused(SharedContent.nothingToKeep)
        }
    }

    /// Text: an address on its own, or a sentence with a link in it (D12).
    private nonisolated static func words(_ text: String, as offer: SharedContent.Offer) -> SharedPayload {
        if offer == .webLink, let link = ReferenceURL.normalised(text) { return .link(link.absoluteString) }
        return SharedContent.firstWebLink(in: text).map(SharedPayload.link) ?? .refused(SharedContent.noLink)
    }

    // MARK: - Files

    /// A file the sharing app owns, copied out before the handler returns.
    private nonisolated static func file(at url: URL, as offer: SharedContent.Offer) -> SharedPayload {
        // A file link offered as a link is a file of its own type, if it is one Red Moon keeps.
        let kind = UTType(filenameExtension: url.pathExtension)
            .flatMap { SharedContent.offer(registeredTypes: [$0.identifier]) } ?? offer
        guard kind != .webLink else { return .refused(SharedContent.nothingToKeep) }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let copy = try? stagingURL(SharedContent.inboxFileName(original: url.lastPathComponent, offer: kind)),
              (try? FileManager.default.copyItem(at: url, to: copy)) != nil else {
            return .refused(ReferenceAttachmentCopy.unreadable)
        }
        let size = (try? copy.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .file(copy, kind, originalName: url.lastPathComponent, byteCount: size)
    }

    /// Bytes handed over with no file around them.
    private nonisolated static func file(_ data: Data, as offer: SharedContent.Offer,
                                         originalName: String? = nil) -> SharedPayload {
        guard let copy = try? stagingURL(SharedContent.inboxFileName(original: originalName, offer: offer)),
              (try? data.write(to: copy)) != nil else {
            return .refused(ReferenceAttachmentCopy.unreadable)
        }
        return .file(copy, offer, originalName: originalName, byteCount: data.count)
    }

    /// A fresh folder in the extension's temporary directory, and the file's place in it.
    private nonisolated static func stagingURL(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString,
                                                                      directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: name, directoryHint: .notDirectory)
    }
}
