import SwiftUI

/// What the References editor was opened for. Both cases are the same sheet with a different
/// starting point, so they share one piece of `@State`.
///
/// **Identified by the link's business `uid`, never its `persistentModelID`** (ADR 0090,
/// `docs/swiftdata-gotchas.md`): on first save that id flips from temporary to permanent, SwiftUI
/// reads the change as a new identity and dismisses the sheet mid-edit. `uid` does not move.
enum ReferenceLinkDraft: Identifiable {
    case adding
    case editing(ReferenceLink)

    var id: UUID {
        switch self {
        case .adding: return Self.addingID
        case .editing(let link): return link.uid
        }
    }

    /// A fixed id for the add case — one "new link" sheet exists at a time per surface. Any stable
    /// value would do; the zero UUID is the one that cannot collide with a link's own `uid`, which
    /// `UUID()` always generates as v4 (never all-zero).
    private static let addingID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    var title: String {
        switch self {
        case .adding: return ""
        case .editing(let link): return link.title
        }
    }

    var urlString: String {
        switch self {
        case .adding: return ""
        case .editing(let link): return link.urlString
        }
    }

    var note: String {
        switch self {
        case .adding: return ""
        case .editing(let link): return link.note
        }
    }
}

/// Add or correct one reference link (ADR 0167). Three fields and a paste button.
///
/// **The paste affordance is required, not optional.** On a phone, typing a YouTube address by
/// hand is the difference between this feature being used and not — a bare `TextField` would make
/// the common path (copy from a share sheet, come back here) a two-gesture fiddle inside a keyboard
/// accessory. It is a `PasteButton` rather than a hand-rolled one, for the reason written at the
/// call site: reading the clipboard ourselves would ask the player's permission to do so every time
/// this sheet opened. The title is optional and the URL is not, because a link with no name is
/// still a place and the row falls back to the site.
struct ReferenceLinkEditor: View {
    let draft: ReferenceLinkDraft
    let accent: Color
    /// Called with a title, a URL string that has already passed `ReferenceURL.isValid`, and a
    /// note. All three are `String`, so the order — **title, url, note**, matching the store — is
    /// the one thing here the compiler cannot check for you.
    let save: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var urlString: String
    @State private var note: String
    /// Set only after a failed save attempt, so the field is not red while it is still being typed.
    @State private var showingRejection = false

    init(draft: ReferenceLinkDraft, accent: Color, save: @escaping (String, String, String) -> Void) {
        self.draft = draft
        self.accent = accent
        self.save = save
        _title = State(initialValue: draft.title)
        _urlString = State(initialValue: draft.urlString)
        _note = State(initialValue: draft.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                // **A file has no address to correct.** The editor is reached for an attachment only
                // through the row's hold menu, and what there is to change is what it is called and
                // what you took from it. Showing an empty, unfillable Link field would invite a
                // player to try to re-point a file at a URL.
                if !isAttachmentDraft {
                    linkSection
                }

                Section {
                    TextField("What is this?", text: $title)
                } header: {
                    Text("Name")
                } footer: {
                    // The title doubles as the alt text (ADR 0167 phase 2 decision 4), so for a
                    // picture this footer is the only place that says so — and it says it as a
                    // reason to name it, not as a requirement, because requiring a name in front of
                    // a photo you just chose is friction where the feature is weakest.
                    Text(isAttachmentDraft
                         ? "Optional — and it's what VoiceOver reads. Left empty, the row just says "
                           + "what kind of file it is."
                         : "Optional. Left empty, the row shows the site instead.")
                }

                Section {
                    // The house note idiom, unchanged from `Exercise.notes` and `Song.comment`:
                    // vertical axis, a soft line range, and the keyboard's escape hatch. The
                    // `keyboardDoneButton` is attached **once for the whole sheet** — it resigns
                    // whichever field is first responder rather than naming one — which is also
                    // what finally gives the Link field above an escape. That field has been
                    // `axis: .vertical` with no way off the keyboard since ADR 0167 shipped.
                    TextField("What you took from it", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .keyboardDoneButton(tint: accent)
                } header: {
                    Text("Note")
                } footer: {
                    Text(isAttachmentDraft
                         ? "Optional. What this shows you, or which bit of it matters — the row "
                           + "shows it under the name."
                         : "Optional. What this taught you, or where in it to look — the row shows "
                           + "it under the site.")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .tint(accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // A file is already saved — its bytes were written when it was picked, and this
                    // sheet only renames it. There is nothing to require, so nothing disables.
                    Button("Save") { attemptSave() }
                        .disabled(!isAttachmentDraft
                                  && urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    /// The address half — hidden entirely for an attachment, which has none.
    private var linkSection: some View {
        Section {
            TextField("Link", text: $urlString, axis: .vertical)
                .accessibilityIdentifier(UITestHooks.referenceLinkField)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onChange(of: urlString) { _, _ in showingRejection = false }
            // **`PasteButton`, not a `Button` that reads `UIPasteboard`.** The first version did the
            // latter, inside `body`, so it could name the site it would paste. Two things wrong with
            // that, one of them severe: reading the pasteboard programmatically raises the system's
            // *Allow Paste?* prompt, so merely opening this sheet would ask permission to look at
            // the clipboard — and it re-read on every body evaluation. It hung the app for 60s under
            // UI test (measured 2026-08-17: `App event loop idle notification not received`).
            //
            // `PasteButton` is the control designed for exactly this: the tap *is* the consent, so
            // nothing is read until the player asks and no prompt appears. The cost is that it says
            // "Paste" rather than naming the host, which is a fair trade for not interrogating the
            // clipboard behind their back.
            PasteButton(payloadType: String.self) { strings in
                guard let pasted = strings.first else { return }
                urlString = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                showingRejection = false
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
        } header: {
            Text("Link")
        } footer: {
            if showingRejection {
                Text(Self.rejection)
                    .foregroundStyle(PocketColor.danger)
            } else {
                // **Red Moon, not Pocket.** `Pocket` is the Xcode target and the bundle id; the app
                // has never gone by it. The CHANGELOG carries a Fixed entry for this exact leak in
                // two other strings, found while writing the manual — whose rule is that it quotes
                // the app's own words, and it cannot quote a name the product does not use.
                Text("A web address — Red Moon opens it in its own app and never fetches "
                     + "anything from it.")
            }
        }
    }

    /// The plain message ADR 0167 asks for: it names the two schemes rather than saying "invalid".
    static let rejection = "That doesn't look like a web address. Links must start with http:// or "
        + "https:// — Red Moon can't open anything else."

    private var isEditing: Bool {
        if case .editing = draft { return true }
        return false
    }

    /// Whether this sheet was opened on an attachment. There is no *adding* case for one: files
    /// arrive through a picker, and this editor only ever corrects one that already exists.
    private var isAttachmentDraft: Bool {
        if case .editing(let link) = draft { return link.isAttachment }
        return false
    }

    private var navigationTitle: String {
        if isAttachmentDraft { return "Edit details" }
        return isEditing ? "Edit link" : "Add a link"
    }

    /// Validate here *and* in `ReferenceLinkStore`. The store's gate is the one that protects the
    /// model from every caller; this one exists so the player sees why, instead of a Save button
    /// that silently does nothing.
    private func attemptSave() {
        if isAttachmentDraft {
            // No URL to gate. The commit side branches on the link's own kind, so what is passed
            // here for the URL is ignored rather than trusted.
            save(title, urlString, note)
            dismiss()
            return
        }
        guard ReferenceURL.isValid(urlString) else {
            showingRejection = true
            return
        }
        save(title, urlString, note)
        dismiss()
    }
}
