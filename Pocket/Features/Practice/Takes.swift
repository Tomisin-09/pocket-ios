import SwiftUI

/// Relisten to **practice takes** (ADR 0069, slice 3) — the audio counterpart to the journal. The
/// full playable list (`TakesSheet`) is reached from the compact `PracticeReviewBar`; takes are the
/// app's own AAC files, played by a shared `RecordingPlayer`. Owner-agnostic via `RecordingOwner`,
/// so the same UI serves loops, exercises, and songs.

/// The full playable Takes list — one row per take with a play/pause toggle, rename, and delete.
/// Owns the `RecordingPlayer` (one take plays at a time) and stops it on dismiss. Delete is handled
/// by the caller (`onDelete`) so the model-context write stays at the owning screen.
///
/// **Delete is a hold, not a swipe, and it is undoable** (2026-08-06). Both used to be the other way
/// round, which made this the easiest place in the app to lose a recording: a swipe is the cheapest
/// gesture in a list, and `onDelete` removes the AAC file from disk. A take has no source to
/// regenerate it from — unlike an exercise, which can be rebuilt from the same idea — so the gesture
/// now costs what the mistake does, and the deferral means the file survives until the toast does.
struct TakesSheet: View {
    let owner: RecordingOwner
    let onDelete: (Recording) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var player = RecordingPlayer()
    /// The take being named, by stable `uid` — never `persistentModelID` (ADR 0090).
    @State private var renaming: StableRef<Recording>?
    /// Deferred, undoable deletion, sheet-owned. The host screens are untouched: their existing
    /// `onDelete` becomes the *deferred action* rather than the immediate one.
    @State private var rowDeletion = RowDeletionCoordinator()

    /// Newest-first, minus anything awaiting deletion — so the row leaves on the request and comes
    /// back on Undo, and the empty state follows without a second rule.
    private var takes: [Recording] {
        owner.recordingsByRecent.filter { !rowDeletion.isPending($0.uid) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if takes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Takes")
            .navigationBarTitleDisplayMode(.inline)
            .background(PocketColor.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Above the list-vs-empty-state branch, so deleting the last take doesn't take the toast with
        // it when the sheet swaps to its empty view.
        .pocketRowUndoHost(rowDeletion)
        .onDisappear { player.stop() }
        .renameTakeAlert($renaming, context: modelContext)
    }

    private var list: some View {
        List {
            ForEach(takes, id: \.uid) { take in
                TakeRow(take: take, isPlaying: player.isPlaying(take.fileName)) {
                    player.toggle(take.fileName)
                }
                .listRowBackground(PocketColor.background)
                // Rename leads, because a list of identical "Take" rows is the problem this sheet
                // has. Not `role: .destructive` — this button changes nothing until you type.
                .swipeActions(edge: .leading) {
                    Button { renaming = StableRef(value: take) } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(PocketColor.practice)
                }
                // The same two verbs on a hold, matching the Journal's take rows — a swipe is only
                // discoverable by trying it, and this list's rows are the ones most in need of a name.
                .contextMenu {
                    Button {
                        renaming = StableRef(value: take)
                    } label: {
                        Label(take.title == nil ? "Name this take" : "Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) { delete(take) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    /// Hide the row, raise the Undo toast, and hand the real delete to the owning screen only once the
    /// window closes — `onDelete` removes the audio file, so nothing irreversible happens while Undo
    /// is still on screen. The player stops up front rather than in the deferred closure: hearing a
    /// take you just deleted keep playing is its own kind of wrong.
    private func delete(_ take: Recording) {
        if player.isPlaying(take.fileName) { player.stop() }
        let name = take.title.map { "“\($0)”" } ?? "this take"
        rowDeletion.request(PocketRowDelete(id: take.uid, name: name) { onDelete(take) })
        haptic(.light)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No takes yet")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            // Surface-neutral: this sheet now also serves a freeform block, which has no arm and no
            // Start training to arm against (ADR 0069 amendment).
            Text("Record while you practise to capture your playing.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One take row — a play/pause toggle, the date, and the duration.
private struct TakeRow: View {
    let take: Recording
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.futura(.title))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause take" : "Play take")

            VStack(alignment: .leading, spacing: 2) {
                // A named take leads with its name; an unnamed one keeps the date it always had, so
                // nothing about an old list changes until the player names something.
                Text(take.title ?? take.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                HStack(spacing: 8) {
                    Text(take.durationLabel)
                    if take.title != nil {
                        Text(take.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .font(.pocketMono(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
