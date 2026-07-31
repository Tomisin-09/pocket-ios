import SwiftData
import SwiftUI

/// The **Journal space** (Wave 2, ADR 0100): a single, read-only practice-history timeline that
/// aggregates journal **notes** and audio **takes** across every owner — song loops (Library) and
/// exercises (Practice) alike. A top-level Home destination (the 4th nav strip), because the feed is
/// cross-cutting: it belongs above Practice and Library, not inside either.
///
/// Read-only by design — reflection, not authoring: writing/editing entries stays in the per-owner
/// `JournalSheet`. Takes are the exception, since playing one *is* their nature. All the merge /
/// filter / owner-label logic is the pure `JournalTimeline`; this view only queries, groups by day,
/// and renders.
struct JournalTabView: View {
    // Unfiltered queries (no optional `#Predicate` — those starve the main thread); the merge and
    // scope filter happen in memory via `JournalTimeline`.
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Recording.createdAt, order: .reverse) private var takes: [Recording]

    @State private var scope: JournalTimeline.Scope = .all
    /// Free-text search over song / loop / exercise / template / date (`JournalTimeline.searchHaystack`).
    @State private var query = ""
    /// Day order — newest-first by default; flip to walk the history forwards.
    @State private var sortOrder: JournalTimeline.SortOrder = .newest
    /// One take plays at a time; stopped on dismiss (mirrors `TakesSheet`).
    @State private var player = RecordingPlayer()

    /// The scope- then search-filtered feed.
    private var items: [JournalTimeline.Item] {
        let scoped = JournalTimeline.filter(JournalTimeline.merge(entries: entries, takes: takes),
                                            scope: scope)
        return JournalTimeline.filter(scoped, query: query)
    }

    /// Day-sectioned for display (pure helper, shared with `JournalSheet`); `oldest` reverses both the
    /// day order and the within-day order.
    private var sections: [JournalGrouping.DaySection<JournalTimeline.Item>] {
        let grouped = JournalGrouping.byDay(items) { $0.date }
        switch sortOrder {
        case .newest:
            return grouped
        case .oldest:
            return grouped.reversed().map {
                JournalGrouping.DaySection(day: $0.day, entries: Array($0.entries.reversed()))
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            scopePicker
            if sections.isEmpty { emptyState } else { list }
        }
        // Cap to a readable column at regular width (iPad / landscape); no-op at compact
        // width, dormant on the iPhone-only v1 build (ADR 0105).
        .readableWidth()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .background(PocketColor.background.ignoresSafeArea())
        .searchable(text: $query, prompt: "Search by song, exercise, template or date")
        .toolbar {
            // Progress lives behind the same door as the timeline: both are read-only practice
            // history, so ADR 0117's screen is reached from here rather than from a new Home card —
            // which keeps Home's grouped layout (ADR 0102) unchanged until the deferred year tier and
            // card evolution land together. A fixed-width glyph, per the toolbar grammar (ADR 0126).
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PracticeProgressView()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .accessibilityLabel("Progress")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        Label("Newest first", systemImage: "arrow.down").tag(JournalTimeline.SortOrder.newest)
                        Label("Oldest first", systemImage: "arrow.up").tag(JournalTimeline.SortOrder.oldest)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort order")
            }
        }
        .onDisappear { player.stop() }
    }

    // MARK: - Scope filter

    private var scopePicker: some View {
        Picker("Show", selection: $scope) {
            Text("All").tag(JournalTimeline.Scope.all)
            Text("Notes").tag(JournalTimeline.Scope.notes)
            Text("Takes").tag(JournalTimeline.Scope.takes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(sections, id: \.day) { section in
                Section(dayHeader(section.day)) {
                    ForEach(section.entries) { item in
                        row(item).listRowBackground(PocketColor.background)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private func row(_ item: JournalTimeline.Item) -> some View {
        switch item {
        case .note(let entry):
            JournalEntryRow(entry: entry, ownerLabel: JournalTimeline.ownerLabel(for: item))
        case .take(let take):
            JournalTakeRow(take: take,
                           ownerLabel: JournalTimeline.ownerLabel(for: item),
                           isPlaying: player.isPlaying(take.fileName)) {
                player.toggle(take.fileName)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searching ? "magnifyingglass" : "book.closed")
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.textSecondary)
            Text(emptyTitle)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(emptyMessage)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Whether a live search is narrowing the feed (drives the "no matches" empty state).
    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var emptyTitle: String {
        if searching { return "No matches" }
        switch scope {
        case .all: return "Nothing here yet"
        case .notes: return "No notes yet"
        case .takes: return "No takes yet"
        }
    }

    private var emptyMessage: String {
        if searching {
            return "Nothing matches “\(query)”. Try a song, exercise, template, or date."
        }
        switch scope {
        case .all:
            return "Notes you write and takes you record — on your loops and exercises — gather here."
        case .notes:
            return "Jot a goal, a breakthrough, or a struggle after a run and it shows up here."
        case .takes:
            return "Arm recording next to Start training to capture your playing."
        }
    }

    // MARK: - Day header

    /// "Today" / "Yesterday" / a medium date for a section's day (mirrors `JournalSheet`).
    private func dayHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Take row

/// One take on the aggregated feed — a play/pause toggle, its owner caption, duration, and time.
/// Plays through the shared `RecordingPlayer` (one at a time). Read only bar the play control.
private struct JournalTakeRow: View {
    let take: Recording
    let ownerLabel: String?
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.futura(.title))
                    .foregroundStyle(PocketColor.journal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause take" : "Play take")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Take")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(take.durationLabel)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                    Spacer(minLength: 0)
                    Text(take.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if let ownerLabel {
                    Text(ownerLabel)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.journal)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Journal — mixed") {
    NavigationStack { JournalTabView() }
        .modelContainer(JournalTabPreview.container())
        .preferredColorScheme(.dark)
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Journal — regular width (iPad groundwork)") {
    NavigationStack { JournalTabView() }
        .modelContainer(JournalTabPreview.container())
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

/// Seeds an in-memory store with a mixed feed (loop + exercise notes and a take) for the preview.
/// Kept in a helper so the `#Preview` body stays a single view expression.
private enum JournalTabPreview {
    @MainActor static func container() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: Song.self, Loop.self, Exercise.self, JournalEntry.self, Recording.self,
            PracticeRun.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date()

        let song = Song.sample()
        song.title = "Little Wing"
        song.artist = "Jimi Hendrix"
        let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.9, repeats: 4)
        loop.mastery = 3
        loop.commandTempo = 0.9
        song.loops = [loop]
        context.insert(song)

        let drill = Exercise(name: "Chords", currentTempo: 84, commandTempo: 96)
        context.insert(drill)

        let breakthrough = JournalEntry.forExercise(text: "Clean run at 90% — finally locked it.",
                                                    kind: .breakthrough, commandBpmAtEntry: 96,
                                                    createdAt: now.addingTimeInterval(-3600))
        breakthrough.exercise = drill
        context.insert(breakthrough)

        let struggle = JournalEntry.forLoop(text: "Barre still buzzing on the B string.",
                                            kind: .struggle, masteryAtEntry: 3,
                                            commandTempoAtEntry: 0.9,
                                            createdAt: now.addingTimeInterval(-86_400))
        struggle.loop = loop
        context.insert(struggle)

        let take = Recording(fileName: "demo.m4a", duration: 48,
                             createdAt: now.addingTimeInterval(-7200), loop: loop)
        context.insert(take)

        try? context.save()
        return container
    }
}
