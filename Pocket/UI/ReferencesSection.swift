import SwiftData
import SwiftUI

/// **Where you learned it** (ADR 0167) — one `Section` shared by every owner surface, so the four
/// places a player can attach a source cannot drift apart in wording, ordering or delete
/// behaviour. Drop it into a `Form`/`List` body:
///
/// ```swift
/// ReferencesSection(owner: exercise, accent: PocketColor.practice)
/// ```
///
/// **Never on a run screen.** ADR 0077 already strips authoring and review from the run screen, and
/// tapping a lesson link mid-session leaves the app — the exact interruption the product is written
/// against. If that is ever reversed, `LoopModeIdentityHeader` is the recorded insertion point.
///
/// Copy follows `docs/design-brief.md` §3.5: no count is judged and no owner is nagged for having
/// none. The empty line says what the section is *for*, not what the player has failed to do.
///
/// Rows are identified by the business `uid`, never `persistentModelID` — that id flips from
/// temporary to permanent on a model's first save, and SwiftUI reads the flip as a new identity
/// (ADR 0090, `docs/swiftdata-gotchas.md`). Every link here is session-new the moment it is added,
/// which is exactly the case that trips it.
struct ReferencesSection<Owner: ReferenceLinkOwner & AnyObject>: View {
    let owner: Owner
    let accent: Color
    /// The context to write into. Defaults to the environment's, which is right for the three
    /// surfaces that edit a live model.
    ///
    /// **`RoutineDetailView` must pass its own.** That screen edits in a private child `ModelContext`
    /// with autosave off, and its `routine` belongs to *that* context — inserting a link into the
    /// environment's context while pointing it at a sandboxed routine is a cross-context
    /// relationship, which is a corruption, not a preference.
    var context: ModelContext?
    /// Whether a change is durable the moment it is made.
    ///
    /// True everywhere except the routine editor, whose whole contract is that Cancel discards and
    /// Save keeps. Saving its child context here would commit whatever block rearrangement happened
    /// to be pending — an unrelated edit made permanent by adding a link.
    var savesImmediately: Bool = true

    @Environment(\.modelContext) private var environmentContext
    @Environment(\.openURL) private var openURL

    /// The context every mutation below runs in.
    private var writeContext: ModelContext { context ?? environmentContext }

    /// The link being added or edited — **owned by the host**, not by this section.
    ///
    /// ⚠ It used to be `@State` here, with the `.sheet` attached to the `Section`. That does not
    /// present: measured 2026-08-17, tapping **Add a link** on `ExerciseDetailSheet` **dismissed the
    /// detail sheet** and left the app on the exercise run screen. Nothing failed to compile and
    /// nothing logged; the accessibility hierarchy at the moment of the tap is the only thing that
    /// said so.
    ///
    /// A sheet presented from a row or section *inside* another sheet's `Form` fights the
    /// presentation that already owns that screen. The working pattern is the one
    /// `ExerciseDetailSheet` already used for its song picker — attach at the `NavigationStack`, via
    /// `.referenceLinkEditing(…)`. So this section raises the intent and the host presents it.
    @Binding var editing: ReferenceLinkDraft?

    /// The picture being looked at, or the picker being opened — raised here, presented by the host
    /// through `.referenceAttachments(…)`, for exactly the reason `editing` is (ADR 0167 phase 2). A
    /// `.photosPicker` or `.fileImporter` attached inside this `Form` is a presentation competing
    /// with the sheet that already owns the screen, the same way that sheet was.
    @Binding var presenting: ReferenceAttachmentPresentation?

