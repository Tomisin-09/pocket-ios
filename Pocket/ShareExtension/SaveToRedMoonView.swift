import SwiftUI

/// **Save to Red Moon** (ADR 0264 D8), as drawn: *Cancel* and *Save*; the item, with what to call it and
/// an optional *What you took from it*; then **Where it goes**, with *Keep for later* chosen, a search,
/// *Recent* and *Show everything*. D6's rules decide what's offered and what's locked, from the
/// snapshot (D9).
///
/// **Save writes and closes.** There is no *Open Red Moon*: a share extension has no public way to open
/// its app, and the reference is there the next time it opens.
struct SaveToRedMoonView: View {
    @Bindable var model: ShareSaveModel
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            content
                .background(PocketColor.background.ignoresSafeArea())
                .navigationTitle("Save to Red Moon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    if model.phase == .ready {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save", action: onSave).fontWeight(.semibold)
                        }
                    }
                }
                .alert("Not saved", isPresented: failureShowing) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.saveFailure ?? "")
                }
        }
        .tint(PocketColor.toolkit)
        .font(.futura(.body))
        .preferredColorScheme(model.snapshot?.appearance.colorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .refused(let reason):
            ContentUnavailableView {
                Label("Nothing to save", systemImage: "tray")
            } description: {
                Text(reason)
            }
        case .ready:
            form
        }
    }

    private var form: some View {
        List {
            Section { SharedItemCard(model: model) }
            Section {
                PlaceSearchField(text: $searchText,
                                 prompt: ReferenceDestinationPicker.searchPrompt(for: model.standing))
                    .listRowBackground(PocketColor.surfaceSubtle)
            } header: {
                Text("Where it goes")
            }
            Section {
                KeepForLaterRow(isSelected: model.destination == nil) { model.destination = nil }
            } footer: {
                if model.snapshot == nil { Text(Self.noSnapshot) }
            }
            if model.snapshot != nil {
                ReferencePlaceSections(rows: model.rows, standing: model.standing, searchText: searchText,
                                       picking: .held(selected: model.destination)) { row in
                    model.destination = row.id
                    searchText = ""
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var failureShowing: Binding<Bool> {
        Binding(get: { model.saveFailure != nil }, set: { if !$0 { model.saveFailure = nil } })
    }

    /// Before the app has opened once since it was installed, it hasn't said where things can go.
    static let noSnapshot = "Your songs, loops and drills show here once you've opened Red Moon."
}

/// What's being saved: its glyph, a title to edit, where it's from, and *What you took from it*.
private struct SharedItemCard: View {
    @Bindable var model: ShareSaveModel

    var body: some View {
        HStack(spacing: 12) {
            ReferencePlaceGlyph(icon: icon, tint: PocketColor.toolkit)
            VStack(alignment: .leading, spacing: 2) {
                TextField(placeholder, text: $model.title)
                    .font(.futura(.body))
                    .submitLabel(.done)
                Text(source)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .listRowBackground(PocketColor.surfaceSubtle)
        VStack(alignment: .leading, spacing: 4) {
            Text("What you took from it")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            TextField("Optional: the bit at 3:40, only the chorus…", text: $model.note, axis: .vertical)
                .font(.futura(.body))
                .lineLimit(1...5)
        }
        .listRowBackground(PocketColor.surfaceSubtle)
    }

    private var icon: String {
        guard case .file(_, let offer, _, _) = model.payload else { return "link" }
        return switch offer {
        case .pdf: "doc.richtext"
        case .plainText: "doc.plaintext"
        case .markdown: "text.alignleft"
        case .image, .webLink: "photo"
        }
    }

    /// The second line: the link's site, or the file's kind.
    private var source: String {
        switch model.payload {
        case .link(let url): ReferenceURL.displayHost(url) ?? url
        case .file(_, let offer, _, _): offer.kindNoun
        default: ""
        }
    }

    /// The title field's placeholder: what the row is called if the player leaves it empty.
    private var placeholder: String {
        switch model.payload {
        case .link(let url): ReferenceURL.displayHost(url) ?? "Title"
        case .file(_, let offer, _, _): offer.kindNoun
        default: "Title"
        }
    }
}

/// *Keep for later* (D1), the default: no place, so it lands in *Not filed*.
private struct KeepForLaterRow: View {
    let isSelected: Bool
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 12) {
                ReferencePlaceGlyph(icon: "tray", tint: PocketColor.toolkit)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep for later").font(.futura(.body)).foregroundStyle(PocketColor.textPrimary)
                    Text("In Toolkit › References")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                ReferencePlaceMark(isSelected: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.surfaceSubtle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The search over the places, under *Where it goes* as drawn, not in the navigation bar: the item
/// comes first on this screen.
private struct PlaceSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PocketColor.textSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .font(.futura(.body))
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(PocketColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
    }
}

extension SharedContent.Offer {
    /// What a file of this kind is called on its own, as a row with no title reads
    /// (`ReferenceLinkKind.capitalizedNoun`).
    var kindNoun: String {
        switch self {
        case .image: ReferenceLinkKind.image.capitalizedNoun
        case .pdf: ReferenceLinkKind.pdf.capitalizedNoun
        case .plainText: ReferenceLinkKind.text.capitalizedNoun
        case .markdown: ReferenceLinkKind.markdown.capitalizedNoun
        case .webLink: ReferenceLinkKind.link.capitalizedNoun
        }
    }
}

#if DEBUG
#Preview("Save to Red Moon, lapsed") {
    let day: TimeInterval = 86_400
    let snapshot = ShareOwnerSnapshot(standing: .lapsed, appearance: .system, places: [
        ReferenceDestination(id: "exercise:a", kind: .exercise, name: "CAGED shape 2", lastPracticed: .now),
        ReferenceDestination(id: "song:b", kind: .song, name: "Slow Bend", parent: "Jack Trader",
                             lastPracticed: .now - day),
        ReferenceDestination(id: "loop:c", kind: .loop, name: "Bridge bend", parent: "Slow Bend",
                             lastPracticed: .now - day),
        ReferenceDestination(id: "routine:d", kind: .routine, name: "Morning routine", lastPracticed: .now - 2 * day)
    ])
    let model = ShareSaveModel(snapshot: snapshot)
    model.preview(.link("https://youtube.com/watch?v=abc"), title: "CAGED, the A shape")
    return SaveToRedMoonView(model: model, onCancel: {}, onSave: {})
}
#endif
