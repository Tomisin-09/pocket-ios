import SwiftData
import SwiftUI

/// What a tapped routine block previews — an exercise or a loop, resolved into the app context.
/// Identifiable so `RoutineDetailView` can drive a `navigationDestination(item:)` push.
enum RoutineBlockPreviewTarget: Identifiable, Hashable {
    case exercise(Exercise)
    case loop(Loop)

    var id: PersistentIdentifier {
        switch self {
        case .exercise(let exercise): return exercise.persistentModelID
        case .loop(let loop): return loop.persistentModelID
        }
    }
}

/// A **read-only, pre-start preview** of an exercise block (ADR 0071 R4b): shows *what* you'll play
/// (the template content rendered) and *how* (the tempo anchors + the staircase), plus a short
/// command-tempo **audio preview** — so you understand every block from the routine before you start,
/// removing the need for previews mid-session. It is deliberately read-only (no engine, no promote,
/// no Start): it reads the exercise's stored values and composes the same standalone content cards the
/// run screen uses. Deeper tuning stays behind the **Details** button (`ExerciseDetailSheet`).
struct ExerciseBlockPreview: View {
    let exercise: Exercise
    @State private var preview = CommandTempoPreviewPlayer()
    @State private var strumPreview = StrumPatternPreviewPlayer()
    @State private var showingDetail = false

    /// The strum pattern to audition, if this is a strumming or strum-&-chords drill (R5). Other
    /// templates have no strum rhythm, so they fall back to the plain command-tempo click.
    private var strumPattern: StrumPattern? {
        exercise.strumPattern ?? exercise.strumChordSheet?.strumPattern
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let pattern = exercise.strumPattern { StrumPatternPreview(pattern: pattern) }
                if let drill = exercise.fretboardDrill { FretboardExercisePreview(drill: drill) }
                if let progression = exercise.chordProgression {
                    ChordProgressionPreview(progression: progression)
                }
                if let sheet = exercise.strumChordSheet { StrumChordsPreview(sheet: sheet) }

                PreviewTempoReadout(anchors: "\(exercise.workingTempo) → \(exercise.command)",
                                    reach: "\(exercise.derivedTarget)", unit: "BPM")
                RoutineStairs(plateaus: exercise.ramp.plateaus, tint: PocketColor.practice)
                    .frame(height: 120)
                if let strumPattern {
                    PreviewAudioButton(isPlaying: strumPreview.isPlaying,
                                       idleTitle: "Hear the strum") {
                        strumPreview.toggle(pattern: strumPattern, signature: signature,
                                            bpm: exercise.command)
                    }
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear command tempo") {
                        preview.toggle(bpm: exercise.command, signature: signature)
                    }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop(); strumPreview.stop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingDetail = true; haptic(.light) } label: {
                    Image(systemName: "info.circle")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("Exercise details")
            }
        }
        .sheet(isPresented: $showingDetail) { ExerciseDetailSheet(exercise: exercise) }
    }

    private var signature: TimeSignature {
        TimeSignature.forStored(beats: exercise.beatsPerBar, noteValue: exercise.noteValue,
                                accentBeats: exercise.accentBeats)
    }
}

/// A **read-only, pre-start preview** of a loop block (ADR 0071 R4b): its source song, the speed
/// anchors + staircase, and a short **audio audition of the loop's actual audio** (the looping region
/// at command speed) — the loop analogue of the exercise preview. Read-only; no engine setup, no run.
struct LoopBlockPreview: View {
    let loop: Loop
    @State private var preview: LoopAudioPreviewPlayer

    init(loop: Loop) {
        self.loop = loop
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let song = loop.song {
                    VStack(spacing: 4) {
                        Text(song.title.isEmpty ? "Untitled song" : song.title)
                            .font(.futura(.title3, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.subheadline))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }

                PreviewTempoReadout(anchors: "\(loop.ramp.working)% → \(loop.ramp.command)%",
                                    reach: "\(loop.ramp.target)%", unit: "of original")
                RoutineStairs(plateaus: loop.ramp.plateaus, tint: PocketColor.practice)
                    .frame(height: 120)
                if preview.isUnavailable {
                    Text("Audio unavailable — the song file couldn't be found.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear the loop") { preview.toggle() }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(loop.name.isEmpty ? "Loop" : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }
}

// MARK: - Shared preview pieces

/// The tempo/speed anchor line shared by both previews: "working → command · reach", in the unit the
/// block trains in (BPM for exercises, % of original for loops).
private struct PreviewTempoReadout: View {
    let anchors: String
    let reach: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(anchors)
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
            Text("reach \(reach) · \(unit)")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The pill audio-preview button shared by both previews — an audition, not a run (ADR 0070).
private struct PreviewAudioButton: View {
    let isPlaying: Bool
    let idleTitle: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Label(isPlaying ? "Stop preview" : idleTitle,
                  systemImage: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(PocketColor.practice.opacity(0.14), in: Capsule())
        }
    }
}