    var body: some View {
        Section {
            if owner.references.isEmpty {
                Text("Nothing here yet — add the lesson, tab, course or file this "
                     + "\(owner.referenceOwnerNoun) came from.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    // **Hold for the menu, swipe for either half** — the grammar every other list
                    // row in this app already reads in (`pocketRowActions`). Editing used to be
                    // reachable *only* by the leading swipe, which nothing on the row advertised,
                    // so a link named badly was effectively stuck. Found on device by going looking
                    // for the affordance and not finding it.
                    //
                    // A `.contextMenu` rather than a hand-rolled long press: it carries its own
                    // haptic and lift preview, and it does not fight the row's tap the way an
                    // `onLongPressGesture` on a `Button` does. Delete is `role: .destructive` here
                    // because this section deletes immediately — there is no deferred-delete seam
                    // on these hosts, so nothing can disappear on a promise it doesn't keep.
                    ReferenceLinkRow(link: link, accent: accent) { activate(link) }
                        .contextMenu {
                            Button { editing = .editing(link) } label: {
                                Label(link.isAttachment ? "Edit details" : "Edit link",
                                      systemImage: "pencil")
                            }
                            Button(role: .destructive) { delete(link) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { editing = .editing(link) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(accent)
                        }
                }
                .onDelete(perform: delete)
                // Only reachable where the host puts the list into edit mode, which today is the
                // routine editor alone. Kept on every surface rather than conditionalised: it costs
                // nothing where edit mode never arrives, and omitting it would make reordering
                // silently absent the first time another host does turn edit mode on.
                .onMove(perform: move)
            }
            Button { editing = .adding } label: {
                Label("Add a link", systemImage: "plus.circle")
                    .foregroundStyle(accent)
            }
            // A `Menu` of two actions, not a picker of options — the two are different things, and
            // the rule against growing popup menus is about **option sets** with nowhere to put
            // prose (`OptionListSection` is the answer there). Two sources, named plainly, with the
            // explanation in the section footer where it already lives.
            Menu {
                Button { presenting = .pickingPhoto } label: {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                }
                Button { presenting = .pickingFile } label: {
                    Label("Choose a file", systemImage: "folder")
                }
            } label: {
                Label("Add a file", systemImage: "paperclip")
                    .foregroundStyle(owner.canAddAttachment ? accent : PocketColor.textSecondary)
            }
            .disabled(!owner.canAddAttachment)
        } header: {
            Text("Where you learned it")
        } footer: {
            Text(footer)
        }
    }

    /// What the section says under itself. The limit line replaces the second sentence rather than
    /// being appended to it: a footer that grows a third clause the moment you hit a cap reads as
    /// telling you off, and `docs/design-brief.md` §3.5 says no owner is nagged for what it holds.
    private var footer: String {
        let sources = "A lesson, a tab page, a teacher's write-up — or a picture, PDF, text or "
            + "Markdown file you keep here."
        guard owner.canAddAttachment else {
            return sources + " Files are capped at \(ReferenceAttachmentStore.maxPerOwner) — remove "
                + "one to add another."
        }
        return sources + " Tapping a link opens it in its own app, so save it for between sessions, "
            + "not during."
    }

    // MARK: - Actions

    /// Tap. Shared with the read-only surfaces through `ReferenceRowAction`, which is where the
    /// difference between opening a link and opening a picture is written down.
    private func activate(_ link: ReferenceLink) {
        ReferenceRowAction.activate(link, presenting: $presenting, openURL: openURL)
    }

    /// Delete one link — the menu's route in. The `IndexSet` overload below is the swipe's, and
    /// both land on the same store call so the two cannot drift.
    private func delete(_ link: ReferenceLink) {
        ReferenceLinkStore.delete([link], from: owner, in: writeContext)
        persist()
    }

    private func delete(at offsets: IndexSet) {
        let ordered = owner.referencesInOrder
        ReferenceLinkStore.delete(offsets.map { ordered[$0] }, from: owner, in: writeContext)
        persist()
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        ReferenceLinkStore.move(from: offsets, to: destination, in: owner)
        persist()
    }

    /// Make the change durable, unless the host owns that decision.
    private func persist() {
        guard savesImmediately else { return }
        try? writeContext.save()
    }
}

/// The read-only half, for `RoutineBlockPreview` — checking *what is in a session without starting
/// it* (`docs/manual/routines.md`) is a reading moment, so the preview shows the sources without
/// offering to edit them. Renders nothing at all when there are none, rather than an empty section
/// on a surface that is already dense.
struct ReferencesReadOnlySection<Owner: ReferenceLinkOwner & AnyObject>: View {
    let owner: Owner
    let accent: Color
    /// Looking at a picture is **reading**, so it belongs on a read-only surface — presented by the
    /// host through `.referenceAttachmentViewing(…)`, which carries the viewer without the pickers.
    @Binding var presenting: ReferenceAttachmentPresentation?

    @Environment(\.openURL) private var openURL

    var body: some View {
        if owner.hasReferences {
            Section("Where you learned it") {
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    // No menu: this surface reads, it does not edit.
                    ReferenceLinkRow(link: link, accent: accent) {
                        ReferenceRowAction.activate(link, presenting: $presenting, openURL: openURL)
                    }
                }
            }
        }
    }
}

/// The same read-only list as a **card**, for `RoutineBlockPreview` — that screen is a `ScrollView`
/// of stacked cards rather than a `List`, so a `Section` would render as nothing there. Renders
/// nothing when the owner has no sources, for the same reason as `ReferencesReadOnlySection`.
struct ReferencesCard<Owner: ReferenceLinkOwner & AnyObject>: View {
    let owner: Owner
    let accent: Color
    /// See `ReferencesReadOnlySection.presenting`.
    @Binding var presenting: ReferenceAttachmentPresentation?

