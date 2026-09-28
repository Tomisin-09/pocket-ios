import SwiftUI

// **Correcting the count** (ADR 0231), under the strip: take the chip's tap out, or add a note that was
// missed by tapping it on the pad while the stretch around the chip plays. A miscount found while naming no
// longer means counting again. Every correction can be undone until the next change. Split out for file
// length.
extension NameTheNotesSheet {

    /// The two corrections, and under them what the last one did with **Undo**, so a second stray tap can
    /// go straight after the first without the button moving.
    @ViewBuilder var correctionControls: some View {
        if addingNote {
            missedNotePanel
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 18) {
                    link("Missed a \(noun)?") { listenForMissed() }
                        .accessibilityIdentifier("naming.missedNote")
                    if taps.count > 1 {
                        link("Take \(noun) \(active + 1) out") { takeOut() }
                            .accessibilityIdentifier("naming.takeOut")
                    }
                }
                if let undo, undo.isCurrent(for: taps) {
                    HStack(spacing: 18) {
                        hint(undo.said)
                        link("Undo") { undoCorrection(undo) }
                            .accessibilityIdentifier("naming.undoCorrection")
                    }
                }
            }
        }
    }

    /// The stretch playing, the pad waiting for one tap, and a way to hear it again or leave.
    private var missedNotePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            hint(PassCorrection.stretchWords(around: active, count: taps.count, noun: noun)
                 + " Tap once where you hear the \(noun) you missed; it goes in unnamed.")
            TapPad(words: .missed(noun), isLive: player.isSlicePlaying, flashToken: 0, nudgeToken: missedNudge,
                   height: 84) { tapMissed() }
            HStack(spacing: 18) {
                link("Play it again") { listenForMissed() }
                link("Cancel") {
                    addingNote = false
                    player.stopSlice()
                }
            }
        }
    }

    /// Play the stretch around the chip, from the tap before it to the tap after, with the ring following
    /// it, and wait for the pad.
    func listenForMissed() {
        guard let stretch = PassCorrection.stretch(around: active, in: taps.map(\.seconds),
                                                   region: request.region) else { return }
        if player.isPlaying { player.stop() }
        replacing = nil
        awaitingStart = nil
        addingNote = true
        sounding = max(0, active - 1)...min(taps.count - 1, active + 1)
        player.playSlice(from: stretch.from, to: stretch.to)
    }

    /// The pad: a tap added where the ear is now, in song seconds, the way the count placed every other.
    /// With nothing playing it says so rather than guess.
    private func tapMissed() {
        guard let second = player.sliceClock().flatMap(AudioSlice.heardSecond) else {
            missedNudge += 1
            return
        }
        let added = PassCorrection.adding(second, to: taps)
        haptic(.light)
        correct(to: added.taps, selecting: added.index, said: "Added \(noun) \(added.index + 1) where you tapped.")
    }

    private func takeOut() {
        guard let remaining = PassCorrection.removing(at: active, from: taps) else { return }
        correct(to: remaining, selecting: PassCorrection.selection(afterRemoving: active, count: taps.count),
                said: "Took \(noun) \(active + 1) out.")
    }

    /// Apply a correction, tidied first so a join it breaks is gone before Undo remembers the result.
    private func correct(to corrected: [PieceTranscription.Tap], selecting index: Int, said: String) {
        let tidy = PassCorrection.tidied(corrected)
        undo = PassCorrection.Undo(before: taps, after: tidy, selected: active, said: said)
        // The ring's taps have moved under it.
        sounding = nil
        taps = tidy
        active = index
        chipChanged()
    }

    private func undoCorrection(_ undo: PassCorrection.Undo) {
        self.undo = nil
        sounding = nil
        taps = undo.before
        active = undo.selected
        chipChanged()
    }
}
