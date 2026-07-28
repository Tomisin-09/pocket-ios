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
    @Query private var routines: [Routine]
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112); safe preview defaults (free / no-op).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

    /// Count of trainable loops — those with a measured command tempo (in-memory filter, not a
    /// SwiftData optional `#Predicate`, which starves the main thread; see `PracticeRunUITests`).
    private var measuredLoopCount: Int { allLoops.lazy.filter { $0.commandTempo != nil }.count }

    var body: some View {
        List {
            Section {
                plannerCard
                libraryRow(title: "Routines", subtitle: "Hand-built practice sessions",
                           icon: "list.bullet.rectangle.portrait", count: routines.count) {
                    RoutineLibraryView()
                }
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
        // Cap the list to a readable column at regular width (iPad / landscape); no-op at
        // compact width, dormant on the iPhone-only v1 build (ADR 0105).
        .readableWidth()
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Planner (V2 planner, Slice 3)

    /// The orchestration entry (ADR 0046 / 0015): pushes the planner, where you pick a duration, keep
    /// goals, and generate a session from your units. The guided "build a session" altitude above the
    /// focused libraries.
    private var plannerCard: some View {
        // Today's session is a Pro feature (ADR 0112): Pro pushes the planner; free gets the paywall.
        Group {
            if isPro {
                NavigationLink { PlannerView() } label: { plannerCardLabel }
            } else {
                Button { presentPaywall(.planner) } label: { plannerCardLabel }
                    .buttonStyle(.plain)
            }
        }
        .listRowBackground(PocketColor.background)
        .accessibilityLabel("Today's session")
        .accessibilityHint("A session shaped by your goals")
    }

    private var plannerCardLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.practiceCircleWash))
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's session")
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("A session shaped by your goals")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: isPro ? "chevron.right" : "lock.fill")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
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
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle)
                        .font(.futura(.caption))
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
    let container = try! ModelContainer(for: Exercise.self, Song.self, Routine.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96))
    container.mainContext.insert(Exercise(name: "Spider", currentTempo: 60))
    return NavigationStack { PracticeView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Practice hub — regular width (iPad groundwork)") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self, Song.self, Routine.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96))
    return NavigationStack { PracticeView() }
        .modelContainer(container)
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}
