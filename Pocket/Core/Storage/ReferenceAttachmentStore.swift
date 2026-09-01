import Foundation
import ImageIO
import UniformTypeIdentifiers

/// On-disk home for reference attachments (ADR 0167 phase 2) — a tab screenshot, a photo of a page,
/// a downloaded PDF, an ASCII tab in a `.txt`, somebody's lesson notes in a `.md`.
///
/// Deliberately the third instance of one shape, after `RecordingStore` (ADR 0069 §5) and
/// `SongFileStore` (ADR 0148): bytes in `Application Support/`, the **leaf filename** in the model,
/// `FileManager` injected so the derivations and the orphan sweep are unit-testable without a real
/// container. ADR 0167 phase 2 names that pattern explicitly and rules out
/// `@Attribute(.externalStorage)`, which is used nowhere in this codebase and is the wrong shape for
/// the day sync lands — a file reference is CloudKit-safe in a way a blob attribute is not.
///
/// **Only images are re-encoded.** That asymmetry is the whole design: a photo is *material to look
/// at*, so cutting it to something a phone screen can show costs nothing anyone can see; a PDF, a
/// text file and a Markdown file are **documents**, and rewriting a document is losing part of it. A tab PDF flattened to
/// a JPEG of page one silently drops pages five through nine, and that is a worse feature than not
/// taking PDFs at all.
enum ReferenceAttachmentStore {

    /// Subdirectory of Application Support that holds reference attachments.
    static let directoryName = "References"

    /// Longest edge, in pixels, that any stored **image** is allowed to have.
    ///
    /// A phone screenshot (1290×2796 on the master device) lands essentially native, which is the
    /// case this feature exists for; a photo taken with the camera app is cut by roughly an order of
    /// magnitude in bytes. Above this, nothing on a phone screen is resolving the extra detail — and
    /// these are read at card size, not pinch-zoomed into a tab reader (that would be the OCR feature
    /// `docs/research/feasibility-tab-to-fretboard.md` explicitly does not plan).
    static let maxPixelSize = 2048

    /// JPEG quality for the image re-encode. High enough that screenshot text stays crisp at the
    /// sizes these are viewed at, low enough that the cap above is doing real work.
    static let jpegQuality = 0.85

    /// The ceiling on a stored **document**, which is not re-encoded and so has no other bound.
    ///
    /// Images cannot reach this — `maxPixelSize` gets there first — but a PDF can be arbitrarily
    /// large, and a scanned 400-page method book is not a reference, it is somebody's whole library
    /// arriving through a side door. Refused with a message that names the size rather than failing
    /// vaguely.
    static let maxDocumentBytes = 25 * 1024 * 1024

    /// How many attachments one owner may hold (ADR 0167 phase 2 decision 3).
    ///
    /// **Attachments are capped and links are not**, which looks inconsistent until you price them: a
    /// link is a hundred bytes and a row, an attachment is megabytes and a thumbnail in a card that
    /// `RoutineBlockPreview` already has to keep short. The limit disables the control and says so
    /// plainly — no owner is nagged for what it holds (`docs/design-brief.md` §3.5).
    static let maxPerOwner = 5

    // MARK: - What we accept

    /// Markdown. Not a `UTType` constant the SDK vends, but a system-declared type all the same —
    /// and one that **conforms to `public.plain-text`**, which is why it has to be recognised
    /// explicitly: a `.md` handed to the plain-text branch would be stored as a `.txt` and drawn as
    /// if it were ASCII tab.
    static let markdownType = UTType("net.daringfireball.markdown")

    /// The document types offered beside images, and the only non-image things that can be stored.
    /// A downloaded guitar tab is, in practice, one of the first three.
    static var documentTypes: [UTType] { [.pdf, .plainText] + [markdownType].compactMap { $0 } }

    /// Types the file picker may offer, which is deliberately **not** `[.image]`.
    ///
    /// `UTType.image` is the abstract supertype, so a bare `[.image]` filter offers everything
    /// conforming to it — including **SVG**, which ImageIO cannot decode (measured on iOS, not
    /// assumed). That combination is the worst of both: the picker advertises a file and the app then
    /// refuses it. Offering exactly what can be read means a file that appears selectable is one that
    /// will work.
    static var pickerTypes: [UTType] {
        let decodable = Set(CGImageSourceCopyTypeIdentifiers() as? [String] ?? [])
        return decodable.compactMap(UTType.init).filter { $0.conforms(to: .image) } + documentTypes
    }

