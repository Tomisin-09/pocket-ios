import SwiftData
import SwiftUI

/// The **add-unit picker** for the routine editor (ADR 0066, slice 2), structured like the
/// Apple Music **Library** — two levels deep, exactly like Library → Artists → an artist's
/// tracks. The root lists **buckets** (**Exercises**, **Loops**, **Songs**) over a **Recently
/// Added** shortcut. Drilling Exercises/Loops lands not on a flat list but on their **sub-buckets**
/// — Exercises group by their **template** (Strumming, Scales …), Loops group by their **song** —
/// and one more tap opens that group's units; **Songs** is a flat list (a song is the top entity).
/// Exercises come first (the exercises-first direction — technique mode, audio-free, works with an
/// empty library). Each grouped level also offers **All …** at its top, the same units flat and
/// A→Z, for when you know the unit's name but not the group it landed in (ADR 0127).
///
/// **Multi-add (ADR 0127):** a tap adds the unit to the routine *there and then* and leaves the
/// sheet open, so you can add a scale drill, back out, drill into Loops and add two more without
/// reopening the picker each time. An added row shows a check and a second tap takes it back out
/// again; **Done** closes. Blocks land in tap order, and — like every other edit in this screen —
/// only reach the store when the routine is Saved.
///
/// The picker keeps **no selection state of its own**: the editor owns the ids it has added and
/// hands them back each render (`addedIDs`), so the checkmarks can't disagree with the block list.
struct AddRoutineUnitSheet: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Loop.name) private var loops: [Loop]
    @Query(sort: \Song.title) private var songs: [Song]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    /// The row auditioning on the root screen (recently-added / search results) — one loop at a time.
    @State private var rootPlayingID: String?

    /// `RoutineUnitPick.pickID`s this sheet session has added, owned by the editor.
    var addedIDs: Set<String> = []
    /// Add the unit, or remove the block this session added for it. A no-op default keeps
    /// previews compiling.
    var onToggle: (RoutineUnitPick) -> Void = { _ in }

    /// Only loops with a measured command tempo are trainable in a routine (the same gate as the
    /// loop library — an unmeasured loop has no ramp for the player to run).
    private var trainableLoops: [Loop] { loops.filter { $0.commandTempo != nil } }

    /// Only songs whose audio the play-along can actually run — local/iCloud files (and the demo);
    /// Apple Music catalog items are browse/metadata only and can't be time-stretched (ADR 0001), so
    /// they'd be dead blocks and are excluded.
    private var playableSongs: [Song] { songs.filter { $0.ref.source != .appleMusic } }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    bucketsSection
                    if !recentlyAdded.isEmpty {
                        Section("Recently Added") {
                            ForEach(recentlyAdded) { row in
                                AddRoutineUnitRow(row: row, playingID: $rootPlayingID)
                                    .listRowBackground(PocketColor.background)
                            }
                        }
                    }
                } else {
                    searchResults
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises, loops, songs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: addedIDs.isEmpty ? nil : .bold))
                        .tint(PocketColor.practice)
                }
            }
        }
        // On the stack, not a level's list, so the running tally follows you into every drill-in.
        .safeAreaInset(edge: .bottom) { addedTally }
        .presentationDetents([.large])
    }

    /// The running tally of what this sheet session has put in the routine — the receipt for a
    /// picker that no longer dismisses on a pick, so "did that land?" is answered without closing.
    /// Absent at zero, so the sheet opens exactly as it always did.
    @ViewBuilder private var addedTally: some View {
        if !addedIDs.isEmpty {
            Text(addedIDs.count == 1 ? "1 block added" : "\(addedIDs.count) blocks added")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.practice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// The default browse view — the four typed buckets (ADR 0104 Slice 2 adds Ear training).
    @ViewBuilder private var bucketsSection: some View {
        Section {
            NavigationLink {
                GroupPickList(title: "Exercises", groups: exerciseGroups,
                              allRows: allExerciseRows)
            } label: {
                bucketRow(title: "Exercises", subtitle: "By template",
                          icon: "metronome", count: exercises.count)
            }
            .listRowBackground(PocketColor.background)

            NavigationLink {
                GroupPickList(title: "Loops", groups: loopGroups, allRows: allLoopRows)
            } label: {
                bucketRow(title: "Loops", subtitle: "By song",
                          icon: "repeat", count: trainableLoops.count)
            }
            .listRowBackground(PocketColor.background)

            NavigationLink {
                UnitPickList(title: "Songs", rows: playableSongs.map(songRow))
            } label: {
                bucketRow(title: "Songs", subtitle: "Play along",
                          icon: "music.note", count: playableSongs.count)
            }
            .listRowBackground(PocketColor.background)

            // Ear training (ADR 0104 Slice 2): the same loops, added as an ears-only block —
            // hum/sing a loop inside the routine. Kept a peer bucket so it's discoverable
            // without burying a mode toggle under Loops.
            NavigationLink {
                GroupPickList(title: "Ear training", groups: earLoopGroups,
                              allRows: allEarLoopRows)
            } label: {
                bucketRow(title: "Ear training", subtitle: "Hum & sing a loop",
                          icon: "ear", count: trainableLoops.count)
            }
            .listRowBackground(PocketColor.background)
        }
    }

    // MARK: - Search (ADR 0104 Slice 2 follow-up)
    //
    // A `.searchable` field flattens the buckets into typed result sections across **every** add-routine
    // element — exercises, loops, songs, and ear training (the same loops, ears-only). Matches on the
    // unit name plus a loop/song's song title, case/diacritic-insensitive.

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ text: String?) -> Bool {
        guard let text, !query.isEmpty else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }

    private var matchingExercises: [Exercise] { exercises.filter { matches($0.name) } }
    private var matchingLoops: [Loop] {
        trainableLoops.filter { matches($0.name) || matches($0.song?.title) }
    }
    private var matchingSongs: [Song] {
        playableSongs.filter { matches($0.title) || matches($0.artist) }
    }

    @ViewBuilder private var searchResults: some View {
        if matchingExercises.isEmpty && matchingLoops.isEmpty && matchingSongs.isEmpty {
            Text("No matches.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .listRowBackground(PocketColor.background)
        } else {
            resultSection("Exercises", rows: matchingExercises.map { exerciseRow($0) })
            resultSection("Loops", rows: matchingLoops.map(loopRow))
            // Loops appear again as ear-training picks — the same units, a different block (ADR 0104).
            resultSection("Ear training", rows: matchingLoops.map(earLoopRow))
            resultSection("Songs", rows: matchingSongs.map(songRow))
        }
    }

    @ViewBuilder private func resultSection(_ title: String, rows: [PickRow]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    AddRoutineUnitRow(row: row, playingID: $rootPlayingID)
                        .listRowBackground(PocketColor.background)
                }
            }
        }
    }

    // MARK: - Rows

    /// A bucket row — icon, name, one-line description, and a count — mirroring the Practice hub
    /// and the Apple Music Library buckets.
    private func bucketRow(title: String, subtitle: String, icon: String, count: Int) -> some View {
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
        .accessibilityLabel("\(title), \(count)")
    }

    // MARK: - Grouped data

    /// Exercises bucketed by their (immutable) **template**, in canonical menu order
    /// (`displayOrder` — the *full* set, so drills made under a now-retired template still group),
    /// dropping templates with no exercises. Each group drills into its own unit list.
    private var exerciseGroups: [PickGroup] {
        let byTemplate = Dictionary(grouping: exercises, by: \.template)
        return ExerciseTemplate.displayOrder.compactMap { template in
            guard let members = byTemplate[template], !members.isEmpty else { return nil }
            return PickGroup(id: template.rawValue, title: template.displayName,
                             icon: template.iconName, rows: members.map { exerciseRow($0) })
        }
    }

    /// Trainable loops bucketed by their **song**, songs A→Z, loops with no song collected under
    /// "No song" last. Each group drills into its own unit list. The standard **Loops** bucket adds a
    /// command-anchored trainer block; the **Ear training** bucket reuses the same grouping with an
    /// ears-only pick action (ADR 0104 Slice 2), so both stay one implementation.
    private var loopGroups: [PickGroup] { loopGroups(makeRow: loopRow) }
    private var earLoopGroups: [PickGroup] { loopGroups(makeRow: earLoopRow) }

    /// Every unit in a bucket, flat and A→Z (the `@Query` order) — the **All** escape hatch each
    /// grouped level offers (ADR 0127). The grouping is still the way in; this is for the times you
    /// know the drill's name but not which template it was made under.
    ///
    /// The exercise rows take the **template** as their context line, because in the grouped list
    /// that fact was carried by the section you had to walk through to get there. Loop and ear rows
    /// already show their song, so they're the same rows the groups render.
    private var allExerciseRows: [PickRow] {
        exercises.map { exerciseRow($0, showsTemplate: true) }
    }
    private var allLoopRows: [PickRow] { trainableLoops.map(loopRow) }
    private var allEarLoopRows: [PickRow] { trainableLoops.map(earLoopRow) }

    private func loopGroups(makeRow: (Loop) -> PickRow) -> [PickGroup] {
        let bySong = Dictionary(grouping: trainableLoops) { $0.song?.title ?? "" }
        return bySong.keys.sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty { return !lhs.isEmpty }  // "No song" sinks to the bottom
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { key in
            let members = bySong[key] ?? []
            return PickGroup(id: key.isEmpty ? "\u{0}nosong" : key,
                             title: key.isEmpty ? "No song" : key,
                             icon: "music.note", rows: members.map(makeRow))
        }
    }

    /// The newest units across both types, one tap away. Exercises carry a real `dateAdded`;
    /// loops have none, so their parent song's added date stands in (a loop's recency ≈ its
    /// song's) — good enough for a shortcut, and undated units simply sink.
    private var recentlyAdded: [PickRow] {
        let dated: [(date: Date, row: PickRow)] =
            exercises.map { ($0.dateAdded, exerciseRow($0)) }
            + trainableLoops.map { ($0.song?.dateAdded ?? .distantPast, loopRow($0)) }
            + playableSongs.map { ($0.dateAdded ?? .distantPast, songRow($0)) }
        return dated.sorted { $0.date > $1.date }.prefix(6).map(\.row)
    }

    /// An exercise row. `showsTemplate` is on only in the flat **All exercises** list, where the
    /// template has to move onto the row — in the grouped list it's the section you walked through.
    private func exerciseRow(_ exercise: Exercise, showsTemplate: Bool = false) -> PickRow {
        row(.exercise(exercise), title: exercise.name.isEmpty ? "Untitled" : exercise.name,
            context: showsTemplate ? exercise.template.displayName : nil,
            progress: exercise.commandProgressLabel)
    }

    private func loopRow(_ loop: Loop) -> PickRow {
        row(.loop(loop), title: loop.name.isEmpty ? "Untitled loop" : loop.name,
            context: loop.song?.title,
            progress: "Command \(Int((loop.command * 100).rounded()))%", previewLoop: loop)
    }

    /// The ear-training variant of `loopRow` — same loop, but the pick adds an ears-only block
    /// (ADR 0104). The prefixed `pickID` keeps it distinct from the trainer row in the shared
    /// grouping, and lets one routine hold both blocks for the same loop.
    private func earLoopRow(_ loop: Loop) -> PickRow {
        row(.earLoop(loop), title: loop.name.isEmpty ? "Untitled loop" : loop.name,
            context: loop.song?.title, progress: "Ear training", previewLoop: loop)
    }

    private func songRow(_ song: Song) -> PickRow {
        row(.song(song), title: song.title.isEmpty ? "Untitled song" : song.title,
            context: song.artist.isEmpty ? nil : song.artist, progress: "Play-along")
    }

    /// The one place a `PickRow` is built — so every bucket's row derives its id, its added state
    /// and its toggle from the same `RoutineUnitPick`, and none of the four can drift from the
    /// others (a row whose id didn't match its pick would check the wrong row on add).
    private func row(_ pick: RoutineUnitPick, title: String, context: String?,
                     progress: String, previewLoop: Loop? = nil) -> PickRow {
        PickRow(id: pick.pickID, title: title, context: context, progress: progress,
                pick: { onToggle(pick) }, previewLoop: previewLoop,
                isAdded: addedIDs.contains(pick.pickID))
    }
}
