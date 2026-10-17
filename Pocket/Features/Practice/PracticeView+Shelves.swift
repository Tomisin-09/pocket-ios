import SwiftUI

/// The hub's three library shelves (ADR 0257 D3, D5, D6): Routines, Exercises and Loops. Each is a
/// header with **All N ›**, then one fixed-height row that swipes sideways.
extension PracticeView {

    // MARK: - Routines (D3)

    var routinesShelf: some View {
        let saved = savedRoutines
        let history = routineHistory
        let shelf = PracticeHubShelves.routineShelf(saved, placement: {
            .init(isFavorite: $0.isFavorite, lastPractised: history.dates[$0.uid], dateAdded: $0.dateAdded)
        }, id: \.uid.uuidString)
        return VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: "Routines", linkText: allLinkText(saved.count),
                        linkAccessibilityLabel: "Routines, \(saved.count)") {
                RoutineLibraryView()
            }
            shelfRow {
                HStack(alignment: .top, spacing: PracticeHubMetrics.shelfSpacing) {
                    ForEach(shelf, id: \.uid) { routine in
                        routineCard(routine, history: history)
                    }
                    NavigationLink {
                        RoutineDetailView(container: context.container, existing: nil)
                    } label: {
                        DashedNewTile(title: "New routine", width: PracticeHubMetrics.newRoutineWidth,
                                      stacked: true)
                    }
                    .buttonStyle(.plain)
                }
                // Every card as tall as the tallest, without fixing a height Dynamic Type would break.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func routineCard(_ routine: Routine,
                             history: (counts: [UUID: Int], dates: [UUID: Date])) -> some View {
        let name = routine.name.isEmpty ? "Untitled routine" : routine.name
        let minutes = PracticePlanner.estimatedMinutes(forRoutine: routine)
        let summary = minutes > 0 ? "\(routine.blockSummary) · ~\(minutes) min" : routine.blockSummary
        let status: PracticeReminderPlan.Status = practiceReminder.map {
            PracticeReminderPlan.status(for: $0.schedule(for: routine.uid),
                                        permission: notificationPermission, now: .now)
        } ?? .off
        return RoutineShelfCard(
            name: name, isFavorite: routine.isFavorite, summary: summary,
            line: PracticeHubShelves.cardLine(reminder: status, sessions: history.counts[routine.uid] ?? 0,
                                              lastPractised: history.dates[routine.uid]),
            onPlay: { playing = routine; haptic(.light) },
            destination: { RoutineDetailView(container: context.container, existing: routine) })
    }

    // MARK: - Exercises (D5)

    var exercisesShelf: some View {
        let tiles = PracticeHubShelves.categoryTiles(exercises.map(\.template))
        let items = tiles.map(ExerciseShelfItem.category) + [.newExercise]
        // Two rows, filled column by column (Basic over Warm-up, then Strumming over Picking), in the
        // picker's order. Built as columns of two rather than a `LazyHGrid`, whose rows would have to
        // be a fixed height that Dynamic Type would overflow.
        let columns = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        return VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: "Exercises", linkText: allLinkText(exercises.count),
                        linkAccessibilityLabel: "Exercises, \(exercises.count)") {
                ExerciseLibraryView()
            }
            shelfRow {
                HStack(alignment: .top, spacing: PracticeHubMetrics.shelfSpacing) {
                    ForEach(columns.indices, id: \.self) { index in
                        VStack(spacing: PracticeHubMetrics.shelfSpacing) {
                            ForEach(columns[index]) { exerciseShelfItem($0) }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func exerciseShelfItem(_ item: ExerciseShelfItem) -> some View {
        switch item {
        case .category(let tile):
            NavigationLink { ExerciseLibraryView(category: tile.template) } label: {
                ShelfTile(icon: tile.template.iconName, tint: PocketColor.practice,
                          wash: PocketColor.practiceCircleWash, title: tile.template.displayName,
                          caption: "\(tile.count) drill\(tile.count == 1 ? "" : "s")")
            }
            .buttonStyle(.plain)
        case .newExercise:
            Button { creatingExercise = true; haptic(.light) } label: {
                DashedNewTile(title: "New exercise")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Loops (D6)

    var loopsShelf: some View {
        let measured = measuredLoops
        let groups = PracticeHubShelves.songGroups(measured, song: \.song, id: \.persistentModelID,
                                                   title: \.title, lastPractised: \.lastPracticed)
        return VStack(alignment: .leading, spacing: 12) {
            // The link shows even with nothing measured, as on every shelf: the library's *Show all
            // loops* is the way to an unmeasured one (ADR 0138), so it must be reachable before
            // anything is measured.
            ShelfHeader(title: "Loops", linkText: allLinkText(measured.count),
                        linkAccessibilityLabel: "Loops, \(measured.count)") {
                LoopLibraryView()
            }
            if groups.isEmpty {
                loopsEmptyNote
            } else {
                shelfRow {
                    HStack(spacing: PracticeHubMetrics.shelfSpacing) {
                        ForEach(groups, id: \.song.persistentModelID) { group in
                            NavigationLink { LoopLibraryView(song: group.song) } label: {
                                ShelfTile(icon: "music.note", tint: PocketColor.library,
                                          wash: PocketColor.libraryCircleWash, title: group.song.title,
                                          caption: "\(group.count) loop\(group.count == 1 ? "" : "s")")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// What the Loops shelf says before it has a tile: where loops come from, or — with loops drawn
    /// but none measured — what makes one land here.
    private var loopsEmptyNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.library)
                .frame(width: 34, height: 34)
                .background(Circle().fill(PocketColor.libraryCircleWash))
                .accessibilityHidden(true)
            Text(allLoops.isEmpty ? "Loops you make in your songs land here."
                                  : "Set a loop's command tempo in its song and it lands here to train.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.surfaceStandard.opacity(0.6)))
        .padding(.horizontal, 16)
    }

    // MARK: - Shelf row

    /// One sideways-swiping row: inset 16 pt at rest, bleeding to the screen's right edge so the next
    /// card peeks in to say there is more. Cards snap into place.
    func shelfRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }
}

/// One cell on the Exercises shelf: a category you have drills in, or the tile that makes a new one.
enum ExerciseShelfItem: Identifiable {
    case category(PracticeHubShelves.CategoryCount)
    case newExercise

    var id: String {
        switch self {
        case .category(let tile): tile.template.rawValue
        case .newExercise: "new"
        }
    }
}
