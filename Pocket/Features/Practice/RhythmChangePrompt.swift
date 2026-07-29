import SwiftUI

/// The question a **rhythm change** asks when it would revalue a measured command tempo (ADR 0121).
///
/// Changing Rhythm from eighths to sixteenths doubles what each beat demands, so a command of 80
/// stops meaning what it meant when it was earned. There is no safe default here: leaving the number
/// alone silently inflates an achievement, and rescaling it silently rewrites one. So the player is
/// asked, with the arithmetic shown rather than implied — both answers quote the number they produce.
///
/// A plain value + a modifier rather than logic inside the shape sheet, so the prompt can be attached
/// anywhere a rhythm becomes editable later without re-deriving the copy.
struct RhythmChangePrompt: Identifiable, Equatable {
    let id = UUID()
    /// The rhythm the command was measured in.
    let from: NoteRate
    /// The rhythm the drill is moving to.
    let to: NoteRate
    /// The command tempo as it stands, in `from`'s rhythm.
    let command: Int
    /// What the command becomes if the note speed is held (already clamped by `RhythmChange`).
    let rescaledCommand: Int

    /// Build the prompt for a change, or `nil` when nothing is being revalued — a drill with no
    /// measured command, or none bound to a rhythm. The caller can ask for the prompt unconditionally
    /// and let this decide, so the "should we ask?" test lives in one place.
    init?(exercise: Exercise, movingTo newPerBeat: Int, range: ClosedRange<Int>) {
        guard exercise.rhythmChangeRevaluesCommand(to: newPerBeat),
              let bound = exercise.commandNotesPerBeat else { return nil }
        from = NoteRate(perBeat: bound)
        to = NoteRate(perBeat: newPerBeat)
        command = exercise.command
        rescaledCommand = RhythmChange.keepingNoteSpeed(exercise.rhythmTempos, from: bound,
                                                        to: newPerBeat, clampedTo: range).command
    }

    var title: String { "\(from.label) → \(to.label)" }

    /// The trade, in notes per minute — the unit that doesn't change under "keep note speed", which is
    /// what makes that option comprehensible rather than a mysterious halving of the tempo.
    var message: String {
        let earned = RhythmChange.notesPerMinute(bpm: command, perBeat: from.perBeat)
        let now = RhythmChange.notesPerMinute(bpm: command, perBeat: to.perBeat)
        return "You earned \(command) BPM in \(from.label.lowercased()) — \(earned) notes a minute. "
            + "At \(to.label.lowercased()), \(command) BPM is \(now).\n\n"
            + "Keep the same note speed and your command becomes \(rescaledCommand) BPM. "
            + "Or clear it and re-measure at the new rhythm."
    }

    var keepLabel: String { "Keep note speed · \(rescaledCommand) BPM" }
    var reMeasureLabel: String { "Re-measure" }
}

extension View {
    /// Present the rhythm-change question. Deliberately **two answers and no cancel**: the player has
    /// already made the change, and both options are valid resolutions of it — dismissing without
    /// answering is the one outcome that would leave a measured achievement silently revalued.
    func rhythmChangePrompt(_ prompt: Binding<RhythmChangePrompt?>,
                            onKeep: @escaping () -> Void,
                            onReMeasure: @escaping () -> Void) -> some View {
        alert(prompt.wrappedValue?.title ?? "Rhythm changed",
              isPresented: .init(get: { prompt.wrappedValue != nil },
                                 set: { if !$0 { prompt.wrappedValue = nil } }),
              presenting: prompt.wrappedValue) { _ in
            Button(prompt.wrappedValue?.keepLabel ?? "Keep note speed") { onKeep() }
            Button(prompt.wrappedValue?.reMeasureLabel ?? "Re-measure", role: .destructive) {
                onReMeasure()
            }
        } message: { prompt in
            Text(prompt.message)
        }
    }
}
