import SwiftData
import SwiftUI

/// **One source** (ADR 0264 D5), opened from the References library: open it, read what you took from
/// it, see where it's used, file it somewhere, start a drill from it, and delete it for good.
///
/// **While it isn't filed, *Start an exercise from this* is the main action**, with *Attach to…* under
/// it. Once it is, the two swap places and change their words: *Also attach to…* and *Start another
/// exercise from this*, as drawn. What either does to the rows is `ReferenceFiling`'s.
///
/// **It follows the row it was opened from**, not the link: a source is a group of rows by address
/// (D3), and an edit can change the address. Recomputed from `@Query` on every read, so a change made
/// here or anywhere else shows at once, and a source deleted elsewhere leaves a plain message.
///
/// **A source has one name and one address; each place keeps its own note** (D3). So *Edit* writes the
/// name and the link to every row, and the note only to the row it was opened for. With more than one
/// row, *Edit* asks which place's note.
struct ReferenceSourceView: View {
    let anchor: UUID

    @Query private var links: [ReferenceLink]
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(PlanStore.self) private var plan: PlanStore?

    @State private var editing: ReferenceLinkDraft?
    @State private var presenting: ReferenceAttachmentPresentation?
    @State private var confirmingDelete = false
    @State private var attaching = false
    @State private var startingExercise = false

