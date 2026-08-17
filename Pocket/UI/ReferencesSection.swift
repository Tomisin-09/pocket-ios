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

    var body: some View {
        Section {
            if owner.references.isEmpty {
                Text("Nothing linked yet — add the lesson, tab or course this \(owner.referenceOwnerNoun) came from.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    ReferenceLinkRow(link: link, accent: accent) { open(link) }
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
        } header: {
            Text("Where you learned it")
        } footer: {
            Text("A lesson, a tab page, a teacher's write-up. Tapping one opens it in its own app — "
                 + "so save it for between sessions, not during.")
        }
    }

    // MARK: - Actions

    /// Open the source. A link whose stored string no longer normalises is left inert rather than
    /// handed to `openURL` — the same gate as the save, read at the other end.
    private func open(_ link: ReferenceLink) {
        guard let destination = link.destination else { return }
        openURL(destination)
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

    @Environment(\.openURL) private var openURL

    var body: some View {
        if owner.hasReferences {
            Section("Where you learned it") {
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    ReferenceLinkRow(link: link, accent: accent) {
                        if let destination = link.destination { openURL(destination) }
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

    @Environment(\.openURL) private var openURL

    var body: some View {
        if owner.hasReferences {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where you learned it")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                ForEach(owner.referencesInOrder, id: \.uid) { link in
                    ReferenceLinkRow(link: link, accent: accent) {
                        if let destination = link.destination { openURL(destination) }
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
struct ReferenceLinkRow: View {
    let link: ReferenceLink
    let accent: Color
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.displayTitle)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let host = link.displayHost, host != link.displayTitle {
                        Text(host)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        // Red Moon, not Pocket — the internal target name must not reach a VoiceOver string either.
        .accessibilityHint("Opens \(link.displayHost ?? "this link") outside Red Moon")
    }
}
