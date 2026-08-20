import SwiftData
import SwiftUI

/// One **practice take**, on a screen of its own (ADR 0174) — scrub to a point in it, trim it down
/// to what matters, and write a note on it. Reached by tapping a take row in `TakesSheet` or on the
/// Journal feed.
///
/// **The player is passed in, not owned.** Both surfaces that reach here already hold a
/// `RecordingPlayer` for their rows, and one take plays at a time across the whole surface — so a
/// take auditioned from a row and then opened is still the take that is playing, rather than a
/// second player starting it again underneath the first.
///
/// **Delete is not reimplemented here.** It is the `onDelete` closure the takes list already threads
/// down to its owning screen, because that write belongs to the screen that owns the model context —
/// and because `deleteTake` is already duplicated across five run screens, which is four too many to
/// add a sixth to.
struct TakeDetailView: View {
    let take: Recording
    let player: RecordingPlayer
    /// Delete this take — hands back to the takes list's own deferred, undoable delete.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    // Not `private`: `private` is file-scoped, and the trim half of this screen lives in
    // `TakeDetailView+Trim.swift` (the 400-line cap, and the destructive half reads better alone).
    @Environment(\.modelContext) var modelContext

    /// The take's envelope, extracted on open. Not stored on the model: a take is short, the
    /// reduction is cheap, and the alternative is a persisted array with a format version to keep in
    /// step for a screen nobody stands on for long.
    @State var samples: [Double] = []

    /// The take's real length, read off the file alongside the envelope. Preferred over
    /// `take.duration` because it is what the scrubber is scaled by — and after a trim it is the
    /// number that has just changed.
    @State var audioDuration: TimeInterval = 0

    /// The keep-span while trimming, `.idle` when not. `ABSpan` because this is exactly the ordered,
    /// width-clamped two-handle span it already models for loops.
    @State var trim: ABSpan = .idle

