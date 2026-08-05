import SwiftUI

/// Relisten to **practice takes** (ADR 0069, slice 3) — the audio counterpart to the journal. The
/// full playable list (`TakesSheet`) is reached from the compact `PracticeReviewBar`; takes are the
/// app's own AAC files, played by a shared `RecordingPlayer`. Owner-agnostic via `RecordingOwner`,
/// so the same UI serves loops, exercises, and songs.

/// The full playable Takes list — one row per take with a play/pause toggle and swipe-to-delete.
/// Owns the `RecordingPlayer` (one take plays at a time) and stops it on dismiss. Delete is handled
/// by the caller (`onDelete`) so the model-context write stays at the owning screen.
struct TakesSheet: View {
    let owner: RecordingOwner
    let onDelete: (Recording) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var player = RecordingPlayer()
    /// The take being named, by stable `uid` — never `persistentModelID` (ADR 0090).
    @State private var renaming: StableRef<Recording>?

    private var takes: [Recording] { owner.recordingsByRecent }

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
            }
            .onDelete { indexSet in
                indexSet.map { takes[$0] }.forEach(delete)
            }
        }
        .listStyle(.plain)
    }

    private func delete(_ take: Recording) {
        if player.isPlaying(take.fileName) { player.stop() }
        onDelete(take)
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
            Text("Arm recording next to Start training to capture your playing.")
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
