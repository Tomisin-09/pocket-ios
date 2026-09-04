import SwiftData
import SwiftUI

// `AddRoutineUnitSheet`'s search layer, split into this file to keep both under the 400-line cap
// (the sheet's buckets and rows live in `AddRoutineUnitSheet.swift`). It holds no state of its own
// beyond the sheet's `searchText`.

extension AddRoutineUnitSheet {

    // MARK: - Search (ADR 0104 Slice 2 follow-up)
    //
    // A `.searchable` field flattens the buckets into typed result sections across **every** add-routine
    // element — exercises, loops, songs, and ear training (the same loops, ears-only). Matches on the
    // unit name plus a loop/song's song title, case/diacritic-insensitive.

    var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Empty query returns **false**, unlike every other matcher in the app, and that is load-bearing
    /// here: `searchResults` renders "No matches." when all six buckets come back empty, so an empty
    /// query matching everything would flatten the sheet's buckets into a full result list the moment
    /// the field was focused. The call site gates on `isSearching`; this is the second belt.
    private func matches(_ text: String?) -> Bool {
        guard let text, !query.isEmpty else { return false }
        return TextMatch.contains(text, query)
    }

    private var matchingExercises: [Exercise] { exercises.filter { matches($0.name) } }
    /// Search narrows each mode's own population (ADR 0138), so a result section can never offer a
    /// block that mode can't run — the Ear section can surface an unmeasured loop the Loops section
    /// correctly withholds.
    private func matchingLoops(in source: [Loop]) -> [Loop] {
        source.filter { matches($0.name) || matches($0.song?.title) }
    }
    private var matchingTrainerLoops: [Loop] { matchingLoops(in: trainerLoops) }
    private var matchingEarLoops: [Loop] { matchingLoops(in: earLoops) }
    private var matchingImproviseLoops: [Loop] { matchingLoops(in: improviseLoops) }
    private var matchingSongs: [Song] {
        playableSongs.filter { matches($0.title) || matches($0.artist) }
    }

    @ViewBuilder var searchResults: some View {
        if matchingExercises.isEmpty && matchingTrainerLoops.isEmpty && matchingEarLoops.isEmpty
            && matchingImproviseLoops.isEmpty && matchingSongs.isEmpty {
            Text("No matches.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .listRowBackground(PocketColor.background)
        } else {
            resultSection("Exercises", rows: matchingExercises.map { exerciseRow($0) })
            resultSection("Loops", rows: matchingTrainerLoops.map(loopRow))
            // Loops appear again as ear-training picks — the same units, a different block (ADR 0104),
            // and a wider set of them (ADR 0138): ear needs audio, not a measured tempo.
            resultSection("Ear training", rows: matchingEarLoops.map(earLoopRow))
            // And a third time as improvise picks — the narrowest of the three sections, since only
            // flagged backing tracks qualify (ADR 0135).
            resultSection("Improvise", rows: matchingImproviseLoops.map(improviseLoopRow))
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
}
