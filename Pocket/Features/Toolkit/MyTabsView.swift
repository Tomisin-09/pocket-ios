import SwiftData
import SwiftUI

/// **My tabs** (ADR 0235 D2): the tabs the player wrote on the neck, the one changed last at the top.
/// Tap a tab to read it, with **Edit**; hold or swipe it to rename or delete it, and a delete can be undone
/// from the toast; **+** writes a new one. Written tabs are not in the Journal: this is their only home.
struct MyTabsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WrittenTab.changedAt, order: .reverse) private var tabs: [WrittenTab]

    /// Deferred delete with Undo, as every list in the app (Slice 3).
    @State private var rowDeletion = RowDeletionCoordinator()
    /// The tab being renamed, by its uid (ADR 0090: never a model's `persistentModelID`), and the name so far.
    @State private var renamingUID: UUID?
    @State private var renameText = ""

    private var visible: [WrittenTab] { tabs.filter { !rowDeletion.isPending($0.uid) } }

    var body: some View {
        Group {
            if visible.isEmpty { emptyState } else { list }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("My tabs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { TabWriterView(tab: nil) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New tab")
            }
        }
        .pocketRowUndoHost(rowDeletion)
        // One alert for the screen, at its root, keyed by the tab's uid.
        .alert("Rename tab", isPresented: renaming) {
            TextField("Tab name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveRename() }
        }
        .tint(PocketColor.toolkit)
    }

    private var list: some View {
        List {
            ForEach(visible) { tab in
                NavigationLink { WrittenTabView(tab: tab) } label: { row(tab) }
                    .listRowBackground(PocketColor.background)
                    .pocketRowActions(tab.displayTitle,
                                      tint: PocketColor.toolkit,
                                      menu: [PocketRowMenuItem("Rename", systemImage: "pencil") { startRename(tab) }],
                                      delete: PocketRowDelete(id: tab.uid, name: tab.displayTitle) {
                                          modelContext.delete(tab)
                                      })
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// Its title and when it last changed, then how many notes and sections it has, and on what.
    private func row(_ tab: WrittenTab) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(tab.displayTitle)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(WrittenTab.day(tab.changedAt))
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(tab.payload.summary)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No tabs yet", systemImage: ToolkitSection.myTabs.info.icon)
        } description: {
            Text("Write a riff or a line you play, one note at a time on the neck.")
        } actions: {
            NavigationLink { TabWriterView(tab: nil) } label: {
                Label("Write a tab", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(PocketColor.toolkit)
        }
    }

    // MARK: - Rename

    private var renaming: Binding<Bool> {
        Binding(get: { renamingUID != nil }, set: { if !$0 { renamingUID = nil } })
    }

    private func startRename(_ tab: WrittenTab) {
        renameText = tab.title
        renamingUID = tab.uid
    }

    /// A rename is a change: the tab moves to the top.
    private func saveRename() {
        guard let uid = renamingUID, let tab = tabs.first(where: { $0.uid == uid }) else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != tab.title else { return }
        tab.title = trimmed
        tab.changedAt = .now
    }
}

#Preview("My tabs") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: WrittenTab.self, configurations: .init(isStoredInMemoryOnly: true))
    let content = TabContent(labels: [.fretted(string: 5, fret: 0), .fretted(string: 5, fret: 3)], bars: [],
                             sections: [TabSection(start: 0, name: "Intro")])
    let payload = WrittenTabPayload(content: content, tuningLabel: "Guitar · Standard")
    container.mainContext.insert(WrittenTab(title: "Morning riff", tabData: payload.encoded))
    return NavigationStack { MyTabsView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