    /// The references directory, created on first access. Application Support rather than Documents:
    /// these are app-managed artefacts, not files the player browses.
    static func directory(_ fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        let dir = base.appending(path: directoryName, directoryHint: .isDirectory)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Leaf filename for a reference's `uid`, extension chosen by what is being stored.
    ///
    /// The extension is **load-bearing, not decoration**: it is how `filesOnDisk` recognises our own
    /// files during a sweep, and how a person unzipping an export can open what they find. Images are
    /// always `.jpg` because `adopt` re-encodes them; documents keep the format they arrived in.
    static func fileName(for uid: UUID, kind: ReferenceLinkKind) -> String {
        "\(uid.uuidString).\(kind.fileExtension)"
    }

    /// Resolve a stored `fileName` to its on-disk `URL`.
    static func url(for fileName: String, _ fileManager: FileManager = .default) throws -> URL {
        try directory(fileManager).appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Whether a stored `fileName` still has a file behind it. A row whose file has gone renders as a
    /// placeholder rather than vanishing — the player's title and note are still worth something.
    static func exists(fileName: String, _ fileManager: FileManager = .default) -> Bool {
        guard let fileURL = try? url(for: fileName, fileManager) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // MARK: - Import

    /// What can go wrong on the way in, in the player's terms rather than ImageIO's.
    enum ImportError: Error, Equatable {
        /// The bytes are not anything we know how to store.
        case unreadable
        /// Recognised, but decoding or re-encoding failed.
        case couldNotConvert
        /// A document over `maxDocumentBytes`.
        case tooLarge
    }

    /// Store `data` as the attachment for `uid`, returning its leaf name and what it turned out to be.
    ///
    /// `contentType` is what the picker said it handed over; it is a **hint, not a verdict**. The
    /// bytes decide: an image is only an image if ImageIO reads it, and a PDF is only a PDF if it
    /// starts like one. A picker can be wrong about a file's type — a `.txt` extension on a JPEG, a
    /// PDF served with no type at all — and the model must never end up saying *picture* about
    /// something no picture viewer can open.
    ///
    /// Any existing file for this `uid` is replaced, so re-picking into the same reference overwrites
    /// rather than accumulating — the rule `SongFileStore.adopt` follows for a relink.
    @discardableResult
    static func adopt(_ data: Data, contentType: UTType?, for uid: UUID,
                      _ fileManager: FileManager = .default) throws -> (fileName: String,
                                                                        kind: ReferenceLinkKind) {
        let resolved = try resolve(data, contentType: contentType)
        let leaf = fileName(for: uid, kind: resolved.kind)
        let destination = try url(for: leaf, fileManager)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try resolved.bytes.write(to: destination, options: .atomic)
        return (leaf, resolved.kind)
    }

    /// Decide what these bytes are and what should be written for them. **Pure**, so the storage rule
    /// is testable on bytes with no container, no picker and no device.
    static func resolve(_ data: Data,
                        contentType: UTType?) throws -> (bytes: Data, kind: ReferenceLinkKind) {
        if let jpeg = try? downscaledJPEG(data) { return (jpeg, .image) }

        // Not an image. The only other things we store are documents, and both are size-capped
        // because neither is re-encoded.
        guard data.count <= maxDocumentBytes else { throw ImportError.tooLarge }

        if isPDF(data) { return (data, .pdf) }

        // Text of some sort. **The claim chooses the encoding ladder; the bytes decide whether there
        // is any text at all.**
        //
        // That split matters because *every single-byte encoding decodes anything* — Windows-1252
        // will happily turn a `.zip` into several kilobytes of mojibake and report success. So the
        // legacy ladder is only offered to a file that **claims** to be text, which is the case it
        // exists for (a `.txt` from a 1990s tab archive). Anything else has to be valid **UTF-8**,
        // which is the one encoding that can fail honestly.
        let claimsText = contentType?.conforms(to: .plainText) ?? false
        let contents = claimsText ? decodedText(data) : String(data: data, encoding: .utf8)
        guard contents != nil else { throw ImportError.unreadable }

        // **Markdown is checked before plain text, and the order is the whole point:**
        // `net.daringfireball.markdown` conforms to `public.plain-text`, so asking the plain-text
        // question first would answer `true` for every `.md` and quietly draw prose as a tab grid.
        if let type = contentType, let markdown = markdownType, type.conforms(to: markdown) {
            return (data, .markdown)
        }
        // Plain text, no type at all, or a type that turned out to be **wrong** — a file claiming to
        // be a PDF whose bytes are a tab. The claim got its chance above; from here the bytes win.
        return (data, .text)
    }

    /// `%PDF-` at the head. The format's own magic number, checked rather than trusting an extension:
    /// PDFKit will happily hand back an empty document for something that merely claims to be one.
    static func isPDF(_ data: Data) -> Bool {
        data.prefix(5).elementsEqual(Data("%PDF-".utf8))
    }

    /// The image re-encode. ImageIO rather than `UIImage`, for three reasons that all bite here:
    /// - it reads HEIC, which is what the camera roll actually hands over;
    /// - `kCGImageSourceCreateThumbnailWithTransform` bakes in the EXIF orientation, so a photo taken
    ///   sideways is stored the way it was seen rather than rotating when something later reads the
    ///   pixels without consulting the tag;
    /// - it never touches UIKit, so this file stays free of the main actor.
    /// - Parameter longestEdge: defaults to the storage cap. A row's thumbnail passes a much smaller
    ///   number through `thumbnailData` — decoding a 2048px picture per row is how a list of five
    ///   references would cost more memory than every other screen in the app put together.
    static func downscaledJPEG(_ data: Data, longestEdge: Int = maxPixelSize) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ImportError.unreadable
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Only *down*: the flag caps the longest edge, and ImageIO returns the image untouched
            // when it is already smaller. A screenshot is never upscaled into a bigger file than it
            // arrived as.
            kCGImageSourceThumbnailMaxPixelSize: longestEdge
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.couldNotConvert
        }
        let output = NSMutableData()
        guard let writer = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString,
                                                            1, nil) else {
            throw ImportError.couldNotConvert
        }
        CGImageDestinationAddImage(writer, image,
                                   [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(writer) else { throw ImportError.couldNotConvert }
        return output as Data
    }

    // MARK: - Reading

    /// The stored bytes, or `nil` if the file is gone. Blocking file I/O — call it off the main actor.
    /// `Data` is `Sendable`, which is why this hands back bytes rather than a `UIImage`: the decode
    /// happens on the main actor where the view needs it, and nothing non-`Sendable` crosses a
    /// boundary under Swift 6 strict concurrency.
    static func data(fileName: String, _ fileManager: FileManager = .default) -> Data? {
        guard let fileURL = try? url(for: fileName, fileManager),
              fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// A small version of a stored image, for a list row. `nil` rather than a placeholder, so the
    /// caller decides what a missing picture looks like.
    static func thumbnailData(fileName: String, longestEdge: Int,
                              _ fileManager: FileManager = .default) -> Data? {
        guard let full = data(fileName: fileName, fileManager) else { return nil }
        return try? downscaledJPEG(full, longestEdge: longestEdge)
    }

    /// A stored text or Markdown attachment as a `String`.
    ///
    /// **UTF-8 first, then Windows-1252, then Mac OS Roman.** Not belt and braces: ASCII tab files
    /// have been passed around since the 1990s, and a `.txt` from a tab archive is routinely in a
    /// legacy single-byte encoding. Refusing to show one because it is not UTF-8 would fail exactly
    /// the file this feature exists to keep — and every single-byte encoding decodes *something*, so
    /// the order matters: UTF-8 is tried first because it is the one that can fail honestly.
    static func text(fileName: String, _ fileManager: FileManager = .default) -> String? {
        guard let bytes = data(fileName: fileName, fileManager) else { return nil }
        return decodedText(bytes)
    }

    /// The pure half of `text(fileName:)`, so the encoding ladder is testable on bytes.
    static func decodedText(_ data: Data) -> String? {
        for encoding: String.Encoding in [.utf8, .windowsCP1252, .macOSRoman] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return nil
    }

    // MARK: - Retention

    /// Delete a reference's file if present (idempotent — a missing file is not an error).
    static func delete(fileName: String, _ fileManager: FileManager = .default) throws {
        let fileURL = try url(for: fileName, fileManager)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// File size in bytes, or `nil` if it can't be read.
    static func fileSize(fileName: String, _ fileManager: FileManager = .default) -> Int64? {
        guard let fileURL = try? url(for: fileName, fileManager),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return Int64(size)
    }

    /// The reference attachments currently on disk.
    ///
    /// Filtered to **our own extensions** rather than listing everything: this set is what the sweep
    /// proposes deleting, so a file it cannot account for must not appear in it. Anything else in the
    /// directory is left alone on purpose.
    static func filesOnDisk(_ fileManager: FileManager = .default) -> [String] {
        guard let dir = try? directory(fileManager),
              let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }
        let ours = Set(ReferenceLinkKind.attachmentKinds.map(\.fileExtension))
        return names.filter { ours.contains(($0 as NSString).pathExtension.lowercased()) }
    }

    /// **Pure** retention sweep: files on disk not referenced by any surviving `ReferenceLink`.
    ///
    /// ⚠ This one is not a backstop for an interrupted write, it is the **primary** collector for the
    /// commonest case. `ReferenceLink`'s owner inverses **cascade** (ADR 0167 — the opposite of the
    /// nullify rule notes and takes follow under ADR 0151), and a SwiftData cascade deletes rows
    /// without running any code of ours: delete an exercise and its attachment rows go while their
    /// bytes stay. `ReferenceLinkStore.delete` removes the file on the paths that *do* run through us;
    /// every cascade lands here, which is why *Reclaim space* (ADR 0182) had to learn this directory.
    static func orphanedFiles(onDisk: [String], referenced: Set<String>) -> [String] {
        onDisk.filter { !referenced.contains($0) }
    }
}