    var body: some View {
        Group {
            if let source = ReferenceLibrary.source(containing: anchor, in: links) {
                content(source)
            } else {
                ContentUnavailableView("This reference has gone", systemImage: "bookmark.slash")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { draft in
            ReferenceLinkEditor(draft: draft, accent: PocketColor.toolkit) { title, url, note in
                commit(draft, title: title, url: url, note: note)
            }
        }
        .referenceAttachmentViewing($presenting)
        .sheet(isPresented: $attaching) { ReferenceAttachSheet(anchor: anchor) }
        // New exercise, through the one insert path (ADR 0128), which files this source onto the drill
        // and opens it. Behind the plan by the sheet's own gate (0256 D3), so a free player meets the
        // wall there (D6).
        .newExerciseFlow(isPresented: $startingExercise, startingFrom: anchor)
        .tint(PocketColor.toolkit)
    }

    private func content(_ source: ReferenceSource) -> some View {
        List {
            Section { header(source) }
            Section { openButton(source) }
            if !source.unfiledNotes.isEmpty {
                Section("What you took from it") {
                    ForEach(source.unfiledNotes, id: \.uid) { row in
                        Text(row.displayNote ?? "")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                            .contextMenu { editButton(row) }
                    }
                }
            }
            Section {
                uses(source)
            } header: {
                Text("Where it's used")
            } footer: {
                if source.distinctPlaces.count > 1 { Text("Each place keeps its own note.") }
            }
            actions(source)
            Section {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Text(ReferenceLibrary.deleteButtonTitle(places: source.distinctPlaces.count))
                }
                // On the button, not the list: iOS 26 draws the dialog as a popover pointing at the view
                // it hangs from, and hung from the list it pointed at *Open link*.
                .confirmationDialog("Delete this reference?", isPresented: $confirmingDelete,
                                    titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { delete(source) }
                } message: {
                    Text(ReferenceLibrary.deleteMessage(places: source.distinctPlaces))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { editControl(source) }
        }
    }

    // MARK: - Sections

    private func header(_ source: ReferenceSource) -> some View {
        HStack(spacing: 14) {
            ReferenceSourceIcon(link: source.newest, side: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayTitle)
                    .font(.futura(.title3, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("\(source.origin) · \(WrittenTab.day(source.newest.dateAdded))")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Out of the app for a link, the viewer for a file: `ReferenceRowAction`, as every row taps.
    private func openButton(_ source: ReferenceSource) -> some View {
        let title: String = source.isAttachment ? "Open \(source.newest.kind.noun)" : "Open link"
        let icon: String = source.isAttachment ? "arrow.up.left.and.arrow.down.right" : "arrow.up.right.square"
        return Button {
            ReferenceRowAction.activate(source.newest, presenting: $presenting, openURL: openURL)
        } label: {
            Label(title, systemImage: icon)
        }
    }

    /// A source filed nowhere has no place to hang a note on, so its notes get a section of their own,
    /// as drawn (`ReferenceSource.unfiledNotes`), and this says so. Every other note sits under its place.
    @ViewBuilder
    private func uses(_ source: ReferenceSource) -> some View {
        if !source.isFiled {
            Text("Not filed yet")
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textSecondary)
        } else {
            ForEach(Self.usesInOrder(source), id: \.uid) { row in
                ReferenceUseRow(row: row)
                    .contextMenu { editButton(row) }
            }
        }
    }

    private func editButton(_ row: ReferenceLink) -> some View {
        Button { editing = .editing(row) } label: { Label("Edit", systemImage: "pencil") }
    }

    /// The places first, newest first, then any row kept for later (D3).
    private static func usesInOrder(_ source: ReferenceSource) -> [ReferenceLink] {
        source.rows.filter(\.isFiled) + source.keptForLater
    }

    // MARK: - File it, or start a drill from it

    /// Not filed: *Start an exercise from this*, full width, with its caption, then *Attach to…*.
    /// Filed: *Also attach to…* (or *Move to…* for a file), then *Start another exercise from this*.
    @ViewBuilder
    private func actions(_ source: ReferenceSource) -> some View {
        let start = ReferenceFiling.startTitle(for: source)
        if !source.isFiled, let start {
            Section {
                Button { startingExercise = true } label: {
                    // White throughout, glyph and lock too: a List draws a row's label icon in the
                    // screen's indigo, which on teal can't be read, and the grey badge can't either.
                    HStack(spacing: 8) {
                        Label(start, systemImage: "metronome")
                        if plan.showsPlanLocks {
                            Image(systemName: "lock.fill").font(.footnote.weight(.semibold)).accessibilityHidden(true)
                        }
                    }
                    .font(.futura(.headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(PocketColor.practice)
                .planLockedValue(plan.showsPlanLocks)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                if let caption = ReferenceFiling.startCaption(for: source) {
                    Text(caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            Section { attachButton(source) }
        } else {
            Section {
                attachButton(source)
                if let start {
                    Button { startingExercise = true } label: {
                        HStack(spacing: 8) {
                            // Teal, glyph included: left alone the List draws the glyph in indigo.
                            Label(start, systemImage: "metronome").foregroundStyle(PocketColor.practice)
                            if plan.showsPlanLocks { PlanLockBadge() }
                        }
                    }
                    .planLockedValue(plan.showsPlanLocks)
                }
            }
        }
    }

    private func attachButton(_ source: ReferenceSource) -> some View {
        Button { attaching = true } label: {
            Label(ReferenceFiling.attachTitle(for: source),
                  systemImage: source.isFiled && source.isAttachment ? "arrow.right.circle" : "plus.circle")
        }
    }

    // MARK: - Edit

    /// Filed: a menu naming each place, since the note is that place's, or a button for one row. Filed
    /// nowhere: a button for the newest row, as nothing tells its rows apart; another note is edited by
    /// holding it.
    @ViewBuilder
    private func editControl(_ source: ReferenceSource) -> some View {
        if source.rows.count == 1 || !source.isFiled {
            Button("Edit") { editing = .editing(source.newest) }
        } else {
            Menu("Edit") {
                ForEach(Self.usesInOrder(source), id: \.uid) { row in
                    Button(row.place?.name ?? "Kept for later") { editing = .editing(row) }
                }
            }
        }
    }

    /// The editor's save. A file is renamed, never re-pointed, and never groups (ADR 0167 phase 2, D3).
    /// A link's name and address go to every row of its source, so it stays one source; the note goes to
    /// the row being edited and no other.
    private func commit(_ draft: ReferenceLinkDraft, title: String, url: String, note: String) {
        guard let row = draft.link else { return }
        if row.isAttachment {
            ReferenceLinkStore.updateAttachment(row, title: title, note: note)
        } else {
            let siblings = ReferenceLibrary.source(containing: row.uid, in: links)?.rows ?? [row]
            guard ReferenceLinkStore.update(row, title: title, url: url, note: note) else { return }
            for sibling in siblings where sibling.uid != row.uid {
                ReferenceLinkStore.update(sibling, title: title, url: url, note: sibling.note)
            }
        }
        try? context.save()
    }

    // MARK: - Delete

    private func delete(_ source: ReferenceSource) {
        ReferenceLinkStore.delete(source, in: context)
        try? context.save()
        dismiss()
    }
}

/// One place a source is used: the place, its kind, and the note that place keeps. A row kept for
/// later reads *Kept for later* in the place's stead.
struct ReferenceUseRow: View {
    let row: ReferenceLink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let place = row.place {
                Text(place.name)
                    .font(.futura(.body))
                    .foregroundStyle(place.kind.tint)
                Text(place.detail)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                Text("Kept for later")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            if let note = row.displayNote {
                Text(note)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
