import SwiftData
import SwiftUI

/// The **add-unit picker** for the routine editor (ADR 0066, slice 2), structured like the
/// Apple Music **Library** root: a short list of **buckets** you drill into — **Exercises**,
/// **Loops** (and **Songs** once the player runs them, slice 3) — over a **Recently Added**
/// shortcut so the newest unit is one tap away without drilling. Exercises come first (the
/// exercises-first direction — technique mode, audio-free, works with an empty library).
///
/// Picking a unit fires the matching callback; the editor both creates the `RoutineItem` and
/// closes this sheet (by flipping its presentation flag), so a pick from any depth dismisses.
struct AddRoutineUnitSheet: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Loop.name) private var loops: [Loop]
    @Environment(\.dismiss) private var dismiss

    let onPickExercise: (Exercise) -> Void
    let onPickLoop: (Loop) -> Void

    /// Only loops with a measured command tempo are trainable in a routine (the same gate as the
    /// loop library — an unmeasured loop has no ramp for the player to run).
    private var trainableLoops: [Loop] { loops.filter { $0.commandTempo != nil } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        UnitPickList(title: "Exercises", rows: exerciseRows)
                    } label: {
                        bucketRow(title: "Exercises", subtitle: "Click-only command drills",
                                  icon: "metronome", count: exercises.count)
                    }
                    .listRowBackground(PocketColor.background)

                    NavigationLink {
                        UnitPickList(title: "Loops", rows: loopRows)
                    } label: {
                        bucketRow(title: "Loops", subtitle: "Measured song loops",
                                  icon: "repeat", count: trainableLoops.count)
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

    // MARK: - Row data

    private var exerciseRows: [PickRow] {
        exercises.map { exercise in
            PickRow(id: exercise.uid, title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                    context: nil,
                    progress: "Command \(exercise.command) → \(exercise.derivedTarget) BPM",
                    pick: { onPickExercise(exercise) })
        }
    }

    private var loopRows: [PickRow] {
        trainableLoops.map { loop in
            PickRow(id: loop.uid, title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                    context: loop.song?.title,
                    progress: "Command \(Int((loop.command * 100).rounded()))%",
                    pick: { onPickLoop(loop) })
        }
    }

    /// The newest units across both types, one tap away. Exercises carry a real `dateAdded`;
    /// loops have none, so their parent song's added date stands in (a loop's recency ≈ its
    /// song's) — good enough for a shortcut, and undated units simply sink.
    private var recentlyAdded: [PickRow] {
        let dated: [(date: Date, row: PickRow)] =
            exercises.map { ($0.dateAdded, exerciseRow($0)) }
            + trainableLoops.map { ($0.song?.dateAdded ?? .distantPast, loopRow($0)) }
        return dated.sorted { $0.date > $1.date }.prefix(6).map(\.row)
    }

    private func exerciseRow(_ exercise: Exercise) -> PickRow {
        PickRow(id: exercise.uid, title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                context: nil,
                progress: "Command \(exercise.command) → \(exercise.derivedTarget) BPM",
                pick: { onPickExercise(exercise) })
    }

    private func loopRow(_ loop: Loop) -> PickRow {
        PickRow(id: loop.uid, title: loop.name.isEmpty ? "Untitled loop" : loop.name,
                context: loop.song?.title,
                progress: "Command \(Int((loop.command * 100).rounded()))%",
                pick: { onPickLoop(loop) })
    }
}

/// A flat, tappable list of pickable units — the drill-in destination for a bucket. Kept
/// dumb (a rendered array of `PickRow`) so the sheet owns all querying.
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

/// A single pickable unit projected for display — the row's text plus the action that adds it
/// to the routine. Decouples the list UI from `Exercise`/`Loop` so both flow through one row.
private struct PickRow: Identifiable {
    let id: UUID
    let title: String
    let context: String?
    let progress: String
    let pick: () -> Void
}
