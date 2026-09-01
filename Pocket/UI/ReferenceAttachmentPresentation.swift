import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// What a References section is asking its host to put on screen for the file half (ADR 0167
/// phase 2) — the attachment being read, or the picker being opened.
///
/// **The host presents, the section only raises the intent.** That is not a style preference, it is
/// the rule ADR 0167 phase 1 paid for: a sheet attached inside another sheet's `Form` fights the
/// presentation that already owns the screen, and on `ExerciseDetailSheet` it *dismissed the detail
/// sheet* instead of presenting anything. `ReferenceLinkEditing` carries the long version of that
/// story. The same applies to `.photosPicker` and `.fileImporter`, which are presentations too.
///
/// Identified by the link's business `uid`, never `persistentModelID` (ADR 0090) — an attachment row
/// is session-new the moment it is added, which is exactly when that id flips and SwiftUI reads the
/// flip as a new identity mid-sheet.
enum ReferenceAttachmentPresentation: Identifiable {
    /// Read a stored attachment full-screen.
    case viewing(ReferenceLink)
    /// Pick from the camera roll.
    case pickingPhoto
    /// Pick from Files.
    case pickingFile

    var id: UUID {
        switch self {
        case .viewing(let link): return link.uid
        case .pickingPhoto: return Self.photoID
        case .pickingFile: return Self.fileID
        }
    }

    // Fixed ids for the two picker cases, distinct from each other and from any link's `uid` —
    // `UUID()` always mints v4, so neither of these can collide with a real one.
    private static let photoID = UUID(uuid: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    private static let fileID = UUID(uuid: (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    var isViewing: Bool { if case .viewing = self { return true } else { return false } }
}

/// What tapping a reference row does — shared by the editable section and the two read-only
/// surfaces, so an attachment cannot open one way in one place and another way in another.
///
/// **A link leaves the app; an attachment does not.** That asymmetry is the point rather than an
/// accident: ADR 0167 keeps references off the run screen because following one is the interruption
/// the product is written against, and a file we hold is the reference that never causes it.
@MainActor
enum ReferenceRowAction {
    static func activate(_ link: ReferenceLink,
                         presenting: Binding<ReferenceAttachmentPresentation?>,
                         openURL: OpenURLAction) {
        if link.isAttachment {
            presenting.wrappedValue = .viewing(link)
        } else if let destination = link.destination {
            // A stored string that no longer normalises leaves the row inert rather than being
            // handed to `openURL` — the same gate as the save, read at the other end.
            openURL(destination)
        }
    }
}

/// Hosts the whole file half for one owner: the two pickers, the import write, and the viewer.
///
/// Attach at the host's **root** — the `NavigationStack` or the `List` — never inside the `Form`:
///
/// ```swift
/// .referenceAttachments($attachments, naming: $editingReference, owner: exercise,
///                       accent: PocketColor.practice)
/// ```
///
/// **Photos and Files, no camera** (ADR 0167 phase 2 decision 1). Both are out-of-process pickers
/// that hand back the bytes the player chose, so neither needs an `Info.plist` usage string —
/// `AGENTS.md` forbids adding one the app does not exercise, and a camera would be a real new
/// capability for a feature whose commonest input is a screenshot already in the roll.
///
/// Files is not the lesser route here: **a downloaded tab is usually a PDF or a `.txt`**, and neither
/// is ever in the camera roll.
struct ReferenceAttachmentPicking<Owner: ReferenceLinkOwner & AnyObject>: ViewModifier {
    @Binding var presenting: ReferenceAttachmentPresentation?
    /// Where a just-imported file is sent to be described — the host's `ReferenceLinkDraft` state,
    /// the same one **Add a link** writes to, so both halves of the section finish in one sheet.
    ///
    /// This modifier raises the intent; `ReferenceLinkEditing` presents it. That split is not
    /// tidiness: both modifiers hang off the host's root because a sheet presented from inside a
    /// `Form` fights the presentation that already owns the screen (ADR 0167 phase 1), and a picker
    /// is a presentation too.
    @Binding var naming: ReferenceLinkDraft?
    let owner: Owner
    let accent: Color
    /// See `ReferencesSection.context` — `RoutineDetailView` must pass its sandbox, or the insert
    /// lands in a different context from the routine it points at.
    var context: ModelContext?
    /// See `ReferencesSection.savesImmediately` — false only in the routine editor.
    var savesImmediately: Bool = true

    @Environment(\.modelContext) private var environmentContext
    @State private var photoItem: PhotosPickerItem?
    @State private var failure: String?

    private var writeContext: ModelContext { context ?? environmentContext }

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: isPresented(.pickingPhoto), selection: $photoItem,
                          matching: .images, photoLibrary: .shared())
            // **Not `[.image]`.** That is the abstract supertype, so it offers everything conforming
            // to `public.image` — including SVG, which ImageIO cannot decode (measured on iOS, not
            // assumed). The picker would advertise a file the app then refused. `pickerTypes` is
            // exactly what can be read, plus the two document types.
            .fileImporter(isPresented: isPresented(.pickingFile),
                          allowedContentTypes: ReferenceAttachmentStore.pickerTypes,
                          onCompletion: importFile)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task { await importPhoto(item) }
            }
            .referenceAttachmentViewing($presenting)
            .alert("Couldn't add that file", isPresented: failureAlert) {
                Button("OK", role: .cancel) { failure = nil }
            } message: {
                Text(failure ?? "")
            }
    }

    // MARK: - Presentation plumbing

