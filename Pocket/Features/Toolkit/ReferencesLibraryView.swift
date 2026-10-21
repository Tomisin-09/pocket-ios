import SwiftData
import SwiftUI

/// **References** (ADR 0264 D4): every source the player keeps, wherever it is filed. A search field,
/// then **Not filed**, then **Everything**, newest first in each. A source used in two places is one row
/// here (D3). Tap one to open its screen (D5); **＋** adds a link, a photo or a file, kept for later.
///
/// Free for good (ADR 0263: keeping is free), so the screen carries no `PlanGated`. The rules are
/// `ReferenceLibrary`'s; this draws what they return.
///
/// **No options menu yet.** D4 names 0126's grammar, `ellipsis.circle` then ＋, but nothing for the menu
/// to hold: the order is fixed (newest first) and search covers finding. An empty menu would be a
/// control that does nothing, so the bar carries ＋ alone, as My tabs does, until there is an option.
struct ReferencesLibraryView: View {
    @Query(sort: \ReferenceLink.dateAdded, order: .reverse) private var links: [ReferenceLink]

    @State private var searchText = ""
    /// The link being added, or the file just picked and waiting for its name, presented at the root as
    /// every References host does (`ReferenceLinkEditing`).
    @State private var editing: ReferenceLinkDraft?
    @State private var presenting: ReferenceAttachmentPresentation?

    /// What ＋ adds to: no owner (D1).
    private let keep = KeepForLater()

    var body: some View {
        let sources = ReferenceLibrary.sources(links)
        let sections = ReferenceLibrary.sections(sources, matching: searchText)
        Group {
            if sources.isEmpty {
                emptyState
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                list(sections)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("References")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search references")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { addMenu }
        }
        .referenceLinkEditing($editing, owner: keep, accent: PocketColor.toolkit)
        .referenceAttachments($presenting, naming: $editing, owner: keep, accent: PocketColor.toolkit)
        .tint(PocketColor.toolkit)
    }

    private func list(_ sections: ReferenceLibrary.Sections) -> some View {
        List {
            if !sections.notFiled.isEmpty {
                Section {
                    rows(sections.notFiled)
                } header: {
                    HStack {
                        Text("Not filed")
                        Spacer()
                        Text("\(sections.notFiled.count)")
                    }
                }
            }
            if !sections.everything.isEmpty {
                Section("Everything") { rows(sections.everything) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func rows(_ sources: [ReferenceSource]) -> some View {
        ForEach(sources) { source in
            // Opened by the newest row's uid, never by the link: an edit can change the address, and the
            // screen follows the row it was opened from (ADR 0090's rule, for a value with no model).
            NavigationLink { ReferenceSourceView(anchor: source.newest.uid) } label: {
                ReferenceSourceRow(source: source)
            }
            .listRowBackground(PocketColor.surfaceSubtle)
        }
    }

    /// The three ways in an owner's section offers, here in one menu: the first half of adding, as there.
    private var addMenu: some View {
        Menu {
            addButtons
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add a reference")
    }

    @ViewBuilder private var addButtons: some View {
        Button { editing = .adding } label: { Label("Add a link", systemImage: "link") }
        Button { presenting = .pickingPhoto } label: { Label("Choose a photo", systemImage: "photo.on.rectangle") }
        Button { presenting = .pickingFile } label: { Label("Choose a file", systemImage: "folder") }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No references yet", systemImage: ToolkitSection.references.info.icon)
        } description: {
            Text("Keep the lessons, tabs and files you learn from. Add one here to file later, or on an "
                 + "exercise, song, loop or routine.")
        } actions: {
            Button { editing = .adding } label: { Label("Add a link", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
                .tint(PocketColor.toolkit)
        }
    }
}

/// One source in the library (D4): its title; its site or kind and when it was saved; *On Triad climb ·
/// Morning routine* in each place's colour; then the first line of its note.
struct ReferenceSourceRow: View {
    let source: ReferenceSource

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ReferenceSourceIcon(link: source.newest, side: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayTitle)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(2)
                // The Journal's days, as My tabs reads them.
                Text("\(source.origin) · \(WrittenTab.day(source.newest.dateAdded))")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                if !source.distinctPlaces.isEmpty {
                    Text(Self.placesLine(source.distinctPlaces))
                        .font(.futura(.caption))
                        .lineLimit(2)
                }
                if let note = source.noteLine {
                    Text(note)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// *On Triad climb · Slow Bend*: each name in its place's colour, the joins in the secondary text.
    static func placesLine(_ places: [ReferencePlace]) -> AttributedString {
        var line = AttributedString("On ")
        line.foregroundColor = PocketColor.textSecondary
        for (index, place) in places.enumerated() {
            if index > 0 {
                var join = AttributedString(" · ")
                join.foregroundColor = PocketColor.textSecondary
                line += join
            }
            var name = AttributedString(place.name)
            name.foregroundColor = place.kind.tint
            line += name
        }
        return line
    }
}

/// A reference's glyph at row size: the file's own thumbnail, or a link glyph drawn in the same tile so a
/// list of both reads as one list.
struct ReferenceSourceIcon: View {
    let link: ReferenceLink
    var side: CGFloat = 32

    var body: some View {
        if link.isAttachment {
            ReferenceAttachmentThumbnail(link: link, side: side)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(PocketColor.toolkitCircleWash)
                .overlay {
                    Image(systemName: "link")
                        .font(.footnote)
                        .foregroundStyle(PocketColor.toolkit)
                }
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        }
    }
}

#Preview("References") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: ReferenceLink.self, Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Triad climb")
    container.mainContext.insert(drill)
    container.mainContext.insert(ReferenceLink(title: "CAGED, the A shape", note: "The A shape starts at 3:40.",
                                               urlString: "https://youtube.com/watch?v=a"))
    container.mainContext.insert(ReferenceLink(title: "Triads across the neck",
                                               urlString: "https://youtube.com/watch?v=b", exercise: drill))
    return NavigationStack { ReferencesLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