    @Environment(\.openURL) private var openURL

    var body: some View {
        if owner.hasReferences {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where you learned it")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    // No menu: this surface reads, it does not edit.
                    ReferenceLinkRow(link: link, accent: accent) {
                        ReferenceRowAction.activate(link, presenting: $presenting, openURL: openURL)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.surfaceSubtle))
        }
    }
}

/// One row: the player's title over the site it points at. Shared so the three surfaces cannot
/// present the same link differently.
///
/// A plain `Button` rather than `Link`, because the row must stay tappable when the destination is
/// no longer openable — and because a `Link` inside a `List` row swallows the swipe actions.
///
/// **The hold is a `.contextMenu`, applied by the host, and that is what lets this stay a `Button`.**
/// A first pass gave the row an `onLongPressGesture` and had to stop being a `Button` to do it: a
/// SwiftUI `Button` fires its tap action on the *release of a long press too*, so it would have
/// opened the source **and** the editor on every hold — the bug this repo has shipped to a device
/// twice. A `.contextMenu` has no such quarrel with the tap, brings its own haptic and preview, and
/// is the idiom every other row in the app already uses through `pocketRowActions`. The row that
/// needed hand-rolled gestures was the row solving the wrong problem.
struct ReferenceLinkRow: View {
    let link: ReferenceLink
    let accent: Color
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                if link.isAttachment {
                    ReferenceAttachmentThumbnail(link: link)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.displayTitle)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    // An attachment has no host, and no second line stands in for one: "Picture"
                    // under the title would say what the thumbnail beside it already shows.
                    if !link.isAttachment, let host = link.displayHost, host != link.displayTitle {
                        Text(host)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    // **What you took from it**, under the site. `lineLimit(2)` is load-bearing
                    // rather than cosmetic: this row is also used by `ReferencesCard`, which sits
                    // in `RoutineBlockPreview`'s `ScrollView`, where an uncapped note would push
                    // the rest of the card off a dense screen.
                    //
                    // ⚠ **Do not move this into `.accessibilityHint`.** The row combines its
                    // children into one label, so this `Text` is already read — in full and
                    // untruncated, which is the right behaviour: the two-line cap is a layout
                    // decision, not a content one. Adding it to the hint would read it twice.
                    if let note = link.displayNote {
                        Text(note)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                // The icon says where the tap goes: out of the app, or bigger within it.
                Image(systemName: link.isAttachment ? "arrow.up.left.and.arrow.down.right"
                                                    : "arrow.up.right.square")
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        // Red Moon, not Pocket — the internal target name must not reach a VoiceOver string either.
        .accessibilityHint(link.isAttachment
                           ? "Opens this \(link.kind.noun) in Red Moon"
                           : "Opens \(link.displayHost ?? "this link") outside Red Moon")
    }
}
