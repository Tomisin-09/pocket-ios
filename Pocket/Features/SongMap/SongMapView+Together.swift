import SwiftData
import SwiftUI

/// *Put it together* (ADR 0232 D11): pick pieces on the board, and they make a routine, opened for review.
/// Apart from `SongMapView` only to keep each file within its length budget.
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

    /// *Put it together…* from a piece's hold menu: picking starts, with that piece picked. Behind Routines'
    /// own gate (ADR 0144), the one *Build a routine for this song* uses.
    func startTogether(_ uid: UUID) {
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else { return presentPaywall(.routine(.generate)) }
        made = nil
        withAnimation(.easeOut(duration: 0.2)) { selection = [uid] }
    }

    func toggleSelected(_ uid: UUID) {
        guard var picked = selection else { return }
        if picked.contains(uid) { picked.remove(uid) } else { picked.insert(uid) }
        selection = picked
    }

    /// The bar along the bottom while picking, held clear of the board so the last row can scroll above it.
    @ViewBuilder func pickingBar(_ map: SongMap) -> some View {
        if let selection {
            let reading = SongMapTogether.read(selection, in: map)
            SongMapTogetherBar(count: selection.count, line: SongMapTogether.line(for: reading, in: map),
                               canPut: reading.shape != nil, onPut: { putTogether(reading, in: map) },
                               onCancel: { withAnimation(.easeOut(duration: 0.2)) { self.selection = nil } })
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

    /// The routine, built in the review's own context: nothing lands in Routines until Save (ADR 0111).
    @ViewBuilder var togetherReview: some View {
        if let reviewing {
            RoutineDetailView(container: modelContext.container) { context in
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
