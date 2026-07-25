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

    var body: some View {
        NavigationStack {
            Form {
                Section("Length") {
                    Picker("Length", selection: $length) {
                        ForEach(SessionLength.allCases) { length in
                            Text(length.displayName).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
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
                    Text("Drills and passages from every song in “\(collection)”, sized to fit — "
                         + "reorder or trim before you save.")
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
