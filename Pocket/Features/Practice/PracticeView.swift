import SwiftData
import SwiftUI

/// **Practice** — a top-level destination (ADR 0046), peer to the song library and the
/// metronome, reached from Home. The home for everything you *train*, structured as a hub at two
/// altitudes:
///
/// - **Build today's session** — the guided path (the planner, V2): a placeholder until Phase C,
///   so the information architecture reads correctly from day one.
/// - **Two unit libraries** — the focused path, split for clarity (and accessibility): an
///   **Exercises** library (click-only command drills) and a **Loops** library (measured song
///   loops). Each pushes its own list; the underlying models stay separate (`Exercise` is
///   audio-free, `Loop` is bound to a file) but both are "things you train," which is the
///   multi-source surface the V2 planner composes a session from.
///
/// Relies on an ambient `NavigationStack` (pushed from Home, like `LibraryView`) rather than owning
/// one, so the library pushes land in Home's navigation.
struct PracticeView: View {
    @Query private var exercises: [Exercise]
    @Query private var allLoops: [Loop]

    /// Count of trainable loops — those with a measured command tempo (in-memory filter, not a
    /// SwiftData optional `#Predicate`, which starves the main thread; see `PracticeRunUITests`).
    private var measuredLoopCount: Int { allLoops.lazy.filter { $0.commandTempo != nil }.count }

    var body: some View {
        List {
            Section {
                plannerCard
            }
            Section("Your units") {
                libraryRow(title: "Exercises", subtitle: "Click-only command drills",
                           icon: "metronome", count: exercises.count) {
                    ExerciseLibraryView()
                }
                libraryRow(title: "Loops", subtitle: "Measured song loops",
                           icon: "repeat", count: measuredLoopCount) {
                    LoopLibraryView()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Planner placeholder (V2)

    /// The orchestration entry — disabled until Phase C. Present now so Practice reads as the
    /// two-altitude space the ADR describes (guided "build a session" above the focused libraries).
    private var plannerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(PocketColor.practice)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.practice.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Build today's session")
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                Text("Guided routine from your units")
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text("SOON")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(PocketColor.barPlayed))
        }
        .listRowBackground(PocketColor.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Build today's session, coming soon")
    }

    // MARK: - Library rows

    /// A hub entry that pushes one unit library, with an icon, a one-line description, and a count.
    private func libraryRow<Destination: View>(title: String, subtitle: String, icon: String,
                                               count: Int,
                                               @ViewBuilder destination: @escaping () -> Destination)
        -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(PocketColor.background)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityHint(subtitle)
    }
}

#Preview("Practice hub") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self, Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96))
    container.mainContext.insert(Exercise(name: "Spider", currentTempo: 60))
    return NavigationStack { PracticeView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
