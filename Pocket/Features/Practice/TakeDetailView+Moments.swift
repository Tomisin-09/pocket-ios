import SwiftUI

/// **Moments** on the take detail screen (ADR 0175) — notes pinned to points in the audio, marked on
/// the strip and listed underneath. Split from `TakeDetailView` for the same two reasons the trim
/// half was: the 400-line cap, and a section with its own write path reading better on its own.
///
/// The take's whole-take note (ADR 0174) is untouched and still sits above this. They answer
/// different questions — "what was this take like?" against "what happened *here*?" — and collapsing
/// them into one list would have cost a migration to say something neither of them says.
extension TakeDetailView {

    /// Where this take's moments sit on the strip, as `0…1`. Computed in the screen's body and
    /// handed down, so the leaf that draws them keeps its per-tick dependency to the playhead alone
    /// (ADR 0153).
    var momentFractions: [Double] {
        guard audioDuration > 0 else { return [] }
        return take.momentsByTime.map { TakeTrim.fraction(of: $0.time, duration: audioDuration) }
    }

    var momentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Moments")
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                addMomentButton
            }
            if take.moments.isEmpty {
                Text("Play to the bit you want to remember and add a note there. It lands on the "
                     + "strip, and tapping it takes you back.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(take.momentsByTime, id: \.uid) { moment in
                        momentRow(moment)
                        if moment.uid != take.momentsByTime.last?.uid {
                            Divider().overlay(PocketColor.fine)
                        }
                    }
                }
                .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    /// **No live timecode on this label.** "Add note at 1:47" would read `player.position` from the
    /// screen's body and re-execute it twenty times a second — the exact 120 Hz-class invalidation
    /// ADR 0153 exists to prevent, on a screen that also draws a `Canvas` and carries a menu, three
    /// sheets and a confirmation. The position is read **once**, on the tap, and the sheet shows the
    /// time it caught.
    private var addMomentButton: some View {
        Button(action: addMomentHere) {
            Label("Add note here", systemImage: "plus.circle")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.journal)
        }
        .buttonStyle(.plain)
        .disabled(audioDuration <= 0)
        .accessibilityIdentifier(UITestHooks.takeAddMoment)
    }

    /// One moment: its timecode and its words, as **two controls side by side** — never one nested
    /// inside the other.
    ///
    /// A `Button` inside another `Button`'s label is not a second tap target; the outer one swallows
    /// it, and the row would have looked right while the timecode did nothing. Two siblings in an
    /// `HStack`, which is how `JournalTakeRow` splits its play glyph from its title line for exactly
    /// the same reason.
    private func momentRow(_ moment: TakeNote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // The timecode takes you to the audio rather than opening the words, which is the more
            // useful of the two most of the time.
            Button { goTo(moment) } label: {
                Text(moment.timeLabel)
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.journal)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(PocketColor.journal.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play from \(moment.timeLabel)")

            Button { edit(moment) } label: {
                Text(moment.text)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the note")
        }
        .padding(12)
        .contentShape(Rectangle())
        .contextMenu {
            Button { goTo(moment) } label: { Label("Play from here", systemImage: "play") }
            Button { edit(moment) } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) { delete(moment) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Writes

    /// Capture the playhead and open the editor on it. Playback **pauses** first: the note is about
    /// this instant, and a take running on behind the sheet moves the thing you are describing away
    /// from the timestamp you just took.
    func addMomentHere() {
        let caught = player.isLoaded(take.fileName) ? player.position : 0
        player.pause()
        editing = TakeMomentDraft(noteUID: nil, time: min(max(caught, 0), audioDuration), text: "")
    }

    func edit(_ moment: TakeNote) {
        editing = TakeMomentDraft(noteUID: moment.uid, time: moment.time, text: moment.text)
    }

    /// Jump to a moment and play from it — the point of having written it down.
    func goTo(_ moment: TakeNote) {
        seek(toTime: moment.time)
        if !player.isPlaying(take.fileName) { player.resume() }
    }

    func delete(_ moment: TakeNote) {
        // Detach before deleting, so the array this screen renders from doesn't briefly hold a row
        // that no longer exists.
        take.moments.removeAll { $0.uid == moment.uid }
        modelContext.delete(moment)
        try? modelContext.save()
        haptic(.light)
    }
}
