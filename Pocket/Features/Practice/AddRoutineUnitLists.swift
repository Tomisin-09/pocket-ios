import SwiftUI

/// The drill-in levels and value projections behind `AddRoutineUnitSheet`. Split out of that file
/// when the picker gained multi-add (ADR 0127), to keep both under the 400-line cap.

/// A unit the add-to-routine picker can put into — or take back out of — the routine being edited
/// (ADR 0127). One callback carries all four bucket types so the sheet has a single seam, and
/// `pickID` is the **one** definition of a row's identity: the picker keys its "added" checkmarks
/// on it and the editor keys the block it created on the same string, so the two can never drift.
enum RoutineUnitPick {
    case exercise(Exercise)
    case loop(Loop)
    /// The same `Loop`, added as an ears-only block (ADR 0104 Slice 2) — a *different* pick from
    /// `.loop`, hence the prefixed id: both may sit in one routine.
    case earLoop(Loop)
    case song(Song)

    /// Stable per-row identity. A `Song` has no business `uid`; its import `sourceID` (a UUID
    /// string for local files) stands in, as it already does in the library lists.
    var pickID: String {
        switch self {
        case .exercise(let exercise): return exercise.uid.uuidString
        case .loop(let loop): return loop.uid.uuidString
        case .earLoop(let loop): return "ear-" + loop.uid.uuidString
        case .song(let song): return song.sourceID
        }
    }
}

/// A list of **sub-buckets** — the middle level of the picker (Exercises→templates,
/// Loops→songs). Each row is a group that drills into its `UnitPickList`. Kept dumb (a rendered
/// array of `PickGroup`) so the sheet owns all querying.
///
/// The grouping stays the **primary** way in, but it assumes you know which template a drill was
/// made under — so a first section offers **All …**, the same units flat and A→Z (ADR 0127). It's a
/// section of its own rather than a ninth group: it isn't a peer of the groups, it's the way past
/// them. Hidden when there's only one group, where it would just be that group again.
struct GroupPickList: View {
    let title: String
    let groups: [PickGroup]
    /// Every unit in this bucket, flat. Empty = no **All** row (the Songs bucket, already flat,
    /// never renders this level at all).
    var allRows: [PickRow] = []

    /// "Exercises" → "All exercises". The bucket already names itself; this only has to say *all*.
    private var allTitle: String { "All " + title.lowercased() }

    var body: some View {
        List {
            if groups.count > 1 && !allRows.isEmpty {
                Section {
                    NavigationLink {
                        UnitPickList(title: allTitle, rows: allRows)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "list.bullet")
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.practice)
                                .frame(width: 28)
                            Text(allTitle)
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textPrimary)
                            Spacer(minLength: 8)
                            Text("\(allRows.count)")
                                .font(.pocketMono(.body))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .accessibilityLabel("\(allTitle), \(allRows.count)")
                    }
                    .listRowBackground(PocketColor.background)
                }
            }

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
struct UnitPickList: View {
    let title: String
    let rows: [PickRow]
    /// The row currently auditioning (loops/ear), so only one plays at a time on this screen.
    @State private var playingID: String?

    var body: some View {
        List {
            if rows.isEmpty {
                Text("Nothing here yet.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(rows) { row in
                    AddRoutineUnitRow(row: row, playingID: $playingID)
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
struct PickGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let rows: [PickRow]
}

/// A single pickable unit projected for display — the row's text plus the action that toggles it
/// in or out of the routine. Decouples the list UI from `Exercise`/`Loop` so both flow through one
/// row. `previewLoop` (loops/ear rows only) carries the loop to **audition** in the row (ADR 0104
/// Slice 2 follow-up) so indistinctly-named loops can be told apart by ear; `nil` = no preview
/// affordance. `isAdded` is owned by the editor, not the row: the sheet is handed the set of
/// already-added ids each render, so nothing about what's in the routine lives in this layer.
struct PickRow: Identifiable {
    let id: String
    let title: String
    let context: String?
    let progress: String
    /// Toggle: adds the unit to the routine, or removes the block this sheet session added.
    let pick: () -> Void
    var previewLoop: Loop?
    /// Whether this sheet session has already put the unit in the routine (ADR 0127).
    var isAdded: Bool = false
}
