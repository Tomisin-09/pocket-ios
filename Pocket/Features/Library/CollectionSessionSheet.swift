import SwiftData
import SwiftUI

/// The small "Build a session from these songs" configurator (ADR 0118) — reached from the Library
/// when it's filtered to a single collection. Two dials: a `SessionLength` (how long) and an
/// `OrderMode` (how ordered). **Build** generates `CollectionSessionBuilder.sessionBlocks` and pushes
/// them into the existing `RoutineDetailView(generatedSession:)` review flow, so the session persists
/// only on **Save** — Cancel/back leaves no orphan (the ADR-0111 seam).
///
/// Owns its own `NavigationStack` (it's a sheet), and pushes the review screen inside it — the same
/// pattern `SongDetailsSheet` uses for the per-song build.
struct CollectionSessionSheet: View {
    let collection: String
    /// The whole library; the builder matches by collection label so search-narrowing the Library
    /// doesn't shrink the session — it's built over the entire collection.
    let songs: [Song]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var length: SessionLength = .default
    @State private var order: OrderMode = .structured
    /// Fresh per build so a return trip reshuffles; set the instant Build is tapped.
    @State private var seed: UInt64 = .random(in: .min ... .max)
    @State private var building = false

    /// What the collection offers the builder — deduped exercises/loops + song count (ADR 0118),
    /// shown as the tally so the player sees the session depends on how much is linked here.
    private var pool: CollectionSessionBuilder.CollectionPool {
        CollectionSessionBuilder.pool(for: collection, in: songs)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    tallyRow("Exercises", pool.exercises, "guitars")
                    tallyRow("Loops", pool.loops, "repeat")
                    tallyRow("Songs", pool.songs, "music.note.list")
                } header: {
                    Text("In “\(collection)”")
                } footer: {
                    Text("Your session is drawn from these. A collection with more linked exercises "
                         + "and loops makes a fuller session — link more from each song's details to "
                         + "enrich it.")
                }

                Section {
                    Picker("Length", selection: $length) {
                        ForEach(SessionLength.allCases) { length in
                            Text(lengthLabel(length)).monospacedDigit().tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Length")
                } footer: {
                    Text("An estimate of the whole sitting — the focused work plus its rests and a "
                         + "play-through or two. The exact length shows on the next screen.")
                }

                Section {
                    Picker("Order", selection: $order) {
                        ForEach(OrderMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(order.detail)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                } header: {
                    Text("Order")
                } footer: {
                    Text("Drills and passages from every song in “\(collection)”, sized to fit. "
                         + "It's a starting point — reorder, trim or add more (even exercises from "
                         + "outside this collection) before you save.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Build a session")
            .navigationBarTitleDisplayMode(.inline)
            // Push (not a modal cover) so RoutineDetailView's provisional, Save-only state keeps the
            // nav back button to abandon it — matching the SongDetailsSheet / planner flow.
            .navigationDestination(isPresented: $building) {
                RoutineDetailView(
                    container: context.container,
                    generatedSession: CollectionSessionBuilder.sessionBlocks(
                        for: collection, in: songs, length: length, order: order, seed: seed),
                    defaultName: CollectionSessionBuilder.defaultName(for: collection))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Build") {
                        seed = .random(in: .min ... .max)
                        building = true
                    }
                    .tint(PocketColor.practice)
                }
            }
        }
    }

    /// A Length tab's label — the preset name plus its estimated total minutes ("Quick · ~22m"), so
    /// each tab reads as a real sitting rather than a bare word. Falls back to the plain name if the
    /// collection can't yield an estimate (guarded against, as the sheet only shows when it can).
    private func lengthLabel(_ length: SessionLength) -> String {
        let minutes = CollectionSessionBuilder.estimatedMinutes(for: collection, in: songs, length: length)
        guard minutes > 0 else { return length.displayName }
        return "\(length.displayName) · ~\(minutes)m"
    }

    /// One tally row — an item kind, its icon, and a right-aligned count (tabular digits so the
    /// numbers line up).
    private func tallyRow(_ label: String, _ count: Int, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.futura(.body).monospacedDigit())
                .foregroundStyle(PocketColor.textSecondary)
        }
        .listRowBackground(PocketColor.background)
    }
}

#Preview("Collection session") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self, Exercise.self, Loop.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    song.collections = ["blues"]
    container.mainContext.insert(song)
    return CollectionSessionSheet(collection: "blues", songs: [song])
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