    @State private var renaming: StableRef<Recording>?
    // Not `private`: the moments half of this screen lives in `TakeDetailView+Moments.swift`.
    /// The moment being written or edited (ADR 0175), or `nil`. A plain draft rather than a
    /// `StableRef`, because a moment being written for the first time has no row to refer to yet —
    /// see `TakeMomentDraft`.
    @State var editing: TakeMomentDraft?
    @State private var editingNote: StableRef<Recording>?
    @State var confirmingTrim = false
    @State var isTrimming = false
    @State var trimFailure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                scrubber
                transport
                if let span = trim.bounds { trimBar(span) }
                noteSection
                momentsSection
                detailsSection
            }
            .padding(20)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(take.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { actionsMenu } }
        // The player is shared with the list behind this screen, so leaving stops it rather than
        // letting a take play on under a list that shows it as stopped.
        .onDisappear { player.stop() }
        .task(id: take.uid) { await loadWaveform() }
        .renameTakeAlert($renaming, context: modelContext)
        .takeNoteSheet($editingNote, context: modelContext)
        .takeMomentSheet($editing, take: take, context: modelContext)
        .confirmationDialog("Trim this take?", isPresented: $confirmingTrim, titleVisibility: .visible) {
            Button("Trim", role: .destructive) { Task { await commitTrim() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(trimWarning)
        }
        .alert("Couldn’t trim", isPresented: trimFailurePresented) {
            Button("OK", role: .cancel) { trimFailure = nil }
        } message: {
            Text(trimFailure ?? "")
        }
    }

    // MARK: - Sections

    /// What this take was recorded against.
    ///
    /// Computed from the **live** relationship first and only then falling back to the snapshot,
    /// which is the order `JournalTakeRow` already renders in — so the two surfaces can't disagree,
    /// and a renamed loop reads as its new name here rather than the name it had at capture. The
    /// snapshot is what survives the owner's deletion (ADR 0151), so it stays as the fallback rather
    /// than the source.
    private var ownerLabel: String? {
        JournalTimeline.ownerLabel(loop: take.loop, exercise: take.exercise, song: take.song)
            ?? take.ownerLabelAtTake
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ownerLabel {
                Text(ownerLabel)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(take.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// The strip, plus its timecodes — both live in the leaf, because both change on every tick and
    /// ADR 0153 keeps that dependency out of this body.
    private var scrubber: some View {
        PlayheadTakeScrubber(player: player,
                             fileName: take.fileName,
                             duration: audioDuration,
                             samples: samples,
                             trimSpan: trim.bounds,
                             momentFractions: momentFractions,
                             onSeek: { seek(toFraction: $0) },
                             onMoveTrimHandle: moveTrimHandle)
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Spacer(minLength: 0)
            skipButton(seconds: -10, systemImage: "gobackward.10", label: "Back ten seconds")
            Button(action: togglePlayback) {
                Image(systemName: player.isPlaying(take.fileName) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.futura(.largeTitle))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying(take.fileName) ? "Pause take" : "Play take")
            skipButton(seconds: 10, systemImage: "goforward.10", label: "Forward ten seconds")
            Spacer(minLength: 0)
        }
    }

    private func skipButton(seconds: TimeInterval, systemImage: String, label: String) -> some View {
        Button {
            player.seek(to: player.position + seconds)
        } label: {
            Image(systemName: systemImage)
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .buttonStyle(.plain)
        .disabled(!player.isLoaded(take.fileName))
        .accessibilityLabel(label)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Button { editingNote = StableRef(value: take) } label: {
                Text(take.note ?? "What was this take like? What would you change?")
                    .font(.futura(.subheadline))
                    .foregroundStyle(take.hasNote ? PocketColor.textPrimary : PocketColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow("Length", timecode(audioDuration > 0 ? audioDuration : take.duration))
            if let size = RecordingStore.fileSize(fileName: take.fileName) {
                detailRow("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
            }
        }
        .font(.pocketMono(.caption))
        .foregroundStyle(PocketColor.textSecondary)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text(value)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                renaming = StableRef(value: take)
            } label: {
                Label(take.title == nil ? "Name this take" : "Rename", systemImage: "pencil")
            }
            Button {
                editingNote = StableRef(value: take)
            } label: {
                Label(take.hasNote ? "Edit note" : "Add a note", systemImage: "text.alignleft")
            }
            Button { addMomentHere() } label: {
                Label("Add note here", systemImage: "mappin.and.ellipse")
            }
            .disabled(audioDuration <= 0)
            Button { beginTrim() } label: {
                Label("Trim…", systemImage: "scissors")
            }
            .disabled(audioDuration <= TakeTrim.minimumKeep)
            Divider()
            Button(role: .destructive) {
                onDelete()
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Take actions")
    }

    // MARK: - Playback

    private func togglePlayback() {
        if player.isPlaying(take.fileName) {
            player.pause()
        } else if player.isLoaded(take.fileName) {
            player.resume()
        } else {
            player.play(take.fileName)
        }
    }

    /// Scrub to a fraction of the take. Labelled `toFraction:` rather than `to:` so an unapplied
    /// reference to it can't be confused with the seconds-based `seek(toTime:)` — `TimeInterval` is
    /// `Double`, so the two would otherwise be indistinguishable at a call site that passes the
    /// method itself as a closure.
    func seek(toFraction fraction: Double) {
        seek(toTime: TakeTrim.time(at: fraction, duration: audioDuration))
    }

    /// Move the playhead to a position in seconds. A take that has never been played has no loaded
    /// player to seek, so the first scrub loads it **paused** at that point rather than doing
    /// nothing — dragging the strip of a stopped take should move its playhead, not start it.
    func seek(toTime target: TimeInterval) {
        if player.isLoaded(take.fileName) {
            player.seek(to: target)
        } else if player.play(take.fileName, from: target) {
            player.pause()
        }
    }

    // MARK: - Loading

    func loadWaveform() async {
        let fileName = take.fileName
        let extracted = await Task.detached(priority: .userInitiated) { () -> (TimeInterval, [Double])? in
            guard let url = try? RecordingStore.url(for: fileName),
                  let result = try? WaveformExtractor.extract(from: url, buckets: 256) else { return nil }
            return (result.duration, result.amplitudes)
        }.value
        guard let extracted else { return }
        audioDuration = extracted.0
        samples = extracted.1
    }
}