    /// A `Bool` binding for one picker case. Writing `false` clears the intent only if *this* case is
    /// still the one showing — a picker dismissing after the state already moved on must not wipe
    /// what replaced it.
    private func isPresented(_ target: ReferenceAttachmentPresentation) -> Binding<Bool> {
        Binding(
            get: { presenting?.id == target.id },
            set: { shown in if !shown, presenting?.id == target.id { presenting = nil } }
        )
    }

    private var failureAlert: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    // MARK: - Import

    /// Camera roll. `loadTransferable` is the supported way off a `PhotosPickerItem` and hands back
    /// the original bytes — HEIC included, which `ReferenceAttachmentStore` reads and re-encodes.
    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                failure = Self.unreadable
                return
            }
            store(data, contentType: nil)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Files. The URL is security-scoped and **must be opened before reading** — the same discipline
    /// the four audio `fileImporter` call sites already follow. Read here rather than handed on: the
    /// scope closes when this function returns, and the store must not depend on it still being open.
    private func importFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            failure = error.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                failure = Self.unreadable
                return
            }
            // What the file *claims* to be, passed on as a hint. The store overrules it from the
            // bytes — a `.txt` extension on a JPEG must not become a text attachment no text view
            // can render.
            let claimed = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
            store(data, contentType: claimed ?? nil)
        }
    }

    /// The one write. Both pickers land here so the cap, the re-encode and the save cannot differ
    /// between them.
    ///
    /// The cap is re-checked at the moment of the write, not only when the control was drawn: a
    /// picker is a separate presentation, and the underlying owner can have changed between opening
    /// it and choosing something.
    ///
    /// The downscale runs on the main actor, which is a deliberate small cost: it is bounded by
    /// `ReferenceAttachmentStore.maxPixelSize`, it happens once per explicit tap, and moving it off would
    /// mean either a second door into the store or encoding the same file twice.
    private func store(_ data: Data, contentType: UTType?) {
        guard owner.canAddAttachment else {
            failure = Self.atLimit
            return
        }
        do {
            let link = try ReferenceLinkStore.addAttachment(data, contentType: contentType,
                                                            to: owner, in: writeContext)
            if savesImmediately { try? writeContext.save() }
            describe(link)
        } catch ReferenceAttachmentStore.ImportError.tooLarge {
            failure = Self.tooLarge
        } catch {
            failure = Self.unreadable
        }
    }

    /// Hand the new file to the editor to be named and noted — the second half of adding one, and
    /// the reason a file is now described the way a link always has been.
    ///
    /// **Raised a turn late, and only after the picker's own intent is cleared.** The picker is
    /// still dismissing when it hands the bytes back, and asking SwiftUI to present a sheet on a
    /// root that is mid-dismiss is the same fight ADR 0167 phase 1 paid six-minute runs to learn
    /// about. The `Task` hop puts the sheet on the next main-actor turn, by which point the picker
    /// has gone.
    @MainActor
    private func describe(_ link: ReferenceLink) {
        presenting = nil
        Task { @MainActor in naming = .naming(link) }
    }

    static var unreadable: String {
        "Red Moon couldn't read that one. It takes pictures, PDFs and plain text files."
    }

    static var tooLarge: String {
        let limit = StorageUsage.formatted(bytes: Int64(ReferenceAttachmentStore.maxDocumentBytes))
        return "That file is bigger than \(limit). Red Moon keeps a copy of everything you attach, "
            + "so it holds the line there."
    }

    static var atLimit: String {
        "This already has \(ReferenceAttachmentStore.maxPerOwner) files. Remove one to add another."
    }
}

/// The viewer half on its own, for the surfaces that read but do not edit —
/// `ReferencesReadOnlySection` and `ReferencesCard`. An attachment must still be readable there:
/// checking *what is in a session without starting it* (`docs/manual/routines.md`) is exactly when a
/// player wants to see the chart, and a thumbnail too small to read would make the row decorative.
struct ReferenceAttachmentViewingModifier: ViewModifier {
    @Binding var presenting: ReferenceAttachmentPresentation?

    func body(content: Content) -> some View {
        content.sheet(isPresented: viewerShown) {
            if case .viewing(let link) = presenting {
                ReferenceAttachmentViewer(link: link)
            }
        }
    }

    /// Only the `.viewing` case drives this sheet. The picker cases share the binding and must pass
    /// straight through, or opening a picker would also try to present an empty viewer.
    private var viewerShown: Binding<Bool> {
        Binding(
            get: { presenting?.isViewing ?? false },
            set: { shown in if !shown, presenting?.isViewing == true { presenting = nil } }
        )
    }
}

extension View {
    /// Host the pickers, the import and the viewer for `owner`. Attach at the screen's root — see
    /// `ReferenceLinkEditing` for the failure that rule comes from.
    func referenceAttachments<Owner: ReferenceLinkOwner & AnyObject>(
        _ presenting: Binding<ReferenceAttachmentPresentation?>,
        naming: Binding<ReferenceLinkDraft?>,
        owner: Owner,
        accent: Color,
        context: ModelContext? = nil,
        savesImmediately: Bool = true
    ) -> some View {
        modifier(ReferenceAttachmentPicking(presenting: presenting, naming: naming, owner: owner,
                                            accent: accent, context: context,
                                            savesImmediately: savesImmediately))
    }

    /// Host only the viewer — for a surface that shows references without offering to change them.
    func referenceAttachmentViewing(_ presenting: Binding<ReferenceAttachmentPresentation?>) -> some View {
        modifier(ReferenceAttachmentViewingModifier(presenting: presenting))
    }
}
