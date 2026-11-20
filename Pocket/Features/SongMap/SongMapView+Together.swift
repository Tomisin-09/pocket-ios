import SwiftData
import SwiftUI

/// Picking (ADR 0308 D1, D8), and *Put it together* (ADR 0232 D11): pick pieces on the board, then watch them
/// on the neck or make a routine of them, opened for review. Apart from `SongMapView` only to keep each file
/// within its length budget.
extension SongMapView {

    /// A plan, and the command tempos asked for it, begun once the sheet asking has gone.
    struct TogetherBegin {
        let plan: SongMapTogether.Plan
        let commands: [UUID: Double]
    }

    /// The command tempos Put it together is asking for.
    struct TogetherAsk: Identifiable {
        let id = UUID()
        let plan: SongMapTogether.Plan
        let answers: SongMapCommandSheet.Answers
    }

    /// The routine being reviewed, and the joined loops made for it.
    struct TogetherReview {
        let name: String
        let runs: [SongMapTogether.Run]
        let joined: [Loop]
    }

    // MARK: - Picking

    /// *Pick pieces…* from a piece's hold menu (0308 D1): picking starts, with that piece picked.
    func startPicking(_ uid: UUID) {
        made = nil
        withAnimation(.easeOut(duration: 0.2)) { selection = [uid] }
    }

    /// A section's name (0308 D1): while picking, a tap picks every piece in it or lets them all go; before,
    /// *Pick this section* starts picking with them picked.
    func pickSection(_ section: SongMap.Section, in map: SongMap) {
        guard let picked = selection else {
            made = nil
            withAnimation(.easeOut(duration: 0.2)) { selection = SongMapPicking.pieces(in: section, of: map) }
            return
        }
        selection = SongMapPicking.toggle(section, picked: picked, in: map)
    }

    func toggleSelected(_ uid: UUID) {
        guard var picked = selection else { return }
        if picked.contains(uid) { picked.remove(uid) } else { picked.insert(uid) }
        selection = picked
    }

    /// The bar along the bottom while picking, held clear of the board so the last row can scroll above it.
    @ViewBuilder func pickingBar(_ map: SongMap, sources: [SectionWatch.Source]) -> some View {
        if let selection {
            let reading = SongMapTogether.read(selection, in: map)
            let watch = SongMapPicking.watch(selection, in: map)
            let onWatch = watchDoor(watch, sources: sources)
            SongMapTogetherBar(count: selection.count,
                               lines: pickingLines(watch, canWatch: onWatch != nil, reading: reading, in: map),
                               onWatch: onWatch, onPut: reading.shape == nil ? nil : { putTogether(reading, in: map) },
                               onCancel: { withAnimation(.easeOut(duration: 0.2)) { self.selection = nil } })
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// What the bar says (0308 D8): what's picked and where, then only what needs saying. What stays dark
    /// (D3), why Watch can't open, and why Put it together can't, each when it's so.
    private func pickingLines(_ watch: SongMapPicking.Watch?, canWatch: Bool, reading: SongMapTogether.Reading,
                              in map: SongMap) -> [String] {
        guard let watch else {
            return [map.hasSections ? "Tap pieces, or a section's name, to pick them." : "Tap pieces to pick them."]
        }
        var lines = [watch.barLine]
        if let dark = watch.darkLine { lines.append(dark) }
        if !canWatch {
            lines.append(LoopModeAccess.Facts.audioResolves(song) ? "Nothing picked is placed on the neck yet."
                         : "The song's audio can't play here, so there's nothing to watch.")
        }
        if let cant = SongMapTogether.line(for: reading) { lines.append(cant) }
        return lines
    }

    // MARK: - Putting it together

    /// Ask for any command tempo the Practice blocks or the backing need first (ADR 0138), then begin.
    func putTogether(_ reading: SongMapTogether.Reading, in map: SongMap) {
        guard let shape = reading.shape else { return }
        let plan = SongMapTogether.plan(shape, in: map, songTitle: song.title,
                                        existingNames: song.loops.map(\.name))
        guard let answers = SongMapCommandSheet.Answers(asking: plan, loops: song.loops, place: { uid in
            map.pieces[uid].map { place(of: $0, in: map) } ?? ""
        }) else { return begin(plan, commands: [:]) }
        askingCommands = TogetherAsk(plan: plan, answers: answers)
    }

    /// The command tempos were given: begin once the sheet has gone, since a push can't start under it.
    func beginAfterAsking() {
        guard let begin = beginAfterSheet else { return }
        beginAfterSheet = nil
        self.begin(begin.plan, commands: begin.commands)
    }

    /// Write what the plan needs, the joined loops among it, and open the routine for review. The pieces
    /// stay picked until here, so cancelling the tempo sheet goes back to them.
    func begin(_ plan: SongMapTogether.Plan, commands: [UUID: Double]) {
        selection = nil
        let joined = SongMapWriter.prepare(plan, commands: commands, in: song, context: modelContext)
        onOpenNestedAudio()
        reviewing = TogetherReview(name: plan.name, runs: SongMapTogether.runs(plan, joined: joined.map(\.uid)),
                                   joined: joined)
    }

    /// The routine, built in the review's own context: nothing lands in Routines until Save or Start
    /// (ADR 0111). Built from the song, so Start keeps it rather than running it temporary (ADR 0243 D1).
    @ViewBuilder var togetherReview: some View {
        if let reviewing {
            RoutineDetailView(container: modelContext.container, startsAs: .saved) { context in
                SongMapWriter.routine(named: reviewing.name, runs: reviewing.runs, in: context)
            }
        }
    }

    /// Back on the map from the review: the joined loops drawn heavier for a moment, and Undo for them
    /// (D17) while no saved routine uses them. Once one does, they're its blocks.
    func finishReview() {
        guard let review = reviewing else { return }
        reviewing = nil
        guard let first = review.joined.first else { return }
        let uids = Set(review.joined.map(\.uid))
        highlighted = uids
        guard !SongMapWriter.routineUses(uids, context: modelContext) else { return }
        showMade(review.joined, message: review.joined.count == 1 ? "Made \(first.name)"
                    : "Made \(review.joined.count) joined loops")
    }
}
