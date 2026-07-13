import SwiftData
import SwiftUI

/// The **add-unit picker** for the routine editor (ADR 0066, slice 2), structured like the
/// Apple Music **Library** — two levels deep, exactly like Library → Artists → an artist's
/// tracks. The root lists **buckets** (**Exercises**, **Loops**, **Songs**) over a **Recently
/// Added** shortcut. Drilling Exercises/Loops lands not on a flat list but on their **sub-buckets**
/// — Exercises group by their **template** (Strumming, Scales …), Loops group by their **song** —
/// and one more tap opens that group's units; **Songs** is a flat list (a song is the top entity).
/// Exercises come first (the exercises-first direction — technique mode, audio-free, works with an
/// empty library).
///
/// Picking a unit fires the matching callback; the editor both creates the `RoutineItem` and
/// closes this sheet (by flipping its presentation flag), so a pick from any depth dismisses.
struct AddRoutineUnitSheet: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Loop.name) private var loops: [Loop]
    @Query(sort: \Song.title) private var songs: [Song]
    @Environment(\.dismiss) private var dismiss

    let onPickExercise: (Exercise) -> Void
    let onPickLoop: (Loop) -> Void
    let onPickSong: (Song) -> Void

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
                Section {
                    NavigationLink {
                        GroupPickList(title: "Exercises", groups: exerciseGroups)
                    } label: {
                        bucketRow(title: "Exercises", subtitle: "By template",
                                  icon: "metronome", count: exercises.count)
                    }
                    .listRowBackground(PocketColor.background)

                    NavigationLink {
                        GroupPickList(title: "Loops", groups: loopGroups)
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
                }

                if !recentlyAdded.isEmpty {
                    Section("Recently Added") {
                        ForEach(recentlyAdded) { pickButton(for: $0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(PocketColor.practice)
                }
            }
        }
        .presentationDetents([.large])
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

    private func pickButton(for row: PickRow) -> some View {
        Button { row.pick() } label: {
            PracticeUnitRow(title: row.title, context: row.context, progress: row.progress)
        }
        .listRowBackground(PocketColor.background)
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
                             icon: template.iconName, rows: members.map(exerciseRow))
        }
    }

    /// Trainable loops bucketed by their **song**, songs A→Z, loops with no song collected under
    /// "No song" last. Each group drills into its own unit list.
    private var loopGroups: [PickGroup] {
        let bySong = Dictionary(grouping: trainableLoops) { $0.song?.title ?? "" }
        return bySong.keys.sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty { return !lhs.isEmpty }  // "No song" sinks to the bottom
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { key in
            let members = bySong[key] ?? []
            return PickGroup(id: key.isEmpty ? "\u{0}nosong" : key,
                             title: key.isEmpty ? "No song" : key,
                             icon: "music.note", rows: members.map(loopRow))
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

    private func exerciseRow(_ exercise: Exercise) -> PickRow {
        PickRow(id: exercise.uid.uuidString, title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                context: nil,
                progress: "Command \(exercise.command) → \(exercise.reachTempo) BPM",
                pick: { onPickExercise(exercise) })
    }

    private func loopRow(_ loop: Loop) -> PickRow {
        PickRow(id: loop.uid.uuidString, title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                context: loop.song?.title,
                progress: "Command \(Int((loop.command * 100).rounded()))%",
                pick: { onPickLoop(loop) })
    }

    private func songRow(_ song: Song) -> PickRow {
        // A `Song` has no business `uid`; its import `sourceID` (a UUID string for local files) is a
        // stable per-row identity.
        PickRow(id: song.sourceID,
                title: song.title.isEmpty ? "Untitled song" : song.title,
                context: song.artist.isEmpty ? nil : song.artist,
                progress: "Play-along", pick: { onPickSong(song) })
    }
}

/// A list of **sub-buckets** — the middle level of the picker (Exercises→templates,
/// Loops→songs). Each row is a group that drills into its `UnitPickList`. Kept dumb (a rendered
/// array of `PickGroup`) so the sheet owns all querying.
private struct GroupPickList: View {
    let title: String
    let groups: [PickGroup]

    var body: some View {
        List {
            if groups.isEmpty {
                Text("Nothing here yet.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(groups) { group in
                    NavigationLink {
                        UnitPickList(title: group.title, rows: group.rows)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: group.icon)
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.practice)
                                .frame(width: 28)
                            Text(group.title)
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textPrimary)
                            Spacer(minLength: 8)
                            Text("\(group.rows.count)")
                                .font(.pocketMono(.body))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .accessibilityLabel("\(group.title), \(group.rows.count)")
                    }
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A flat, tappable list of pickable units — the leaf destination for a sub-bucket. Kept dumb
/// (a rendered array of `PickRow`) so the sheet owns all querying.
private struct UnitPickList: View {
    let title: String
    let rows: [PickRow]

    var body: some View {
        List {
            if rows.isEmpty {
                Text("Nothing here yet.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(rows) { row in
                    Button { row.pick() } label: {
                        PracticeUnitRow(title: row.title, context: row.context,
                                        progress: row.progress)
                    }
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A sub-bucket projected for display — a named, counted group of units that drills into its own
/// `UnitPickList`. Decouples the middle-level UI from `ExerciseTemplate`/`Song`.
private struct PickGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let rows: [PickRow]
}

/// A single pickable unit projected for display — the row's text plus the action that adds it
/// to the routine. Decouples the list UI from `Exercise`/`Loop` so both flow through one row.
private struct PickRow: Identifiable {
    let id: String
    let title: String
    let context: String?
    let progress: String
    let pick: () -> Void
}
