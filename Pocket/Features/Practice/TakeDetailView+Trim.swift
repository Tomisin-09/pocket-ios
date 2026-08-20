import SwiftUI

/// Trim mode on the take detail screen (ADR 0174). Split from `TakeDetailView` to keep both files
/// inside the 400-line cap, and because this is the destructive half — it deserves reading on its
/// own.
///
/// **Trim is entered deliberately and committed with a confirmation.** Deleting a take is a hold
/// with an undo window, because a take has no source to regenerate from; trimming destroys the same
/// audio and *cannot* offer an undo once the bytes are re-encoded, so the guard is moved forward:
/// the handles only appear from the menu (never a stray touch on the strip, the same reasoning
/// `WaveformCanvas` gives for not making saved-loop edges directly draggable), and the commit says
/// how much goes before it goes.
extension TakeDetailView {

    /// The controls under the strip while trimming — what will be kept, what will go, and the two
    /// ways out.
    @ViewBuilder
    func trimBar(_ span: (start: Double, end: Double)) -> some View {
        let keep = TakeTrim.span(from: span.start, to: span.end, duration: audioDuration)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Keeping \(timecode(keep.end - keep.start))", systemImage: "scissors")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Text("\(timecode(keep.start))–\(timecode(keep.end))")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text("Drag the handles to set what to keep. Play to hear just that part.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 12) {
                Button("Cancel") { cancelTrim() }
                    .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button("Trim") { confirmingTrim = true }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketColor.danger)
                    .disabled(isTrimming || TakeTrim.isNoOp(start: keep.start, end: keep.end,
                                                            duration: audioDuration))
            }
            if isTrimming {
                ProgressView().progressViewStyle(.linear)
            }
        }
        .padding(14)
        .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 12))
    }

    /// What the confirmation says. The numbers are the point — "this can't be undone" means little
    /// without saying what actually goes.
    ///
    /// **Since ADR 0175 there are two things that go**, and the sentence names both: the audio, and
    /// the moments pinned inside it. A note whose passage is being removed is removed with it, and a
    /// player who is about to lose three of them should be told before, not discover it after.
    var trimWarning: String {
        guard let span = trim.bounds else { return "" }
        let keep = TakeTrim.span(from: span.start, to: span.end, duration: audioDuration)
        let removed = TakeTrim.removed(start: keep.start, end: keep.end, duration: audioDuration)
        let dropped = TakeMoments.droppedCount(times: take.moments.map(\.time),
                                               keepStart: keep.start, keepEnd: keep.end)
        let alsoNotes = dropped == 0 ? "" : ", and \(TakeMoments.noteCountPhrase(dropped)) with it"
        return "This removes \(timecode(removed)) from the take\(alsoNotes). "
            + "It can’t be undone — \(timecode(keep.end - keep.start)) is kept."
    }

    var trimFailurePresented: Binding<Bool> {
        Binding(get: { trimFailure != nil }, set: { if !$0 { trimFailure = nil } })
    }

    /// Open trim mode with the handles at the take's own edges, so the first drag narrows from the
    /// whole take rather than from an arbitrary guess at what you meant.
    func beginTrim() {
        player.pause()
        trim = .set(start: 0, end: 1)
    }

    func cancelTrim() {
        trim = .idle
        player.limitPlayback(until: nil)
    }

    /// Move one handle, keeping the span ordered and at least `minLoopWidth` wide, then teach the
    /// player the new end so pressing play auditions the span you are choosing rather than the whole
    /// take. Seeking to the new start on a *start* drag is what makes that audible immediately.
    func moveTrimHandle(_ handle: WaveformGesture.Handle, to fraction: Double) {
        guard let span = trim.bounds else { return }
        let moved = WaveformGesture.movingHandle(handle, toFraction: fraction,
                                                 start: span.start, end: span.end)
        trim = .set(start: moved.start, end: moved.end)
        let keep = TakeTrim.span(from: moved.start, to: moved.end, duration: audioDuration)
        player.limitPlayback(until: keep.end)
        if handle == .start { seek(toTime: keep.start) }
    }

    /// Commit the trim: stop playback, rewrite the file off the main actor, then adopt the length
    /// the file came back with — not the length that was asked for, because the encoder's is the one
    /// that is now true.
    ///
    /// `TakeTrimmer` leaves the take untouched on every failure path, so a throw here means nothing
    /// was lost; the alert says so and trim mode stays open to try again.
    func commitTrim() async {
        guard let span = trim.bounds, !isTrimming else { return }
        let keep = TakeTrim.span(from: span.start, to: span.end, duration: audioDuration)
        guard !TakeTrim.isNoOp(start: keep.start, end: keep.end, duration: audioDuration) else { return }

        // Stop, don't pause: the file underneath the player is about to be replaced.
        player.stop()
        isTrimming = true
        defer { isTrimming = false }

        let fileName = take.fileName
        do {
            let trimmed = try await Task.detached(priority: .userInitiated) {
                try TakeTrimmer.trim(fileName: fileName, from: keep.start, to: keep.end)
            }.value
            take.duration = trimmed
            rebaseMoments(keep: keep, newDuration: trimmed)
            try? modelContext.save()
            trim = .idle
            player.limitPlayback(until: nil)
            haptic(.light)
            await loadWaveform()
        } catch {
            trimFailure = "The take was left as it was. \(error.localizedDescription)"
        }
    }

    /// Move the surviving moments onto the trimmed timeline, and delete the ones whose audio has
    /// gone (ADR 0175). Called **only after** `TakeTrimmer` returns — a trim that throws leaves the
    /// file untouched, and the notes must be left untouched with it.
    ///
    /// The drop decision uses the span the player was shown and agreed to, so what happens here is
    /// exactly what the confirmation counted. The surviving positions are then clamped into the
    /// length the **encoder** produced rather than the one that was asked for, because that is the
    /// audio a mark can now point into.
    private func rebaseMoments(keep: (start: TimeInterval, end: TimeInterval),
                               newDuration: TimeInterval) {
        let ordered = take.momentsByTime
        guard !ordered.isEmpty else { return }
        let outcome = TakeMoments.rebase(times: ordered.map(\.time),
                                         keepStart: keep.start, keepEnd: keep.end)
        for (moment, rebased) in zip(ordered, outcome.kept) {
            guard let rebased else {
                take.moments.removeAll { $0.uid == moment.uid }
                modelContext.delete(moment)
                continue
            }
            moment.time = min(max(rebased, 0), newDuration)
        }
    }
}
