import SwiftData
import SwiftUI

/// **Attach to…** (ADR 0264 D5): the owner picker, from a source's screen. *Also attach to…* once the
/// source is filed (`ReferenceFiling`).
///
/// A tap attaches and closes. The share extension's picker (D8) holds a choice for its *Save*, because
/// the thing being saved doesn't exist yet; here it does, so the pick is the save. *Keep for later* isn't
/// offered: the source is either kept for later already, or filed, where a second row with no place and
/// no note would keep nothing.
///
/// What is offered, locked or out of reach is `ReferenceDestinationPicker`'s, over D6's rules. This view
/// turns the store into those values and a pick back into a write; `ReferencePlaceList` draws them.
struct ReferenceAttachSheet: View {
    /// A row of the source, as `ReferenceSourceView` follows it. Re-read here, so the sheet acts on the
    /// source as it is when the pick lands.
    let anchor: UUID

    @Query private var links: [ReferenceLink]
    @Query private var exercises: [Exercise]
    @Query private var routines: [Routine]
    @Query private var songs: [Song]
    @Query private var loops: [Loop]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(PlanStore.self) private var plan: PlanStore?

    var body: some View {
        NavigationStack {
            Group {
                if let source = ReferenceLibrary.source(containing: anchor, in: links) {
                    ReferencePlaceList(rows: rows(for: source), standing: standing) { row in
                        attach(source, to: row.destination)
                    }
                    .navigationTitle(ReferenceFiling.pickerTitle(for: source))
                } else {
                    ContentUnavailableView("This reference has gone", systemImage: "bookmark.slash")
                }
            }
            .background(PocketColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(PocketColor.toolkit)
    }

    /// Where the player stands (D6). Before StoreKit has answered, as a paying player: their drills must
    /// not vanish from the list for that moment, as no lock draws then either (`showsPlanLocks`).
    private var standing: PlanStanding {
        guard plan?.hasResolved != false else { return .onPlan }
        return PlanStanding(access: plan?.access ?? PlanStore.accessWithoutStore,
                            hasBoughtBefore: plan?.hasBoughtBefore ?? false)
    }

    // MARK: - Values

    /// A place and the model behind it, so a pick finds its way back to the owner.
    private struct Candidate {
        let destination: ReferenceDestination
        let owner: any ReferenceLinkOwner
    }

    /// Every place in the library: saved routines only, since a temporary session (ADR 0243) is
    /// replaced by the next Start. Typed statements, not one `+` chain: CI's Xcode 16 timed out on that
    /// shape in slice 1.
    private var candidates: [Candidate] {
        var all: [Candidate] = exercises.map { Candidate(destination: ReferenceDestination(exercise: $0), owner: $0) }
        all += Routine.saved(routines).map { Candidate(destination: ReferenceDestination(routine: $0), owner: $0) }
        all += songs.map { Candidate(destination: ReferenceDestination(song: $0), owner: $0) }
        all += loops.map { Candidate(destination: ReferenceDestination(loop: $0), owner: $0) }
        return all
    }

    private func rows(for source: ReferenceSource) -> [ReferenceDestinationPicker.Row] {
        let all = candidates
        let alreadyOn = Set(source.rows.compactMap { $0.owner.flatMap(ReferenceDestination.key(of:)) })
        // Only a file counts against the five-file cap; a link never fills a place.
        var full: Set<String> = []
        if source.isAttachment {
            full = Set(all.filter { !$0.owner.canAddAttachment }.map(\.destination.id))
        }
        return ReferenceDestinationPicker.rows(all.map(\.destination), for: standing,
                                               alreadyOn: alreadyOn, full: full)
    }

    // MARK: - The pick

    private func attach(_ source: ReferenceSource, to destination: ReferenceDestination) {
        guard let owner = candidates.first(where: { $0.destination.id == destination.id })?.owner else { return }
        guard ReferenceLinkStore.attach(source, to: owner, in: context) != nil else { return }
        try? context.save()
        haptic(.medium)
        dismiss()
    }
}

#Preview("Attach to, on the plan") {
    let day: TimeInterval = 86_400
    let rows = ReferenceDestinationPicker.rows([
        ReferenceDestination(id: "exercise:a", kind: .exercise, name: "CAGED shape 2", lastPracticed: .now),
        ReferenceDestination(id: "song:b", kind: .song, name: "Slow Bend", parent: "Jack Trader",
                             lastPracticed: .now - day),
        ReferenceDestination(id: "loop:c", kind: .loop, name: "Bridge bend", parent: "Slow Bend",
                             lastPracticed: .now - day),
        ReferenceDestination(id: "routine:d", kind: .routine, name: "Morning routine", lastPracticed: .now - 2 * day)
    ], for: .lapsed, alreadyOn: ["song:b"])
    return NavigationStack {
        ReferencePlaceList(rows: rows, standing: .lapsed) { _ in }
            .navigationTitle("Attach to")
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
