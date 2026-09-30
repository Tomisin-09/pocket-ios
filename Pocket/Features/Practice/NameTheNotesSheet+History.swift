import SwiftUI

// **Undo and redo** (ADR 0234 D6), and the row they share with *Next unnamed*. Every change to the pass
// goes through `commit`, which tidies it and remembers what it replaced, so ↶ can put back a fret re-picked,
// a bend, a name, a tap taken out or tapped in, and ↷ can put it back again. The row used to hold *Hear it
// again* and *Next note*: tapping a chip plays it, and placing a note moves on by itself (D3), so both went
// and the history took their place. Split out for file length.
extension NameTheNotesSheet {

    /// ↶ ↷ on the left, *Next unnamed* on the right. Nothing here plays: a chip tap is what's heard.
    var moveButtons: some View {
        HStack(spacing: 10) {
            historyButton("arrow.uturn.backward", label: "Undo", enabled: history.canUndo, action: undoLast)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityIdentifier("naming.undo")
            historyButton("arrow.uturn.forward", label: "Redo", enabled: history.canRedo, action: redoLast)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityIdentifier("naming.redo")
            Spacer(minLength: 0)
            if let gap = NamingStrip.nextUnnamed(after: active, in: labels) {
                Button("Next unnamed") { moveTo(gap) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("naming.nextUnnamed")
            }
        }
        .font(.futura(.subheadline))
        .tint(PocketColor.practice)
        // ⌘Y as well as ⇧⌘Z, the redo a Windows hand reaches for. Zero-sized, so it takes no room.
        .background {
            Button("Redo", action: redoLast)
                .keyboardShortcut("y", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func historyButton(_ symbol: String, label: String, enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(minWidth: 24, minHeight: 24)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Go to a chip without hearing it: *Next unnamed*, and the jumps that aren't a chip tap.
    func moveTo(_ index: Int) {
        guard labels.indices.contains(index) else { return }
        placedNote = nil
        active = index
    }

    // MARK: - The history

    /// The sheet as a step: what undo would put back.
    var currentStep: NamingHistory.Step {
        NamingHistory.Step(taps: taps, openMidi: tuning.openMidi, tuningLabel: tuning.label, active: active)
    }

    /// Write new answers (and, for the instrument sheet, new strings) as **one step**. The joins are tidied
    /// first, so a join the change broke goes in the same step rather than as a second one that would leave
    /// ↶ stuck on it (0227 D5: a join lives on the second note, and moving the first can break it).
    func commit(labeled next: [PieceLabel?], tuning nextTuning: NamingTuning? = nil) {
        var named = taps
        for index in named.indices {
            named[index].label = next.indices.contains(index) ? next[index] : nil
        }
        commit(taps: named, tuning: nextTuning)
    }

    /// Write a new pass (a correction adds or takes out a tap) as one step, tidied.
    func commit(taps next: [PieceTranscription.Tap], tuning nextTuning: NamingTuning? = nil) {
        let before = currentStep
        taps = PassCorrection.tidied(next)
        if let nextTuning { tuning = nextTuning }
        history.record(before, now: currentStep)
    }

    /// ↶: back one step, on the note it changed, and nothing plays.
    func undoLast() {
        guard let step = history.undo(from: currentStep) else { return }
        restore(step)
    }

    /// ↷: the step undone last, again.
    func redoLast() {
        guard let step = history.redo(from: currentStep) else { return }
        restore(step)
    }

    private func restore(_ step: NamingHistory.Step) {
        if player.isSlicePlaying { player.stopSlice() }
        // The ring's taps may have moved under it.
        sounding = nil
        taps = step.taps
        tuning = NamingTuning(openMidi: step.openMidi, label: step.tuningLabel)
        placedNote = nil
        active = step.active
        chipChanged()
    }
}
