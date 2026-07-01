import SwiftData
import SwiftUI

/// The **Loops** library inside Practice (ADR 0046 Phase B): the focused list of song loops you've
/// **measured** (a command tempo set), pushed from the Practice hub. A measured loop is a trainable
/// unit — tapping it opens its `LoopRunView` to train the same warm-up → dwell → reach → back-off
/// staircase as an exercise, against the loop's time-stretched audio.
///
/// No creation or deletion here: a loop belongs to its **song**, made and removed on the waveform
/// screen. This library is a read-through onto the loops worth training. The `commandTempo != nil`
/// gate is an **in-memory** filter, not a SwiftData optional `#Predicate` (which starves the main
/// thread — see `PracticeRunUITests`). Sort key + direction and the search query narrow the list in
/// memory too (ADR 0056), reusing the pure `PracticeLibrarySort`.
struct LoopLibraryView: View {
    @Query private var allLoops: [Loop]
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("loopLibrarySort") private var sortKey: LoopSortKey = .song
    @AppStorage("loopLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""

    /// The measured loops (a command set) narrowed by search and ordered by the current sort.
    private var visibleLoops: [Loop] {
        let measured = allLoops
            .filter { $0.commandTempo != nil }
            .filter { PracticeLibrarySort.loopMatches(fields(for: $0), query: searchText) }
        return PracticeLibrarySort.sortedLoops(measured, by: sortKey,
                                               ascending: sortAscending, fields: fields(for:))
    }

    /// Are there measured loops at all, before the search narrows them? Distinguishes the
    /// "none yet" empty state from the "no search matches" one.
    private var hasMeasuredLoops: Bool { allLoops.contains { $0.commandTempo != nil } }

    private func fields(for loop: Loop) -> LoopSortFields {
        LoopSortFields(name: loop.name, songTitle: loop.song?.title ?? "",
                       command: loop.command, mastery: loop.mastery)
    }

    var body: some View {
        List {
            if !hasMeasuredLoops {
                Text("No measured loops yet. Open a song, set a loop's command tempo on the "
                     + "waveform, and it'll show up here to train.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if visibleLoops.isEmpty {
                Text("No loops match “\(searchText)”.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(visibleLoops) { loop in
                    NavigationLink {
                        LoopRunView(loop: loop)
                    } label: {
                        PracticeUnitRow(title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                                        context: loop.song?.title,
                                        progress: "Command \(LoopCommandRamp.percent(loop.command))% → "
                                            + "\(LoopCommandRamp.percent(loop.derivedTargetSpeed))%")
                    }
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Loops")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Loops and songs")
        .toolbar {
            if hasMeasuredLoops {
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
        }
    }

    /// The sort control — a menu whose label spells out the active key with a direction arrow, and
    /// whose contents pick the key and flip ascending/descending (ADR 0056, mirroring the library).
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortKey) {
                ForEach(LoopSortKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
            Picker("Order", selection: $sortAscending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                Text(sortKey.label)
            }
            .tint(PocketColor.practice)
        }
        .accessibilityLabel("Sort by \(sortKey.label), \(sortAscending ? "ascending" : "descending")")
    }
}

#Preview("Loops — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return NavigationStack { LoopLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
