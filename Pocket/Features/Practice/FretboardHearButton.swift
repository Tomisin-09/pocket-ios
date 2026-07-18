import SwiftUI

/// The **audio sibling** of `FretboardPlayOnceButton` (ADR 0097 Slice 3): "Watch" walks the shape
/// visually, "Hear" sounds it *and* walks it. Sequences the run's ordered MIDI through the shared
/// `ToneEngine`, one note at a time (a scale box or arpeggio *is* a melodic line — the sequential case
/// of the same primitive that sounds a chord as a block, ADR 0097 D4.5/D4.6). Hand it the run's
/// `sequence` already mapped to MIDI (`run.sequence.map(CAGEDShape.midi)`); it derives no notes itself,
/// so scales and arpeggios drive it identically and agree with chord audio by construction.
///
/// **Locked to the tracker.** The audio onset stride is `secondsPerNote` — the *same* per-note cadence
/// the `FretboardDrillPreview` walks at (`60 / previewBPM / notesPerBeat`) — and tapping Hear also fires
/// the one-shot `playToken`, so the highlight restarts from note 0 in step with the tone.
///
/// **Tap to play, tap to stop.** While a preview is sounding the button flips to **Stop** and silences it;
/// it also self-resets when the run finishes on its own. The paired view stops the tone on disappear too,
/// so leaving the screen never leaves a preview ringing.
struct FretboardHearButton: View {
    /// The run's notes as MIDI, in playing order (ascending, then the descent when round-trip is on). A
    /// `nil` entry is a **rest** — it keeps its slot in the walk (so a custom drill's empty cells stay
    /// aligned to the highlight) but sounds nothing.
    let notes: [Int?]
    /// Seconds each note occupies on the preview walk — the audio matches it so tone and highlight
    /// advance together (`60 / FretboardDrillPreview.previewBPM / notesPerBeat`).
    let secondsPerNote: Double
    /// The same one-shot token the paired `FretboardDrillPreview` reads: tapping Hear sets it so a single
    /// synced walk-through starts from note 0 alongside the audio.
    @Binding var playToken: Date?
    var tint: Color = PocketColor.practice

    /// Non-nil while a preview is sounding; a background sleep clears it when the run ends naturally so the
    /// label falls back to "Hear". Held as view state so it survives re-renders by view identity.
    @State private var playback: Task<Void, Never>?

    private var isPlaying: Bool { playback != nil }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 4) {
                Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                Text(isPlaying ? "Stop" : "Hear")
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(tint)
        }
        .buttonStyle(.borderless)
        .disabled(!notes.contains { $0 != nil })
        .accessibilityLabel(isPlaying ? "Stop" : "Hear the run")
        .accessibilityHint(isPlaying ? "Stops the preview" : "Plays the notes one at a time, with the highlight")
    }

    private func toggle() {
        haptic(.light)
        if isPlaying { stop(); return }

        playToken = Date()
        // Sound at the walker's cadence: onset stride (noteDuration + gap) == secondsPerNote, with a
        // short release before the next note for articulation without breaking the lock-step.
        let duration = secondsPerNote * 0.9
        ToneEngine.shared.sequence(notes, noteDuration: duration, gap: secondsPerNote - duration)

        let total = Double(notes.count) * secondsPerNote
        playback = Task {
            try? await Task.sleep(for: .seconds(total))
            if !Task.isCancelled { playback = nil }
        }
    }

    private func stop() {
        playback?.cancel()
        playback = nil
        ToneEngine.shared.stop()
    }
}

#Preview("Hear button") {
    struct Harness: View {
        @State private var token: Date?
        var body: some View {
            FretboardHearButton(notes: ScaleRun.aMinorPentatonic.sequence.map { Optional(CAGEDShape.midi($0)) },
                                secondsPerNote: 0.5, playToken: $token)
        }
    }
    return Harness()
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
